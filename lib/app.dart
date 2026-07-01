import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/gallery/gallery_provider.dart';
import 'router.dart';
import 'services/log_service.dart';
import 'services/shared_media_handler.dart';

class MemeHelperApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MemeHelperApp({super.key, required this.prefs});

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
  String? _lastClipboardPath;
  int _clipboardRetryCount = 0;
  static const _maxClipboardRetries = 3;
  /// 防止重复 resume 导致并行检测
  bool _clipboardCheckBusy = false;

  LogService get _log => ref.read(logServiceProvider);

  @override
  void initState() {
    super.initState();
    SharedMediaHandler.init();
    SharedMediaHandler.onNativeEvent = (method) {
      if (method == 'onNewIntent' && mounted) {
        _log.info('Intent', 'native onNewIntent event → checking pending files');
        _checkOnResume();
      }
    };
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnStart());
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
      _log.info('Intent', 'goNamed import-receive');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            GoRouter.of(context).goNamed('import-receive', extra: paths);
          } catch (e) {
            _log.error('Intent', 'goNamed import-receive failed: $e');
          }
        } else {
          _log.warning('Intent', 'goNamed skipped: not mounted');
        }
      });
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
      _log.info('Intent', 'goNamed import-receive (scheduled post-frame)');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            GoRouter.of(context).goNamed('import-receive', extra: paths);
          } catch (e) {
            _log.error('Intent', 'goNamed import-receive failed: $e');
          }
        } else {
          _log.warning('Intent', 'goNamed skipped: not mounted');
        }
      });
      return;
    }
    if (mounted && !_clipboardCheckBusy) {
      _clipboardRetryCount = 0;
      _scheduleClipboardCheck(delay: const Duration(seconds: 2));
    }
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
    _log.info('Clipboard', 'getClipboardImage attempt ${_clipboardRetryCount + 1}/$_maxClipboardRetries');
    final rawPath = await SharedMediaHandler().getClipboardImage();
    final preview = rawPath != null ? (rawPath.length > 120 ? '${rawPath.substring(0, 120)}...' : rawPath) : 'null';
    _log.info('Clipboard', 'getClipboardImage returned: $preview');

    if (rawPath == null && _clipboardRetryCount < _maxClipboardRetries - 1) {
      _clipboardRetryCount++;
      _log.info('Clipboard', 'retrying after 1s delay...');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        await _doClipboardCheck();
      }
      return;
    }

    _clipboardRetryCount = 0;

    if (rawPath == null || rawPath == _lastClipboardPath || !mounted) {
      _log.info('Clipboard', 'skip: rawPath=$preview lastPath=$_lastClipboardPath mounted=$mounted');
      return;
    }

    _lastClipboardPath = rawPath;

    String? localPath;
    if (rawPath.startsWith('http-url://')) {
      final url = rawPath.substring(10);
      _log.info('Clipboard', 'downloading HTTP URL: $url');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在下载剪贴板中的图片...')),
        );
      }
      localPath = await _downloadToCache(url);
      _log.info('Clipboard', 'download result: $localPath');
      if (localPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('剪贴板图片下载失败')),
          );
        }
        return;
      }
    } else {
      localPath = rawPath;
    }

    _log.info('Clipboard', 'showing import dialog for: $localPath');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('检测到剪贴板图片'),
        content: Text('剪贴板中有一张图片，是否导入到 MemeHelper？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    _log.info('Clipboard', 'dialog result: $confirmed');

    final importPath = localPath;
    if (confirmed == true && mounted) {
      final service = ref.read(importServiceProvider);
      final meme = await service.importImage(importPath);
      _log.info('Clipboard', 'import result: ${meme != null ? "imported" : "skipped (duplicate)"}');
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              meme != null ? '导入成功' : '图片已存在，跳过导入',
            ),
          ),
        );
      }
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
      title: 'MemeHelper',
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
