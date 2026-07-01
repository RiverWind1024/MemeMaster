import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/gallery/gallery_screen.dart';
import 'features/gallery/meme_detail_screen.dart';
import 'features/import/import_receiver_screen.dart';
import 'features/import/import_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/log_viewer_screen.dart';
import 'features/settings/s3_sync_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
/// 分享给其他文件使用的 Navigator key，用于在 MaterialApp.router 内部显示对话框等
GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

/// [DIAG] 记录所有路由变化
class _RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[Router] didPush: ${route.settings.name} <- ${previousRoute?.settings.name}');
  }
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[Router] didPop: ${route.settings.name} -> ${previousRoute?.settings.name}');
  }
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint('[Router] didReplace: ${newRoute?.settings.name} <- ${oldRoute?.settings.name}');
  }
}

final _routeLogger = _RouteLogger();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [_routeLogger],
  initialLocation: '/gallery',
  // 拦截 Android intent deep link（content:// file:// 等），避免 GoException
  redirect: (context, state) {
    final location = state.uri.toString();
    if (location.startsWith('content://') ||
        location.startsWith('file://') ||
        location.startsWith('http://') ||
        location.startsWith('https://')) {
      return '/gallery';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/gallery',
      name: 'gallery',
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: '/meme/:id',
      name: 'meme-detail',
      builder: (context, state) => MemeDetailScreen(
        memeId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/import',
      name: 'import',
      builder: (context, state) => const ImportScreen(),
    ),
    GoRoute(
      path: '/import/receive',
      name: 'import-receive',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is List<String>) {
          return ImportReceiverScreen(filePaths: extra);
        }
        return const ImportReceiverScreen();
      },
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/logs',
      name: 'logs',
      builder: (context, state) => const LogViewerScreen(),
    ),
    GoRoute(
      path: '/settings/s3-sync',
      name: 's3-sync',
      builder: (context, state) => const S3SyncScreen(),
    ),
  ],
);
