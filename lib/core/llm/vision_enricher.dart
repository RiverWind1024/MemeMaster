import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../services/log_service.dart';
import '../database/database.dart';
import '../repositories/meme_repository.dart';
import 'llm_service.dart';
import 'models.dart';

/// 多模态 LLM 驱动的图片标签生成器
///
/// 直接分析图片内容（而非 OCR 文本），识别物体/场景/表情/情绪等。
/// 生成 TagEntry(source: 'llm') 标签和 Meme.description。
class VisionLlmEnricher {
  final LlmService _llm;
  final MemeRepository _repo;
  final LogService _log;

  /// 图片最大边长（超过此尺寸会被压缩以节省 token）
  static const int _maxImageDimension = 1024;

  const VisionLlmEnricher({
    required LlmService llm,
    required MemeRepository repo,
    required LogService log,
  })  : _llm = llm,
        _repo = repo,
        _log = log;

  /// 对单张 meme 执行多模态分析
  Future<void> enrich(String memeId, String imagePath) async {
    if (!_llm.isAvailable) {
      _log.warning('VisionLLM', 'LLM 不可用，跳过分析');
      return;
    }

    _log.info('VisionLLM', '开始多模态分析: $memeId');

    try {
      // 1. 读取图片并转 base64
      final imageBytes = await _readAndResizeImage(imagePath);
      final base64Image = base64Encode(imageBytes);
      _log.info('VisionLLM', '图片 base64: ${base64Image.length} 字节');

      // 2. 调用多模态 LLM
      final result = await _analyzeImage(base64Image);

      if (result == null) {
        _log.warning('VisionLLM', 'LLM 返回空结果');
        return;
      }

      // 3. 保存标签
      if (result.tags.isNotEmpty) {
        final tagEntries = result.tags.map((tag) => TagEntry(
              id: '${memeId}_llm_${tag.hashCode}',
              memeId: memeId,
              content: tag,
              source: 'llm',
              confidence: 0.7,
            )).toList();
        await _repo.saveTags(tagEntries);
        _log.info(
            'VisionLLM', '保存 ${tagEntries.length} 个标签: ${result.tags.join(", ")}');
      }

      // 4. 保存描述
      if (result.description.isNotEmpty) {
        await _repo.updateDescription(memeId, result.description);
        _log.info('VisionLLM', '保存描述: ${result.description}');
      }
    } catch (e) {
      _log.error('VisionLLM', '多模态分析失败: $e');
    }
  }

  Future<_AnalysisResult?> _analyzeImage(String base64Image) async {
    final messages = [
      LlmMessage(
        role: 'system',
        content: _systemPrompt,
      ),
      LlmMessage(
        role: 'user',
        content: _userPrompt,
        imageBase64: base64Image,
      ),
    ];

    final response = await _llm.chat(
      messages,
      options: const LlmOptions(temperature: 0.3, maxTokens: 256),
    );

    return _parseResponse(response);
  }

  _AnalysisResult? _parseResponse(String raw) {
    try {
      // 尝试解析 JSON
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final tags = (json['tags'] as List?)
              ?.map((e) => e.toString().trim())
              .where((t) => t.length >= 2 && t.length <= 20)
              .toList() ??
          [];
      final description = (json['description'] as String?)?.trim() ?? '';
      return _AnalysisResult(tags: tags, description: description);
    } catch (_) {
      // JSON 解析失败，回退：从纯文本中提取逗号分隔的标签
      _log.warning('VisionLLM', 'JSON 解析失败，尝试回退解析: $raw');
      final tags = raw
          .split(RegExp(r'[,，、\n]+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 2 && w.length <= 20)
          .toList();
      return tags.isNotEmpty
          ? _AnalysisResult(tags: tags, description: '')
          : null;
    }
  }

  Future<Uint8List> _readAndResizeImage(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();

    // 如果图片过大，简单提示压缩（后续可用 image 库 resize）
    if (bytes.length > 1024 * 1024) {
      _log.info(
        'VisionLLM',
        '图片较大 (${bytes.length} 字节)，建议压缩后发送',
      );
    }
    return bytes;
  }

  static const _systemPrompt = '''
你是一个表情包分析专家。请分析这张图片，返回 JSON 格式的分析结果。

要求：
- 标签用中文，每个 2-10 字
- 标签需反映图片的核心内容，如：物体、场景、人物表情、情绪、meme 模板类型
- 标签数量 3-8 个
- 描述用一句话概括，10 字以内
- 只返回 JSON，不要多余文字

输出格式：
{"tags": ["标签1", "标签2"], "description": "一句话描述"}
''';

  static const _userPrompt = '请分析这张表情包图片：';
}

class _AnalysisResult {
  final List<String> tags;
  final String description;
  const _AnalysisResult({required this.tags, required this.description});
}
