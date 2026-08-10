import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/llm/local_service.dart';
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

  // macOS 退出前，原生侧请求关闭本地 LLM（释放 llama.cpp 的 Metal 资源后再退出进程，
  // 否则静态析构时 ggml_metal_rsets_free 断言失败崩溃）
  const lifecycleChannel = MethodChannel('com.mememaster/app_lifecycle');
  lifecycleChannel.setMethodCallHandler(_handleAppLifecycle);

  debugPrint('[Startup] runApp: ${DateTime.now().difference(t0).inMilliseconds}ms');

  runApp(MemeManagerApp(prefs: prefs, storageDir: modelsDir.path));
}

/// 处理原生侧（macOS AppDelegate）的生命周期回调。
Future<void> _handleAppLifecycle(MethodCall call) async {
  if (call.method == 'shutdownLlm') {
    final futures = LocalLlmService.activeInstances.map((s) => s.shutdown());
    try {
      await Future.wait(futures).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // 超时兜底：不阻塞退出
    }
  }
}
