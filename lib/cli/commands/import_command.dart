import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// 支持的图片扩展名（与 ImportService._mimeType 保持一致）。
const Set<String> _imageExts = {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'};

/// import 命令：导入图片（支持文件路径或目录，目录可 --recursive 递归）。
class ImportCommand extends CliCommand {
  ImportCommand()
      : super(name: 'import', description: '导入图片');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final paths = args.rest;
    final source = args['source'] as String?;
    final recursive = args['recursive'] as bool? ?? false;

    if (paths.isEmpty) {
      stderr.writeln('用法: mememaster import <路径...> [--source 标记] [--recursive]');
      return 1;
    }

    final files = <String>[];
    final pathErrors = <String>[];
    for (final path in paths) {
      final type = await FileSystemEntity.type(path);
      if (type == FileSystemEntityType.file) {
        files.add(path);
      } else if (type == FileSystemEntityType.directory) {
        final scanned = await _scanDirectory(Directory(path), recursive: recursive);
        if (scanned.isEmpty) {
          pathErrors.add('$path: 目录中没有支持的图片');
        } else {
          files.addAll(scanned);
        }
      } else {
        pathErrors.add('$path: 路径不存在');
      }
    }

    if (files.isEmpty) {
      for (final e in pathErrors) {
        stderr.writeln(e);
      }
      return 1;
    }

    final result = await context.importService.importImages(files, source: source);

    if (context.jsonOutput) {
      print(jsonEncode({
        'success': result.success,
        'skipped': result.skipped,
        'errors': result.errors,
        'skippedFiles': result.skippedFiles,
      }));
    } else {
      print(
        '导入完成: 成功 ${result.success} 张, 跳过 ${result.skipped} 张, '
        '失败 ${result.errors.length} 张',
      );
      for (final f in result.skippedFiles) {
        print('[跳过] $f');
      }
      for (final e in result.errors) {
        print('[错误] $e');
      }
    }

    return pathErrors.isEmpty && result.errors.isEmpty ? 0 : 1;
  }

  /// 扫描目录下的图片文件，[recursive] 时递归子目录。
  Future<List<String>> _scanDirectory(Directory dir,
      {required bool recursive}) async {
    final files = <String>[];
    await for (final entity in recursive ? dir.list(recursive: true) : dir.list()) {
      if (entity is File && _isImage(entity.path)) {
        files.add(entity.path);
      }
    }
    return files;
  }

  bool _isImage(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return false;
    return _imageExts.contains(path.substring(dot + 1).toLowerCase());
  }
}
