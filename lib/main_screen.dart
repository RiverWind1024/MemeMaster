import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/glass_container.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'l10n/app_localizations.dart';

/// 应用主界面：底部 3 Tab（图库 / 搜索 / 设置）
class MainScreen extends StatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 1});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentTab;
  DateTime? _lastBackPress;

  /// 仅移动端拦截返回键（桌面端无系统返回键）
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  final _tabs = <Widget>[
    const GalleryScreen(),
    const SearchScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  /// 返回键处理：2 秒内连续两次直接退出；首次弹出确认对话框
  Future<void> _handleBackPop(bool didPop) async {
    if (didPop) return;

    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    _showExitConfirmDialog();
  }

  Future<void> _showExitConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx).exitAppTitle),
        content: Text(S.of(ctx).exitAppMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(ctx).exitApp),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: !_isMobile,
      onPopInvokedWithResult: (didPop, _) => _handleBackPop(didPop),
      child: Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentTab,
        children: _tabs,
      ),
      bottomNavigationBar: GlassContainer(
        blur: 22,
        borderRadius: 0,
        padding: EdgeInsets.zero,
        child: NavigationBar(
          selectedIndex: _currentTab,
          onDestinationSelected: (i) => setState(() => _currentTab = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.photo_library_outlined),
              selectedIcon: const Icon(Icons.photo_library),
              label: s.tabGallery,
            ),
            NavigationDestination(
              icon: const Icon(Icons.search_outlined),
              selectedIcon: const Icon(Icons.search),
              label: s.tabSearch,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: s.tabSettings,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
