import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../core/database/daos/sync_state_dao.dart';
import '../core/database/database.dart';
import '../core/repositories/album_repository.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';
import 'log_service.dart';
import 'object_store.dart';
import 's3_keys.dart';
import 's3_manifest.dart';
import 's3_secret_store.dart';
import 's3_sync_serializer.dart';

/// 单次同步的计数结果。
class SyncResult {
  int pushed = 0;
  int pulled = 0;
  int deleted = 0;
  int imagesUploaded = 0;
  int imagesDownloaded = 0;

  /// 远端缺少对应图片 blob，本轮未能落图的条目数（下一轮会重试）。
  int imagesMissing = 0;
  int failed = 0;
}

/// 引擎内部进度回调事件。
///
/// 仅用于把阶段 1/2 的「条目级」进度暴露给上层（让 UI 能看到「下载中」状态），
/// 阶段 3 边界不向外汇报（它要么一起成功、要么整轮失败）。
class SyncEngineProgress {
  /// `push` / `pull`：当前所处的同步阶段。
  final String phase;

  /// 当前阶段已完成条目数。
  final int done;

  /// 当前阶段的总条目数（同步启动后才能确定）。
  final int total;

  const SyncEngineProgress({
    required this.phase,
    required this.done,
    required this.total,
  });
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

  /// 阶段 1/2 条目级进度回调（可选）。
  ///
  /// 调用方通常把它桥接成一个 stream，让 UI 能显示「正在下载 N/Z」之类的提示。
  /// **仅供 UI 反馈使用**，错误仍通过抛异常暴露，调用方**不应**根据它修改业务状态。
  void Function(SyncEngineProgress p)? onProgress;

  void _emitProgress(String phase, int done, int total) {
    final cb = onProgress;
    if (cb == null) return;
    cb(SyncEngineProgress(phase: phase, done: done, total: total));
  }

  /// 图片 blob 的对象键。
  String blobKey(String hash) => '$kBlobPrefix$hash';

  /// 生成或读取稳定的本机 deviceId。
  Future<String> _deviceId() async {
    if (_deviceIdOverride != null && _deviceIdOverride.isNotEmpty) {
      return _deviceIdOverride;
    }
    var id = await _secretStore.read(kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'dev-${DateTime.now().microsecondsSinceEpoch}';
      await _secretStore.write(kDeviceIdKey, id);
    }
    return id;
  }

  /// 读取远端 manifest。
  ///
  /// 关键：只有对象**确实不存在**才返回空 manifest；读取失败（网络抖动、5xx）
  /// 必须让异常向上抛出，使整轮 `sync()` 失败并放弃写入 manifest。
  /// 否则一次瞬时故障会被当成「远端是空的」，阶段 1 重推全部数据，
  /// 阶段 3 写出只含本机条目的 manifest，其他设备的 blob 就全成了孤儿。
  Future<Manifest> _loadManifest() async {
    final bytes = await _store.getBytes(kManifestKey);
    if (bytes == null) return Manifest.empty();
    final manifest = Manifest.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    if (manifest.schema != Manifest.currentSchema) {
      // 不直接失败（旧 manifest 字段向下兼容），但要让用户/日志知道版本不一致。
      LogService.instance.warning(
          'S3Sync',
          'manifest schema 不匹配: 远端=${manifest.schema} '
          '本地=${Manifest.currentSchema}，可能存在兼容性问题');
    }
    return manifest;
  }

