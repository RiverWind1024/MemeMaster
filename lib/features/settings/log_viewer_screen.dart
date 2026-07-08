import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/log_service.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class LogViewerScreen extends ConsumerStatefulWidget {
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 按当前搜索词过滤日志：匹配 message / tag / level（大小写不敏感）
  List<LogEntry> _filter(List<LogEntry> logs) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return logs;
    return logs.where((e) {
      return e.message.toLowerCase().contains(q) ||
          e.tag.toLowerCase().contains(q) ||
          e.level.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final logService = ref.read(logServiceProvider);
    final allLogs = logService.logs;
    final filteredLogs = _filter(allLogs);
    final theme = Theme.of(context);
    final l10n = S.of(context);

    Color levelColor(LogLevel level) => switch (level) {
          LogLevel.info => Colors.green,
          LogLevel.warning => Colors.orange,
          LogLevel.error => Colors.red,
        };

    String levelLabel(LogLevel level) =>
        level.name.toUpperCase().padRight(7);

    Widget emptyState(IconData icon, String message) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(message,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  )),
            ],
          ),
        );

    Widget logRow(LogEntry entry) => Padding(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.logViewer),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              logService.reloadMllmLog();
              setState(() {});
            },
            tooltip: l10n.refresh,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: filteredLogs.isEmpty
                ? null
                : () {
                    final text = filteredLogs
                        .map((e) =>
                            '${e.formattedTimestamp} ${e.level.name.toUpperCase().padRight(7)} [${e.tag}] ${e.message}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${l10n.logCopied} (${filteredLogs.length}${_query.trim().isEmpty ? '' : '/${allLogs.length}'})'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            tooltip: l10n.copy,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: allLogs.isEmpty
                ? null
                : () async {
                    final text = allLogs
                        .map((e) =>
                            '${e.formattedTimestamp} ${e.level.name.toUpperCase().padRight(7)} [${e.tag}] ${e.message}')
                        .join('\n');
                    try {
                      final tempDir = await getTemporaryDirectory();
                      final now = DateTime.now();
                      final filename =
                          'memehelper-log-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.log';
                      final file = File('${tempDir.path}/$filename');
                      await file.writeAsString(text);
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        text: 'MemeHelper Logs',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.logExported),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.exportFailed(e.toString())),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
            tooltip: l10n.export,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              logService.clear();
              setState(() {});
            },
            tooltip: l10n.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.logSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (allLogs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.logFilteredCount(filteredLogs.length, allLogs.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          Expanded(
            child: allLogs.isEmpty
                ? emptyState(Icons.article_outlined, l10n.noLogs)
                : filteredLogs.isEmpty
                    ? emptyState(Icons.search_off, l10n.logNoMatch)
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) =>
                            logRow(filteredLogs[index]),
                      ),
          ),
        ],
      ),
    );
  }
}