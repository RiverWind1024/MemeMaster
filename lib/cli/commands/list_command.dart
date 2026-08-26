import 'dart:convert';

import 'package:args/args.dart';

import '../cli_context.dart';
import '../format.dart';
import 'command.dart';

/// list 命令：列出所有 meme。
class ListCommand extends CliCommand {
  ListCommand()
      : super(name: 'list', description: '列出所有 meme（id 短码 + 文件名）');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final limit = parsePositiveLimit(args);
    if (args.wasParsed('limit') && limit == null) return 1;

    final memes = await context.memeRepo.getAll(limit: limit);

    if (context.jsonOutput) {
      print(jsonEncode([
        for (final m in memes) {...memeToJson(m), 'source': m.source}
      ]));
      return 0;
    }

    print('共 ${memes.length} 条');
    for (final m in memes) {
      print(formatMemeRow(m));
    }
    return 0;
  }
}
