import 'dart:convert';
import 'dart:io';

import '../core/llm/config.dart';
import '../services/s3_config.dart';

/// CLI 配置（LLM + S3），持久化到 [CliConfigStore] 管理的 JSON 文件。
class CliConfig {
  final LlmConfig llm;
  final S3Config s3;

  const CliConfig({
    this.llm = const LlmConfig(),
    this.s3 = const S3Config(),
  });
}

/// CLI 配置文件读写（纯 Dart）。
///
/// 默认路径 `~/.config/mememaster/cli_config.json`（`~` 用 HOME 展开），
/// 测试通过构造参数 [configPath] 注入临时路径，避免写真实 HOME。
class CliConfigStore {
  final String configPath;

  CliConfigStore({String? configPath})
      : configPath = configPath ?? defaultConfigPath();

  static String defaultConfigPath() {
    final home = Platform.environment['HOME'];
    final base = (home != null && home.isNotEmpty)
        ? '$home/.config/mememaster'
        : '.mememaster';
    return '$base/cli_config.json';
  }

  /// 加载配置；文件不存在或损坏时回退默认值。
  Future<CliConfig> load() async {
    final file = File(configPath);
    if (!await file.exists()) return const CliConfig();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return const CliConfig();
      return CliConfig(
        llm: json['llm'] is Map<String, dynamic>
            ? LlmConfig.fromJson(json['llm'] as Map<String, dynamic>)
            : const LlmConfig(),
        s3: json['s3'] is Map<String, dynamic>
            ? S3Config.fromJson(json['s3'] as Map<String, dynamic>)
            : const S3Config(),
      );
    } catch (_) {
      return const CliConfig();
    }
  }

  /// 保存配置（自动创建父目录）。
  Future<void> save(CliConfig config) async {
    final file = File(configPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'llm': config.llm.toJson(),
      's3': config.s3.toJson(),
      }));
  }
}
