/// LLM 模式
enum LlmMode { off, remote, local }

/// LLM 供应商类型
enum LlmProviderType {
  openai,
  ollama,
}

/// LLM 配置
class LlmConfig {
  final LlmMode mode;
  final LlmProviderType provider;
  final String baseUrl;
  final String apiKey;
  final String model;

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'provider': provider.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
        mode: LlmMode.values.byName(json['mode'] as String? ?? 'off'),
        provider:
            LlmProviderType.values.byName(json['provider'] as String),
        baseUrl: json['baseUrl'] as String,
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String,
      );

  const LlmConfig({
    this.mode = LlmMode.off,
    this.provider = LlmProviderType.ollama,
    this.baseUrl = 'http://localhost:11434/v1',
    this.apiKey = '',
    this.model = 'llama3.2',
  });

  LlmConfig copyWith({
    LlmMode? mode,
    LlmProviderType? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return LlmConfig(
      mode: mode ?? this.mode,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}
