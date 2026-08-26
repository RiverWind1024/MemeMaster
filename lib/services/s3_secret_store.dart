/// 密钥/值存储抽象（GUI 用 FlutterSecureStorage 实现，CLI 用文件/内存实现）
///
/// 把敏感数据（如 S3 配置、清空密码）的持久化从 [S3SyncService] 中解耦出来，
/// 使纯 Dart CLI（不依赖 Flutter 插件）也能构造 [S3SyncService]。
abstract class S3SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
