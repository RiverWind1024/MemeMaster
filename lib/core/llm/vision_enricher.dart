import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../services/log_service.dart';
import '../database/database.dart';
import '../repositories/meme_repository.dart';
import 'config.dart';
import 'local_config.dart';
import 'local_service.dart';
import 'llm_service.dart';
import 'models.dart';
import 'openai_service.dart';

/// 多模态 LLM 驱动的图片标签生成器
///
/// 直接分析图片内容（而非 OCR 文本），识别物体/场景/表情/情绪等。
/// 生成 TagEntry(source: 'llm') 标签和 Meme.description。
class VisionLlmEnricher {
  final LlmService _llm;
  final MemeRepository _repo;
  final LogService _log;
  final bool _isLocalLlm;
  final LlmConfig? _llmConfig;
  final LocalLlmConfig? _localLlmConfig;

  /// 获取底层的 LLM 服务（用于检查模型加载状态）
  LlmService get llm => _llm;

  /// 图片最大边长（超过此尺寸会被压缩以节省 token）
  /// 本地 LLM 缩到 384px（减少 vision encoder 计算量），远程 API 保持 768px（节省 token）
  int get _maxImageDimension => _isLocalLlm ? 384 : 768;

  /// 是否启用图片压缩（用户可关闭以提高分析质量）
  bool get _compressionEnabled {
    // LlmConfig 和 LocalLlmConfig 字段相同，用 dynamic 避免联合类型问题
    final dynamic cfg = _isLocalLlm ? _localLlmConfig : _llmConfig;
    return cfg?.imageCompressionEnabled ?? true;
  }

  /// JPEG 编码质量（1-100）
  static const int _jpgQuality = 85;

  /// 原始文件超过此大小才触发重编码（字节）
  static const int _reencodeThreshold = 200 * 1024;

  VisionLlmEnricher({
    required LlmService llm,
    required MemeRepository repo,
    required LogService log,
    LlmConfig? llmConfig,
    LocalLlmConfig? localLlmConfig,
  })  : _llm = llm,
        _repo = repo,
        _log = log,
        _isLocalLlm = llm is LocalLlmService,
        _llmConfig = llmConfig,
        _localLlmConfig = localLlmConfig;

  /// 对单张 meme 执行多模态分析
  ///
  /// [locale] 为应用当前语言设置，用于选择对应语言的 prompt 模板。
  Future<void> enrich(String memeId, String imagePath, {Locale? locale}) async {
    if (!_llm.isAvailable) {
      _log.warning('VisionLLM', 'LLM 不可用，跳过分析');
      return;
    }

    final effectiveLocale = locale ?? PlatformDispatcher.instance.locale;
    _log.info('VisionLLM', '开始多模态分析: $memeId, locale: ${effectiveLocale.languageCode}');

    try {
      // 1. 读取图片（本地 LLM 直接传原始字节，跳过 base64）
      final imageBytes = await _readAndResizeImage(imagePath);
      final base64Image = _isLocalLlm ? null : base64Encode(imageBytes);
      if (!_isLocalLlm) {
        _log.info('VisionLLM', '图片 base64: ${base64Image!.length} 字节');
      }

      // 2. 调用多模态 LLM（带超时保护）
      final result = await _analyzeImageWithTimeout(base64Image, imageBytes, effectiveLocale);

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
    } on LlmException catch (e) {
      _log.error('VisionLLM', 'LLM API 错误: $e');
      rethrow;  // 让上层知道是API错误
    } catch (e) {
      _log.error('VisionLLM', '多模态分析失败: $e');
      rethrow;  // 重新抛出，让上层处理
    }
  }

