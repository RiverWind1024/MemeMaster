import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../l10n/app_localizations.dart';
import '../gallery/gallery_provider.dart';

/// 日期范围枚举
enum StatsDateRange { last7, last30, last365 }

/// 用户统计页面（含 Token 用量热度图）
class UserStatsScreen extends ConsumerStatefulWidget {
  const UserStatsScreen({super.key});

  @override
  ConsumerState<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends ConsumerState<UserStatsScreen> {
  StatsDateRange _dateRange = StatsDateRange.last7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.userStatsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 日期范围选择
          _DateRangeSelector(
            selected: _dateRange,
            onChanged: (v) => setState(() => _dateRange = v),
          ),
          const SizedBox(height: 16),

          // 今日统计
          Text(s.todayStats, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ref.watch(todayStatsProvider).when(
            loading: () => _cardLoading(),
            error: (e, _) => _cardError('$e'),
            data: (stats) => _TodayStatsCard(stats: stats, theme: theme, cs: cs, s: s),
          ),

          const SizedBox(height: 24),

          // Token 用量热度图
          Text('${s.tokenUsage} · ${s.heatmap}', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ref.watch(_statsListProvider(_dateRange)).when(
            loading: () => _cardLoading(),
            error: (e, _) => _cardError('$e'),
            data: (stats) => _HeatmapCard(
              stats: stats,
              days: _dateRangeDays(_dateRange),
              theme: theme,
              cs: cs,
            ),
          ),

          const SizedBox(height: 24),

          // 每日明细趋势
          Text(s.recent7DayTrend, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ref.watch(_statsListProvider(_dateRange)).when(
            loading: () => _cardLoading(),
            error: (e, _) => _cardError('$e'),
            data: (stats) => _TrendListCard(stats: stats, theme: theme, cs: cs, s: s),
          ),

          const SizedBox(height: 24),

          // 全部汇总
          Text(s.totalSummary, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ref.watch(totalStatsProvider).when(
            loading: () => _cardLoading(),
            error: (e, _) => _cardError('$e'),
            data: (totals) => _TotalSummaryCard(totals: totals, theme: theme, cs: cs, s: s),
          ),
        ],
      ),
    );
  }

  Widget _cardLoading() => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );

  Widget _cardError(String msg) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(msg),
        ),
      );

  int _dateRangeDays(StatsDateRange range) => switch (range) {
        StatsDateRange.last7 => 7,
        StatsDateRange.last30 => 30,
        StatsDateRange.last365 => 365,
      };
}

/// 根据日期范围获取统计数据
final _statsListProvider =
    FutureProvider.family<List<UserStatsEntry>, StatsDateRange>((ref, range) {
  final dao = ref.read(userStatsDaoProvider);
  final days = switch (range) {
    StatsDateRange.last7 => 7,
    StatsDateRange.last30 => 30,
    StatsDateRange.last365 => 365,
  };
  return dao.getRecentDays(days);
});

// ─── 日期范围选择器 ────────────────────────────────────────────

class _DateRangeSelector extends StatelessWidget {
  final StatsDateRange selected;
  final ValueChanged<StatsDateRange> onChanged;

  const _DateRangeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Text('${s.statsDateRange}: ', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        ...StatsDateRange.values.map((range) {
          final label = switch (range) {
            StatsDateRange.last7 => s.last7Days,
            StatsDateRange.last30 => s.last30Days,
            StatsDateRange.last365 => s.last365Days,
          };
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected == range,
              onSelected: (_) => onChanged(range),
            ),
          );
        }),
      ],
    );
  }
}

// ─── 今日统计卡片 ──────────────────────────────────────────────

class _TodayStatsCard extends StatelessWidget {
  final UserStatsEntry? stats;
  final ThemeData theme;
  final ColorScheme cs;
  final S s;

  const _TodayStatsCard({
    required this.stats,
    required this.theme,
    required this.cs,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final entry = stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Expanded(child: _StatItem(icon: Icons.file_download, label: s.imported,
                value: '${entry?.importedCount ?? 0}', color: cs.primary)),
            Expanded(child: _StatItem(icon: Icons.copy, label: s.copied,
                value: '${entry?.copiedCount ?? 0}', color: cs.secondary)),
            Expanded(child: _StatItem(icon: Icons.favorite, label: s.favorited,
                value: '${entry?.favoritedCount ?? 0}', color: Colors.pink)),
            Expanded(child: _StatItem(icon: Icons.timer, label: s.promptTokens,
                value: '${entry?.promptTokens ?? 0}', color: Colors.teal)),
            Expanded(child: _StatItem(icon: Icons.done_outline, label: s.completionTokens,
                value: '${entry?.completionTokens ?? 0}', color: Colors.indigo)),
          ],
        ),
      ),
    );
  }
}

