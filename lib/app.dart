import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/gallery/gallery_provider.dart';
import 'router.dart';

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

/// App 主体，负责启动调度器等全局初始化
class _AppBody extends ConsumerWidget {
  const _AppBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 立即启动分析队列调度器（Provider 懒初始化，watch 会触发创建 + start()）
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
