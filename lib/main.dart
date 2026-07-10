import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/llm/local_service.dart';
import 'core/ocr/ocr_service.dart';
import 'features/gallery/gallery_provider.dart';

void main() async {
  final t0 = DateTime.now();
  debugPrint('[Startup] main begin');

  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Startup] ensureInitialized: ${DateTime.now().difference(t0).inMilliseconds}ms');

  // 在所有 Provider 之前初始化 SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  debugPrint('[Startup] SharedPreferences: ${DateTime.now().difference(t0).inMilliseconds}ms');

  // 应用内部目录：数据库、缓存、配置导出、模型文件、日志
  final docsDir = await getApplicationDocumentsDirectory();
  final logFilePath = '${docsDir.path}/logs/app.log';
  initLogFilePath(logFilePath);
  final modelsDir = Directory('${docsDir.path}/models');
  if (!await modelsDir.exists()) {
    await modelsDir.create(recursive: true);
  }
  debugPrint('[Startup] models dir: ${modelsDir.path}');

  // C++ 端 mllm_init 的日志输出文件
  final mllmLogDir = Directory('${docsDir.path}/logs');
  if (!await mllmLogDir.exists()) {
    await mllmLogDir.create(recursive: true);
  }
  setMllmLogFilePath('${mllmLogDir.path}/mllm.log');

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  debugPrint('[Startup] runApp: ${DateTime.now().difference(t0).inMilliseconds}ms');

  // Linux/macOS: 检测 Tesseract OCR 依赖（延迟检测，避免阻塞启动）
  if (Platform.isLinux) {
    OcrService.linuxCheckAndNotify();
  } else if (Platform.isMacOS) {
    OcrService.macOSCheckAndNotify();
  }

  runApp(MemeManagerApp(prefs: prefs, storageDir: modelsDir.path));
}
