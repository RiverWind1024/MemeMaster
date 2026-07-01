import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/color_utils.dart';
import '../../services/search_service.dart';
import '../gallery/gallery_provider.dart';
import 'color_picker_dialog.dart';
import 'color_picker_palette.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  List<SearchResult>? _results;
  bool _searching = false;
  SearchLevel _level = SearchLevel.browse;

  // 选择的颜色（色值列表）
  final Set<int> _selectedColorValues = {};
  final List<ColorRgb> _customColors = [];

  bool get _hasActiveFilters =>
      _queryController.text.trim().isNotEmpty || _selectedColorValues.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _detectLevel();
    // 初始加载最近图片
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerSearch());
  }

  @override
  void dispose() {
    _queryController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _detectLevel() async {
    final service = ref.read(searchServiceProvider);
    final level = await service.detectLevel();
    if (mounted) setState(() => _level = level);
  }

  /// 所有选中的颜色（预设 + 自定义）
  List<ColorRgb> get _allColors {
    final colors = <ColorRgb>[];
    for (final v in _selectedColorValues) {
      colors.add(_intToRgb(v));
    }
    colors.addAll(_customColors);
    return colors;
  }

  ColorRgb _intToRgb(int value) => ColorRgb(
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      );

  /// 触发搜索（合并文本 + 颜色）
  Future<void> _triggerSearch() async {
    final query = _queryController.text.trim();
    final colors = _allColors;

    setState(() => _searching = true);

    try {
      final service = ref.read(searchServiceProvider);
      final results = await service.search(
        query: query,
        colors: colors.isNotEmpty ? colors : null,
      );

      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _triggerSearch);
  }

  void _onColorToggle(int colorValue) {
    setState(() {
      if (_selectedColorValues.contains(colorValue)) {
        _selectedColorValues.remove(colorValue);
      } else {
        _selectedColorValues.add(colorValue);
      }
    });
    _triggerSearch();
  }

  void _removeColor(int colorValue) {
    setState(() => _selectedColorValues.remove(colorValue));
    _triggerSearch();
  }

  void _removeCustomColor(int index) {
    setState(() => _customColors.removeAt(index));
    _triggerSearch();
  }

  Future<void> _openCustomPicker() async {
    final color = await ColorPickerDialog.show(context);
    if (color != null && mounted) {
      setState(() => _customColors.add(color));
      _triggerSearch();
    }
  }

  void _clearAll() {
    _queryController.clear();
    setState(() {
      _selectedColorValues.clear();
      _customColors.clear();
      _results = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          if (_hasActiveFilters)
            TextButton(
              onPressed: _clearAll,
              child: const Text('重置'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _queryController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索图片（语义/关键词）...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 颜色选择区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    const Icon(Icons.palette_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('按颜色筛选', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (_allColors.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColorValues.clear();
                            _customColors.clear();
                          });
                          _triggerSearch();
                        },
                        child: Text('清除',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                            )),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // 色板
                ColorPickerPalette(
                  selectedValues: _selectedColorValues.toList(),
                  onToggle: _onColorToggle,
                  onCustom: _openCustomPicker,
                ),

                // 已选颜色 chips
                if (_allColors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ..._selectedColorValues.map((v) {
                        final preset = kPresetColors.firstWhere(
                          (p) => p.value == v,
                          orElse: () => PresetColor(
                            label: '',
                            value: v,
                            rgb: _intToRgb(v),
                          ),
                        );
                        return _ColorChip(
                          label: preset.label,
                          color: Color(v),
                          onRemove: () => _removeColor(v),
                        );
                      }),
                      ..._customColors.asMap().entries.map((e) => _ColorChip(
                            label: e.value.hex,
                            color: Color.fromARGB(255, e.value.r, e.value.g, e.value.b),
                            onRemove: () => _removeCustomColor(e.key),
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 搜索级别指示器
          if (_level != SearchLevel.browse)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Spacer(),
                  _SearchLevelBadge(level: _level),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // 搜索结果
          Expanded(child: _buildResults(theme, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme, ColorScheme colorScheme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results == null) {
      // 初始状态（无搜索）
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '输入关键词或选择颜色开始搜索',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _level == SearchLevel.browse
                  ? '暂无图片数据，请先导入图片'
                  : '支持文字搜索 + 颜色筛选叠加使用',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_results!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配的图片',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '试试其他关键词或颜色',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 结果计数
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '找到 ${_results!.length} 个结果',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // 结果网格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: _results!.length,
            itemBuilder: (context, index) {
              final result = _results![index];
              return _SearchResultGridTile(
                result: result,
                onTap: () => context.pushNamed(
                  'meme-detail',
                  pathParameters: {'id': result.meme.id},
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 搜索结果网格瓦片（带匹配度角标）
class _SearchResultGridTile extends ConsumerWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultGridTile({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(fileStorageServiceProvider);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder(
              future: storage.getImage(result.meme.filePath),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.file(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                  );
                }
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
            // 匹配度角标
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(result.relevance * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已选颜色 chip
class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;

  const _ColorChip({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14,
                color: Theme.of(context).colorScheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// 搜索级别徽章
class _SearchLevelBadge extends StatelessWidget {
  final SearchLevel level;

  const _SearchLevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      SearchLevel.full => ('L3 全功能', Colors.green),
      SearchLevel.colorAndKeyword => ('L2 关键词+颜色', Colors.orange),
      SearchLevel.colorOnly => ('L1 仅颜色', Colors.blue),
      SearchLevel.browse => ('L0 浏览', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
