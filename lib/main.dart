import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/gallery/gallery_provider.dart';

void main() async {
  final t0 = DateTime.now();
  debugPrint('[Startup] main begin');

  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Startup] ensureInitialized: ${DateTime.now().difference(t0).inMilliseconds}ms');

  // 在所有 Provider 之前初始化 SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  debugPrint('[Startup] SharedPreferences: ${DateTime.now().difference(t0).inMilliseconds}ms');

  // 初始化日志持久化路径（LogService 通过此路径恢复上次会话的日志）
  final docsDir = await getApplicationDocumentsDirectory();
  initLogFilePath('${docsDir.path}/logs/app.log');
  debugPrint('[Startup] docsDir: ${DateTime.now().difference(t0).inMilliseconds}ms');

  // 初始化模型存储目录
  final modelsDir = Directory('${docsDir.path}/models');
  if (!await modelsDir.exists()) {
    await modelsDir.create(recursive: true);
  }
  debugPrint('[Startup] models dir: ${modelsDir.path}');

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  debugPrint('[Startup] runApp: ${DateTime.now().difference(t0).inMilliseconds}ms');
  runApp(MemeManagerApp(prefs: prefs, storageDir: modelsDir.path));
}
