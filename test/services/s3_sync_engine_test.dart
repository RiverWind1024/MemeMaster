import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/repositories/album_repository.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:mememaster/services/file_storage_service.dart';
import 'package:mememaster/services/object_store.dart';
import 'package:mememaster/services/s3_manifest.dart';
import 'package:mememaster/services/s3_secret_store.dart';
import 'package:mememaster/services/s3_sync_engine.dart';
import 'package:mememaster/services/s3_sync_serializer.dart';

/// 内存版密钥存储，避免依赖 Flutter 插件。
class InMemorySecret implements S3SecretStore {
  final Map<String, String> m = {};

  @override
  Future<String?> read(String k) async => m[k];

  @override
  Future<void> write(String k, String v) async {
    m[k] = v;
  }
}

/// 一个逻辑「设备」：独立 DB + 存储目录 + 引擎，共享同一个 ObjectStore。
class _Device {
  final Directory dir;
  final AppDatabase db;
  final MemeRepository memeRepo;
  final AlbumRepository albumRepo;
  final FileStorageService storage;
  final SyncEngine engine;

  _Device(this.dir, this.db, this.memeRepo, this.albumRepo, this.storage,
      this.engine);

  Future<void> dispose() async {
    await db.close();
    await dir.delete(recursive: true);
  }
}

