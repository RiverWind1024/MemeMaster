import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// list 命令：列出所有 meme。
class ListCommand extends CliCommand {
  ListCommand()
      : super(name: 'list', description: '列出所有 meme（id 短码 + 文件名）');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final limitArg = args['limit'] as String?;
    int? limit;
    if (limitArg != null) {
      limit = int.tryParse(limitArg);
      if (limit == null) {
        stderr.writeln('--limit 必须是正整数: $limitArg');
        return 1;
      }
    }

    final memes = await context.memeRepo.getAll(limit: limit);

    if (context.jsonOutput) {
      print(jsonEncode([
        for (final m in memes)
          {
            'id': m.id,
            'shortId': m.id.substring(0, 8),
            'filename': m.filename,
            'width': m.width,
            'height': m.height,
            'importedAt': m.importedAt,
            'analysisStatus': m.analysisStatus,
            'source': m.source,
          }
      ]));
      return 0;
    }

    print('共 ${memes.length} 条');
    for (final m in memes) {
      final size = '${m.width}x${m.height}';
      print(
        '${m.id.substring(0, 8)}  ${m.filename}  $size  '
        '${_formatTime(m.importedAt)}  ${m.analysisStatus}',
      );
    }
    return 0;
  }

  String _formatTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
