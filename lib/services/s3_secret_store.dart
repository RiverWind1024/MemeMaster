import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// S3 清空密码存储抽象（GUI 用 FlutterSecureStorage，CLI 用文件/内存存储）
///
/// 把 S3 配置/清空密码的持久化从 [S3SyncService] 中解耦出来，
/// 使纯 Dart CLI（不依赖 Flutter 插件）也能构造 [S3SyncService]。
abstract class S3SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// 基于 FlutterSecureStorage 的实现（GUI 使用，密钥不落明文）
class FlutterSecureStorageS3SecretStore implements S3SecretStore {
  const FlutterSecureStorageS3SecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
