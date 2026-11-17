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

/// 包装 [ObjectStore]，在读取指定 key 时抛出异常。
///
/// 用于模拟 S3 的瞬时故障（5xx / 503）：这些错误**不能**被当成
/// 「对象不存在」，否则一次抖动就会让同步引擎把远端当成空库。
class _ThrowingStore implements ObjectStore {
  _ThrowingStore(this._inner, this.failOnGet);

  final ObjectStore _inner;
  final String failOnGet;

  @override
  Future<Uint8List?> getBytes(String key) async {
    if (key == failOnGet) throw StateError('模拟的 S3 503 Service Unavailable');
    return _inner.getBytes(key);
  }

  @override
  Future<void> putBytes(String key, Uint8List bytes) => _inner.putBytes(key, bytes);

  @override
  Future<void> uploadFile(String key, String srcPath) =>
      _inner.uploadFile(key, srcPath);

  @override
  Future<void> downloadToFile(String key, String destPath) =>
      _inner.downloadToFile(key, destPath);

  @override
  Future<bool> exists(String key) => _inner.exists(key);

  @override
  Future<List<String>> list(String prefix) => _inner.list(prefix);

  @override
  Future<Map<String, int>> listWithSizes(String prefix) =>
      _inner.listWithSizes(prefix);

  @override
  Future<void> delete(String key) => _inner.delete(key);
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

