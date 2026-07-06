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

  const LocalLlmConfig({
    this.modelPath,
    this.mmprojPath,
    this.contextSize = 2048,
    this.threads = 0,
    this.useGpu = true,
    this.flashAttn = FlashAttnMode.auto,
    this.kvCacheType = KvCacheType.f16,
    this.kvUnified = true,
    this.useMmap = false,
    this.nBatch = 512,
    this.nUBatch = 256,
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
        'flashAttn': flashAttn.name,
        'kvCacheType': kvCacheType.name,
        'kvUnified': kvUnified,
        'useMmap': useMmap,
        'nBatch': nBatch,
        'nUBatch': nUBatch,
      };

  factory LocalLlmConfig.fromJson(Map<String, dynamic> json) =>
      LocalLlmConfig(
        modelPath: json['modelPath'] as String?,
        mmprojPath: json['mmprojPath'] as String?,
        contextSize: json['contextSize'] as int? ?? 2048,
        threads: json['threads'] as int? ?? 0,
        useGpu: json['useGpu'] as bool? ?? true,
        flashAttn: FlashAttnMode.values.firstWhere(
          (e) => e.name == json['flashAttn'],
          orElse: () => FlashAttnMode.auto,
        ),
        kvCacheType: KvCacheType.values.firstWhere(
          (e) => e.name == json['kvCacheType'],
          orElse: () => KvCacheType.f16,
        ),
        kvUnified: json['kvUnified'] as bool? ?? true,
        useMmap: json['useMmap'] as bool? ?? false,
        nBatch: json['nBatch'] as int? ?? 512,
        nUBatch: json['nUBatch'] as int? ?? 256,
      );

  LocalLlmConfig copyWith({
    String? modelPath,
    String? mmprojPath,
    int? contextSize,
    int? threads,
    bool? useGpu,
    FlashAttnMode? flashAttn,
    KvCacheType? kvCacheType,
    bool? kvUnified,
    bool? useMmap,
    int? nBatch,
    int? nUBatch,
  }) {
    return LocalLlmConfig(
      modelPath: modelPath ?? this.modelPath,
      mmprojPath: mmprojPath ?? this.mmprojPath,
      contextSize: contextSize ?? this.contextSize,
      threads: threads ?? this.threads,
      useGpu: useGpu ?? this.useGpu,
      flashAttn: flashAttn ?? this.flashAttn,
      kvCacheType: kvCacheType ?? this.kvCacheType,
      kvUnified: kvUnified ?? this.kvUnified,
      useMmap: useMmap ?? this.useMmap,
      nBatch: nBatch ?? this.nBatch,
      nUBatch: nUBatch ?? this.nUBatch,
    );
  }
}
