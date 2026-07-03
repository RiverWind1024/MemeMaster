import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/image/color_extraction_config.dart';
import '../core/llm/config.dart';
import '../core/llm/local_config.dart';
import 's3_config.dart';

/// 当前导出格式版本
const int _exportVersion = 1;

/// 导出数据结构
class ExportPayload {
  final int version;
  final String exportedAt;
  final Map<String, dynamic> configs;

  const ExportPayload({
    required this.version,
    required this.exportedAt,
    required this.configs,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt,
        'configs': configs,
      };

  factory ExportPayload.fromJson(Map<String, dynamic> json) {
    return ExportPayload(
      version: json['version'] as int? ?? 1,
      exportedAt: json['exportedAt'] as String? ?? '',
      configs: Map<String, dynamic>.from(json['configs'] as Map? ?? {}),
    );
  }
}

/// 配置导出/导入服务
///
/// 将应用的所有可配置项（S3、LLM、颜色提取、主题、语言等）序列化为 JSON，
/// 支持导出到文件 / 分享，以及从文件导入恢复。
class ConfigExporter {
  /// 收集所有配置并返回 JSON 字符串
  static Future<String> exportConfig({
    required S3Config s3Config,
    required LlmConfig llmConfig,
    required LocalLlmConfig localLlmConfig,
    required ColorExtractionConfig colorExtractionConfig,
    required String themeMode,
    required String? locale,
    required bool ocrEnabled,
    required bool llmEnabled,
    required String llmMode,
  }) async {
    final payload = ExportPayload(
      version: _exportVersion,
      exportedAt: DateTime.now().toIso8601String(),
      configs: {
        's3': s3Config.toJson(),
        'llm': {
          'mode': llmMode,
          'remote': llmConfig.toJson(),
          'local': localLlmConfig.toJson(),
        },
        'colorExtraction': colorExtractionConfig.toJson(),
        'themeMode': themeMode,
        'locale': locale,
        'ocrEnabled': ocrEnabled,
        'llmEnabled': llmEnabled,
      },
    );
    return const JsonEncoder.withIndent('  ').convert(payload.toJson());
  }

  /// 从 JSON 字符串解析配置负载
  static ExportPayload parseExport(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ExportPayload.fromJson(data);
  }

  /// 将配置导出为文件
  ///
  /// 桌面平台使用系统文件选择器，移动平台保存到应用文档目录后用分享弹窗通知用户。
  static Future<String?> exportToFile(String jsonContent) async {
    if (Platform.isAndroid || Platform.isIOS) {
      // 移动平台：保存到文档目录，然后通过分享发送
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/memehelper_config.json');
      await file.writeAsString(jsonContent, flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'MemeHelper 配置');
      return file.path;
    }
    // 桌面平台：使用系统文件选择器
    final location = await getSaveLocation(
      suggestedName: 'memehelper_config.json',
    );
    final path = location?.path;
    if (path == null) return null;
    await File(path).writeAsString(jsonContent, flush: true);
    return path;
  }

  /// 通过系统分享导出配置
  static Future<void> exportViaShare(String jsonContent) async {
    // 先写入临时文件
    final tmpDir = Directory.systemTemp;
    final tmpFile = File('${tmpDir.path}/memehelper_config.json');
    await tmpFile.writeAsString(jsonContent, flush: true);
    await Share.shareXFiles([XFile(tmpFile.path)], text: 'MemeHelper 配置');
  }

  /// 从文件读取并解析配置
  static Future<ExportPayload?> importFromFile() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'JSON 配置',
          extensions: ['json'],
        ),
      ],
    );
    if (files.isEmpty) return null;
    final content = await files.first.readAsString();
    return parseExport(content);
  }

  /// 应用导入的配置（通过回调写入各 Notifier，调用方持有 ref）
  static Future<Map<String, String>> applyConfig({
    required ExportPayload payload,
    required Future<void> Function(S3Config) saveS3Config,
    required void Function(LlmConfig) updateLlmConfig,
    required void Function(LocalLlmConfig) updateLocalLlmConfig,
    required void Function(ColorExtractionConfig) updateColorExtraction,
    required void Function(String) setThemeMode,
    required void Function(String?) setLocale,
    required void Function(bool) setOcrEnabled,
    required void Function(bool) setLlmEnabled,
    required void Function(String) setLlmMode,
  }) async {
    final errors = <String, String>{};
    final configs = payload.configs;

    try {
      final s3 = configs['s3'];
      if (s3 != null) {
        await saveS3Config(
            S3Config.fromJson(Map<String, dynamic>.from(s3 as Map)));
      }
    } catch (e) {
      errors['s3'] = '$e';
    }

    try {
      final llm = configs['llm'];
      if (llm != null) {
        final llmMap = Map<String, dynamic>.from(llm as Map);
        setLlmMode(llmMap['mode'] as String? ?? 'off');
        final remote = llmMap['remote'];
        if (remote != null) {
          updateLlmConfig(
              LlmConfig.fromJson(Map<String, dynamic>.from(remote as Map)));
        }
        final local = llmMap['local'];
        if (local != null) {
          updateLocalLlmConfig(
              LocalLlmConfig.fromJson(Map<String, dynamic>.from(local as Map)));
        }
      }
    } catch (e) {
      errors['llm'] = '$e';
    }

    try {
      final ce = configs['colorExtraction'];
      if (ce != null) {
        updateColorExtraction(
            ColorExtractionConfig.fromJson(Map<String, dynamic>.from(ce as Map)));
      }
    } catch (e) {
      errors['colorExtraction'] = '$e';
    }

    try {
      final tm = configs['themeMode'];
      if (tm != null) {
        setThemeMode(tm as String);
      }
    } catch (e) {
      errors['themeMode'] = '$e';
    }

    try {
      // locale can be null (means system follow)
      final loc = configs['locale'];
      setLocale(loc as String?);
    } catch (e) {
      errors['locale'] = '$e';
    }

    try {
      final ocr = configs['ocrEnabled'];
      if (ocr != null) {
        setOcrEnabled(ocr as bool);
      }
    } catch (e) {
      errors['ocrEnabled'] = '$e';
    }

    try {
      final llmE = configs['llmEnabled'];
      if (llmE != null) {
        setLlmEnabled(llmE as bool);
      }
    } catch (e) {
      errors['llmEnabled'] = '$e';
    }

    return errors;
  }
}
