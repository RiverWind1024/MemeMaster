import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../cli_context.dart';
import '../command_parser.dart';
import 'command.dart';

/// export 命令：导出 meme 为 zip 数据包。
///
/// 用法: mememaster export [--ids id1,id2 | --all] --output <路径.zip>
class ExportCommand extends CliCommand {
  ExportCommand() : super(name: 'export', description: '导出为 zip 数据包');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final idsArg = args['ids'] as String?;
    final all = args['all'] as bool? ?? false;
    final output = args['output'] as String?;

    final idsProvided = idsArg != null && idsArg.trim().isNotEmpty;

    // --ids 与 --all 必须二选一，且至少给一个
    if (!idsProvided && !all) {
      stderr.writeln(
          '用法: mememaster export [--ids id1,id2 | --all] --output <路径.zip>');
      return 1;
    }
    if (idsProvided && all) {
      stderr.writeln('--ids 与 --all 不能同时使用');
      return 1;
    }
    if (output == null || output.trim().isEmpty) {
      stderr.writeln('--output 必填');
      return 1;
    }
    final outputPath = CommandParser.expandPath(output);

    final List<String> ids;
    if (all) {
      ids = [for (final m in await context.memeRepo.getAll()) m.id];
      if (ids.isEmpty) {
        stderr.writeln('没有可导出的 meme');
        return 1;
      }
    } else {
      ids = idsArg!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (ids.isEmpty) {
        stderr.writeln('--ids 不能为空');
        return 1;
      }
    }

    // 校验每个 id 都存在，避免导出结果与预期不符
    final missing = <String>[];
    for (final id in ids) {
      if (await context.memeRepo.getById(id) == null) missing.add(id);
    }
    if (missing.isNotEmpty) {
      stderr.writeln('未找到 meme: ${missing.join(', ')}');
      return 1;
    }

    try {
      File(outputPath).parent.createSync(recursive: true);
    } on FileSystemException catch (e) {
      stderr.writeln('无法创建输出目录: $e');
      return 1;
    }

    try {
      final path = await context.exportService.exportMemes(
        memeIds: ids,
        outputPath: outputPath,
      );
      final size = await File(path).length();
      if (context.jsonOutput) {
        print(jsonEncode({
          'success': true,
          'path': path,
          'size': size,
          'count': ids.length,
        }));
      } else {
        print('导出成功: ${ids.length} 条, $size 字节 -> $path');
      }
      return 0;
    } catch (e) {
      stderr.writeln('导出失败: $e');
      return 1;
    }
  }
}
