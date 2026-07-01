import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/gallery/gallery_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 在所有 Provider 之前初始化 SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // 初始化日志持久化路径（LogService 通过此路径恢复上次会话的日志）
  final docsDir = await getApplicationDocumentsDirectory();
  initLogFilePath('${docsDir.path}/logs/app.log');

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(MemeHelperApp(prefs: prefs));
}
