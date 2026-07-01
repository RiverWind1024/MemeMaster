import '../database/database.dart';
import '../repositories/meme_repository.dart';
import 'llm_service.dart';

/// LLM 驱动的标签和描述生成器
///
/// 在分析管线中运行，在颜色提取和 OCR 之后执行。
/// 当前基于 OCR 文本来推断图片内容。
///
/// TODO(Phase 2): 替换为 LLM 视觉能力（多模态模型），直接分析图片识别：
///   1. 识别图片中的物体/场景/角色（如"猫"、"狗"、"meme 模板名"）
///   2. 返回结构化 JSON（包含标签、置信度、描述）
///   3. 标签写入 TagEntry(source: 'llm')，描述写入 Meme.description
class LlmEnricher {
  final LlmService _llm;
  final MemeRepository _repo;

  const LlmEnricher({required this._llm, required this._repo});

  /// 对单张 meme 执行 LLM 富化
  /// TODO(Phase 2): 参数改为 imagePath，直接传图片路径给多模态模型
  Future<void> enrich(String memeId, String ocrText) async {
    if (!_llm.isAvailable) return;

    // 1. 标签建议
    final tags = await _suggestTags(ocrText);
    if (tags.isNotEmpty) {
      await _repo.saveTags(tags);
    }

    // 2. 描述生成
    final description = await _describe(ocrText);
    if (description.isNotEmpty) {
      await _repo.updateDescription(memeId, description);
    }
  }

  Future<List<TagEntry>> _suggestTags(String ocrText) async {
    final prompt = _tagPrompt(ocrText);
    try {
      final result = await _llm.complete(
        prompt,
        options: const LlmOptions(
          temperature: 0.3,
          maxTokens: 128,
        ),
      );
      return _parseTags(result);
    } catch (_) {
      return [];
    }
  }

  Future<String> _describe(String ocrText) async {
    final prompt = _descriptionPrompt(ocrText);
    try {
      return await _llm.complete(
        prompt,
        options: const LlmOptions(
          temperature: 0.5,
          maxTokens: 256,
        ),
      );
    } catch (_) {
      return '';
    }
  }

  /// 解析 LLM 返回的逗号分隔标签
  List<TagEntry> _parseTags(String raw) {
    return raw
        .split(RegExp(r'[,，、\n]+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 2 && w.length <= 20)
        .toList()
        .asMap()
        .entries
        .map((e) => TagEntry(
              id: 'llm_tag_${e.value.hashCode}',
              memeId: '',
              content: e.value,
              source: 'llm',
              confidence: 0.8,
            ))
        .toList();
  }

  String _tagPrompt(String ocrText) => '''
从以下图片文字中提取 3~5 个标签，反映图片内容或主题。
只返回逗号分隔的标签，不要解释或额外文字。

图片文字：
$ocrText
''';

  String _descriptionPrompt(String ocrText) => '''
根据以下图片中的文字，用一句话描述这张图片的内容（20字以内）。

图片文字：
$ocrText
''';
}
