import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/gallery/gallery_provider.dart';
import 'router.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkOnResume();
    }
  }

  Future<void> _checkOnStart() async {
    final paths = await SharedMediaHandler().getPendingFiles();
    if (paths.isNotEmpty && mounted) {
      context.pushNamed('import-receive', extra: paths);
      return;
    }
    if (mounted) {
      _checkClipboardImage();
    }
  }

  Future<void> _checkOnResume() async {
    final paths = await SharedMediaHandler().getPendingFiles();
    if (paths.isNotEmpty && mounted) {
      context.pushNamed('import-receive', extra: paths);
      return;
    }
    if (mounted) {
      _checkClipboardImage();
    }
  }

  Future<void> _checkClipboardImage() async {
    final path = await SharedMediaHandler().getClipboardImage();
    if (path == null || path == _lastClipboardPath || !mounted) return;

    _lastClipboardPath = path;

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

    final importPath = path;
    if (confirmed == true && mounted) {
      final service = ref.read(importServiceProvider);
      final meme = await service.importImage(importPath);
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
