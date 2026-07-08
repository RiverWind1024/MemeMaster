import 'dart:io';

/// flash_attn 模式
enum FlashAttnMode { auto, enabled, disabled }

/// KV 缓存量化类型
enum KvCacheType { f16, q4_0 }

/// 本地 LLM 模型配置
class LocalLlmConfig {
  /// GGUF 模型文件路径
  final String? modelPath;

  /// 多模态投影文件路径（如 Qwen2-VL 的 mmproj-*.gguf）
  final String? mmprojPath;

  /// 上下文长度
  final int contextSize;

  /// 推理线程数（0 表示自动检测 CPU 核数）
  final int threads;

  /// 是否启用 GPU 加速
  final bool useGpu;

  /// 放到 GPU 的层数（-1=全部, 0=仅 CPU, 其他值=具体层数）
  final int nGpuLayers;

  /// Flash Attention（auto 根据 GPU 自动决定）
  final FlashAttnMode flashAttn;

  /// KV 缓存量化类型
  final KvCacheType kvCacheType;

  /// 统一 KV 缓存（kv_unified）
  final bool kvUnified;

  /// 是否使用 mmap 加载模型（Android 推荐关闭）
  final bool useMmap;

  /// batch 大小
  final int nBatch;

  /// ubatch 大小
  final int nUBatch;

  /// 温度（控制随机性）
  final double temperature;

  /// 最大 token 数
  final int maxTokens;

  /// 是否启用图片压缩（分析前将图片缩放/压缩以节省 token）
  final bool imageCompressionEnabled;

  /// 自定义系统提示词（null 则使用默认模板）
  final String? customSystemPrompt;

  /// 自定义用户提示词（null 则使用默认模板）
  final String? customUserPrompt;

  const LocalLlmConfig({
    this.modelPath,
    this.mmprojPath,
    this.contextSize = 2048,
    this.threads = 0,
    this.useGpu = false,
    this.nGpuLayers = -1,
    this.flashAttn = FlashAttnMode.enabled,
    this.kvCacheType = KvCacheType.q4_0,
    this.kvUnified = true,
    this.useMmap = true,
    this.nBatch = 512,
    this.nUBatch = 256,
    this.temperature = 0.1,
    this.maxTokens = 256,
    this.imageCompressionEnabled = true,
    this.customSystemPrompt,
    this.customUserPrompt,
  });

  /// 实际使用的线程数（自动检测时根据 CPU 核数计算）
  int get effectiveThreads {
    if (threads > 0) return threads;
    try {
      return Platform.numberOfProcessors.clamp(2, 16);
    } catch (_) {
      return 4;
    }
  }

  String buildExtraParams() {
    final parts = <String>[];
    if (flashAttn != FlashAttnMode.auto) {
      parts.add('flash_attn=${flashAttn == FlashAttnMode.enabled ? "enabled" : "disabled"}');
    }
    parts.add('kv_cache=${kvCacheType == KvCacheType.q4_0 ? "q4_0" : "f16"}');
    parts.add('kv_unified=${kvUnified ? 1 : 0}');
    parts.add('use_mmap=${useMmap ? 1 : 0}');
    parts.add('n_batch=$nBatch');
    parts.add('n_ubatch=$nUBatch');
    return parts.join(',');
  }

  Map<String, dynamic> toJson() => {
        'modelPath': modelPath,
        'mmprojPath': mmprojPath,
        'contextSize': contextSize,
        'threads': threads,
        'useGpu': useGpu,
        'nGpuLayers': nGpuLayers,
        'flashAttn': flashAttn.name,
        'kvCacheType': kvCacheType.name,
        'kvUnified': kvUnified,
        'useMmap': useMmap,
        'nBatch': nBatch,
        'nUBatch': nUBatch,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'imageCompressionEnabled': imageCompressionEnabled,
        if (customSystemPrompt != null) 'customSystemPrompt': customSystemPrompt,
        if (customUserPrompt != null) 'customUserPrompt': customUserPrompt,
      };

  factory LocalLlmConfig.fromJson(Map<String, dynamic> json) =>
      LocalLlmConfig(
        modelPath: json['modelPath'] as String?,
        mmprojPath: json['mmprojPath'] as String?,
        contextSize: json['contextSize'] as int? ?? 2048,
        threads: json['threads'] as int? ?? 0,
        useGpu: json['useGpu'] as bool? ?? false,
        nGpuLayers: json['nGpuLayers'] as int? ?? -1,
        flashAttn: FlashAttnMode.values.firstWhere(
          (e) => e.name == json['flashAttn'],
          orElse: () => FlashAttnMode.enabled,
        ),
        kvCacheType: KvCacheType.values.firstWhere(
          (e) => e.name == json['kvCacheType'],
          orElse: () => KvCacheType.q4_0,
        ),
        kvUnified: json['kvUnified'] as bool? ?? true,
        useMmap: json['useMmap'] as bool? ?? false,
        nBatch: json['nBatch'] as int? ?? 512,
        nUBatch: json['nUBatch'] as int? ?? 256,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.1,
        maxTokens: json['maxTokens'] as int? ?? 256,
        imageCompressionEnabled: json['imageCompressionEnabled'] as bool? ?? true,
        customSystemPrompt: json['customSystemPrompt'] as String?,
        customUserPrompt: json['customUserPrompt'] as String?,
      );

  LocalLlmConfig copyWith({
    String? modelPath,
    String? mmprojPath,
    int? contextSize,
    int? threads,
    bool? useGpu,
    int? nGpuLayers,
    FlashAttnMode? flashAttn,
    KvCacheType? kvCacheType,
    bool? kvUnified,
    bool? useMmap,
    int? nBatch,
    int? nUBatch,
    double? temperature,
    int? maxTokens,
    bool? imageCompressionEnabled,
    String? customSystemPrompt,
    String? customUserPrompt,
    bool clearSystemPrompt = false,
    bool clearUserPrompt = false,
  }) {
    return LocalLlmConfig(
      modelPath: modelPath ?? this.modelPath,
      mmprojPath: mmprojPath ?? this.mmprojPath,
      contextSize: contextSize ?? this.contextSize,
      threads: threads ?? this.threads,
      useGpu: useGpu ?? this.useGpu,
      nGpuLayers: nGpuLayers ?? this.nGpuLayers,
      flashAttn: flashAttn ?? this.flashAttn,
      kvCacheType: kvCacheType ?? this.kvCacheType,
      kvUnified: kvUnified ?? this.kvUnified,
      useMmap: useMmap ?? this.useMmap,
      nBatch: nBatch ?? this.nBatch,
      nUBatch: nUBatch ?? this.nUBatch,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      imageCompressionEnabled: imageCompressionEnabled ?? this.imageCompressionEnabled,
      customSystemPrompt: clearSystemPrompt ? null : (customSystemPrompt ?? this.customSystemPrompt),
      customUserPrompt: clearUserPrompt ? null : (customUserPrompt ?? this.customUserPrompt),
    );
  }
}
