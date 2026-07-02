import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

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
  static const int _maxImageDimension = 768;

  /// JPEG 编码质量（1-100）
  static const int _jpgQuality = 85;

  /// 原始文件超过此大小才触发重编码（字节）
  static const int _reencodeThreshold = 200 * 1024;

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
    final locale = PlatformDispatcher.instance.locale;
    final isChinese = locale.languageCode.startsWith('zh');

    final systemPrompt = await _loadPrompt(
      isChinese ? 'vision_system_zh.txt' : 'vision_system_en.txt',
      locale,
    );
    final userPrompt = await _loadPrompt(
      isChinese ? 'vision_user_zh.txt' : 'vision_user_en.txt',
      locale,
    );

    final messages = [
      LlmMessage(role: 'system', content: systemPrompt),
      LlmMessage(role: 'user', content: userPrompt, imageBase64: base64Image),
    ];

    final response = await _llm.chat(
      messages,
      options: const LlmOptions(temperature: 0.3, maxTokens: 256),
    );

    return _parseResponse(response);
  }

  static Future<String> _loadPrompt(String filename, Locale locale) async {
    var text = await rootBundle.loadString('assets/prompts/$filename');
    return text.replaceAll('{locale_language}', _localeLanguageName(locale));
  }

  static String _localeLanguageName(Locale locale) {
    const names = {
      'ja': 'Japanese', 'ko': 'Korean', 'fr': 'French', 'de': 'German',
      'es': 'Spanish', 'pt': 'Portuguese', 'ru': 'Russian', 'it': 'Italian',
      'th': 'Thai', 'vi': 'Vietnamese', 'ar': 'Arabic', 'hi': 'Hindi',
      'id': 'Indonesian', 'tr': 'Turkish', 'nl': 'Dutch', 'pl': 'Polish',
      'sv': 'Swedish', 'da': 'Danish', 'fi': 'Finnish', 'nb': 'Norwegian',
      'cs': 'Czech', 'uk': 'Ukrainian', 'hu': 'Hungarian', 'ro': 'Romanian',
    };
    return names[locale.languageCode] ?? locale.languageCode.toUpperCase();
  }

  _AnalysisResult? _parseResponse(String raw) {
    // 剥离 markdown 代码块包裹（模型有时返回 ```json ... ```）
    var text = raw.trim();
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
      return _AnalysisResult(tags: tags, description: description);
    } catch (_) {
      _log.warning('VisionLLM', 'JSON 解析失败，尝试回退解析: $text');
      final tags = text
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
    final originalSize = bytes.length;

    // 解码图片
    final original = img.decodeImage(bytes);
    if (original == null) {
      _log.warning('VisionLLM', '无法解码图片，使用原始文件');
      return bytes;
    }

    int w = original.width;
    int h = original.height;

    // 如果尺寸超出阈值，等比缩放
    if (w > _maxImageDimension || h > _maxImageDimension) {
      if (w > h) {
        h = (h * _maxImageDimension / w).round();
        w = _maxImageDimension;
      } else {
        w = (w * _maxImageDimension / h).round();
        h = _maxImageDimension;
      }
      final resized = img.copyResize(original, width: w, height: h);
      final jpeg = img.encodeJpg(resized, quality: _jpgQuality);
      _log.info(
        'VisionLLM',
        '图片压缩: $originalSize -> ${jpeg.length} 字节, '
            '尺寸: ${original.width}x${original.height} -> ${w}x$h',
      );
      return Uint8List.fromList(jpeg);
    }

    // 尺寸没超但文件较大 → 重编码为 JPEG 减体积
    if (originalSize > _reencodeThreshold) {
      final jpeg = img.encodeJpg(original, quality: _jpgQuality);
      _log.info(
        'VisionLLM',
        '图片重编码: $originalSize -> ${jpeg.length} 字节',
      );
      return Uint8List.fromList(jpeg);
    }

    _log.info('VisionLLM', '图片无需压缩: ${w}x$h, $originalSize 字节');
    return bytes;
  }

}

class _AnalysisResult {
  final List<String> tags;
  final String description;
  const _AnalysisResult({required this.tags, required this.description});
}