  Future<_Device> newDevice({ObjectStore? storeOverride}) async {
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
      store: storeOverride ?? store,
      memeRepo: memeRepo,
      albumRepo: albumRepo,
      db: db,
      syncStateDao: db.syncStateDao,
      secretStore: InMemorySecret(),
      storage: storage,
    );
    return _Device(dir, db, memeRepo, albumRepo, storage, engine);
  }

  /// 读取远端 manifest。
  Future<Manifest> readManifest() async => Manifest.fromJson(
      jsonDecode(utf8.decode((await store.getBytes('sync/manifest.json'))!))
          as Map<String, dynamic>);

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

  test('用户统计：本地变更推送，其他设备拉取', () async {
    await d1.db.userStatsDao.incrementImported();
    final r1 = await d1.engine.sync();
    expect(r1.failed, 0);
    expect(await store.exists('sync/user_stats.json'), isTrue);

    final d2 = await newDevice();
    try {
      final r2 = await d2.engine.sync();
      expect(r2.failed, 0);
      final totals = await d2.db.userStatsDao.getTotals();
      expect(totals['totalImported'], 1);
    } finally {
      await d2.dispose();
    }
  });

  // ---- 读取失败必须与「远端为空」区分开（Critical 1）----

  test('manifest 读取失败时整轮同步失败且不覆盖已有 manifest', () async {
    await insertMeme(d1, 'm1', updatedAt: 1000, hash: 'h1');
    await d1.engine.sync();
    final before = await store.getBytes('sync/manifest.json');

    final d2 = await newDevice(
        storeOverride: _ThrowingStore(store, 'sync/manifest.json'));
    try {
      // 瞬时 5xx 绝不能退化成 Manifest.empty()。
      await expectLater(d2.engine.sync(), throwsA(anything));
      // 既不能写出只含本机条目的 manifest，也不能覆盖远端 manifest。
      expect(await store.getBytes('sync/manifest.json'), before);
    } finally {
      await d2.dispose();
    }
  });

  test('manifest 读取失败时首次同步不创建 manifest', () async {
    await insertMeme(d1, 'm1');
    final d2 = await newDevice(
        storeOverride: _ThrowingStore(store, 'sync/manifest.json'));
    try {
      await expectLater(d2.engine.sync(), throwsA(anything));
      expect(await store.exists('sync/manifest.json'), isFalse);
    } finally {
      await d2.dispose();
    }
  });

  // ---- 拉取必须先落图再落库（Important 3）----

  test('远端缺少图片 blob 时计入失败、不落库，下一轮补齐后重试成功', () async {
    await insertMeme(d1, 'm1', updatedAt: 1000, hash: 'h1');
    await d1.engine.sync();
    // 只删 blob，manifest 与 meme json 仍在。
    await store.delete('blobs/h1');

    final d2 = await newDevice();
    try {
      final r = await d2.engine.sync();
      expect(r.imagesMissing, 1);
      expect(r.failed, greaterThanOrEqualTo(1));
      // 关键：不能先落库，否则下一轮 LWW 守卫会永久跳过。
      expect(await d2.db.memeDao.getById('m1'), isNull);

      // 远端补回 blob 后，下一轮应能正常拉取。
      await store.putBytes('blobs/h1', Uint8List.fromList([1, 2, 3]));
      final r2 = await d2.engine.sync();
      expect(r2.failed, 0);
      expect(r2.pulled, greaterThanOrEqualTo(1));
      expect(await d2.db.memeDao.getById('m1'), isNotNull);
    } finally {
      await d2.dispose();
    }
  });

  // ---- 用户统计失败不得中断整轮（Important 5）----

  test('用户统计对象损坏时只记录失败，整轮同步仍完成', () async {
    await insertMeme(d1, 'm1', updatedAt: 1000, hash: 'h1');
    await d1.engine.sync();

    // manifest 声称远端用户统计更新，但对象本身是非法 JSON。
    final m = await readManifest();
    await store.putBytes(
      'sync/manifest.json',
      _bytes(Manifest(
        schema: m.schema,
        generatedAt: m.generatedAt,
        lastWriter: m.lastWriter,
        clock: m.clock,
        memes: m.memes,
        albums: m.albums,
        userStatsUpdatedAt: 999999999,
      ).toJson()),
    );
    await store.putBytes(
        'sync/user_stats.json', Uint8List.fromList(utf8.encode('{not-json')));

    final d2 = await newDevice();
    try {
      final r = await d2.engine.sync();
      expect(r.failed, greaterThanOrEqualTo(1));
      // 阶段 3 必须照常执行（否则用户统计会永久卡死整轮同步）。
      expect(await d2.db.syncStateDao.getLastSyncAt(), isNotNull);
      expect(await d2.db.memeDao.getById('m1'), isNotNull);
    } finally {
      await d2.dispose();
    }
  });

  test('本地无用户统计行且本地时钟领先时对齐时钟，不再空转', () async {
    await d1.db.syncStateDao
        .set('user_stats_updated_at', '999999999');
    final r = await d1.engine.sync();
    expect(r.failed, 0);
    expect(await store.exists('sync/user_stats.json'), isFalse);
    expect(await d1.db.syncStateDao.get('user_stats_updated_at'), '0');
  });

  // ---- 默认相册不得重复（Important 6）----

  test('全新设备首次同步后本地只有一个默认相册', () async {
    await insertMeme(d1, 'm1');
    await d1.engine.sync();

    final d2 = await newDevice();
    try {
      await d2.engine.sync();
      final defaults = await (d2.db.select(d2.db.albumsTable)
            ..where((a) => a.isDefault.equals(1)))
          .get();
      expect(defaults.length, 1);
      // getDefaultAlbum 用 getSingleOrNull，出现两个默认相册会直接抛错。
      expect(await d2.db.albumDao.getDefaultAlbum(), isNotNull);
    } finally {
      await d2.dispose();
    }
  });

  test('远端已有相册时全新设备不再推送自己的默认相册', () async {
    await insertMeme(d1, 'm1');
    await d1.engine.sync();

    final d2 = await newDevice();
    try {
      await d2.engine.sync();
      final m = await readManifest();
      final localDefault = await d2.db.albumDao.getDefaultAlbum();
      expect(m.albums.containsKey(localDefault!.id), isFalse);
    } finally {
      await d2.dispose();
    }
  });

  // ---- 时钟写回（Important 9）----

  test('写回的逻辑时钟等于本轮实际使用过的最大时间戳', () async {
    // 删掉建库时自动插入的默认相册：它的 createdAt 是「当前时间」，
    // 会把时钟顶到一个远大于测试用时间戳的值上。
    final def = await d1.db.albumDao.getDefaultAlbum();
    await d1.db.albumDao.delete(def!.id);

    await insertMeme(d1, 'm1', updatedAt: 5000, hash: 'h1');
    await insertMeme(d1, 'm2', updatedAt: 1000, hash: 'h2');
    await d1.engine.sync();

    // m1 的 5000 抬高远端时钟；把 m2 改到 1000 与 5000 之间，
    // 迫使引擎使用 clock+1 兜底戳。
    await d1.db.memeDao.touchUpdatedAt('m2', 2000);
    await d1.engine.sync();

    final m = await readManifest();
    expect(m.memes['m2']!.updatedAt, 5001);
    // 旧实现写回的是起始 clock(5000)，会依赖 maxUpdatedAt() 才能恢复。
    expect(m.clock, 5001);
    expect(await d1.db.syncStateDao.get('sync_clock'), '5001');
  });

  // ---- 幂等（Important 10）----

  test('重复同步是幂等的：第二次 pushed/pulled/failed 全为 0', () async {
    await insertMeme(d1, 'm1');
    await d1.db.userStatsDao.incrementImported();
    final r1 = await d1.engine.sync();
    expect(r1.failed, 0);
    expect(r1.pushed, greaterThan(0));
    final before = await readManifest();

    final r2 = await d1.engine.sync();
    expect(r2.pushed, 0);
    expect(r2.pulled, 0);
    expect(r2.deleted, 0);
    expect(r2.failed, 0);

    final after = await readManifest();
    expect(after.clock, before.clock);
    expect(after.userStatsUpdatedAt, before.userStatsUpdatedAt);
    expect(after.memes.length, before.memes.length);
    expect(after.albums.length, before.albums.length);
    for (final id in before.memes.keys) {
      expect(after.memes[id]!.updatedAt, before.memes[id]!.updatedAt);
    }
    for (final id in before.albums.keys) {
      expect(after.albums[id]!.updatedAt, before.albums[id]!.updatedAt);
    }
  });

  // ---- 进度回调 ----

  test('onProgress 在 push 与 pull 阶段逐条目推进', () async {
    await insertMeme(d1, 'm1');
    await insertMeme(d1, 'm2');

    final events = <SyncEngineProgress>[];
    d1.engine.onProgress = (p) => events.add(p);

    await d1.engine.sync();

    // 阶段 1：push 阶段应有 (0, total) 起步 + 每条目一次推进。
    expect(events.first.phase, 'push');
    expect(events.first.done, 0);
    expect(events.first.total, 2);
    final pushEvents =
        events.where((e) => e.phase == 'push').toList();
    expect(pushEvents.length, 3); // 起步 + 2 条
    expect(pushEvents.last.done, 2);
    expect(pushEvents.last.total, 2);

    // 阶段 2：pull 阶段本机为空，远端无增量；空跑也应发出起始事件。
    final pullEvents =
        events.where((e) => e.phase == 'pull').toList();
    expect(pullEvents, isNotEmpty);
    expect(pullEvents.last.total, pullEvents.last.done);
  });

  test('onProgress 反映远端拉取进度：每个远端条目一次推进', () async {
    // 设备 1 先建 3 张图，写入云端。d1 由 tearDown 释放，不要手动 dispose。
    await insertMeme(d1, 'm1');
    await insertMeme(d1, 'm2');
    await insertMeme(d1, 'm3');
    await d1.engine.sync();

    // 设备 2 用一个独立的 InMemoryObjectStore 模拟「空设备」拉取。
    final dir = await Directory.systemTemp.createTemp('engine2_');
    final db = AppDatabase.open('${dir.path}/t.db');
    final d2memeRepo = MemeRepository(
      memeDao: db.memeDao,
      tagDao: db.tagDao,
      colorDao: db.colorDao,
      queueDao: db.analysisQueueDao,
    );
    final d2engine = SyncEngine(
      store: store,
      memeRepo: d2memeRepo,
      albumRepo: AlbumRepository(db.albumDao),
      db: db,
      syncStateDao: db.syncStateDao,
      secretStore: InMemorySecret(),
      storage: FileStorageService(basePath: '${dir.path}/memes'),
    );
    final events = <SyncEngineProgress>[];
    d2engine.onProgress = (p) => events.add(p);
    try {
      await d2engine.sync();

      final pullEvents =
          events.where((e) => e.phase == 'pull').toList();
      // pull 分母 = 远端 albums + memes = 1（默认相册）+ 3 = 4
      expect(pullEvents.first.total, 4);
      expect(pullEvents.last.done, 4);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
}
