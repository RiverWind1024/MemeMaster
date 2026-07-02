import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/import_service.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _paths = <String>[];
  ImportResult? _result;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).importImages)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 选择按钮
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.add_photo_alternate,
                          size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _importing ? null : _pickImages,
                        icon: const Icon(Icons.folder_open),
                        label: Text(S.of(context).importFromAlbum),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 已选文件列表（带缩略图）
                if (_paths.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(S.of(context).selectedCount(_paths.length),
                          style: theme.textTheme.titleSmall),
                      const Spacer(),
                      if (!_importing)
                        TextButton.icon(
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: Text(S.of(context).clear),
                          onPressed: () => setState(() => _paths.clear()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._paths.map((p) => _FileTile(
                        path: p,
                        canRemove: !_importing,
                        onRemove: () => setState(() => _paths.remove(p)),
                      )),
                ],

                // 导入结果
                if (_result != null) ...[
                  const Divider(),
                  Text(S.of(context).importDone, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(S.of(context).importResultSummary(_result!.success, _result!.skipped)),
                  if (_result!.errors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(S.of(context).errorLabel,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.red)),
                    ..._result!.errors.map((e) => Text(e,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.red))),
                  ],
                ],

                if (_importing)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),

          // 底部导入按钮
          if (_paths.isNotEmpty && !_importing)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _doImport,
                    icon: const Icon(Icons.cloud_download),
                    label: Text(S.of(context).importCountImages(_paths.length)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
    );

    try {
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);

      if (files.isNotEmpty && mounted) {
        setState(() {
          for (final file in files) {
            if (file.path != null) {
              _paths.add(file.path!);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).selectFileFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _doImport() async {
    setState(() => _importing = true);

    final service = ref.read(importServiceProvider);
    final result = await service.importImages(_paths);

    if (mounted) {
      setState(() {
        _result = result;
        _importing = false;
      });

      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);

      if (result.success > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).importSuccessCountImages(result.success))),
        );
      }
    }
  }
}

/// 带缩略图的文件列表项
class _FileTile extends StatelessWidget {
  final String path;
  final bool canRemove;
  final VoidCallback onRemove;

  const _FileTile({
    required this.path,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 48,
            height: 48,
            child: file.existsSync()
                ? Image.file(
                    file,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image,
                      color: theme.colorScheme.outline,
                    ),
                  )
                : Icon(Icons.broken_image, color: theme.colorScheme.outline),
          ),
        ),
        title: Text(
          path.split('/').last,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        trailing: canRemove
            ? IconButton(
                icon: Icon(Icons.close, color: theme.colorScheme.outline),
                onPressed: onRemove,
              )
            : null,
      ),
    );
  }
}
