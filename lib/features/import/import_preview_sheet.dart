import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/file_storage_service.dart';
import '../../services/import_service.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

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
  final PageController _pageCtrl = PageController();
  bool _importing = false;
  bool _done = false;
  int _successCount = 0;
  int _skipCount = 0;
  String? _error;
  int _currentPage = 0;
  List<String> _skippedFiles = [];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = widget.paths.length;
    final single = count == 1;

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
                ? S.of(context).importComplete
                : single
                    ? S.of(context).importImages
                    : S.of(context).importCountImages(count),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          // 图片预览（可滑动画廊）
          if (!_done) ...[
            SizedBox(
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: count == 1
                    ? _ImagePreview(filePath: widget.paths.first)
                    : Stack(
                        children: [
                          PageView(
                            controller: _pageCtrl,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            children: widget.paths
                                .map((p) => _ImagePreview(filePath: p))
                                .toList(),
                          ),
                          // 翻页指示点
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(count, (i) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: _currentPage == i ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _currentPage == i
                                        ? Colors.white
                                        : Colors.white38,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 导入 / 取消 按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _importing ? null : () => Navigator.pop(context),
                    child: Text(S.of(context).cancel),
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
                    label: Text(_importing ? S.of(context).importing : S.of(context).importImages),
                  ),
                ),
              ],
            ),
          ],

          // 导入结果
          if (_done) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _error != null
                        ? Icons.error_outline
                        : Icons.check_circle,
                    color: _error != null ? colorScheme.error : Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error ?? S.of(context).importSuccessCount(_successCount, _skipCount > 0 ? S.of(context).skippedExisting(_skipCount) : ''),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_skippedFiles.isNotEmpty && _skippedFiles.length <= 10) ...[
                        const SizedBox(height: 4),
                        Text(
                          _skippedFiles.map((f) => '• $f').join('\n'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).done),
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
        _skippedFiles = result.skippedFiles;
      });
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _done = true;
        _error = S.of(context).importFailed(e.toString());
      });
    }
  }
}

/// 填充父容器的图片预览（父 SizedBox height:180 控制高度）
class _ImagePreview extends StatelessWidget {
  final String filePath;
  const _ImagePreview({required this.filePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(filePath);

    if (!file.existsSync()) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text(S.of(context).cannotLoadImage, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Image.file(
      file,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.broken_image)),
      ),
    );
  }
}