Uint8List _bytes(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  late _Device d1;
  late InMemoryObjectStore store;

  Future<_Device> newDevice() async {
    final dir = await Directory.systemTemp.createTemp('engine_');
    final db = AppDatabase.open('${dir.path}/t.db');
    final memeRepo = MemeRepository(
      memeDao: db.memeDao,
      tagDao: db.tagDao,
      colorDao: db.colorDao,
      queueDao: db.analysisQueueDao,
    );
    final albumRepo = AlbumRepository(db.albumDao);
    final storage = FileStorageService(basePath: '${dir.path}/memes');
    final engine = SyncEngine(
      store: store,
      memeRepo: memeRepo,
      albumRepo: albumRepo,
      db: db,
      syncStateDao: db.syncStateDao,
      secretStore: InMemorySecret(),
      storage: storage,
    );
    return _Device(dir, db, memeRepo, albumRepo, storage, engine);
  }

  /// 显式指定 id 插入 meme，并落一份真实图片文件。
  Future<Meme> insertMeme(
    _Device d,
    String id, {
    int? updatedAt,
    String? hash,
    String? customName,
    int copyCount = 0,
    String? source,
  }) async {
    final ts = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    final h = hash ?? 'hash_$id';
    final src = File('${d.dir.path}/src_$id.jpg')..writeAsBytesSync([1, 2, 3]);
    final rel = await d.storage.storeImage(src.path, h);
    final meme = Meme(
      id: id,
      filename: '$id.jpg',
      filePath: rel,
      customName: customName,
      fileSize: 3,
      mimeType: 'image/jpeg',
      width: 1,
      height: 1,
      analysisStatus: 'pending',
      colorAnalysisStatus: 'pending',
      ocrAnalysisStatus: 'pending',
      aiAnalysisStatus: 'pending',
      fileHash: h,
      copyCount: copyCount,
      source: source,
      createdAt: ts,
      updatedAt: ts,
      importedAt: ts,
    );
    await d.db.memeDao.insert(meme);
    return meme;
  }

  setUp(() async {
    store = InMemoryObjectStore();
    d1 = await newDevice();
  });

  tearDown(() async {
    await d1.dispose();
  });

  test('首次同步上传本地全部并写入 manifest', () async {
    await insertMeme(d1, 'm1');
    final r = await d1.engine.sync();

    expect(r.failed, 0);
    expect(r.pushed, greaterThanOrEqualTo(1));
    expect(r.imagesUploaded, greaterThanOrEqualTo(1));
    expect(await store.exists('sync/manifest.json'), isTrue);
    expect(await store.exists('sync/memes/m1.json'), isTrue);
    expect(await store.exists('blobs/hash_m1'), isTrue);
  });

  test('第二个空设备能全量拉取（含图片）', () async {
    await insertMeme(d1, 'm1');
    await d1.engine.sync();

    final d2 = await newDevice();
    try {
      final r2 = await d2.engine.sync();
      expect(r2.failed, 0);
      expect(r2.pulled, greaterThanOrEqualTo(1));

      final pulled = await d2.db.memeDao.getById('m1');
      expect(pulled, isNotNull);
      expect((await d2.memeRepo.getAll()).length, 1);

      // 图片也应下载到设备 2 的本地存储。
      final img = await d2.storage.getImage(pulled!.filePath);
      expect(await img.exists(), isTrue);
    } finally {
      await d2.dispose();
    }
  });

  test('LWW：远端 updatedAt 更新时覆盖本地', () async {
    await insertMeme(d1, 'm1', updatedAt: 1000, hash: 'h1');
    await d1.engine.sync();

    // 把远端 m1 改成更新的时间戳与描述。
    final manifest = Manifest.fromJson(
        jsonDecode(utf8.decode((await store.getBytes('sync/manifest.json'))!))
            as Map<String, dynamic>);
    final remoteData = MemeSyncData.fromJson(
        jsonDecode(utf8.decode((await store.getBytes('sync/memes/m1.json'))!))
            as Map<String, dynamic>);
    final newerMeme = remoteData.meme
        .copyWith(updatedAt: 5000, description: Value('from remote'));
    await store.putBytes(
      'sync/memes/m1.json',
      _bytes(MemeSyncData(
        meme: newerMeme,
        tags: remoteData.tags,
        colors: remoteData.colors,
        albumIds: remoteData.albumIds,
      ).toJson()),
    );
    final memes = Map<String, ManifestEntry>.of(manifest.memes);
    memes['m1'] = const ManifestEntry(updatedAt: 5000, hash: 'h1', ext: '.jpg');
    final newManifest = Manifest(
      schema: manifest.schema,
      generatedAt: manifest.generatedAt,
      lastWriter: manifest.lastWriter,
      clock: 5000,
      memes: memes,
      albums: manifest.albums,
      userStatsUpdatedAt: manifest.userStatsUpdatedAt,
    );
    await store.putBytes('sync/manifest.json', _bytes(newManifest.toJson()));

    final r = await d1.engine.sync();
    expect(r.failed, 0);
    expect(r.pulled, greaterThanOrEqualTo(1));

    final local = await d1.db.memeDao.getByIdIncludingDeleted('m1');
    expect(local!.updatedAt, 5000);
    expect(local.description, 'from remote');
  });

  test('LWW：本地 updatedAt 更新时不被远端旧版本覆盖', () async {
    await insertMeme(d1, 'm1', updatedAt: 1000, hash: 'h1');
    await d1.engine.sync();

    // 本地改为更新的时间戳（模拟用户改动）。
    await d1.db.memeDao.touchUpdatedAt('m1', 9000);

    final r = await d1.engine.sync();
    expect(r.failed, 0);

    // 本地未被远端 1000 覆盖。
    final local = await d1.db.memeDao.getByIdIncludingDeleted('m1');
    expect(local!.updatedAt, greaterThanOrEqualTo(9000));

    // 本地更新已被推送到远端 manifest。
    final manifest = Manifest.fromJson(
        jsonDecode(utf8.decode((await store.getBytes('sync/manifest.json'))!))
            as Map<String, dynamic>);
    expect(manifest.memes['m1']!.updatedAt, greaterThanOrEqualTo(9000));
  });

  test('相册归属随 meme 一起同步（先拉相册满足外键）', () async {
    const albumId = 'alb1';
    await d1.db.albumDao.insert(const Album(
      id: albumId,
      name: 'Trip',
      sortOrder: 1,
      isDefault: 0,
      createdAt: 1,
      updatedAt: 1,
    ));
    await insertMeme(d1, 'm1');
    await d1.db.albumDao.addMemeToAlbum('m1', albumId);

    final r1 = await d1.engine.sync();
    expect(r1.failed, 0);

    final d2 = await newDevice();
    try {
      final r2 = await d2.engine.sync();
      expect(r2.failed, 0);
      expect(await d2.albumRepo.getById(albumId), isNotNull);
      expect(await d2.albumRepo.getAlbumIdsByMeme('m1'), contains(albumId));
    } finally {
      await d2.dispose();
    }
  });

  test('墓碑传播：一台设备删除后另一台设备同步删除', () async {
    await insertMeme(d1, 'm1', updatedAt: 1000, hash: 'h1');
    await d1.engine.sync();

    final d2 = await newDevice();
    try {
      await d2.engine.sync();
      expect(await d2.db.memeDao.getById('m1'), isNotNull);

      // 设备 1 软删除。
      await d1.db.memeDao.softDelete('m1');
      final r1 = await d1.engine.sync();
      expect(r1.failed, 0);
      expect(r1.pushed, greaterThanOrEqualTo(1));

      // 设备 2 同步后墓碑生效。
      final r2 = await d2.engine.sync();
      expect(r2.failed, 0);
      expect(r2.deleted, greaterThanOrEqualTo(1));
      expect(await d2.db.memeDao.getById('m1'), isNull);
      final tomb = await d2.db.memeDao.getByIdIncludingDeleted('m1');
      expect(tomb, isNotNull);
      expect(tomb!.deletedAt, isNotNull);
    } finally {
      await d2.dispose();
    }
  });

  test('拉取保留 customName/copyCount/source', () async {
    await insertMeme(
      d1,
      'm1',
      customName: '我的图',
      copyCount: 7,
      source: 'wechat',
    );
    await d1.engine.sync();

    final d2 = await newDevice();
    try {
      final r2 = await d2.engine.sync();
      expect(r2.failed, 0);
      final pulled = await d2.db.memeDao.getById('m1');
      expect(pulled, isNotNull);
      expect(pulled!.customName, '我的图');
      expect(pulled.copyCount, 7);
      expect(pulled.source, 'wechat');
    } finally {
      await d2.dispose();
    }
  });

  test('拉取时忽略本地不存在的相册（不因外键整单回滚）', () async {
    await insertMeme(d1, 'm1', updatedAt: 1000, hash: 'h1');
    await d1.engine.sync();

    // 在远端 meme json 里塞入一个 manifest 中并不存在的相册 id。
    final data = MemeSyncData.fromJson(
        jsonDecode(utf8.decode((await store.getBytes('sync/memes/m1.json'))!))
            as Map<String, dynamic>);
    await store.putBytes(
      'sync/memes/m1.json',
      _bytes(MemeSyncData(
        meme: data.meme,
        tags: data.tags,
        colors: data.colors,
        albumIds: const ['ghost-album'],
      ).toJson()),
    );

    final d2 = await newDevice();
    try {
      final r2 = await d2.engine.sync();
      expect(r2.failed, 0);
      expect(await d2.db.memeDao.getById('m1'), isNotNull);
      expect(await d2.albumRepo.getAlbumIdsByMeme('m1'), isEmpty);
    } finally {
      await d2.dispose();
    }
  });
}