  /// 带超时的图片分析
  Future<_AnalysisResult?> _analyzeImageWithTimeout(String? base64Image, Uint8List imageBytes, Locale locale) async {
    if (_isLocalLlm) {
      // 本地 LLM：不在此处设超时，由 _multimodalComplete 内部处理超时 + isolate 清理
      // （外层的 Future.timeout 无法停止正在运行的 FFI 调用，会导致 CPU 持续空转）
      return await _analyzeImage(base64Image, imageBytes, locale);
    }
    // 远程 API 设置较短超时，避免请求无限挂起
    return await _analyzeImage(base64Image, imageBytes, locale).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw LlmException('AI分析超时（60秒）');
      },
    );
  }

  Future<_AnalysisResult?> _analyzeImage(String? base64Image, Uint8List imageBytes, Locale locale) async {
    final isChinese = locale.languageCode.startsWith('zh');
    final systemFile = isChinese ? 'vision_system_zh.txt' : 'vision_system_en.txt';
    final userFile = isChinese ? 'vision_user_zh.txt' : 'vision_user_en.txt';

    _log.info('VisionLLM', '语言判断: isChinese=$isChinese, 使用模板: $systemFile / $userFile');

    final systemPrompt = await _loadPrompt(systemFile, locale);
    final userPrompt = await _loadPrompt(userFile, locale);

    // 使用配置的参数（优先用本地配置，再用远程配置，都没有则用默认值）
    // LlmConfig 和 LocalLlmConfig 字段相同，用 dynamic 避免联合类型问题
    final dynamic effectiveConfig = _isLocalLlm ? _localLlmConfig : _llmConfig;
    final temperature = effectiveConfig?.temperature ?? 0.3;
    final maxTokens = effectiveConfig?.maxTokens ?? 256;
    // 自定义 prompt 覆盖默认模板
    final systemContent = effectiveConfig?.customSystemPrompt ?? systemPrompt;
    final userContent = effectiveConfig?.customUserPrompt ?? userPrompt;

    final messages = [
      LlmMessage(role: 'system', content: systemContent),
      if (_isLocalLlm)
        LlmMessage(role: 'user', content: userContent, imageBytes: imageBytes)
      else
        LlmMessage(role: 'user', content: userContent, imageBase64: base64Image),
    ];

    _log.info('VisionLLM', '调用 LLM: temperature=$temperature, maxTokens=$maxTokens');

    final response = await _llm.chat(
      messages,
      options: LlmOptions(temperature: temperature, maxTokens: maxTokens),
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
    var text = raw.trim();

    // 1. 剥离推理模型的 <think>...</think> 块（Qwen3 / DeepSeek-R1 等会先输出思考）
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');
    text = text.trim();

    // 2. 剥离 markdown 代码块包裹（模型有时返回 ```json ... ```）
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
    final t0 = DateTime.now();
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final t1 = DateTime.now();

    // 压缩已关闭，直接返回原始图片
    if (!_compressionEnabled) {
      _log.info('VisionLLM', '图片压缩已关闭，返回原始文件: ${bytes.length} 字节 (读取耗时 ${t1.difference(t0).inMilliseconds}ms)');
      return bytes;
    }

    final originalSize = bytes.length;

    // 解码图片
    final t2 = DateTime.now();
    final original = img.decodeImage(bytes);
    final t3 = DateTime.now();
    if (original == null) {
      _log.warning('VisionLLM', '无法解码图片，使用原始文件 (解码耗时 ${t3.difference(t2).inMilliseconds}ms)');
      return bytes;
    }

    try {
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
        final t4 = DateTime.now();
        final resized = img.copyResize(original, width: w, height: h);
        final t5 = DateTime.now();
        try {
          final t6 = DateTime.now();
          final jpeg = img.encodeJpg(resized, quality: _jpgQuality);
          final t7 = DateTime.now();
          _log.info(
            'VisionLLM',
            '图片压缩: $originalSize -> ${jpeg.length} 字节, '
                '尺寸: ${original.width}x${original.height} -> ${w}x$h, '
                '读取=${t1.difference(t0).inMilliseconds}ms, '
                '解码=${t3.difference(t2).inMilliseconds}ms, '
                '缩放=${t5.difference(t4).inMilliseconds}ms, '
                '编码=${t7.difference(t6).inMilliseconds}ms, '
                '总计=${t7.difference(t0).inMilliseconds}ms',
          );
          return Uint8List.fromList(jpeg);
        } finally {
          // 释放resized图片内存
        }
      }

      // 尺寸没超但文件较大 → 重编码为 JPEG 减体积
      if (originalSize > _reencodeThreshold) {
        final t4 = DateTime.now();
        final jpeg = img.encodeJpg(original, quality: _jpgQuality);
        final t5 = DateTime.now();
        _log.info(
          'VisionLLM',
          '图片重编码: $originalSize -> ${jpeg.length} 字节, '
              '读取=${t1.difference(t0).inMilliseconds}ms, '
              '解码=${t3.difference(t2).inMilliseconds}ms, '
              '编码=${t5.difference(t4).inMilliseconds}ms, '
              '总计=${t5.difference(t0).inMilliseconds}ms',
        );
        return Uint8List.fromList(jpeg);
      }

      _log.info('VisionLLM', '图片无需压缩: ${w}x$h, $originalSize 字节 (读取+解码=${t3.difference(t0).inMilliseconds}ms)');
      return bytes;
    } finally {
      // 释放原始解码图片内存
      // image包的Image对象会在垃圾回收时自动释放
    }
  }

}

class _AnalysisResult {
  final List<String> tags;
  final String description;
  const _AnalysisResult({required this.tags, required this.description});
}
