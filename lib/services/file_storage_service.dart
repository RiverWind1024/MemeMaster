import 'dart:io';

import 'package:path/path.dart' as p;

/// 文件存储服务
///
/// 将 meme 图片按日期组织在 app 内部存储中：
///   {basePath}/{yyyy}/{mm}/{hash}.{ext}
///
/// 基础路径必须通过构造器注入：
/// - GUI 由 main.dart 注入 `{documentsDir}/memes`
/// - CLI 由 --storage 参数注入
class FileStorageService {
  String? _basePath;

  FileStorageService({String? basePath}) : _basePath = basePath;

  /// 获取基础存储路径（必须注入，未注入则抛 [StateError]）
  Future<String> get basePath async {
    if (_basePath != null) return _basePath!;
    throw StateError(
      'FileStorageService.basePath 未注入：请在构造时传入 basePath（GUI 由 main.dart 注入，CLI 由 --storage 注入）',
    );
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
    final yearMonth = '${now.year.toString().padLeft(4, '0')}'
        '/${now.month.toString().padLeft(2, '0')}';
    final ext = p.extension(source.path).toLowerCase();
    final relPath = '$yearMonth/$hash$ext';
    final destDir = p.join(await basePath, yearMonth);
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