  /// 执行一次双向同步（三阶段 LWW）。
  Future<SyncResult> sync() async {
    final result = SyncResult();
    final remote = await _loadManifest();
    final deviceId = await _deviceId();

    // 逻辑时钟：不小于已知远端最大 updatedAt，也不小于本地已存时钟。
    var clock = remote.maxUpdatedAt();
    final localClock =
        int.tryParse(await _syncStateDao.get(kSyncClockKey) ?? '') ?? 0;
    if (localClock > clock) clock = localClock;

    // 本轮实际使用过的最大时间戳。阶段 1 会把实体盖上 clock+1 之类的戳，
    // 若只把起始 clock 写回，时钟不变量就得依赖「下一轮 maxUpdatedAt() 能恢复」，
    // 一旦某轮推送失败就会退化。这里显式跟踪实际用过的最大值。
    var maxStampUsed = clock;

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
    final pushTotal = localMemes.length;
    _emitProgress('push', 0, pushTotal);
    for (var i = 0; i < localMemes.length; i++) {
      final meme = localMemes[i];
      try {
        final remoteEntry = remote.memes[meme.id];
        final isChanged =
            remoteEntry == null || meme.updatedAt > remoteEntry.updatedAt;
        if (!isChanged) continue;

        // 逻辑时钟兜底：确保推送时间戳大于已知远端时钟。
        final stamp = meme.updatedAt > clock ? meme.updatedAt : clock + 1;
        if (stamp > maxStampUsed) maxStampUsed = stamp;

        if (meme.deletedAt != null) {
          await _store.putBytes(
              '$kMemePrefix${meme.id}.json', _encode(_tombstoneJson(meme, stamp)));
          newManifest.memes[meme.id] = ManifestEntry(
            updatedAt: stamp,
            deletedAt: meme.deletedAt,
            hash: meme.fileHash,
            ext: _ext(meme.filePath),
          );
        } else {
          final data = await _buildMemeData(meme.copyWith(updatedAt: stamp));
          await _store.putBytes('$kMemePrefix${meme.id}.json', _encode(data.toJson()));
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
      _emitProgress('push', i + 1, pushTotal);
    }

    // 相册推送
    final localAlbums = await _albumRepo.getAll();
    for (final album in localAlbums) {
      try {
        final remoteEntry = remote.albums[album.id];
        // 全新设备自建、从未改动过的默认相册（isDefault==1 且 updatedAt==0）
        // 不参与推送：其 rev 会退化成 createdAt≈now，每台新设备都会往 manifest
        // 塞一个自己的「所有图片」。远端已有任何相册时说明同步已由别的设备
        // 建立过，本机这个默认相册没有对外价值。
        final isUnmodifiedDefault = album.isDefault == 1 && album.updatedAt == 0;
        if (isUnmodifiedDefault && remote.albums.isNotEmpty) continue;

        final rev = album.updatedAt > 0 ? album.updatedAt : album.createdAt;
        if (remoteEntry != null && rev <= remoteEntry.updatedAt) continue;

        final stamp = rev > clock ? rev : clock + 1;
        if (stamp > maxStampUsed) maxStampUsed = stamp;
        await _store.putBytes(
            '$kAlbumPrefix${album.id}.json', _encode(_albumJson(album, stamp)));
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
    // 总进度分母：相册 + meme，每完成一条 emit 一次，便于 UI 显示「下载中 X/Y」。
    final pullTotal = remote.albums.length + remote.memes.length;
    var pullDone = 0;
    _emitProgress('pull', 0, pullTotal);
    // 先拉相册，保证随后 meme 的 meme_albums 外键可满足。
    for (final entry in remote.albums.entries) {
      try {
        final local = await _albumRepo.getById(entry.key);
        if (local != null && local.updatedAt >= entry.value.updatedAt) continue;
        final bytes = await _store.getBytes('$kAlbumPrefix${entry.key}.json');
        if (bytes == null) {
          result.failed++;
          continue;
        }
        final applied = await _applyAlbum(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        // 返回 false 表示这是「远端默认相册但本地已有默认相册」而被跳过：
        // 此时不能计入 pulled，否则每轮都会重复尝试同一个条目。
        if (applied) result.pulled++;
      } catch (_) {
        result.failed++;
      } finally {
        pullDone++;
        _emitProgress('pull', pullDone, pullTotal);
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

        final bytes = await _store.getBytes('$kMemePrefix$id.json');
        if (bytes == null) {
          result.failed++;
          continue;
        }
        final data = MemeSyncData.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);

        // 关键顺序：先把图片落到最终路径，再落库。
        // 若先落库，一旦图片缺失/下载失败，本地行已经带着远端 updatedAt，
        // 下一轮的 `local.updatedAt >= remoteEntry.updatedAt` 守卫会直接跳过它，
        // 该条目永久缺图却一直报「成功」。
        final blobReady = await _downloadBlobIfMissing(data, result);
        if (!blobReady) {
          result.failed++;
          continue; // 不落库、不写 manifest，下一轮自然重试
        }

        await _applyMeme(data);
        newManifest.memes[id] = remoteEntry;
        result.pulled++;
      } catch (_) {
        result.failed++;
      } finally {
        pullDone++;
        _emitProgress('pull', pullDone, pullTotal);
      }
    }

    // ---- 用户统计同步 ----
    // 单个实体失败只记录并跳过，绝不中断整轮：用户统计对象损坏（如 json 被截断）
    // 若直接冒泡，sync() 会永远失败、manifest 永不写回，UI 上也无从修复。
    try {
      final statsStamp = await _syncUserStats(remote, newManifest, result);
      if (statsStamp > maxStampUsed) maxStampUsed = statsStamp;
    } catch (_) {
      result.failed++;
    }

    // ---- 阶段 3：收敛 ----
    // newManifest.memes/albums 是可变 Map，阶段 1/2 已原地更新，直接写回即可。
    // 写回的时钟必须是本轮**实际用过**的最大时间戳，而不是起始 clock。
    newManifest.clock = maxStampUsed;
    await _store.putBytes(kManifestKey, _encode(newManifest.toJson()));
    await _syncStateDao.set(kSyncClockKey, maxStampUsed.toString());
    await _syncStateDao.setLastSyncAt(DateTime.now().millisecondsSinceEpoch);
    return result;
  }

  // ---- 辅助 ----

  /// 用户统计的 LWW 同步。
  ///
  /// 本地时间戳来自 sync_state 的 `user_stats_updated_at`，远端时间戳来自
  /// manifest 的 `userStatsUpdatedAt`。本地更新则推送，远端更新则拉取并落库。
  ///
  /// 返回本轮实际写入/采纳的用户统计时间戳（没有动作时返回 0），供调用方
  /// 把它计入逻辑时钟。
  Future<int> _syncUserStats(
      Manifest remote, Manifest newManifest, SyncResult result) async {
    final localTs =
        int.tryParse(await _syncStateDao.get(kUserStatsClockKey) ?? '') ?? 0;
    final remoteTs = remote.userStatsUpdatedAt ?? 0;

    if (localTs > remoteTs) {
      final rows = await _db.userStatsDao.getAll();
      if (rows.isNotEmpty) {
        await _store.putBytes(
          kUserStatsKey,
          _encode(<String, dynamic>{
            'updatedAt': localTs,
            'rows': rows.map((r) => r.toJson()).toList(),
          }),
        );
        newManifest.userStatsUpdatedAt = localTs;
        result.pushed++;
        return localTs;
      } else {
        // 本地一行都没有：不推送对象，但必须把本地时钟对齐到远端，
        // 否则 localTs 永远大于 remoteTs，每轮都在这里空转。
        await _syncStateDao.set(kUserStatsClockKey, remoteTs.toString());
      }
    } else if (remoteTs > localTs) {
      final bytes = await _store.getBytes(kUserStatsKey);
      if (bytes != null) {
        final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final rows = (j['rows'] as List?) ?? const [];
        for (final r in rows) {
          await _db
              .into(_db.userStatsTable)
              .insertOnConflictUpdate(
                  UserStatsEntry.fromJson(r as Map<String, dynamic>));
        }
        await _syncStateDao.set(kUserStatsClockKey, remoteTs.toString());
        newManifest.userStatsUpdatedAt = remoteTs;
        result.pulled++;
        return remoteTs;
      } else {
        // manifest 说远端更新、但统计对象已被删除/尚未上传：没有可拉取内容，
        // 同样对齐时钟，避免每轮重复进入。
        await _syncStateDao.set(kUserStatsClockKey, remoteTs.toString());
      }
    }
    return 0;
  }

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
      if (data.albumIds.isNotEmpty) {
        // 仅插入本地真实存在的相册，避免 album 尚未拉取时外键失败导致整个事务回滚。
        final existingRows = await (_db.select(_db.albumsTable)
              ..where((t) => t.id.isIn(data.albumIds)))
            .get();
        final existingIds = existingRows.map((a) => a.id).toSet();
        for (final albumId in data.albumIds) {
          if (!existingIds.contains(albumId)) continue;
          await _db.into(_db.memeAlbumsTable).insertOnConflictUpdate(
              MemeAlbum(memeId: data.meme.id, albumId: albumId, addedAt: now));
        }
      }
    });
  }

  /// 落库远端相册。返回 false 表示「被有意跳过」。
  ///
  /// 唯一会跳过的情形：远端是默认相册，但本地已经有自己的默认相册。
  /// 两台设备各自都会在建库时插入一个「所有图片」默认相册，若把远端默认相册
  /// 也建出来，本地就会有两个 `isDefault==1` 记录，而 `getDefaultAlbum()`
  /// 用的是 `getSingleOrNull()`，会直接抛错、整个相册体系不可用。
  /// （推送侧已避免产生第二个默认相册，这里是兜底，防止历史 manifest。）
  Future<bool> _applyAlbum(Map<String, dynamic> j) async {
    final id = j['id'] as String;
    final isDefault = j['isDefault'] as int;
    if (isDefault == 1) {
      final existing = await _db.albumDao.getDefaultAlbum();
      if (existing != null && existing.id != id) return false;
    }
    await _db.into(_db.albumsTable).insertOnConflictUpdate(Album(
          id: id,
          name: j['name'] as String,
          icon: j['icon'] as String?,
          sortOrder: j['sortOrder'] as int,
          isDefault: isDefault,
          createdAt: j['createdAt'] as int,
          updatedAt: j['updatedAt'] as int? ?? 0,
        ));
    return true;
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

  /// 下载远端图片到本地最终路径。
  ///
  /// 返回 `true` 表示图片已就位（本来就存在、无需下载、或下载成功）；
  /// 返回 `false` 表示远端缺少该 blob 或下载失败，调用方**必须**跳过落库，
  /// 否则本地行会先带着远端 updatedAt 落库，下一轮 LWW 守卫再也不重试它。
  Future<bool> _downloadBlobIfMissing(
      MemeSyncData data, SyncResult result) async {
    final hash = data.meme.fileHash;
    if (hash.isEmpty) return true; // 本就没有图，无需下载
    final file = await _storage.getImage(data.meme.filePath);
    if (await file.exists()) return true;
    if (!await _store.exists(blobKey(hash))) {
      result.imagesMissing++; // 远端没有这张图，计入失败而不是静默跳过
      return false;
    }
    await file.parent.create(recursive: true);
    await _store.downloadToFile(blobKey(hash), file.absolute.path);
    result.imagesDownloaded++;
    return true;
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
