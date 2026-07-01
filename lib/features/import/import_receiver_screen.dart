import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/import_service.dart';
import '../../services/log_service.dart';
import '../../services/shared_media_handler.dart';
import '../gallery/gallery_provider.dart';

class ImportReceiverScreen extends ConsumerStatefulWidget {
  final List<String>? filePaths;

  const ImportReceiverScreen({super.key, this.filePaths});

  @override
  ConsumerState<ImportReceiverScreen> createState() =>
      _ImportReceiverScreenState();
}

class _ImportReceiverScreenState extends ConsumerState<ImportReceiverScreen> {
  ImportResult? _result;
  bool _importing = true;
  int _processed = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _doImport());
  }

  Future<void> _doImport() async {
    final log = ref.read(logServiceProvider);

    List<String> paths;
    if (widget.filePaths != null && widget.filePaths!.isNotEmpty) {
      paths = widget.filePaths!;
      log.info('ImportReceiver', '使用 widget.filePaths: ${paths.length} paths');
    } else {
      log.info('ImportReceiver', '调用 getPendingFiles...');
      paths = await SharedMediaHandler().getPendingFiles();
      log.info('ImportReceiver', 'getPendingFiles 返回 ${paths.length} 条: ${paths.take(3)}');
    }

    if (paths.isEmpty) {
      log.warning('ImportReceiver', '没有待导入文件');
      if (mounted) {
        setState(() {
          _importing = false;
          _result = const ImportResult(success: 0, skipped: 0);
        });
      }
      return;
    }

    setState(() => _total = paths.length);
    log.info('ImportReceiver', '开始导入 $_total 个文件');

    final service = ref.read(importServiceProvider);
    int success = 0;
    int skipped = 0;
    final errors = <String>[];

    for (final rawPath in paths) {
      String? localPath = rawPath;
      if (rawPath.startsWith('content://') || rawPath.startsWith('file://')) {
        log.info('ImportReceiver', '检测到 URI 类型的路径: $rawPath');
        localPath = await SharedMediaHandler().copyContentUri(rawPath);
        if (localPath == null) {
          log.error('ImportReceiver', 'copyContentUri 失败: $rawPath');
          errors.add('$rawPath: 无法读取 URI');
          if (mounted) setState(() => _processed++);
          continue;
        }
        log.info('ImportReceiver', 'URI 已复制到缓存: $localPath');
      }

      try {
        log.info('ImportReceiver', '正在导入: $localPath');
        final meme = await service.importImage(localPath);
        if (meme != null) {
          success++;
          log.info('ImportReceiver', '导入成功: ${meme.filename}');
        } else {
          skipped++;
          log.info('ImportReceiver', '跳过（已存在）: $localPath');
        }
      } catch (e) {
        log.error('ImportReceiver', '导入异常: $localPath -> $e');
        errors.add('$localPath: $e');
      }
      if (mounted) {
        setState(() => _processed++);
      }
    }

    log.info('ImportReceiver', '导入完成: 成功=$success 跳过=$skipped 错误=${errors.length}');
    if (mounted) {
      setState(() {
        _result = ImportResult(success: success, skipped: skipped, errors: errors);
        _importing = false;
      });
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[ImportReceiverScreen] build called, filePaths=${widget.filePaths?.length}');
    ref.read(logServiceProvider).info('ImportReceiver', 'build called, filePaths=${widget.filePaths?.length}');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('接收分享')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_importing) ...[
                Icon(Icons.cloud_download,
                    size: 64, color: colorScheme.primary),
                const SizedBox(height: 24),
                Text('正在导入 $_processed/$_total 张图片...',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _total > 0 ? _processed / _total : null),
                const SizedBox(height: 8),
                Text('SHA256 去重中',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline)),
              ] else if (_result != null) ...[
                Icon(
                  _result!.success > 0
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 64,
                  color: _result!.success > 0
                      ? Colors.green
                      : colorScheme.outline,
                ),
                const SizedBox(height: 24),
                Text('导入完成', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Text('成功: ${_result!.success}'),
                Text('跳过（已存在）: ${_result!.skipped}'),
                if (_result!.errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('错误: ${_result!.errors.length}',
                      style: TextStyle(color: colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    context.goNamed('gallery');
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('查看图库'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
