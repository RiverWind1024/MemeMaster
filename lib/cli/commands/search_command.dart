import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../../core/utils/color_utils.dart';
import '../cli_context.dart';
import '../format.dart';
import 'command.dart';

/// search 命令：按关键词 / 颜色搜索 meme。
class SearchCommand extends CliCommand {
  SearchCommand()
      : super(name: 'search', description: '搜索 meme（关键词/颜色）');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    if (args.rest.length > 1) {
      stderr.writeln('search 仅支持单个关键词: ${args.rest.join(' ')}');
      return 1;
    }

    final query = args.rest.isNotEmpty ? args.rest.first : '';
    final colorArg = args['color'] as String?;

    // 至少需要关键词或颜色之一
    if (query.trim().isEmpty && colorArg == null) {
      stderr.writeln('用法: mememaster search <关键词> [--color #RRGGBB] [--limit N]');
      return 1;
    }

    final limit = parsePositiveLimit(args);
    if (args.wasParsed('limit') && limit == null) return 1;

    ColorRgb? color;
    if (colorArg != null) {
      try {
        color = ColorRgb.fromHex(colorArg);
      } on ArgumentError {
        stderr.writeln('--color 必须形如 #RRGGBB: $colorArg');
        return 1;
      } on FormatException {
        stderr.writeln('--color 必须形如 #RRGGBB: $colorArg');
        return 1;
      }
    }

    final rawResults = await context.searchService.search(
      query: query,
      colors: color == null ? null : [color],
      limit: limit ?? 50,
    );
    // 关键词搜索路径（_searchByText）不截断，命令层统一截断以保证 limit 生效。
    final results = rawResults.take(limit ?? 50).toList();

    if (context.jsonOutput) {
      print(jsonEncode([
        for (final r in results)
          {...memeToJson(r.meme), 'relevance': r.relevance}
      ]));
      return 0;
    }

    if (results.isEmpty) {
      print('无结果');
      return 0;
    }

    print('共 ${results.length} 条');
    for (final r in results) {
      print(formatMemeRow(r.meme));
    }
    return 0;
  }
}
