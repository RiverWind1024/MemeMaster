import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../core/database/daos/sync_state_dao.dart';
import '../core/database/database.dart';
import '../core/repositories/album_repository.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';
import 'object_store.dart';
import 's3_manifest.dart';
import 's3_secret_store.dart';
import 's3_sync_serializer.dart';

/// 对象键约定（必须与 Task 6 / 清理逻辑保持一致）。
const _manifestKey = 'sync/manifest.json';
const _memePrefix = 'sync/memes/';
const _albumPrefix = 'sync/albums/';
const _blobPrefix = 'blobs/';

/// 本地逻辑时钟在 SyncStateDao 中的 key。
const _clockKey = 'sync_clock';

/// 本地 deviceId 在 S3SecretStore 中的 key。
const _deviceIdKey = 'device_id';

/// 单次同步的计数结果。
class SyncResult {
  int pushed = 0;
  int pulled = 0;
  int deleted = 0;
  int imagesUploaded = 0;
  int imagesDownloaded = 0;
  int failed = 0;
}

/// 三阶段 LWW 同步引擎。
///
/// 只依赖 [ObjectStore] 与各 Repository，因此可在无网络、无 Flutter 插件的
/// 环境下用 [InMemoryObjectStore] 做全量单测。
///
/// 阶段：
///   1. 推送：本地比远端新的实体（含墓碑）上传 json + 图片 blob；
///   2. 拉取：远端比本地新的实体下载并落库（先相册后 meme 以满足外键）；
///   3. 收敛：写回 manifest、逻辑时钟与 last_sync_at。
class SyncEngine {
  final ObjectStore _store;
  final MemeRepository _memeRepo;
  final AlbumRepository _albumRepo;
  final AppDatabase _db;
  final SyncStateDao _syncStateDao;
  final S3SecretStore _secretStore;
  final FileStorageService _storage;
  final String? _deviceIdOverride;

  SyncEngine({
    required ObjectStore store,
    required MemeRepository memeRepo,
    required AlbumRepository albumRepo,
    required AppDatabase db,
    required SyncStateDao syncStateDao,
    required S3SecretStore secretStore,
    required FileStorageService storage,
    String? deviceId,
  })  : _store = store,
        _memeRepo = memeRepo,
        _albumRepo = albumRepo,
        _db = db,
        _syncStateDao = syncStateDao,
        _secretStore = secretStore,
        _storage = storage,
        _deviceIdOverride = deviceId;

  /// 图片 blob 的对象键。
  String blobKey(String hash) => '$_blobPrefix$hash';

  /// 生成或读取稳定的本机 deviceId。
  Future<String> _deviceId() async {
    if (_deviceIdOverride != null && _deviceIdOverride.isNotEmpty) {
      return _deviceIdOverride;
    }
    var id = await _secretStore.read(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'dev-${DateTime.now().microsecondsSinceEpoch}';
      await _secretStore.write(_deviceIdKey, id);
    }
    return id;
  }

  Future<Manifest> _loadManifest() async {
    final bytes = await _store.getBytes(_manifestKey);
    if (bytes == null) return Manifest.empty();
    return Manifest.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
  }

