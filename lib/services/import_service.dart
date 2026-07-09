import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

import '../core/database/database.dart';
import '../core/database/daos/user_stats_dao.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';

class ImportResult {
  final int success;
  final int skipped;
  final List<String> errors;
  final List<String> skippedFiles;

  const ImportResult({
    required this.success,
    required this.skipped,
    this.errors = const [],
    this.skippedFiles = const [],
  });
}

class ImportService {
  final MemeRepository _memeRepo;
  final FileStorageService _storage;
  final UserStatsDao? _userStatsDao;

  ImportService({
    required this._memeRepo,
    required this._storage,
    this._userStatsDao,
  });

  Future<Meme?> importImage(String sourcePath, {String? source}) async {
    final file = File(sourcePath);
    if (!await file.exists()) return null;

    final fileBytes = await file.readAsBytes();
    final fileHash = sha256.convert(fileBytes).toString();
    final ext = sourcePath.split('.').last.toLowerCase();

    final existing = await _memeRepo.getByFileHash(fileHash);
    if (existing != null) return null;

    int width = 0, height = 0;
    final decoded = img.decodeImage(fileBytes);
    if (decoded != null) {
      width = decoded.width;
      height = decoded.height;
    }

    final relPath = await _storage.storeImage(sourcePath, fileHash);

    final meme = await _memeRepo.create(
      filename: sourcePath.split('/').last,
      filePath: relPath,
      fileSize: fileBytes.length,
      mimeType: _mimeType(ext),
      width: width,
      height: height,
      fileHash: fileHash,
    );

    // 更新图片来源
    if (source != null) {
      await _memeRepo.updateSource(meme.id, source);
    }

    // 用户统计：今日导入数 +1
    await _userStatsDao?.incrementImported();

    await _memeRepo.enqueueAnalysis(meme.id, priority: 0);
    return meme;
  }

  Future<ImportResult> importImages(List<String> sourcePaths,
      {String? source}) async {
    int success = 0;
    int skipped = 0;
    final errors = <String>[];
    final skippedFiles = <String>[];

    // 每批 5 张并发导入，避免大量图片时 UI 卡顿
    for (int i = 0; i < sourcePaths.length; i += 5) {
      final batch = sourcePaths.skip(i).take(5).toList();
      final results = await Future.wait(batch.map((path) async {
        try {
          final result = await importImage(path, source: source);
          if (result != null) return 'success';
          skippedFiles.add(path.split('/').last);
          return 'skipped';
        } catch (e) {
          errors.add('$path: $e');
          return 'error';
        }
      }));
      for (final r in results) {
        if (r == 'success') {
          success++;
        } else if (r == 'skipped') {
          skipped++;
        }
      }
    }

    return ImportResult(
      success: success,
      skipped: skipped,
      errors: errors,
      skippedFiles: skippedFiles,
    );
  }

  String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/$ext';
    }
  }
}
