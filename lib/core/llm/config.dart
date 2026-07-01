/// LLM 供应商类型
enum LlmProviderType {
  openai,
  ollama,
}

/// LLM 配置
class LlmConfig {
  final LlmProviderType provider;
  final String baseUrl;
  final String apiKey;
  final String model;

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
        provider:
            LlmProviderType.values.byName(json['provider'] as String),
        baseUrl: json['baseUrl'] as String,
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String,
      );

  const LlmConfig({
    this.provider = LlmProviderType.ollama,
    this.baseUrl = 'http://localhost:11434',
    this.apiKey = '',
    this.model = 'llama3.2',
  });

  LlmConfig copyWith({
    LlmProviderType? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return LlmConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}
