import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/log_service.dart';
import '../gallery/gallery_provider.dart';

class LogViewerScreen extends ConsumerWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logService = ref.read(logServiceProvider);
    final logs = logService.logs;
    final theme = Theme.of(context);

    Color levelColor(LogLevel level) => switch (level) {
          LogLevel.info => Colors.green,
          LogLevel.warning => Colors.orange,
          LogLevel.error => Colors.red,
        };

    String levelLabel(LogLevel level) =>
        level.name.toUpperCase().padRight(7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => (context as Element).markNeedsBuild(),
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final text = logs
                  .map((e) =>
                      '${e.formattedTimestamp} ${e.level.name.toUpperCase().padRight(7)} [${e.tag}] ${e.message}')
                  .join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('日志已复制到剪贴板'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: '复制日志',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              logService.clear();
              (context as Element).markNeedsBuild();
            },
            tooltip: '清空日志',
          ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.article_outlined,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('暂无日志',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      )),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final entry = logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.formattedTimestamp,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        levelLabel(entry.level),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: levelColor(entry.level),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.tag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
