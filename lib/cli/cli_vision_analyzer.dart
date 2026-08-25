import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../core/llm/config.dart';
import '../core/llm/llm_service.dart';
import '../core/llm/ollama_service.dart';
import '../core/llm/openai_service.dart';

/// CLI 多模态分析结果。
class CliVisionResult {
  final List<String> tags;
  final String description;
  const CliVisionResult({required this.tags, required this.description});
}

/// 内嵌的 prompt 模板（避免分发时依赖外部文件）。
const _kSystemPromptZh = r'''<|no_think|>
你是一个表情包分析专家。请分析这张图片，返回 JSON 格式的分析结果。

要求：
- 标签用中文，每个 2-10 字
- 标签描述图片中的具体内容，如：物体、场景、人物、动作、情绪
- 不要使用宽泛/通用标签，如：表情包、搞笑、网络梗、图片、meme、热梗
- 标签数量 3-8 个
- 描述用一句话概括，10 字以内
- 只返回 JSON，不要多余文字

好 vs 坏的标签示例：
好：熊猫头、愤怒、红色标语、核心价值观、爱国
坏：表情包、搞笑、网络梗、meme、热梗

输出格式：
{"tags": ["标签1", "标签2"], "description": "一句话描述"}''';

const _kSystemPromptEn = r'''You are a meme analysis expert. Analyze this image and return a JSON result.

Requirements:
- Tags in {locale_language}, 2-10 characters each
- Tags should describe specific content: objects, scenes, people, actions, emotions
- Do NOT use generic tags like: meme, funny, internet joke, image, reaction
- 3-8 tags
- Description in one short sentence, under 10 words
- Return ONLY JSON, no extra text

Good vs Bad tag examples:
Good: panda head, angry, red banner, core values, patriotic
Bad: meme, funny, internet joke, reaction, viral

Output format:
{"tags": ["tag1", "tag2"], "description": "one sentence description"}''';

const _kUserPromptZh = '请分析这张表情包图片：';
const _kUserPromptEn = 'Analyze this meme image:';

/// CLI 多模态 LLM 分析器。
///
/// GUI 的 `VisionLlmEnricher` 依赖 Flutter（rootBundle / dart:ui），CLI 无法复用，
/// 这里复刻其调用方式：内嵌提示词，用 [LlmService]
/// 调用 Ollama（默认 localhost:11434）或 OpenAI 兼容 API，返回标签 + 描述。
class CliVisionAnalyzer {
  final LlmService _llm;
  final LlmConfig _config;
  final String locale;

  CliVisionAnalyzer({
    LlmService? llm,
    LlmConfig config = const LlmConfig(),
    this.locale = 'zh',
  })  : _llm = llm ?? _buildLlmService(config),
        _config = config;

  /// 根据 [LlmConfig.provider] 构造对应的 LLM 服务，透传 baseUrl/apiKey/model。
  ///
  /// 默认 [LlmConfig] 的 provider 为 ollama、baseUrl 为 localhost:11434/v1，
  /// 与 GUI `gallery_provider.dart` 的 `llmServiceProvider` 选择逻辑保持一致。
  static LlmService _buildLlmService(LlmConfig config) {
    switch (config.provider) {
      case LlmProviderType.openai:
        return OpenAiLlmService(
          baseUrl: config.baseUrl,
          apiKey: config.apiKey,
          model: config.model,
        );
      case LlmProviderType.ollama:
        return OllamaLlmService(
          baseUrl: config.baseUrl,
          model: config.model,
        );
    }
  }

  LlmService get llm => _llm;

  /// 分析图片，返回标签与描述；LLM 不可达或调用失败时抛出异常。
  Future<CliVisionResult> analyze(String imagePath) async {
    final isChinese = locale.startsWith('zh');
    final systemPrompt = isChinese ? _kSystemPromptZh : _kSystemPromptEn;
    final userPrompt = isChinese ? _kUserPromptZh : _kUserPromptEn;

    final systemText = systemPrompt.replaceAll('{locale_language}', _localeLanguageName);

    final bytes = await _readResizedImage(imagePath);
    final base64 = base64Encode(bytes);

    final messages = [
      LlmMessage(role: 'system', content: systemText),
      LlmMessage(role: 'user', content: userPrompt, imageBase64: base64),
    ];

    final response = await _llm.chat(
      messages,
      options: LlmOptions(
        temperature: _config.temperature,
        maxTokens: _config.maxTokens,
      ),
    );

    return _parseResponse(response);
  }

  String get _localeLanguageName =>
      locale.startsWith('zh') ? 'Chinese' : 'English';

  /// 读取图片，超过最大边长时等比缩放并重编码为 JPEG（节省 token）。
  Future<Uint8List> _readResizedImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileSystemException('图片文件不存在', imagePath);
    }
    final bytes = await file.readAsBytes();

    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    const maxDim = 768;
    final w0 = image.width;
    final h0 = image.height;
    if (w0 <= maxDim && h0 <= maxDim) return bytes;

    int w = w0;
    int h = h0;
    if (w > h) {
      h = (h * maxDim / w).round();
      w = maxDim;
    } else {
      w = (w * maxDim / h).round();
      h = maxDim;
    }
    final resized = img.copyResize(image, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  CliVisionResult _parseResponse(String raw) {
    var text = raw.trim();

    // 剥离推理模型的  thinking... response 块
    text = text.replaceAll(RegExp(r' thinking[\s\S]*? response', caseSensitive: false), '');
    text = text.trim();

    // 剥离 markdown 代码块
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```\w*\n?'), '');
      text = text.replaceFirst(RegExp(r'\n?```$'), '');
      text = text.trim();
    }

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final tags = (json['tags'] as List?)
              ?.map((e) => e.toString().trim())
              .where((t) => t.length >= 2 && t.length <= 20)
              .toList() ??
          [];
      final description = (json['description'] as String?)?.trim() ?? '';
      return CliVisionResult(tags: tags, description: description);
    } catch (_) {
      final tags = text
          .split(RegExp(r'[,，、\n]+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 2 && w.length <= 20)
          .toList();
      return CliVisionResult(tags: tags, description: '');
    }
  }
}