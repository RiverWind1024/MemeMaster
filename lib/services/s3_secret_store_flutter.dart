import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 's3_secret_store.dart';

/// macOS 上 FlutterSecureStorage 在沙盒应用 + ad-hoc 签名下访问 Keychain 会
/// 触发 -34018 错误（"missing entitlement"），导致整个 S3 同步崩溃。
///
/// macOS 不像 iOS 那样有强制 keychain 隔离的需求，且 sandbox 应用本就被系统
/// 保护；这里改用 SharedPreferences 把数据存在沙盒内的 plist 文件里——其权限
/// 等同于 App 自己目录里的其他文件，仅本应用可读。
class FlutterSecureStorageS3SecretStore implements S3SecretStore {
  const FlutterSecureStorageS3SecretStore();

  static const _secure = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    if (Platform.isMacOS) {
      // macOS：绕开 keychain，走 SharedPreferences。
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_macosKey(key));
    }
    return _secure.read(key: key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (Platform.isMacOS) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_macosKey(key), value);
      return;
    }
    await _secure.write(key: key, value: value);
  }

  /// macOS 上 SharedPreferences 与系统 Keychain 的 key 空间隔离，避免误用。
  static String _macosKey(String key) => 'macos_secret_$key';
}