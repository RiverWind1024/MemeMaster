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
  final double temperature;
  final int maxTokens;
  final bool imageCompressionEnabled;
  final String? customSystemPrompt;
  final String? customUserPrompt;

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'provider': provider.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'imageCompressionEnabled': imageCompressionEnabled,
        if (customSystemPrompt != null) 'customSystemPrompt': customSystemPrompt,
        if (customUserPrompt != null) 'customUserPrompt': customUserPrompt,
      };

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
        mode: LlmMode.values.byName(json['mode'] as String? ?? 'off'),
        provider:
            LlmProviderType.values.byName(json['provider'] as String),
        baseUrl: json['baseUrl'] as String,
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.3,
        maxTokens: json['maxTokens'] as int? ?? 256,
        imageCompressionEnabled: json['imageCompressionEnabled'] as bool? ?? true,
        customSystemPrompt: json['customSystemPrompt'] as String?,
        customUserPrompt: json['customUserPrompt'] as String?,
      );

  const LlmConfig({
    this.mode = LlmMode.off,
    this.provider = LlmProviderType.ollama,
    this.baseUrl = 'http://localhost:11434/v1',
    this.apiKey = '',
    this.model = 'llama3.2',
    this.temperature = 0.3,
    this.maxTokens = 256,
    this.imageCompressionEnabled = true,
    this.customSystemPrompt,
    this.customUserPrompt,
  });

  LlmConfig copyWith({
    LlmMode? mode,
    LlmProviderType? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? imageCompressionEnabled,
    String? customSystemPrompt,
    String? customUserPrompt,
    bool clearSystemPrompt = false,
    bool clearUserPrompt = false,
  }) {
    return LlmConfig(
      mode: mode ?? this.mode,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      imageCompressionEnabled: imageCompressionEnabled ?? this.imageCompressionEnabled,
      customSystemPrompt: clearSystemPrompt ? null : (customSystemPrompt ?? this.customSystemPrompt),
      customUserPrompt: clearUserPrompt ? null : (customUserPrompt ?? this.customUserPrompt),
    );
  }
}
