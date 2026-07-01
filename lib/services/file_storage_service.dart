import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 文件存储服务
///
/// 将 meme 图片按日期组织在 app 内部存储中：
///   {appDir}/memes/{yyyy}/{mm}/{hash}.{ext}
class FileStorageService {
  String? _basePath;

  /// 获取基础存储路径（懒初始化）
  Future<String> get basePath async {
    if (_basePath != null) return _basePath!;
    final appDir = await getApplicationDocumentsDirectory();
    _basePath = p.join(appDir.path, 'memes');
    return _basePath!;
  }

  /// 存储图片文件，返回相对路径（用于 DB 存储）
  ///
  /// [sourceFile] 源文件路径
  /// [hash] 文件 SHA256（用于去重 + 文件名）
  /// 返回内部相对路径，如 `2026/06/abc123.png`
  Future<String> storeImage(String sourcePath, String hash) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Source file not found', sourcePath);
    }

    final now = DateTime.now();
    final relDir = '${now.year.toString().padLeft(4, '0')}'
        '/${now.month.toString().padLeft(2, '0')}';
    final ext = p.extension(source.path).toLowerCase();
    final relPath = '$relDir/$hash$ext';
    final destDir = p.join(await basePath, relDir);
    final destPath = p.join(await basePath, relPath);

    // 已存在则跳过（同名 hash = 相同内容）
    if (await File(destPath).exists()) return relPath;

    await Directory(destDir).create(recursive: true);
    await source.copy(destPath);
    return relPath;
  }

  /// 获取图片文件
  Future<File> getImage(String relativePath) async {
    return File(p.join(await basePath, relativePath));
  }

  /// 删除图片文件
  Future<void> deleteImage(String relativePath) async {
    final file = File(p.join(await basePath, relativePath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 计算已使用的存储空间（字节）
  Future<int> storageUsed() async {
    final dir = Directory(await basePath);
    if (!await dir.exists()) return 0;

    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
