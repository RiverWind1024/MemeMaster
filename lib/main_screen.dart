import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
