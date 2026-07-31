import 'dart:io';

/// GPU 检测结果
class GpuDetectionResult {
  /// 检测到的 GPU 类型
  final String backend;

  /// 可用的 GPU 层数（99=全部, 0=不可用）
  final int recommendedLayers;

  /// 是否检测到 GPU 加速可用
  bool get isAvailable => recommendedLayers > 0;

  const GpuDetectionResult({
    required this.backend,
    required this.recommendedLayers,
  });

  @override
  String toString() => 'GpuDetectionResult(backend: $backend, layers: $recommendedLayers)';
}

/// GPU 检测器 - 运行时检测可用 GPU 后端
class GpuDetector {
  GpuDetector._();

  /// 检测当前平台可用的 GPU 后端，返回推荐 GPU 层数
  ///
  /// 参考 Bonsai 项目的 `bonsai_llama_ngl()` 函数实现:
  /// https://github.com/PrismML-Eng/Bonsai-demo/blob/master/scripts/common.sh
  ///
  /// 检测优先级: CUDA > ROCm/HIP > Vulkan > Metal > CPU
  static Future<GpuDetectionResult> detect() async {
    // 用户可通过环境变量覆盖
    final override = Platform.environment['MEME_GPU_LAYERS'];
    if (override != null) {
      final layers = int.tryParse(override);
      if (layers != null) {
        return GpuDetectionResult(
          backend: 'user_override',
          recommendedLayers: layers,
        );
      }
    }

    if (Platform.isMacOS) {
      return _detectMacOS();
    } else if (Platform.isLinux) {
      return await _detectLinux();
    } else if (Platform.isWindows) {
      return await _detectWindows();
    } else if (Platform.isAndroid) {
      return await _detectAndroid();
    }

    return const GpuDetectionResult(backend: 'unknown', recommendedLayers: 0);
  }

  static GpuDetectionResult _detectMacOS() {
    // Apple Silicon 有 Metal，Intel Mac 无 Metal
    if (Platform.isMacOS) {
      // macOS 始终有 Metal 支持（Apple Silicon）
      // 注意: 这只是运行时检测，不保证构建时启用了 Metal
      return const GpuDetectionResult(backend: 'metal', recommendedLayers: 99);
    }
    return const GpuDetectionResult(backend: 'none', recommendedLayers: 0);
  }

  static Future<GpuDetectionResult> _detectLinux() async {
    // 检测优先级: CUDA > Vulkan
    if (await _commandExists('nvidia-smi')) {
      return const GpuDetectionResult(backend: 'cuda', recommendedLayers: 99);
    }
    if (await _commandExists('vulkaninfo')) {
      return const GpuDetectionResult(backend: 'vulkan', recommendedLayers: 99);
    }
    if (await _commandExists('rocminfo')) {
      return const GpuDetectionResult(backend: 'rocm', recommendedLayers: 99);
    }
    return const GpuDetectionResult(backend: 'cpu', recommendedLayers: 0);
  }

  static Future<GpuDetectionResult> _detectWindows() async {
    // Windows: Vulkan 检测
    if (await _commandExists('vulkaninfo')) {
      return const GpuDetectionResult(backend: 'vulkan', recommendedLayers: 99);
    }
    return const GpuDetectionResult(backend: 'cpu', recommendedLayers: 0);
  }

  static Future<GpuDetectionResult> _detectAndroid() async {
    // Android: Vulkan (OpenCL 尚未稳定)
    if (await _commandExists('vulkaninfo')) {
      return const GpuDetectionResult(backend: 'vulkan', recommendedLayers: 99);
    }
    return const GpuDetectionResult(backend: 'cpu', recommendedLayers: 0);
  }

  /// 检测命令是否存在
  static Future<bool> _commandExists(String cmd) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [cmd],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

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
    this.useGpu = true,  // 默认启用 GPU（由 GpuDetector 运行时检测实际可用性）
    this.nGpuLayers = -1,
    this.flashAttn = FlashAttnMode.enabled,
    this.kvCacheType = KvCacheType.q4_0,
    this.useMmap = true,
    this.nBatch = 512,
    this.nUBatch = 256,
    this.temperature = 0.1,
    this.maxTokens = 256,
    this.imageCompressionEnabled = true,
    this.customSystemPrompt,
    this.customUserPrompt,
  });

  /// 自动检测 GPU 并创建配置
  ///
  /// 等价于 `LocalLlmConfig(useGpu: true, nGpuLayers: -1)`，
  /// 但会在运行时检测实际 GPU 可用性：
  /// - Windows/Linux/macOS: 检测到 GPU 时 nGpuLayers=99，否则 0
  /// - 检测失败时 useGpu=false（安全回退）
  ///
  /// 用法:
  /// ```dart
  /// final config = await LocalLlmConfig.autoDetect();
  /// final service = LocalLlmService(config: config);
  /// ```
  static Future<LocalLlmConfig> autoDetect() async {
    final result = await GpuDetector.detect();
    return LocalLlmConfig(
      useGpu: result.isAvailable,
      nGpuLayers: result.isAvailable ? result.recommendedLayers : 0,
    );
  }

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
