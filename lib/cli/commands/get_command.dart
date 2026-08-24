import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../../core/database/database.dart';
import '../cli_context.dart';
import '../format.dart';
import 'command.dart';

/// get 命令：查看单个 meme 详情（支持完整 id 或前 8 位短码）。
class GetCommand extends CliCommand {
  GetCommand()
      : super(name: 'get', description: '查看单个 meme 详情');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    if (args.rest.isEmpty) {
      stderr.writeln('用法: mememaster get <id|短码>');
      return 1;
    }
    final input = args.rest.first;

    final meme = await _findMeme(context, input);
    if (meme == null) {
      stderr.writeln('未找到 meme: $input');
      return 1;
    }

    final tags = await context.memeRepo.getTags(meme.id);
    final colors = await context.memeRepo.getColors(meme.id);

    if (context.jsonOutput) {
      print(jsonEncode({
        'id': meme.id,
        'filename': meme.filename,
        'filePath': meme.filePath,
        'width': meme.width,
        'height': meme.height,
        'fileSize': meme.fileSize,
        'mimeType': meme.mimeType,
        'importedAt': meme.importedAt,
        'analysisStatus': meme.analysisStatus,
        'colorAnalysisStatus': meme.colorAnalysisStatus,
        'ocrAnalysisStatus': meme.ocrAnalysisStatus,
        'aiAnalysisStatus': meme.aiAnalysisStatus,
        'source': meme.source,
        'tags': [for (final t in tags) t.content],
        'colors': [for (final c in colors) c.hexColor],
      }));
    } else {
      print('ID:        ${meme.id}');
      print('文件名:     ${meme.filename}');
      print('路径:       ${meme.filePath}');
      print('尺寸:       ${meme.width}x${meme.height}');
      print('大小:       ${meme.fileSize} B');
      print('类型:       ${meme.mimeType}');
      print('导入时间:   ${formatDateTime(DateTime.fromMillisecondsSinceEpoch(meme.importedAt))}');
      print(
        '分析状态:   ${meme.analysisStatus}（颜色 ${meme.colorAnalysisStatus}, '
        'OCR ${meme.ocrAnalysisStatus}, AI ${meme.aiAnalysisStatus}）',
      );
      print('来源:       ${meme.source ?? '-'}');
      print('标签:       ${tags.isEmpty ? '-' : tags.map((t) => t.content).join(', ')}');
      print('颜色:       ${colors.isEmpty ? '-' : colors.map((c) => c.hexColor).join(', ')}');
    }
    return 0;
  }

  /// 先精确匹配完整 id，再尝试短码前缀匹配。
  ///
  /// 规模取舍：先走精确 id 命中，miss 时才全表加载做短码前缀过滤。个人工具
  /// 规模（百到千条）全表匹配可接受；未来数据量大可改用 SQL LIKE 前缀查询，
  /// 避免全表加载。
  Future<Meme?> _findMeme(CliContext context, String input) async {
    final exact = await context.memeRepo.getById(input);
    if (exact != null) return exact;

    final all = await context.memeRepo.getAll();
    final matches = all.where((m) => m.id.startsWith(input)).toList();
    if (matches.length == 1) return matches.first;
    if (matches.length > 1) {
      stderr.writeln('警告: 短码 "$input" 匹配多个 meme，请使用完整 id');
    }
    return null;
  }
}
