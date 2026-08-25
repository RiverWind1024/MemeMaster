import 'dart:io';

import 'package:args/args.dart';

import '../../core/database/database.dart';
import '../../core/image/color_extractor.dart';
import '../cli_context.dart';
import '../cli_ocr.dart';
import '../cli_vision_analyzer.dart';
import 'command.dart';

/// analyze 命令：分析 meme 的颜色 / OCR / AI 维度。
///
/// 用法: mememaster analyze `<memeId...>` | --all [--color] [--ocr] [--ai]
///
/// - 至少指定一个维度开关，否则默认三个维度都做（与 GUI 分析默认一致）。
/// - 各维度独立执行，某维度失败（如无 AI 服务）不影响其它维度。
/// - 数据库写入语义复刻 GUI 分析队列（见 `parallel_analysis_scheduler.dart`）。
class AnalyzeCommand extends CliCommand {
  AnalyzeCommand() : super(name: 'analyze', description: '分析 meme（颜色/OCR/AI）');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final all = args['all'] as bool? ?? false;
    final ids = List<String>.of(args.rest);
    final doColor = args['color'] as bool? ?? false;
    final doOcr = args['ocr'] as bool? ?? false;
    final doAi = args['ai'] as bool? ?? false;

    // 未指定任何维度 → 默认三个都做
    final any = doColor || doOcr || doAi;
    final runColor = any ? doColor : true;
    final runOcr = any ? doOcr : true;
    final runAi = any ? doAi : true;

    if (!all && ids.isEmpty) {
      stderr.writeln('用法: mememaster analyze <memeId...> | --all [--color] [--ocr] [--ai]');
      return 1;
    }
    if (all && ids.isNotEmpty) {
      stderr.writeln('--all 与位置 memeId 不能同时使用');
      return 1;
    }

    final List<String> memeIds;
    if (all) {
      memeIds = [for (final m in await context.memeRepo.getAll()) m.id];
      if (memeIds.isEmpty) {
        stderr.writeln('没有可分析的 meme');
        return 1;
      }
    } else {
      memeIds = ids;
    }

    var hadError = false;
    for (final id in memeIds) {
      final meme = await _findMeme(context, id);
      if (meme == null) {
        stderr.writeln('未找到 meme: $id');
        hadError = true;
        continue;
      }

      print('分析 ${meme.filename} (${meme.id.substring(0, 8)}):');

      final imageFile = await context.storage.getImage(meme.filePath);
      if (!await imageFile.exists()) {
        stderr.writeln('图片文件不存在: ${imageFile.path}');
        hadError = true;
        continue;
      }
      final path = imageFile.absolute.path;

      if (runColor && await _runColor(context, meme, path)) hadError = true;
      if (runOcr && await _runOcr(context, meme, path)) hadError = true;
      if (runAi && await _runAi(context, meme, path)) hadError = true;

      await _updateOverall(context, meme.id);
    }

