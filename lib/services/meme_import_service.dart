import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/database/database.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';

/// 导入结果
class MemeImportResult {
  final int success;
  final int skipped;
  final List<String> errors;

  MemeImportResult({
    required this.success,
    required this.skipped,
    required this.errors,
  });
}

/// Meme 导入服务
class MemeImportService {
  final MemeRepository _memeRepo;
  final FileStorageService _storage;
  final Uuid _uuid = const Uuid();

  MemeImportService({
    required MemeRepository memeRepo,
    required FileStorageService storage,
  })  : _memeRepo = memeRepo,
        _storage = storage;

  /// 从 zip 文件导入 memes
  /// 返回导入结果
  Future<MemeImportResult> importFromZip({
    required String zipPath,
    void Function(int current, int total)? onProgress,
  }) async {
    int success = 0;
    int skipped = 0;
    final errors = <String>[];

    // 1. 解压到临时目录
    final tempDir = Directory.systemTemp.createTempSync('meme_import_');
    try {
      final zipFile = File(zipPath);
      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // 解压所有文件
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final outputFile = File(p.join(tempDir.path, filename));
          await outputFile.create(recursive: true);
          await outputFile.writeAsBytes(file.content as List<int>);
        }
      }

      // 2. 读取 manifest.json
      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        return MemeImportResult(
          success: 0,
          skipped: 0,
          errors: ['Invalid zip: manifest.json not found'],
        );
      }

      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
      final count = manifest['count'] as int? ?? 0;

      // 3. 遍历 memes/ 目录导入每个 meme
      final memesDir = Directory(p.join(tempDir.path, 'memes'));
      if (!await memesDir.exists()) {
        return MemeImportResult(
          success: 0,
          skipped: 0,
          errors: ['Invalid zip: memes/ directory not found'],
        );
      }

      int processed = 0;
      await for (final entity in memesDir.list()) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          if (filename.endsWith('.png')) {
            final hash = p.basenameWithoutExtension(filename);
            final jsonFile = File(p.join(memesDir.path, '$hash.json'));

            if (await jsonFile.exists()) {
              try {
                final result = await _importSingleMeme(
                  imageFile: entity,
                  jsonFile: jsonFile,
                  hash: hash,
                );
                if (result == 'success') {
                  success++;
                } else if (result == 'skipped') {
                  skipped++;
                }
              } catch (e) {
                errors.add('$hash: $e');
              }
            }
          }
        }

        processed++;
        onProgress?.call(processed, count);
      }

      return MemeImportResult(
        success: success,
        skipped: skipped,
        errors: errors,
      );
    } finally {
      // 4. 清理临时目录
      await tempDir.delete(recursive: true);
    }
  }

  /// 导入单个 meme
  /// 返回: 'success', 'skipped', 或抛出异常
  Future<String> _importSingleMeme({
    required File imageFile,
    required File jsonFile,
    required String hash,
  }) async {
    // 检查是否已存在（通过 hash 去重）
    final existing = await _memeRepo.getByFileHash(hash);
    if (existing != null) {
      return 'skipped';
    }

    // 解析元数据
    final jsonContent = await jsonFile.readAsString();
    final data = jsonDecode(jsonContent) as Map<String, dynamic>;

    // 复制图片到存储
    final storedPath = await _storage.storeImage(imageFile.path, hash);
    final fileSize = await imageFile.length();

    // 获取图片尺寸（简单通过文件名判断）
    final filename = data['filename'] as String? ?? '$hash.png';
    final ext = p.extension(filename).toLowerCase();
    final mimeType = _extToMimeType(ext);

    // 创建 meme 记录
    final now = DateTime.now().millisecondsSinceEpoch;
    await _memeRepo.create(
      filename: filename,
      filePath: storedPath,
      fileSize: fileSize,
      mimeType: mimeType,
      width: 0, // 导入时不确定，留空或后续补充
      height: 0,
      fileHash: hash,
    );

    // 获取刚创建的 meme 以获取其 ID
    final meme = await _memeRepo.getByFileHash(hash);
    if (meme == null) throw Exception('Failed to create meme');

    // 保存 colors
    final colors = data['colors'] as List<dynamic>? ?? [];
    for (final c in colors) {
      final colorMap = c as Map<String, dynamic>;
      await _memeRepo.saveColors([
        ColorEntry(
          id: _uuid.v4(),
          memeId: meme.id,
          hexColor: colorMap['hexColor'] as String,
          labL: (colorMap['labL'] as num).toDouble(),
          labA: (colorMap['labA'] as num).toDouble(),
          labB: (colorMap['labB'] as num).toDouble(),
          ratio: (colorMap['ratio'] as num).toDouble(),
        ),
      ]);
    }

    // 保存 tags
    final tags = data['tags'] as List<dynamic>? ?? [];
    for (final t in tags) {
      final tagMap = t as Map<String, dynamic>;
      await _memeRepo.saveTags([
        TagEntry(
          id: _uuid.v4(),
          memeId: meme.id,
          source: tagMap['source'] as String,
          content: tagMap['content'] as String,
          confidence: (tagMap['confidence'] as num?)?.toDouble() ?? 1.0,
        ),
      ]);
    }

    return 'success';
  }

  String _extToMimeType(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'image/png';
    }
  }
}