// ─── 热度图 ────────────────────────────────────────────────────

class _HeatmapCard extends StatelessWidget {
  final List<UserStatsEntry> stats;
  final int days;
  final ThemeData theme;
  final ColorScheme cs;

  const _HeatmapCard({
    required this.stats,
    required this.days,
    required this.theme,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    const cellSize = 12.0;
    const cellMargin = 3.0;
    const cellTotal = cellSize + cellMargin; // 15

    final statMap = {for (final s in stats) s.date: s};
    final now = DateTime.now();

    // 计算最大活跃度值用于归一化（仅含 meme 操作：导入 + 复制 + 收藏）
    int maxActivity = 0;
    for (final s in stats) {
      final activity = s.importedCount + s.copiedCount + s.favoritedCount;
      if (activity > maxActivity) maxActivity = activity;
    }

    // 生成日期列表（最近 days 天）
    final dateList = List.generate(days, (i) {
      final d = now.subtract(Duration(days: days - 1 - i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return (date: key, weekday: d.weekday);
    });

    // 每列 7 天（周一到周日），与 GitHub 热度图布局一致
    final weeks = <List<Map<String, dynamic>>>[];
    for (int i = 0; i < dateList.length; i += 7) {
      weeks.add(dateList.sublist(i, (i + 7) > dateList.length ? dateList.length : i + 7)
          .map((d) => {
            'date': d.date,
            'weekday': d.weekday,
            'stat': statMap[d.date],
          }).toList());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 7 * cellTotal + 4, // 固定高度容纳 7 行
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weeks.map((week) {
                return Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: week.map((day) {
                      final stat = day['stat'] as UserStatsEntry?;
                      final activity = stat == null ? 0
                          : stat.importedCount + stat.copiedCount + stat.favoritedCount;
                      final intensity = maxActivity > 0 ? activity / maxActivity : 0.0;

                      final color = intensity > 0.75
                          ? Colors.green.shade800
                          : intensity > 0.5
                              ? Colors.green.shade500
                              : intensity > 0.25
                                  ? Colors.green.shade300
                                  : intensity > 0
                                      ? Colors.green.shade100
                                      : cs.surfaceContainerHighest ?? Colors.grey.shade200;

                      return Tooltip(
                        message: '${day['date']}: $activity',
                        child: Container(
                          width: cellSize,
                          height: cellSize,
                          margin: EdgeInsets.only(bottom: cellMargin),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 每日明细趋势 ──────────────────────────────────────────────

class _TrendListCard extends StatelessWidget {
  final List<UserStatsEntry> stats;
  final ThemeData theme;
  final ColorScheme cs;
  final S s;

  const _TrendListCard({
    required this.stats,
    required this.theme,
    required this.cs,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: stats.reversed.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.date.length >= 5 ? entry.date.substring(5) : entry.date,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(label: s.imported, value: '${entry.importedCount}', color: cs.primary),
                  const SizedBox(width: 8),
                  _MiniStat(label: s.copied, value: '${entry.copiedCount}', color: cs.secondary),
                  const SizedBox(width: 8),
                  _MiniStat(label: s.favorited, value: '${entry.favoritedCount}', color: Colors.pink),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.promptTokens + entry.completionTokens}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.teal),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── 全部汇总 ──────────────────────────────────────────────────

class _TotalSummaryCard extends StatelessWidget {
  final Map<String, int> totals;
  final ThemeData theme;
  final ColorScheme cs;
  final S s;

  const _TotalSummaryCard({
    required this.totals,
    required this.theme,
    required this.cs,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Expanded(child: _StatItem(icon: Icons.file_download, label: s.imported,
                value: '${totals['totalImported'] ?? 0}', color: cs.primary)),
            Expanded(child: _StatItem(icon: Icons.copy, label: s.copied,
                value: '${totals['totalCopied'] ?? 0}', color: cs.secondary)),
            Expanded(child: _StatItem(icon: Icons.favorite, label: s.favorited,
                value: '${totals['totalFavorited'] ?? 0}', color: Colors.pink)),
            Expanded(child: _StatItem(icon: Icons.timer, label: s.promptTokens,
                value: '${totals['totalPromptTokens'] ?? 0}', color: Colors.teal)),
            Expanded(child: _StatItem(icon: Icons.done_outline, label: s.completionTokens,
                value: '${totals['totalCompletionTokens'] ?? 0}', color: Colors.indigo)),
          ],
        ),
      ),
    );
  }
}

// ─── 通用小组件 ────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            )),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(width: 2),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}
