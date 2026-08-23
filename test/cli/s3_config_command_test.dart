import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/repositories/album_repository.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:mememaster/services/file_storage_service.dart';
import 'package:mememaster/services/s3_secret_store.dart';
import 'package:mememaster/services/s3_sync_service.dart';
import 'package:mememaster/services/s3_sync_serializer.dart';

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

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('s3_config_test_');
      db = AppDatabase.open('${tempDir.path}/meme_helper.db');
      final memeRepo = MemeRepository(
        memeDao: db.memeDao,
        tagDao: db.tagDao,
        colorDao: db.colorDao,
        queueDao: db.analysisQueueDao,
      );
      final albumRepo = AlbumRepository(db.albumDao);
      secretStore = InMemoryS3SecretStore();
      service = S3SyncService(
        memeRepo: memeRepo,
        albumRepo: albumRepo,
        storage: FileStorageService(),
        syncStateDao: db.syncStateDao,
        serializer: S3SyncSerializer(
          memeRepo: memeRepo,
          albumRepo: albumRepo,
          db: db,
        ),
        db: db,
        secretStore: secretStore,
      );
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
}
