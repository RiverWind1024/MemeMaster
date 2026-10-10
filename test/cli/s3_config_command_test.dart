import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/repositories/album_repository.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:mememaster/services/file_storage_service.dart';
import 'package:mememaster/services/object_store.dart';
import 'package:mememaster/services/s3_config.dart';
import 'package:mememaster/services/s3_manifest.dart';
import 'package:mememaster/services/s3_secret_store.dart';
import 'package:mememaster/services/s3_sync_engine.dart';
import 'package:mememaster/services/s3_sync_service.dart';

/// 纯 Dart 内存版 S3SecretStore（CLI 用，不依赖 Flutter 插件）
class InMemoryS3SecretStore implements S3SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }
}

Uint8List _bytes(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  group('InMemoryS3SecretStore', () {
    test('read/write 往返', () async {
      final store = InMemoryS3SecretStore();
      expect(await store.read('k'), isNull);
      await store.write('k', 'v');
      expect(await store.read('k'), 'v');
    });
  });

  group('S3SyncService 清空密码（注入内存版 S3SecretStore）', () {
    late Directory tempDir;
    late AppDatabase db;
    late S3SyncService service;
    late InMemoryS3SecretStore secretStore;

    S3SyncService buildService(ObjectStore store, S3SecretStore secretStore) {
      final memeRepo = MemeRepository(
        memeDao: db.memeDao,
        tagDao: db.tagDao,
        colorDao: db.colorDao,
        queueDao: db.analysisQueueDao,
      );
      final albumRepo = AlbumRepository(db.albumDao);
      final engine = SyncEngine(
        store: store,
        memeRepo: memeRepo,
        albumRepo: albumRepo,
        db: db,
        syncStateDao: db.syncStateDao,
        secretStore: secretStore,
        storage: FileStorageService(basePath: '${tempDir.path}/memes'),
      );
      return S3SyncService(
        store: store,
        engine: engine,
        syncStateDao: db.syncStateDao,
        secretStore: secretStore,
      );
    }

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('s3_config_test_');
      db = AppDatabase.open('${tempDir.path}/meme_helper.db');
      secretStore = InMemoryS3SecretStore();
      service = buildService(InMemoryObjectStore(), secretStore);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('setClearPassword 写入注入的存储（键 s3_clear_password）', () async {
      await service.setClearPassword('secret-123');
      expect(await secretStore.read('s3_clear_password'), 'secret-123');
    });

    test('hasClearPassword 未设置时 false，设置后 true', () async {
      expect(await service.hasClearPassword(), isFalse);
      await service.setClearPassword('secret-123');
      expect(await service.hasClearPassword(), isTrue);
    });

    test('clearAllData 未设置密码时抛 ArgumentError', () async {
      expect(
        () => service.clearAllData(password: 'secret-123'),
        throwsArgumentError,
      );
    });

    test('clearAllData 密码不匹配时抛 ArgumentError', () async {
      await service.setClearPassword('secret-123');
      expect(
        () => service.clearAllData(password: 'wrong-password'),
        throwsArgumentError,
      );
    });
  });

  group('SyncStats / cleanupOrphans（InMemoryObjectStore）', () {
    late Directory tempDir;
    late AppDatabase db;
    late InMemoryObjectStore store;
    late S3SyncService service;

    const validConfig = S3Config(
      endpoint: 'http://localhost:9000',
      bucket: 'test-bucket',
      accessKey: 'ak',
      secretKey: 'sk',
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('s3_stats_test_');
      db = AppDatabase.open('${tempDir.path}/meme_helper.db');
      store = InMemoryObjectStore();
      final memeRepo = MemeRepository(
        memeDao: db.memeDao,
        tagDao: db.tagDao,
        colorDao: db.colorDao,
        queueDao: db.analysisQueueDao,
      );
      final albumRepo = AlbumRepository(db.albumDao);
      final secretStore = InMemoryS3SecretStore();
      final engine = SyncEngine(
        store: store,
        memeRepo: memeRepo,
        albumRepo: albumRepo,
        db: db,
        syncStateDao: db.syncStateDao,
        secretStore: secretStore,
        storage: FileStorageService(basePath: '${tempDir.path}/memes'),
      );
      service = S3SyncService(
        store: store,
        engine: engine,
        syncStateDao: db.syncStateDao,
        secretStore: secretStore,
      )..updateConfig(validConfig);

      // manifest 引用 refhash；另有一个孤儿 blob 与若干遗留 key。
      final manifest = Manifest(
        schema: Manifest.currentSchema,
        generatedAt: 1,
        lastWriter: 'test',
        clock: 1,
        memes: {
          'm1': const ManifestEntry(updatedAt: 1, hash: 'refhash', ext: '.jpg'),
        },
        albums: const {},
      );
      await store.putBytes('sync/manifest.json', _bytes(manifest.toJson()));
      await store.putBytes(
          'blobs/refhash', Uint8List.fromList([1, 2, 3, 4]));
      await store.putBytes(
          'blobs/orphanhash', Uint8List.fromList([1, 2, 3]));
      await store.putBytes('snapshot-v1.json', Uint8List.fromList([1, 2]));
      await store.putBytes('data/memes.json', Uint8List.fromList([1, 2]));
      await store.putBytes('data/albums.json', Uint8List.fromList([1, 2]));
      await store.putBytes('data/memes/x.json', Uint8List.fromList([1, 2]));
      await store.putBytes('memes/hash.jpg', Uint8List.fromList([1, 2]));
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('未配置时抛 StateError', () async {
      final unconfigured = S3SyncService(
        store: store,
        engine: SyncEngine(
          store: store,
          memeRepo: MemeRepository(
            memeDao: db.memeDao,
            tagDao: db.tagDao,
            colorDao: db.colorDao,
            queueDao: db.analysisQueueDao,
          ),
          albumRepo: AlbumRepository(db.albumDao),
          db: db,
          syncStateDao: db.syncStateDao,
          secretStore: InMemoryS3SecretStore(),
          storage: FileStorageService(basePath: '${tempDir.path}/memes'),
        ),
        syncStateDao: db.syncStateDao,
        secretStore: InMemoryS3SecretStore(),
      );
      expect(() => unconfigured.getStorageStats(), throwsStateError);
      expect(() => unconfigured.cleanupOrphans(), throwsStateError);
    });

    test('getStorageStats 分项统计', () async {
      final stats = await service.getStorageStats();
      expect(stats.objectCount, 8);
      expect(stats.totalBytes, greaterThan(0));
      expect(stats.referencedImages, 1);
      expect(stats.orphanImages, 1);
      expect(stats.metaFiles, 6);
    });

    test('cleanupOrphans 删除孤儿 blob 与遗留 key', () async {
      final removed = await service.cleanupOrphans();
      expect(removed, 6);
      expect(await store.exists('blobs/refhash'), isTrue);
      expect(await store.exists('blobs/orphanhash'), isFalse);
      expect(await store.exists('snapshot-v1.json'), isFalse);
      expect(await store.exists('data/memes.json'), isFalse);
      expect(await store.exists('data/albums.json'), isFalse);
      expect(await store.exists('data/memes/x.json'), isFalse);
      expect(await store.exists('memes/hash.jpg'), isFalse);
    });

    test('cleanupOrphans：manifest 缺失时中止清理且不删除任何对象', () async {
      // 模拟 manifest 不可读（getBytes 返回 null，等同于瞬时错误）。
      await store.delete('sync/manifest.json');

      final removed = await service.cleanupOrphans();

      expect(removed, 0);
      // 无论是「在用」还是「疑似孤儿」的对象，以及遗留 key，都必须原样保留。
      expect(await store.exists('blobs/refhash'), isTrue);
      expect(await store.exists('blobs/orphanhash'), isTrue);
      expect(await store.exists('snapshot-v1.json'), isTrue);
      expect(await store.exists('data/memes.json'), isTrue);
      expect(await store.exists('data/albums.json'), isTrue);
      expect(await store.exists('data/memes/x.json'), isTrue);
      expect(await store.exists('memes/hash.jpg'), isTrue);
    });

    test('getStorageStats：manifest 缺失时 orphanImages 记 0，不臆断孤儿', () async {
      await store.delete('sync/manifest.json');

      final stats = await service.getStorageStats();

      expect(stats.objectCount, 7); // 8 - 1（manifest）
      expect(stats.totalBytes, greaterThan(0));
      expect(stats.referencedImages, 0);
      expect(stats.orphanImages, 0);
      expect(stats.metaFiles, 5); // 7 - 2 个 blob
    });
  });
}