    return hadError ? 1 : 0;
  }

  /// 先精确匹配完整 id，再尝试短码前缀匹配（与 get 命令一致）。
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

  /// 颜色提取：写入 colors 表 + 更新 colorAnalysisStatus。返回是否失败。
  Future<bool> _runColor(CliContext context, Meme meme, String path) async {
    try {
      await context.memeRepo.updateColorAnalysisStatus(meme.id, 'running');
      final colors = await const ColorExtractor().extract(path);
      if (colors.isNotEmpty) {
        await context.memeRepo.saveColors([
          for (final c in colors)
            ColorEntry(
              id: '${meme.id}_${c.hex.replaceFirst('#', '')}',
              memeId: meme.id,
              hexColor: c.hex,
              labL: c.lChannel,
              labA: c.aChannel,
              labB: c.bChannel,
              ratio: c.ratio,
            ),
        ]);
      }
      await context.memeRepo.updateColorAnalysisStatus(meme.id, 'done');
      print('  [颜色] ${colors.length} 个主色'
          '${colors.isEmpty ? '' : '（${colors.map((c) => c.hex).join(', ')}）'}');
      return false;
    } catch (e) {
      stderr.writeln('  [颜色] 提取失败: $e');
      await context.memeRepo.updateColorAnalysisStatus(meme.id, 'failed');
      return true;
    }
  }

  /// OCR 识别：写入 source=ocr 标签 + 更新 ocrAnalysisStatus。返回是否失败。
  Future<bool> _runOcr(CliContext context, Meme meme, String path) async {
    try {
      await context.memeRepo.updateOcrAnalysisStatus(meme.id, 'running');
      final text = await CliOcr().recognize(path);
      final tags = _buildOcrTags(meme.id, text);
      if (tags.isNotEmpty) {
        await context.memeRepo.deleteAutoTags(meme.id, sources: ['ocr']);
        await context.memeRepo.saveTags(tags);
      }
      await context.memeRepo.updateOcrAnalysisStatus(meme.id, 'done');
      print('  [OCR] ${tags.length} 个标签'
          '${text.isEmpty ? '（未识别到文字）' : '：${tags.map((t) => t.content).join(', ')}'}');
      return false;
    } catch (e) {
      stderr.writeln('  [OCR] 识别失败: $e');
      await context.memeRepo.updateOcrAnalysisStatus(meme.id, 'failed');
      return true;
    }
  }

  /// AI 分析：写入 source=llm 标签 + 描述 + 更新 aiAnalysisStatus。返回是否失败。
  Future<bool> _runAi(CliContext context, Meme meme, String path) async {
    try {
      await context.memeRepo.updateAiAnalysisStatus(meme.id, 'running');
      final result = await CliVisionAnalyzer().analyze(path);
      if (result.tags.isNotEmpty) {
        await context.memeRepo.deleteAutoTags(meme.id, sources: ['llm']);
        await context.memeRepo.saveTags([
          for (final t in result.tags)
            TagEntry(
              id: '${meme.id}_llm_${t.hashCode}',
              memeId: meme.id,
              content: t,
              source: 'llm',
              confidence: 0.7,
            ),
        ]);
      }
      if (result.description.isNotEmpty) {
        await context.memeRepo.updateDescription(meme.id, result.description);
      }
      await context.memeRepo.updateAiAnalysisStatus(meme.id, 'done');
      print('  [AI] ${result.tags.length} 个标签'
          '${result.description.isEmpty ? '' : '（${result.description}）'}');
      return false;
    } catch (e) {
      stderr.writeln('  [AI] 分析失败: $e');
      stderr.writeln('  [AI] 未检测到可用的 Ollama/OpenAI 服务，请用 config 命令配置，或确认本地 Ollama 已启动');
      await context.memeRepo.updateAiAnalysisStatus(meme.id, 'failed');
      return true;
    }
  }

  /// 将 OCR 文本切分为标签，复刻 GUI parallel_analysis_scheduler 的过滤规则。
  List<TagEntry> _buildOcrTags(String memeId, String raw) {
    final lines = raw
        .split(RegExp(r'[\n;：:，,。.、]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final tags = <TagEntry>[];
    for (final line in lines) {
      if (line.length < 2) continue;
      // 纯 ASCII 符号/数字（无字母数字）视为乱码，过滤
      if (RegExp(r'^[\x00-\x7f]+$').hasMatch(line) &&
          !RegExp(r'[a-zA-Z0-9]{2,}').hasMatch(line)) {
        continue;
      }
      tags.add(TagEntry(
        id: '${memeId}_ocr_${line.hashCode}',
        memeId: memeId,
        content: line,
        source: 'ocr',
        confidence: 1.0,
      ));
    }
    return tags;
  }

  /// 三纬度都进入终态（done/failed）时结算整体 analysisStatus。
  Future<void> _updateOverall(CliContext context, String memeId) async {
    final meme = await context.memeRepo.getById(memeId);
    if (meme == null) return;

    final colorDone = meme.colorAnalysisStatus == 'done' || meme.colorAnalysisStatus == 'failed';
    final ocrDone = meme.ocrAnalysisStatus == 'done' || meme.ocrAnalysisStatus == 'failed';
    final aiDone = meme.aiAnalysisStatus == 'done' || meme.aiAnalysisStatus == 'failed';

    if (colorDone && ocrDone && aiDone) {
      final hasFailed = meme.colorAnalysisStatus == 'failed' ||
          meme.ocrAnalysisStatus == 'failed' ||
          meme.aiAnalysisStatus == 'failed';
      await context.memeRepo.updateAnalysisStatus(
        memeId,
        hasFailed ? 'failed' : 'done',
      );
    }
  }
}