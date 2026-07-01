import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/file_storage_service.dart';
import '../../services/import_service.dart';
import '../gallery/gallery_provider.dart';

/// 从底部弹出的导入预览弹窗，支持单图/多图
Future<void> showImportPreviewSheet(
  BuildContext context,
  List<String> paths,
) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ImportPreviewSheet(paths: paths),
  );
}

class _ImportPreviewSheet extends ConsumerStatefulWidget {
  final List<String> paths;
  const _ImportPreviewSheet({required this.paths});

  @override
  ConsumerState<_ImportPreviewSheet> createState() =>
      _ImportPreviewSheetState();
}

class _ImportPreviewSheetState extends ConsumerState<_ImportPreviewSheet> {
  bool _importing = false;
  bool _done = false;
  int _successCount = 0;
  int _skipCount = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final single = widget.paths.length == 1;
    final previewPath = widget.paths.first;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖动指示条
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 标题
          Text(
            _done
                ? '导入完成'
                : single
                    ? '导入图片'
                    : '导入 ${widget.paths.length} 张图片',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // 图片预览
          if (!_done) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _ImagePreview(filePath: previewPath),
            ),
            if (!single)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '共 ${widget.paths.length} 张图片',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // 导入 / 取消 按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _importing ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _importing ? null : _doImport,
                    icon: _importing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_download),
                    label: Text(_importing ? '导入中...' : '导入'),
                  ),
                ),
              ],
            ),
          ],

          // 导入结果
          if (_done) ...[
            Row(
              children: [
                Icon(
                  _error != null
                      ? Icons.error_outline
                      : Icons.check_circle,
                  color: _error != null ? colorScheme.error : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ?? '成功 $_successCount 张'
                        '${_skipCount > 0 ? '，已跳过 $_skipCount 张' : ''}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _doImport() async {
    setState(() => _importing = true);
    try {
      final service = ref.read(importServiceProvider);
      final result = await service.importImages(widget.paths);
      setState(() {
        _importing = false;
        _done = true;
        _successCount = result.success;
        _skipCount = result.skipped;
      });
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);
    } catch (e) {
      setState(() {
        _importing = false;
        _done = true;
        _error = '导入失败: $e';
      });
    }
  }
}

/// 异步加载图片文件预览
class _ImagePreview extends StatelessWidget {
  final String filePath;
  const _ImagePreview({required this.filePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(filePath);

    if (!file.existsSync()) {
      return Container(
        height: 200,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text('无法加载图片', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        file,
        height: 260,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      ),
    );
  }
}
