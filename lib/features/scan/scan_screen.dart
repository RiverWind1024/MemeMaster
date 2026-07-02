import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/meme_detector.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  List<String> _allImages = [];
  List<MemeDetectionResult> _memes = [];
  ScanProgress? _progress;
  String? _scanDir;
  String? _safUri; // 原始 SAF 内容 URI，用于列文件
  bool _scanning = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).scanMeme)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 选择目录
          if (_scanDir == null && !_scanning)
            Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 64, color: cs.outline),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _pickDir,
                    icon: const Icon(Icons.folder_copy),
                    label: Text(S.of(context).selectDirectoryToScan),
                  ),
                ],
              ),
            ),

          if (_scanDir != null) ...[
            // 当前目录
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder),
                title: Text(_scanDir!.split('/').last),
                subtitle: Text(_scanDir!, style: theme.textTheme.bodySmall),
                trailing: _scanning ? null
                    : IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _startScan,
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // 扫描进度
            if (_scanning && _progress != null) ...[
              LinearProgressIndicator(
                value: _progress!.total > 0
                    ? _progress!.completed / _progress!.total
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context).scanningProgress(_progress!.completed, _progress!.total),
                style: theme.textTheme.bodySmall,
              ),
              if (_progress!.currentFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _progress!.currentFile!.split('/').last,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // 扫描结果
            if (!_scanning && _progress != null) ...[
              Row(
                children: [
                  _StatCard(
                    icon: Icons.emoji_emotions,
                    label: 'Meme',
                    value: '${_progress!.memesFound}',
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    icon: Icons.text_fields,
                    label: S.of(context).hasText,
                    value: '${_progress!.textFound}',
                    color: cs.secondary,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    icon: Icons.image,
                    label: S.of(context).noText,
                    value: '${_progress!.noText}',
                    color: cs.outline,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 检测到的 meme 列表
              if (_memes.isNotEmpty) ...[
                Text(S.of(context).detectedMemes(_memes.length),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ..._memes.asMap().entries.map((e) {
                      final i = e.key;
                      final m = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: GestureDetector(
                            onTap: () => _showImagePreview(m.filePath),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Image.file(
                                  File(m.filePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(Icons.broken_image,
                                          color: cs.outline),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            m.filePath.split('/').last,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${S.of(context).matchScore((m.score * 100).toInt())}${m.text != null ? ' · ${S.of(context).charCount(m.text!.length)}' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  '${(m.score * 100).toInt()}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: m.score >= 0.7
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 18,
                                    color: cs.onSurfaceVariant),
                                onPressed: () => setState(() {
                                  _memes.removeAt(i);
                                }),
                                visualDensity: VisualDensity.compact,
                                tooltip: S.of(context).remove,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _importing ? null : _importAll,
                    icon: _importing
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_download),
                    label: Text(
                      _importing
                          ? S.of(context).importing
                          : S.of(context).importCountMeme(_memes.length),
                    ),
                  ),
                ),
              ],

              if (_memes.isEmpty && _allImages.isNotEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Icon(Icons.search_off, size: 64, color: cs.outline),
                      const SizedBox(height: 16),
                      Text(S.of(context).noMemeDetected,
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickDir() async {
    // Android 上只能用目录选择器或手动输入路径
    // 简单实现：预先提供几个常用目录
    final dir = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(S.of(context).selectScanDirectory),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '/storage/emulated/0/Download'),
            child: ListTile(
              leading: Icon(Icons.download),
              title: Text(S.of(context).directoryDownloads),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '/storage/emulated/0/Pictures'),
            child: ListTile(
              leading: Icon(Icons.photo_library),
              title: Text(S.of(context).directoryPictures),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '/storage/emulated/0/DCIM'),
            child: ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text(S.of(context).directoryCamera),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '/storage/emulated/0/tencent/MicroMsg/Download'),
            child: ListTile(
              leading: Icon(Icons.wechat),
              title: Text(S.of(context).directoryWechat),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '/storage/emulated/0'),
            child: ListTile(
              leading: Icon(Icons.storage),
              title: Text(S.of(context).directoryStorage),
            ),
          ),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showCustomPathInput();
            },
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text(S.of(context).selectDirectoryEllipsis),
            ),
          ),
        ],
      ),
    );

    if (dir != null && mounted) {
      setState(() {
        _scanDir = dir;
        _safUri = _filePathToSafUri(dir);
        _allImages = [];
        _memes = [];
        _progress = null;
      });
      _startScan();
    }
  }

  /// 把 /storage/emulated/0/XXX 转成 SAF tree URI
  String? _filePathToSafUri(String path) {
    final match = RegExp(r'^/storage/emulated/0/(.+)$').firstMatch(path);
    if (match == null) return null;
    return 'content://com.android.externalstorage.documents/tree/primary%3A${Uri.encodeComponent(match.group(1)!)}';
  }

  void _showImagePreview(String filePath) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black26,
            foregroundColor: Colors.white,
            title: Text(
              filePath.split('/').last,
              style: const TextStyle(fontSize: 14),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 8,
              child: Image.file(
                File(filePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomPathInput() async {
    // 使用系统目录选择器（SAF）
    final dir = await _pickDirectoryWithFileSelector();
    if (dir != null && mounted) {
      setState(() {
        _scanDir = dir;
        _allImages = [];
        _memes = [];
        _progress = null;
      });
      _startScan();
    }
  }

  /// 调用 file_selector 的系统目录选择器，返回真实文件路径
  Future<String?> _pickDirectoryWithFileSelector() async {
    try {
      final uriStr = await getDirectoryPath();
      final log = ref.read(logServiceProvider);
      log.info('Scan', 'SAF returned: $uriStr');
      if (uriStr == null) return null;

      if (uriStr.startsWith('/')) {
        // 直接文件路径：构造 SAF content URI 用于列文件
        log.info('Scan', 'direct file path, using as-is: $uriStr');
        final match = RegExp(r'^/storage/emulated/0/(.+)$').firstMatch(uriStr);
        if (match != null) {
          _safUri = 'content://com.android.externalstorage.documents/tree/primary%3A${Uri.encodeComponent(match.group(1)!)}';
          log.info('Scan', 'constructed SAF URI: $_safUri');
        }
        return uriStr;
      }

      // content:// URI：直接保存用于列文件
      _safUri = uriStr;

      // content://com.android.externalstorage.documents/tree/primary%3ADownload
      // → /storage/emulated/0/Download
      final uri = Uri.tryParse(uriStr);
      if (uri == null) {
        log.warning('Scan', 'cannot parse URI: $uriStr');
        return null;
      }

      final pathSegments = uri.pathSegments;
      final pathSegment = pathSegments.last;
      final decoded = Uri.decodeComponent(pathSegment);
      log.info('Scan', 'content URI pathSegments=$pathSegments decoded="$decoded"');

      if (decoded.startsWith('primary:')) {
        final result = '/storage/emulated/0/${decoded.substring(8)}';
        log.info('Scan', 'primary storage path: $result');
        return result;
      }

      // SD 卡路径: /storage/XXXX-XXXX/path  (decoded 形如 XXXX-XXXX:path)
      final colon = decoded.indexOf(':');
      if (colon > 0) {
        final volume = decoded.substring(0, colon);
        final subPath = decoded.substring(colon + 1);
        final result = '/storage/$volume/$subPath';
        log.info('Scan', 'SD card path: $result');
        return result;
      }

      log.warning('Scan', 'unexpected content URI format, trying /storage/$decoded');
      return '/storage/$decoded';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).selectDirectoryFailed(e.toString()))),
        );
      }
      return null;
    }
  }

  Future<void> _startScan() async {
    if (_scanDir == null) return;

    setState(() {
      _scanning = true;
      _memes = [];
      _progress = null;
    });

    // 1. 扫描目录：优先用 SAF content URI 列文件（兼容 Android 分区存储）
    final log = ref.read(logServiceProvider);
    List<String> images;

    if (_safUri != null) {
      log.info('Scan', 'listing via SAF: $_safUri');
      try {
        const channel = MethodChannel('com.memehelper.app/storage');
        final result = await channel.invokeMethod<List<dynamic>>('listSafDirectory', {
          'uri': _safUri,
        });
        images = result?.cast<String>() ?? [];
        log.info('Scan', 'SAF listing found ${images.length} files');
      } catch (e) {
        log.warning('Scan', 'SAF listing failed: $e, falling back to direct path');
        images = MemeDetector.scanDirectory(_scanDir!, logger: (tag, msg) => log.info(tag, msg));
      }
    } else {
      log.info('Scan', 'scanDirectory: $_scanDir');
      images = MemeDetector.scanDirectory(_scanDir!, logger: (tag, msg) => log.info(tag, msg));
    }
    _allImages = images;
    log.info('Scan', 'scanDirectory found ${images.length} images');

    if (images.isEmpty) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).noImagesInDirectory)),
        );
      }
      return;
    }

    // 2. 批量检测（每批5张并发），直接收集结果
    int memesFound = 0, textFound = 0, noText = 0, completed = 0;
    final total = images.length;
    final memes = <MemeDetectionResult>[];

    for (int i = 0; i < images.length; i += 5) {
      if (!mounted) return;
      final batch = images.skip(i).take(5).toList();
      log.info('Scan', 'batch ${i ~/ 5 + 1}/${(total + 4) ~/ 5}');

      final detector = MemeDetector(logger: (tag, msg) => log.info(tag, msg));
      final results = await Future.wait(
          batch.map((p) => detector.detect(p)));

      for (final r in results) {
        completed++;
        log.info('Scan', '${r.filePath.split('/').last}: score=${r.score.toStringAsFixed(2)}'
            ' text=${r.text?.substring(0, (r.text?.length ?? 0).clamp(0, 30))}');
        if (r.isMeme) {
          memesFound++;
          memes.add(r);
        } else if (r.text != null && r.text!.isNotEmpty) {
          textFound++;
        } else {
          noText++;
        }
        if (mounted) {
          setState(() => _progress = ScanProgress(
            total: total, completed: completed,
            memesFound: memesFound, textFound: textFound, noText: noText,
            currentFile: r.filePath,
          ));
        }
      }
    }

    log.info('Scan', 'done: memes=$memesFound text=$textFound noText=$noText');
    if (mounted) {
      setState(() {
        _memes = memes;
        _scanning = false;
        _progress = ScanProgress(
          total: total, completed: completed,
          memesFound: memesFound, textFound: textFound, noText: noText,
        );
      });
    }
  }

  Future<void> _importAll() async {
    setState(() => _importing = true);
    final paths = _memes.map((m) => m.filePath).toList();
    final service = ref.read(importServiceProvider);
    final result = await service.importImages(paths);
    if (mounted) {
      setState(() => _importing = false);
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          S.of(context).importSuccessWithSkip(result.success, result.skipped > 0 ? S.of(context).skippedCount(result.skipped) : ''))),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
