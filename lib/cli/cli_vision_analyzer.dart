import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../core/llm/llm_service.dart';
import '../core/llm/ollama_service.dart';

/// CLI 多模态分析结果。
class CliVisionResult {
  final List<String> tags;
  final String description;
  const CliVisionResult({required this.tags, required this.description});
}

/// CLI 多模态 LLM 分析器。
///
/// GUI 的 `VisionLlmEnricher` 依赖 Flutter（rootBundle / dart:ui），CLI 无法复用，
/// 这里复刻其调用方式：读取 `assets/prompts/vision_*.txt` 提示词，用 [LlmService]
/// 调用 Ollama（默认 localhost:11434）或 OpenAI 兼容 API，返回标签 + 描述。
class CliVisionAnalyzer {
  final LlmService _llm;
  final String promptDir;
  final String locale;

  CliVisionAnalyzer({
    LlmService? llm,
    this.promptDir = 'assets/prompts',
    this.locale = 'zh',
  }) : _llm = llm ?? OllamaLlmService();

  LlmService get llm => _llm;

  /// 分析图片，返回标签与描述；LLM 不可达或调用失败时抛出异常。
  Future<CliVisionResult> analyze(String imagePath) async {
    final isChinese = locale.startsWith('zh');
    final systemFile = isChinese ? 'vision_system_zh.txt' : 'vision_system_en.txt';
    final userFile = isChinese ? 'vision_user_zh.txt' : 'vision_user_en.txt';

    final systemPrompt = await _loadPrompt(systemFile);
    final userPrompt = await _loadPrompt(userFile);

    final bytes = await _readResizedImage(imagePath);
    final base64 = base64Encode(bytes);

    final messages = [
      LlmMessage(role: 'system', content: systemPrompt),
      LlmMessage(role: 'user', content: userPrompt, imageBase64: base64),
    ];

    final response = await _llm.chat(
      messages,
      options: const LlmOptions(temperature: 0.3, maxTokens: 256),
    );

    return _parseResponse(response);
  }

  Future<String> _loadPrompt(String filename) async {
    final file = File('$promptDir/$filename');
    final text = await file.readAsString();
    return text.replaceAll('{locale_language}', _localeLanguageName);
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