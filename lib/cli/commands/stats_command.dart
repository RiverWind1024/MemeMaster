import 'dart:convert';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// stats 命令：输出统计（meme 总数 / 各分析状态 / 颜色与标签数 / 存储占用）。
///
/// 用法: mememaster stats
class StatsCommand extends CliCommand {
  StatsCommand() : super(name: 'stats', description: '统计信息');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final total = await context.memeRepo.count();
    final statuses = <String, int>{};
    for (final status in const ['pending', 'running', 'done', 'failed']) {
      statuses[status] = await context.memeRepo.countByStatus(status);
    }
    final colors =
        (await context.db.select(context.db.colorsTable).get()).length;
    final tags =
        (await context.db.select(context.db.tagsTable).get()).length;
    final storageUsed = await context.storage.storageUsed();

    if (context.jsonOutput) {
      print(jsonEncode({
        'totalMemes': total,
        'byStatus': statuses,
        'colors': colors,
        'tags': tags,
        'storageBytes': storageUsed,
      }));
      return 0;
    }

    print('meme 总数: $total');
    print('分析状态: ${statuses.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    print('颜色数: $colors');
    print('标签数: $tags');
    print('存储占用: $storageUsed 字节');
    return 0;
  }
}