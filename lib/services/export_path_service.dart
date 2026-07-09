import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// 导出路径服务
///
/// 管理默认导出目录配置，默认值为 ~/Downloads/MemeHelper
class ExportPathService {
  static const _key = 'default_export_path';

  /// 获取默认导出路径
  /// 默认: ~/Downloads/MemeHelper
  static Future<String> getDefaultExportPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key);
    if (path != null && path.isNotEmpty) {
      return _expandPath(path);
    }
    return _expandPath('~/Downloads/MemeHelper');
  }

  /// 设置默认导出路径
  static Future<void> setDefaultExportPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  /// 展开 ~ 路径为完整路径
  static String _expandPath(String path) {
    if (path.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '';
      return path.replaceFirst('~', home);
    }
    return path;
  }

  /// 确保导出目录存在，返回完整路径
  static Future<String> ensureExportDir() async {
    final path = await getDefaultExportPath();
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }
}
