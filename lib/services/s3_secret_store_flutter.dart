import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 's3_secret_store.dart';

/// 基于 FlutterSecureStorage 的 [S3SecretStore] 实现（GUI 使用，密钥不落明文）
class FlutterSecureStorageS3SecretStore implements S3SecretStore {
  const FlutterSecureStorageS3SecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
