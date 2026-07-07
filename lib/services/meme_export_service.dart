import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

import '../core/database/database.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';

/// 导出数据包格式
class MemeExportItem {
  final String hash;
  final String filename;
  final String imagePath;
  final List<ColorEntry> colors;
  final List<TagEntry> tags;
  final String? description;

  MemeExportItem({
    required this.hash,
    required this.filename,
    required this.imagePath,
    required this.colors,
    required this.tags,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'colors': colors
            .map((c) => {
                  'hexColor': c.hexColor,
                  'labL': c.labL,
                  'labA': c.labA,
                  'labB': c.labB,
                  'ratio': c.ratio,
                })
            .toList(),
        'tags': tags
            .map((t) => {
                  'source': t.source,
                  'content': t.content,
                  'confidence': t.confidence,
                })
            .toList(),
        'description': description,
      };
}

/// Meme 导出服务
class MemeExportService {
  final MemeRepository _memeRepo;
  final FileStorageService _storage;

  MemeExportService({
    required MemeRepository memeRepo,
    required FileStorageService storage,
  })  : _memeRepo = memeRepo,
        _storage = storage;

  /// 导出 memes 到 zip 文件
  /// 返回 zip 文件路径
  Future<String> exportMemes({
    required List<String> memeIds,
    required String outputPath,
    void Function(int current, int total)? onProgress,
  }) async {
    final bytes = await exportMemesAsBytes(
      memeIds: memeIds,
      onProgress: onProgress,
    );
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(bytes);
    return outputPath;
  }

  /// 导出 memes 为 zip 字节（不写文件），直接省掉中间文件步骤
  Future<Uint8List> exportMemesAsBytes({
    required List<String> memeIds,
    void Function(int current, int total)? onProgress,
  }) async {
    final archive = Archive();
    final memes = <MemeExportItem>[];

    // 1. 收集 meme 数据
    for (int i = 0; i < memeIds.length; i++) {
      final id = memeIds[i];
      final meme = await _memeRepo.getById(id);
      if (meme == null) continue;

      final colors = await _memeRepo.getColors(id);
      final tags = await _memeRepo.getTags(id);

      memes.add(MemeExportItem(
        hash: meme.fileHash,
        filename: meme.filename,
        imagePath: meme.filePath,
        colors: colors,
        tags: tags,
        description: meme.description,
      ));

      onProgress?.call(i + 1, memeIds.length);
    }

    // 2. 添加 manifest.json
    final manifest = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': memes.length,
    };
    archive.addFile(ArchiveFile(
      'manifest.json',
      utf8.encode(jsonEncode(manifest)).length,
      utf8.encode(jsonEncode(manifest)),
    ));

    // 3. 添加每个 meme 的图片和元数据
    for (final meme in memes) {
      final imageFile = await _storage.getImage(meme.imagePath);
      if (await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();
        archive.addFile(ArchiveFile(
          'memes/${meme.hash}.png',
          imageBytes.length,
          imageBytes,
        ));
      }

      final jsonBytes = utf8.encode(jsonEncode(meme.toJson()));
      archive.addFile(ArchiveFile(
        'memes/${meme.hash}.json',
        jsonBytes.length,
        jsonBytes,
      ));
    }

    // 4. 编码为 zip
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception('Failed to encode zip');
    return Uint8List.fromList(zipData);
  }
}
