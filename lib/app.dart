import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/gallery/gallery_provider.dart';
import 'features/import/import_preview_sheet.dart';
import 'router.dart';
import 'services/log_service.dart';
import 'services/shared_media_handler.dart';

class MemeManagerApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MemeManagerApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: _AppBody(),
    );
  }
}

class _AppBody extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppBody> createState() => _AppBodyState();
}

class _AppBodyState extends ConsumerState<_AppBody> with WidgetsBindingObserver {
  final DateTime _appStartTime = DateTime.now();
  String? _lastClipboardPath;
  /// 防止重复 resume 导致并行检测
  bool _clipboardCheckBusy = false;

  LogService get _log => ref.read(logServiceProvider);
  /// MaterialApp.router 内部的 context（用于 showDialog / ScaffoldMessenger）
  BuildContext? get _navCtx => rootNavigatorKey.currentContext;

  @override
  void initState() {
    final t0 = DateTime.now();
    super.initState();
    debugPrint('[Startup] _AppBodyState.initState: ${t0.difference(_appStartTime).inMilliseconds}ms');
    SharedMediaHandler.init();
    debugPrint('[Startup] SharedMediaHandler.init: ${DateTime.now().difference(t0).inMilliseconds}ms');
    SharedMediaHandler.onNativeEvent = (method) {
      if (method == 'onNewIntent' && mounted) {
        _log.info('Intent', 'native onNewIntent event → checking pending files');
        _checkOnResume();
      }
    };
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[Startup] addObserver: ${DateTime.now().difference(t0).inMilliseconds}ms');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[Startup] postFrameCallback: ${DateTime.now().difference(_appStartTime).inMilliseconds}ms');
      _checkOnStart();
    });
  }

  @override
  void dispose() {
    SharedMediaHandler.onNativeEvent = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _log.info('AppLifecycle', 'resumed → _checkOnResume');
      _checkOnResume();
    }
  }

  Future<void> _checkOnStart() async {
    _log.info('Intent', 'checkOnStart: checking pending files...');
    final paths = await SharedMediaHandler().getPendingFiles();
    final preview = paths.take(3).map((p) => p.length > 80 ? '${p.substring(0, 80)}...' : p).toList();
    _log.info('Intent', 'getPendingFiles returned ${paths.length} paths: $preview');
    if (paths.isNotEmpty && mounted) {
      _showImportSheet(paths);
      return;
    }
    if (mounted) {
      _checkClipboardOnStart();
    }
  }

  Future<void> _checkOnResume() async {
    _log.info('Intent', 'checkOnResume: checking pending files...');
    final paths = await SharedMediaHandler().getPendingFiles();
    final preview = paths.take(3).map((p) => p.length > 80 ? '${p.substring(0, 80)}...' : p).toList();
    _log.info('Intent', 'getPendingFiles returned ${paths.length} paths: $preview');
    if (paths.isNotEmpty && mounted) {
      _showImportSheet(paths);
      return;
    }
    if (mounted && !_clipboardCheckBusy) {
      _scheduleClipboardCheck(delay: const Duration(milliseconds: 500));
    }
  }

  /// 在当前页面弹出导入预览弹窗（不跳转首页，避免导航时序冲突）
  void _showImportSheet(List<String> paths) {
    if (!mounted || _navCtx == null) {
      _log.warning('Intent', '_navCtx null, cannot show import sheet');
      return;
    }
    _log.info('Intent', 'showImportPreviewSheet');
    showImportPreviewSheet(_navCtx!, paths);
  }

  /// app 启动时检查剪贴板（无需延迟）
  Future<void> _checkClipboardOnStart() async {
    if (_clipboardCheckBusy) return;
    _clipboardCheckBusy = true;
    try {
      await _doClipboardCheck();
    } finally {
      _clipboardCheckBusy = false;
    }
  }

  /// resume 后延迟执行剪贴板检测（避免 Android 剪贴板暂态）
  Future<void> _scheduleClipboardCheck({Duration delay = const Duration(seconds: 2)}) async {
    if (_clipboardCheckBusy) {
      _log.info('Clipboard', 'scheduleClipboardCheck: already busy, skip');
      return;
    }
    _clipboardCheckBusy = true;
    try {
      _log.info('Clipboard', 'scheduled clipboard check in ${delay.inSeconds}s');
      await Future.delayed(delay);
      if (!mounted) return;
      await _doClipboardCheck();
    } finally {
      _clipboardCheckBusy = false;
    }
  }

  Future<void> _doClipboardCheck() async {
    _log.info('Clipboard', 'getClipboardImage');
    final rawPath = await SharedMediaHandler().getClipboardImage();
    final preview = rawPath != null ? (rawPath.length > 120 ? '${rawPath.substring(0, 120)}...' : rawPath) : 'null';
    _log.info('Clipboard', 'getClipboardImage returned: $preview');

    if (rawPath == null || rawPath == _lastClipboardPath || !mounted) {
      _log.info('Clipboard', 'skip: rawPath=$preview lastPath=$_lastClipboardPath mounted=$mounted');
      return;
    }

    _lastClipboardPath = rawPath;

    String? localPath;
    if (rawPath.startsWith('http-url://')) {
      final url = rawPath.substring(10);
      _log.info('Clipboard', 'downloading HTTP URL: $url');
      if (_navCtx != null && mounted) {
        ScaffoldMessenger.of(_navCtx!).showSnackBar(
          const SnackBar(content: Text('正在下载剪贴板中的图片...')),
        );
      }
      localPath = await _downloadToCache(url);
      _log.info('Clipboard', 'download result: $localPath');
      if (localPath == null) {
        if (_navCtx != null && mounted) {
          ScaffoldMessenger.of(_navCtx!).showSnackBar(
            const SnackBar(content: Text('剪贴板图片下载失败')),
          );
        }
        return;
      }
    } else {
      localPath = rawPath;
    }

    if (_navCtx == null) {
      _log.error('Clipboard', 'navCtx is null, cannot show bottom sheet');
      return;
    }

    // 查重：剪贴板图片如果已经在库中，静默跳过
    try {
      final clipFile = File(localPath);
      if (await clipFile.exists()) {
        final bytes = await clipFile.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        final existing = await ref.read(memeRepositoryProvider).getByFileHash(hash);
        if (existing != null) {
          _log.info('Clipboard', 'clipboard image already imported (hash=$hash), skipping');
          if (mounted) {
            ScaffoldMessenger.of(_navCtx!).showSnackBar(
              const SnackBar(
                content: Text('剪贴板图片已导入过'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      _log.warning('Clipboard', 'hash check failed, proceeding anyway: $e');
    }

    _log.info('Clipboard', 'showing import preview sheet for: $localPath');
    if (mounted && _navCtx != null) {
      await showImportPreviewSheet(_navCtx!, [localPath]);
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);
    }
  }

  /// 从 URL 下载图片到缓存目录，返回本地路径
  Future<String?> _downloadToCache(String url) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('downloadToCache: HTTP ${response.statusCode}');
        return null;
      }
      final ext = _extFromUrl(url);
      final file = File(
          '${Directory.systemTemp.path}/clipboard_dl_${DateTime.now().millisecondsSinceEpoch}$ext');
      await response.pipe(file.openWrite());
      debugPrint('downloadToCache: $url -> ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('downloadToCache failed: $url -> $e');
      return null;
    }
  }

  String _extFromUrl(String url) {
    final path = Uri.parse(url).path;
    final dot = path.lastIndexOf('.');
    if (dot >= 0) {
      final ext = path.substring(dot).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
        return ext;
      }
    }
    return '.jpg';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(analysisSchedulerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MemeManager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
