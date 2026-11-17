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

/// 内存版密钥存储。
class _MemSecret implements S3SecretStore {
  @override
  Future<String?> read(String k) async => null;

  @override
  Future<void> write(String k, String v) async {}
}

Uint8List _bytes(List<int> b) => Uint8List.fromList(b);

const _validConfig = S3Config(
  endpoint: 's3.example.com',
  bucket: 'bucket',
  accessKey: 'ak',
  secretKey: 'sk',
);

void main() {
  late InMemoryObjectStore store;
  late AppDatabase db;
  late Directory dir;
  late S3SyncService service;

  setUp(() async {
    store = InMemoryObjectStore();
    dir = await Directory.systemTemp.createTemp('svc_');
    db = AppDatabase.open('${dir.path}/t.db');
    final secretStore = _MemSecret();
    final engine = SyncEngine(
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
      secretStore: secretStore,
      storage: FileStorageService(basePath: '${dir.path}/memes'),
    );
    service = S3SyncService(
      store: store,
      engine: engine,
      syncStateDao: db.syncStateDao,
      secretStore: secretStore,
    )..updateConfig(_validConfig);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  group('孤儿清理', () {
    test('manifest 为空但存在遗留 v1 键时拒绝清理，且一个对象都不删', () async {
      await store.putBytes(
          'sync/manifest.json', _bytes(utf8.encode(jsonEncode(Manifest.empty().toJson()))));
      await store.putBytes('blobs/h_legacy', _bytes([1, 2, 3]));
      await store.putBytes('memes/1.png', _bytes([1]));
      await store.putBytes('data/memes.json', _bytes([1]));
      await store.putBytes('data/memes/2.png', _bytes([1]));
      await store.putBytes('snapshot-v1.json', _bytes([1]));

      final removed = await service.cleanupOrphans();

      expect(removed, 0);
      expect(await service.cleanupBlockedReason(), isNotNull);
      for (final key in [
        'sync/manifest.json',
        'blobs/h_legacy',
        'memes/1.png',
        'data/memes.json',
        'data/memes/2.png',
        'snapshot-v1.json',
      ]) {
        expect(await store.exists(key), isTrue, reason: '$key 不应被删除');
      }
    });

    test('manifest 有引用时正常清理孤儿与遗留键', () async {
      await store.putBytes(
        'sync/manifest.json',
        _bytes(utf8.encode(jsonEncode(Manifest(
          schema: Manifest.currentSchema,
          generatedAt: 0,
          lastWriter: 'dev1',
          clock: 100,
          memes: {'m1': const ManifestEntry(updatedAt: 100, hash: 'h_keep', ext: '.jpg')},
          albums: const {},
        ).toJson()))),
      );
      await store.putBytes('blobs/h_keep', _bytes([1]));
      await store.putBytes('blobs/h_orphan', _bytes([1]));
      await store.putBytes('memes/1.png', _bytes([1]));
      await store.putBytes('snapshot-v1.json', _bytes([1]));

      expect(await service.cleanupBlockedReason(), isNull);
      final removed = await service.cleanupOrphans();

      // 孤儿 blob + snapshot-v1.json + memes/1.png 共 3 个。
      expect(removed, 3);
      expect(await store.exists('blobs/h_keep'), isTrue);
      expect(await store.exists('blobs/h_orphan'), isFalse);
      expect(await store.exists('memes/1.png'), isFalse);
      expect(await store.exists('snapshot-v1.json'), isFalse);
      expect(await store.exists('sync/manifest.json'), isTrue);
    });

    test('manifest 缺失时拒绝清理', () async {
      await store.putBytes('blobs/h1', _bytes([1]));
      expect(await service.cleanupOrphans(), 0);
      expect(await store.exists('blobs/h1'), isTrue);
    });
  });

  group('存储统计', () {
    test('按引用/孤儿/元数据拆分统计', () async {
      final manifestBytes =
          _bytes(utf8.encode(jsonEncode(Manifest(
        schema: Manifest.currentSchema,
        generatedAt: 0,
        lastWriter: 'dev1',
        clock: 100,
        memes: {'m1': const ManifestEntry(updatedAt: 100, hash: 'h_keep')},
        albums: const {},
      ).toJson())));
      await store.putBytes('sync/manifest.json', manifestBytes);
      await store.putBytes('blobs/h_keep', _bytes([1, 2]));
      await store.putBytes('blobs/h_orphan', _bytes([1, 2, 3]));

      final stats = await service.getStorageStats();
      expect(stats.objectCount, 3);
      expect(stats.totalBytes, 2 + 3 + manifestBytes.length);
      expect(stats.referencedImages, 1);
      expect(stats.orphanImages, 1);
      expect(stats.metaFiles, 1);
    });
  });
}