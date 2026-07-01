import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/import_service.dart';
import '../gallery/gallery_provider.dart';

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
      appBar: AppBar(
        title: const Text('导入图片'),
        actions: [
          if (_paths.isNotEmpty && !_importing)
            TextButton(
              onPressed: _doImport,
              child: const Text('导入'),
            ),
        ],
      ),
      body: ListView(
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
                  label: const Text('从相册选择'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 已选文件列表
          if (_paths.isNotEmpty) ...[
            Text('已选 ${_paths.length} 张',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._paths.map((p) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.image_outlined),
                  title: Text(p.split('/').last),
                  trailing: _importing
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() => _paths.remove(p));
                          },
                        ),
                )),
          ],

          // 导入结果
          if (_result != null) ...[
            const Divider(),
            Text('导入完成', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('成功: ${_result!.success}  跳过: ${_result!.skipped}'),
            if (_result!.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('错误:', style: theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
              ..._result!.errors.map((e) => Text(e,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red))),
            ],
          ],

          if (_importing)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
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
          SnackBar(content: Text('选择文件失败: $e')),
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
          SnackBar(content: Text('成功导入 ${result.success} 张图片')),
        );
      }
    }
  }
}