  /// 执行一次双向同步（三阶段 LWW）。
  Future<SyncResult> sync() async {
    final result = SyncResult();
    final remote = await _loadManifest();
    final deviceId = await _deviceId();

    // 逻辑时钟：不小于已知远端最大 updatedAt，也不小于本地已存时钟。
    var clock = remote.maxUpdatedAt();
    final localClock =
        int.tryParse(await _syncStateDao.get(_clockKey) ?? '') ?? 0;
    if (localClock > clock) clock = localClock;

    // memes/albums 用 Map.of 生成可变副本，阶段 1/2 直接原地修改。
    final newManifest = Manifest(
      schema: Manifest.currentSchema,
      generatedAt: DateTime.now().millisecondsSinceEpoch,
      lastWriter: deviceId,
      clock: clock,
      memes: Map.of(remote.memes),
      albums: Map.of(remote.albums),
      userStatsUpdatedAt: remote.userStatsUpdatedAt,
    );

    // ---- 阶段 1：推送本地变更 ----
    final localMemes = await _db.memeDao.getAllIncludingDeleted();
    for (final meme in localMemes) {
      try {
        final remoteEntry = remote.memes[meme.id];
        final isChanged =
            remoteEntry == null || meme.updatedAt > remoteEntry.updatedAt;
        if (!isChanged) continue;

        // 逻辑时钟兜底：确保推送时间戳大于已知远端时钟。
        final stamp = meme.updatedAt > clock ? meme.updatedAt : clock + 1;

        if (meme.deletedAt != null) {
          await _store.putBytes(
              '$_memePrefix${meme.id}.json', _encode(_tombstoneJson(meme, stamp)));
          newManifest.memes[meme.id] = ManifestEntry(
            updatedAt: stamp,
            deletedAt: meme.deletedAt,
            hash: meme.fileHash,
            ext: _ext(meme.filePath),
          );
        } else {
          final data = await _buildMemeData(meme.copyWith(updatedAt: stamp));
          await _store.putBytes('$_memePrefix${meme.id}.json', _encode(data.toJson()));
          await _uploadBlobIfMissing(meme.filePath, meme.fileHash, result);
          newManifest.memes[meme.id] = ManifestEntry(
            updatedAt: stamp,
            hash: meme.fileHash,
            ext: _ext(meme.filePath),
          );
        }

        // 把逻辑时钟推进后的时间戳写回本地，保证 manifest 与本地一致。
        if (stamp != meme.updatedAt) {
          await _db.memeDao.touchUpdatedAt(meme.id, stamp);
        }
        result.pushed++;
      } catch (_) {
        result.failed++;
      }
    }

    // 相册推送
    final localAlbums = await _albumRepo.getAll();
    for (final album in localAlbums) {
      try {
        final remoteEntry = remote.albums[album.id];
        final rev = album.updatedAt > 0 ? album.updatedAt : album.createdAt;
        if (remoteEntry != null && rev <= remoteEntry.updatedAt) continue;

        final stamp = rev > clock ? rev : clock + 1;
        await _store.putBytes(
            '$_albumPrefix${album.id}.json', _encode(_albumJson(album, stamp)));
        newManifest.albums[album.id] = ManifestEntry(updatedAt: stamp);
        if (stamp != album.updatedAt) {
          await _touchAlbum(album.id, stamp);
        }
        result.pushed++;
      } catch (_) {
        result.failed++;
      }
    }

    // ---- 阶段 2：拉取远端变更 ----
    // 先拉相册，保证随后 meme 的 meme_albums 外键可满足。
    for (final entry in remote.albums.entries) {
      try {
        final local = await _albumRepo.getById(entry.key);
        if (local != null && local.updatedAt >= entry.value.updatedAt) continue;
        final bytes = await _store.getBytes('$_albumPrefix${entry.key}.json');
        if (bytes == null) {
          result.failed++;
          continue;
        }
        await _applyAlbum(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        newManifest.albums[entry.key] = entry.value;
        result.pulled++;
      } catch (_) {
        result.failed++;
      }
    }

    for (final entry in remote.memes.entries) {
      try {
        final id = entry.key;
        final remoteEntry = entry.value;
        final local = await _db.memeDao.getByIdIncludingDeleted(id);
        if (local != null && local.updatedAt >= remoteEntry.updatedAt) continue;

        if (remoteEntry.deletedAt != null) {
          if (local != null && local.deletedAt == null) {
            await _db.memeDao.softDeleteWithTimestamp(id, remoteEntry.deletedAt!);
            // 让本地 updatedAt 与远端墓碑时间戳对齐，避免重复拉取。
            await _db.memeDao.touchUpdatedAt(id, remoteEntry.updatedAt);
            result.deleted++;
          }
          newManifest.memes[id] = remoteEntry;
          continue;
        }

        final bytes = await _store.getBytes('$_memePrefix$id.json');
        if (bytes == null) {
          result.failed++;
          continue;
        }
        final data = MemeSyncData.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        await _applyMeme(data);
        await _downloadBlobIfMissing(data, result);
        newManifest.memes[id] = remoteEntry;
        result.pulled++;
      } catch (_) {
        result.failed++;
      }
    }

    // ---- 阶段 3：收敛 ----
    // newManifest.memes/albums 是可变 Map，阶段 1/2 已原地更新，直接写回即可。
    await _store.putBytes(_manifestKey, _encode(newManifest.toJson()));
    await _syncStateDao.set(_clockKey, clock.toString());
    await _syncStateDao.setLastSyncAt(DateTime.now().millisecondsSinceEpoch);
    return result;
  }

  // ---- 辅助 ----

  Future<MemeSyncData> _buildMemeData(Meme meme) async {
    final tags = await _memeRepo.getTags(meme.id);
    final colors = await _memeRepo.getColors(meme.id);
    final albumIds = await _albumRepo.getAlbumIdsByMeme(meme.id);
    return MemeSyncData(
        meme: meme, tags: tags, colors: colors, albumIds: albumIds);
  }

  Future<void> _applyMeme(MemeSyncData data) async {
    await _db.transaction(() async {
      await _db.into(_db.memesTable).insertOnConflictUpdate(data.meme);
      await (_db.delete(_db.tagsTable)
            ..where((t) => t.memeId.equals(data.meme.id)))
          .go();
      await (_db.delete(_db.colorsTable)
            ..where((t) => t.memeId.equals(data.meme.id)))
          .go();
      await (_db.delete(_db.memeAlbumsTable)
            ..where((t) => t.memeId.equals(data.meme.id)))
          .go();
      for (final t in data.tags) {
        await _db.into(_db.tagsTable).insertOnConflictUpdate(t);
      }
      for (final c in data.colors) {
        await _db.into(_db.colorsTable).insertOnConflictUpdate(c);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final albumId in data.albumIds) {
        await _db.into(_db.memeAlbumsTable).insertOnConflictUpdate(
            MemeAlbum(memeId: data.meme.id, albumId: albumId, addedAt: now));
      }
    });
  }

  Future<void> _applyAlbum(Map<String, dynamic> j) async {
    await _db.into(_db.albumsTable).insertOnConflictUpdate(Album(
          id: j['id'] as String,
          name: j['name'] as String,
          icon: j['icon'] as String?,
          sortOrder: j['sortOrder'] as int,
          isDefault: j['isDefault'] as int,
          createdAt: j['createdAt'] as int,
          updatedAt: j['updatedAt'] as int? ?? 0,
        ));
  }

  Future<void> _uploadBlobIfMissing(
      String filePath, String hash, SyncResult result) async {
    if (hash.isEmpty) return;
    if (await _store.exists(blobKey(hash))) return;
    final file = await _storage.getImage(filePath);
    if (await file.exists()) {
      await _store.uploadFile(blobKey(hash), file.absolute.path);
      result.imagesUploaded++;
    }
  }

  Future<void> _downloadBlobIfMissing(
      MemeSyncData data, SyncResult result) async {
    final hash = data.meme.fileHash;
    if (hash.isEmpty) return;
    if (!await _store.exists(blobKey(hash))) return; // 远端没有图，跳过
    final file = await _storage.getImage(data.meme.filePath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await _store.downloadToFile(blobKey(hash), file.absolute.path);
      result.imagesDownloaded++;
    }
  }

  Future<void> _touchAlbum(String albumId, int ts) async {
    await (_db.update(_db.albumsTable)..where((t) => t.id.equals(albumId)))
        .write(AlbumsTableCompanion(updatedAt: Value(ts)));
  }

  Map<String, dynamic> _albumJson(Album a, int stamp) => {
        'id': a.id,
        'name': a.name,
        'icon': a.icon,
        'sortOrder': a.sortOrder,
        'isDefault': a.isDefault,
        'createdAt': a.createdAt,
        'updatedAt': stamp,
      };

  Map<String, dynamic> _tombstoneJson(Meme m, int stamp) => {
        'id': m.id,
        'updatedAt': stamp,
        'deletedAt': m.deletedAt,
        'fileHash': m.fileHash,
      };

  Uint8List _encode(Map<String, dynamic> j) =>
      Uint8List.fromList(utf8.encode(jsonEncode(j)));

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot) : '';
  }
}
