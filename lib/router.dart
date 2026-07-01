import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/gallery/gallery_screen.dart';
import 'features/gallery/meme_detail_screen.dart';
import 'features/import/import_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/log_viewer_screen.dart';
import 'features/settings/s3_sync_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/gallery',
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
