import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// reindex 命令：对缺失的分析维度重新入队。
///
/// 用法: mememaster reindex `<memeId...>` | --all
class ReindexCommand extends CliCommand {
  ReindexCommand()
      : super(name: 'reindex', description: '重新索引分析');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final all = args['all'] as bool? ?? false;
    final ids = List<String>.of(args.rest);

    if (!all && ids.isEmpty) {
      stderr.writeln('用法: mememaster reindex <memeId...> | --all');
      return 1;
    }
    if (all && ids.isNotEmpty) {
      stderr.writeln('--all 与位置 memeId 不能同时使用');
      return 1;
    }

    if (all) {
      final result = await context.memeRepo.reindexAll();
      if (context.jsonOutput) {
        print(jsonEncode(result));
      } else {
        print('重新索引完成: 处理 ${result['total']} 条, '
            '入队 ${result['enqueued']} 维度, 失败 ${result['failed']} 条');
      }
      return 0;
    }

    var hadError = false;
    final results = <Map<String, Object?>>[];
    for (final id in ids) {
      if (await context.memeRepo.getById(id) == null) {
        stderr.writeln('未找到 meme: $id');
        hadError = true;
        continue;
      }
      final enqueued = await context.memeRepo.reindexMeme(id);
      results.add({'id': id, 'enqueued': enqueued});
      if (!context.jsonOutput) {
        print('${id.substring(0, 8)}: 入队 $enqueued 个分析维度');
      }
    }

    if (context.jsonOutput) {
      print(jsonEncode(results));
    }
    return hadError ? 1 : 0;
  }
}
