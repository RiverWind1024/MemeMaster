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
    final query = args.rest.isNotEmpty ? args.rest.first : '';
    final colorArg = args['color'] as String?;
    final limitArg = args['limit'] as String?;

    // 至少需要关键词或颜色之一
    if (query.trim().isEmpty && colorArg == null) {
      stderr.writeln('用法: mememaster search <关键词> [--color #RRGGBB] [--limit N]');
      return 1;
    }

    int? limit;
    if (limitArg != null) {
      limit = int.tryParse(limitArg);
      if (limit == null || limit <= 0) {
        stderr.writeln('--limit 必须是正整数: $limitArg');
        return 1;
      }
    }

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

    final results = await context.searchService.search(
      query: query,
      colors: color == null ? null : [color],
      limit: limit ?? 50,
    );

    if (context.jsonOutput) {
      print(jsonEncode([
        for (final r in results)
          {
            'id': r.meme.id,
            'shortId': r.meme.id.substring(0, 8),
            'filename': r.meme.filename,
            'width': r.meme.width,
            'height': r.meme.height,
            'importedAt': r.meme.importedAt,
            'relevance': r.relevance,
          }
      ]));
      return 0;
    }

    if (results.isEmpty) {
      print('无结果');
      return 0;
    }

    print('共 ${results.length} 条');
    for (final r in results) {
      final m = r.meme;
      final size = '${m.width}x${m.height}';
      print(
        '${m.id.substring(0, 8)}  ${m.filename}  $size  '
        '${formatDateTime(DateTime.fromMillisecondsSinceEpoch(m.importedAt))}',
      );
    }
    return 0;
  }
}
