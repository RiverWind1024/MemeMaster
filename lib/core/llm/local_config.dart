/// 本地 LLM 模型配置
class LocalLlmConfig {
  /// GGUF 模型文件路径
  final String? modelPath;

  /// 多模态投影文件路径（如 Qwen2-VL 的 mmproj-*.gguf）
  final String? mmprojPath;

  /// 上下文长度
  final int contextSize;

  /// 推理线程数
  final int threads;

  /// 是否启用 GPU 加速
  final bool useGpu;

  const LocalLlmConfig({
    this.modelPath,
    this.mmprojPath,
    this.contextSize = 2048,
    this.threads = 4,
    this.useGpu = true,
  });

  Map<String, dynamic> toJson() => {
        'modelPath': modelPath,
        'mmprojPath': mmprojPath,
        'contextSize': contextSize,
        'threads': threads,
        'useGpu': useGpu,
      };

  factory LocalLlmConfig.fromJson(Map<String, dynamic> json) =>
      LocalLlmConfig(
        modelPath: json['modelPath'] as String?,
        mmprojPath: json['mmprojPath'] as String?,
        contextSize: json['contextSize'] as int? ?? 2048,
        threads: json['threads'] as int? ?? 4,
        useGpu: json['useGpu'] as bool? ?? true,
      );

  LocalLlmConfig copyWith({
    String? modelPath,
    String? mmprojPath,
    int? contextSize,
    int? threads,
    bool? useGpu,
  }) {
    return LocalLlmConfig(
      modelPath: modelPath ?? this.modelPath,
      mmprojPath: mmprojPath ?? this.mmprojPath,
      contextSize: contextSize ?? this.contextSize,
      threads: threads ?? this.threads,
      useGpu: useGpu ?? this.useGpu,
    );
  }
}
