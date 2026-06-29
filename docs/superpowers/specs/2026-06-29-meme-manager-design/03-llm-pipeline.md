# MemeHelper LLM 与分析管线设计

> 所属项目: MemeHelper
> 文档编号: 03-llm-pipeline.md
> 涉及: llama.cpp FFI 集成、OCR、颜色提取、后台分析队列

---

## 1. llama.cpp Android 集成

### 1.1 编译 llama.cpp 为 Android .so

使用 Android NDK 交叉编译生成 `libllama.so` 和 `libggml.so`:

```bash
# 在 llama.cpp 项目根目录
mkdir build-android && cd build-android

cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-26 \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_METAL=OFF \
      -DLLAMA_CUBLAS=OFF \
      -DLLAMA_VULKAN=ON \
      ..

make -j$(nproc)
```

产物：
- `libllama.so` — 核心推理库
- `libggml.so` — 张量计算库
- `libggml-base.so` — 基础运算

**在 Flutter 中集成**：将 .so 文件放入 `android/app/src/main/jniLibs/arm64-v8a/`，Flutter 打包时自动包含。

### 1.2 Dart FFI 绑定结构

```dart
// lib/core/llm/llm_bindings.dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';  // String 转换

// C 函数签名映射
typedef LlamaModelLoadNative = Pointer<Void> Function(
  Pointer<Utf8> modelPath,   // GGUF 文件路径
  Int32 nCtx,                // 上下文大小 (2048)
);

typedef LlamaModelLoadDart = Pointer<Void> Function(
  Pointer<Utf8> modelPath, int nCtx,
);

// 推理接口
typedef LlamaEvalNative = Pointer<Utf8> Function(
  Pointer<Void> model,
  Pointer<Utf8> prompt,
  Int32 nThreads,
);

typedef LlamaEvalDart = Pointer<Utf8> Function(
  Pointer<Void> model, Pointer<Utf8> prompt, int nThreads,
);

// Embedding 接口
typedef LlamaEmbedNative = Pointer<Void> Function(
  Pointer<Void> model,
  Pointer<Utf8> text,
  Pointer<Float> outEmbeddings,
  Int32 nThreads,
);

typedef LlamaEmbedDart = Pointer<Void> Function(
  Pointer<Void> model, Pointer<Utf8> text,
  Pointer<Float> outEmbeddings, int nThreads,
);

class LlamaBindings {
  late final DynamicLibrary _lib;
  late final LlamaModelLoadDart modelLoad;
  late final LlamaEvalDart eval;
  late final LlamaEmbedDart embed;

  LlamaBindings() {
    _lib = DynamicLibrary.open('libllama.so');
    modelLoad = _lib.lookupFunction<LlamaModelLoadNative, LlamaModelLoadDart>('llama_model_load');
    eval = _lib.lookupFunction<LlamaEvalNative, LlamaEvalDart>('llama_eval');
    embed = _lib.lookupFunction<LlamaEmbedNative, LlamaEmbedDart>('llama_embed');
  }
}
```

### 1.3 LLM Service 封装

```dart
// lib/core/llm/llm_service.dart
class LlmService {
  final LlamaBindings _bindings;
  Pointer<Void>? _currentModel;
  String? _loadedModelPath;

  LlmService(this._bindings);

  /// 加载 GGUF 模型，支持热切换（先 unload 旧模型）
  Future<void> loadModel(String ggufPath) async {
    if (_currentModel != null) {
      unloadModel();
    }
    final pathPtr = ggufPath.toNativeUtf8();
    _currentModel = _bindings.modelLoad(pathPtr, 2048);
    calloc.free(pathPtr);
    _loadedModelPath = ggufPath;
  }

  void unloadModel() {
    // llama.cpp 的 model_free 调用
    _bindings.modelFree(_currentModel!);
    _currentModel = null;
    _loadedModelPath = null;
  }

  /// 多模态推理：传入图片路径 + prompt → 文本描述
  Future<String> multimodalInference({
    required String imagePath,
    required String prompt,
  }) async {
    // 多模态模型的 prompt 需包含图片 token
    // LLaVA 格式: <image>\n{prompt}
    final fullPrompt = '<image>\n$prompt';
    final promptPtr = fullPrompt.toNativeUtf8();
    final resultPtr = _bindings.eval(_currentModel!, promptPtr, 4);
    final result = resultPtr.toDartString();
    calloc.free(promptPtr);
    return result.trim();
  }

  /// 文本 → Embedding 向量
  Future<Uint8List> encode(String text) async {
    // 分配 384 维 float32 数组 (1536 bytes)
    final out = calloc<Float>(384);
    final textPtr = text.toNativeUtf8();
    _bindings.embed(_currentModel!, textPtr, out, 4);
    calloc.free(textPtr);

    // 转换为 Uint8List (binary float32)
    final result = Uint8List.view(out.asTypedList(384).buffer);
    calloc.free(out);
    return result;
  }

  bool get isModelLoaded => _currentModel != null;
  String? get loadedModelPath => _loadedModelPath;
}
```

### 1.4 内存管理

- 模型加载后将常驻内存（~2-8GB 取决于模型大小和量化级别）
- 轻量模式不加载多模态模型，仅加载 embedding 模型（~50MB）
- 用户可在设置中卸载模型以释放内存
- `llama.cpp` 的 context size 设为 2048（移动端平衡值）

---

## 2. 模型管理

### 2.1 模型下载

```dart
// lib/core/llm/model_downloader.dart
class ModelDownloader {
  /// 从 HuggingFace 下载 GGUF 模型
  /// 支持断点续传 (Range header)
  Future<void> download({
    required String url,           // HuggingFace download URL
    required String savePath,      // app_dir/models/filename.gguf
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    // 检查本地是否已有部分下载
    final existingFile = File(savePath);
    int startByte = 0;
    if (await existingFile.exists()) {
      startByte = await existingFile.length();
    }

    // 发起带 Range 的请求
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('Range', 'bytes=$startByte-');
    final response = await request.close();

    // 追加写入
    final totalSize = response.headers.contentLength ?? 0;
    final sink = existingFile.openWrite(mode: FileMode.append);
    int bytesReceived = startByte;
    await for (final chunk in response) {
      sink.add(chunk);
      bytesReceived += chunk.length;
      onProgress(bytesReceived / (startByte + totalSize));
    }
    await sink.close();
  }
}
```

### 2.2 推荐模型

| 用途 | 模型 | 量化 | 大小 | 说明 |
|------|------|------|------|------|
| 多模态描述 | `moondream-2b-Q4_K_M.gguf` | Q4_K_M | ~1.2GB | 轻量多模态，适合移动端 |
| 多模态描述（高质量） | `llava-v1.6-7b-Q4_K_M.gguf` | Q4_K_M | ~4.5GB | 更高精度但更大 |
| Embedding | `all-MiniLM-L6-v2-Q4_K_M.gguf` | Q4_K_M | ~45MB | 384维向量，极轻量 |
| Embedding（中文优化） | `bge-small-zh-v1.5-Q4_K_M.gguf` | Q4_K_M | ~45MB | 中文搜索推荐 |

### 2.3 模型切换策略

```
用户切换模型
    │
    ├── 卸载旧模型 (unloadModel)
    ├── 检查新模型文件是否存在
    │   ├── 是 → 直接 loadModel
    │   └── 否 → 触发下载流程
    └── 模型切换后：
        └── 提示用户 "是否需要重新生成所有 embedding？"
            ├── 是 → 触发全量 re-embed（后台运行）
            └── 否 → 保留旧 embedding，后续新分析用新模型
```

---

## 3. OCR 子系统

### 3.1 ML Kit 集成

通过 Flutter `MethodChannel` 调用 Android 原生 ML Kit：

```dart
// lib/core/ocr/ocr_service.dart
class OcrService {
  static const _channel = MethodChannel('meme_helper/ocr');

  /// 识别图片中的文字
  /// 返回 [{text: "识别文字", confidence: 0.95}]
  Future<List<OcrResult>> recognize(String imagePath) async {
    try {
      final result = await _channel.invokeMethod('recognizeText', {
        'imagePath': imagePath,
        'languages': ['zh', 'en'],  // 自动检测中英文
      });

      final List<dynamic> blocks = result['blocks'];
      return blocks.map((b) => OcrResult(
        text: b['text'] as String,
        confidence: (b['confidence'] as num).toDouble(),
      )).toList();
    } on PlatformException catch (e) {
      throw OcrException('OCR 识别失败: ${e.message}');
    }
  }
}
```

### 3.2 Android 原生实现（Kotlin）

```kotlin
// android/app/src/main/kotlin/.../OcrPlugin.kt
class OcrPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var recognizer: TextRecognition

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        recognizer = TextRecognition.getClient(
            ChineseTextRecognizerOptions.Builder().build()
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "recognizeText") {
            val imagePath = call.argument<String>("imagePath")!!
            val inputImage = InputImage.fromFilePath(context, imagePath)
            
            recognizer.process(inputImage)
                .addOnSuccessListener { visionText ->
                    val blocks = visionText.textBlocks.map { block ->
                        mapOf(
                            "text" to block.text,
                            "confidence" to block.confidence
                        )
                    }
                    result.success(mapOf("blocks" to blocks))
                }
                .addOnFailureListener { e ->
                    result.error("OCR_ERROR", e.message, null)
                }
        }
    }
}
```

### 3.3 OCR 文本后处理

```dart
List<String> _postProcessOcrText(List<OcrResult> results) {
  // 1. 排序（按阅读顺序，从上到下）
  // 2. 去重（同一文字被识别多次）
  // 3. 过滤噪声（单字符、无意义符号）
  // 4. 合并短句

  return results
    .where((r) => r.confidence > 0.5)
    .where((r) => r.text.trim().length >= 2)  // 过滤单字符噪声
    .map((r) => r.text.trim())
    .toSet()                                   // 去重
    .toList();
}
```

---

## 4. 颜色提取

```dart
// lib/core/image/color_extractor.dart
class ColorExtractor {
  /// 从图片中提取 N 个主色调
  /// 算法: 缩放 → 量化 → 聚簇 → 排序
  Future<List<DominantColor>> extract(String imagePath, {int count = 5}) async {
    // 1. 加载图片并缩放到 100x100
    final imageFile = File(imagePath);
    final original = decodeImage(await imageFile.readAsBytes())!;
    final small = copyResize(original, width: 100, height: 100);

    // 2. 收集所有像素
    final pixels = <int>[];
    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        pixels.add(small.getPixel(x, y));
      }
    }

    // 3. 用中值切割算法(Median Cut)提取主色调
    final quantizer = MedianCutQuantizer(pixels, count);
    final palette = quantizer.quantize();

    // 4. 计算每个颜色的占比
    final total = pixels.length;
    return palette.map((color) {
      final hex = _colorToHex(color);
      final lab = rgbToLab(color);
      return DominantColor(
        hexColor: hex,
        labL: lab.l,
        labA: lab.a,
        labB: lab.b,
        ratio: color.count / total,
      );
    }).sorted((a, b) => b.ratio.compareTo(a.ratio)).toList();
  }

  String _colorToHex(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }
}
```

### RGB → CIE Lab 转换

```dart
// lib/core/image/color_utils.dart
class LabColor {
  final double l, a, b;
  LabColor(this.l, this.a, this.b);
}

LabColor rgbToLab(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255.0;
  final g = ((argb >> 8) & 0xFF) / 255.0;
  final b = (argb & 0xFF) / 255.0;

  // RGB linearization (Gamma correction)
  double linearize(double c) =>
    c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4).toDouble() : c / 12.92;

  final rL = linearize(r);
  final gL = linearize(g);
  final bL = linearize(b);

  // sRGB → XYZ (D65)
  final x = 0.4124564 * rL + 0.3575761 * gL + 0.1804375 * bL;
  final y = 0.2126729 * rL + 0.7151522 * gL + 0.0721750 * bL;
  final z = 0.0193339 * rL + 0.1191920 * gL + 0.9503041 * bL;

  // XYZ → Lab (D65 reference)
  final xn = 0.95047, yn = 1.0, zn = 1.08883;
  double f(double t) =>
    t > 0.008856 ? pow(t, 1.0/3.0).toDouble() : (7.787 * t + 16.0/116.0);

  final fx = f(x / xn), fy = f(y / yn), fz = f(z / zn);

  return LabColor(
    l: 116.0 * fy - 16.0,
    a: 500.0 * (fx - fy),
    b: 200.0 * (fy - fz),
  );
}
```

---

## 5. 分析管线完整流程

### 5.1 管线配置 (Pipeline Config)

```dart
// lib/core/config/pipeline_config.dart
class PipelineConfig {
  /// OCR 识别开关
  final bool ocrEnabled;

  /// LLM 描述生成开关
  final bool llmEnabled;

  /// 默认配置: 只有颜色提取是强制开启的
  const PipelineConfig({
    this.ocrEnabled = false,
    this.llmEnabled = false,
  });

  PipelineConfig copyWith({bool? ocrEnabled, bool? llmEnabled}) {
    return PipelineConfig(
      ocrEnabled: ocrEnabled ?? this.ocrEnabled,
      llmEnabled: llmEnabled ?? this.llmEnabled,
    );
  }

  /// 序列化到 SharedPreferences / drift
  Map<String, dynamic> toJson() => {
    'ocr_enabled': ocrEnabled,
    'llm_enabled': llmEnabled,
  };

  factory PipelineConfig.fromJson(Map<String, dynamic> json) => PipelineConfig(
    ocrEnabled: json['ocr_enabled'] as bool? ?? false,
    llmEnabled: json['llm_enabled'] as bool? ?? false,
  );
}
```

### 5.2 单 Meme 分析步骤 (带 Toggle 控制)

```dart
// lib/services/analysis_service.dart
class AnalysisService {
  final PipelineConfig config;

  AnalysisService({required this.config});

  Future<AnalysisResult> analyzeOne(Meme meme) async {
    final stopwatch = Stopwatch()..start();
    final stepsRun = <String>[];

    try {
      // 步骤 1: 颜色提取 (~100ms) — 始终执行，不可关闭
      final colors = await colorExtractor.extract(meme.filePath);
      await colorRepo.insertBatch(colors.map((c) => c.toEntity(meme.id)));
      stepsRun.add('color');

      // 步骤 2: OCR 文字识别 (~500ms) — 可开关
      List<Tag> ocrTags = [];
      if (config.ocrEnabled) {
        if (await ocrService.isAvailable) {
          try {
            final ocrResults = await ocrService.recognize(meme.filePath);
            ocrTags = ocrResults
              .where((r) => r.confidence > 0.5)
              .map((r) => Tag(
                memeId: meme.id,
                source: 'ocr',
                content: r.text,
                confidence: r.confidence,
              )).toList();
            await tagRepo.insertBatch(ocrTags);
            stepsRun.add('ocr');
          } on OcrException catch (_) {
            // OCR 失败不阻塞管线
          }
        } else {
          // OCR 开启但模型不可用 → SnackBar 提示在外部处理
        }
      }

      // 步骤 3: LLM 多模态描述 (~5-15s) — 可开关
      List<Tag> llmTags = [];
      if (config.llmEnabled) {
        if (llmService.isMultimodalModelLoaded) {
          try {
            final description = await llmService.multimodalInference(
              imagePath: meme.filePath,
              prompt: _memeAnalysisPrompt,
            );
            llmTags = [Tag(
              memeId: meme.id,
              source: 'llm',
              content: description,
              confidence: 0.9,
            )];
            await tagRepo.insertBatch(llmTags);
            stepsRun.add('llm');
          } on LlmInferenceException catch (_) {
            // LLM 失败不阻塞管线
          }
        }
        // LLM 开启但模型未下载 → 跳过，不报错
      }

      // 步骤 4: 生成 Embedding (~200ms) — 如果有 embedding 模型且标签不为空
      if (embeddingService.isModelLoaded && (ocrTags.isNotEmpty || llmTags.isNotEmpty)) {
        final tagTexts = [
          ...ocrTags.map((t) => t.content),
          ...llmTags.map((t) => t.content),
          'color: ${colors.map((c) => c.hexColor).join(', ')}',
        ].join(' ');
        final vector = await embeddingService.encode(tagTexts);
        await embedRepo.upsert(Embedding(
          memeId: meme.id,
          modelId: embeddingService.currentModelId,
          vector: vector,
        ));
        stepsRun.add('embedding');
      }

      return AnalysisResult(
        memeId: meme.id,
        success: true,
        durationMs: stopwatch.elapsedMilliseconds,
        stepsRun: stepsRun,
        tagCount: ocrTags.length + llmTags.length,
        colorCount: colors.length,
      );
    } catch (e) {
      return AnalysisResult(
        memeId: meme.id,
        success: false,
        error: e.toString(),
      );
    }
  }
}
```

### 5.3 Meme 分析 Prompt

```dart
static const String _memeAnalysisPrompt = '''
[System] You are a meme analyzer. Describe this image concisely:
- What scene, characters, or template is shown
- What text appears in the image
- What emotion or tone it expresses
- What is the humor or point of this meme
Keep under 100 words. Write in Chinese.
''';
```

### 5.4 管线执行策略总结

| 管线步骤 | 颜色提取 | OCR | LLM 描述 | Embedding 向量化 |
|---------|---------|-----|----------|----------------|
| **执行条件** | 始终执行 | toggle 开启 + 可用 | toggle 开启 + 模型已下载 | embedding 模型已下载 + 标签不为空 |
| **失败处理** | 不适用（本地计算） | 跳过，不阻塞 | 跳过，不阻塞 | 跳过，不阻塞 |
| **无任何模型时** | ✅ 正常 | ❌ 跳过 | ❌ 跳过 | ❌ 跳过 |

---

## 6. 队列调度与后台处理

### 6.1 队列调度器

```dart
class AnalysisQueueScheduler {
  static const int maxConcurrent = 2;
  static const Duration pollInterval = Duration(seconds: 3);

  final Set<String> _runningJobs = {};
  bool _isRunning = false;

  Future<void> start() async {
    _isRunning = true;
    while (_isRunning) {
      await _processNextBatch();
      await Future.delayed(pollInterval);
    }
  }

  void stop() => _isRunning = false;

  Future<void> _processNextBatch() async {
    if (_runningJobs.length >= maxConcurrent) return;

    final jobs = await analysisQueueDao.pollNextJobs(
      limit: maxConcurrent - _runningJobs.length,
    );

    for (final job in jobs) {
      _runningJobs.add(job.id);
      await analysisQueueDao.markRunning(job.id);
      _spawnIsolate(job);
    }
  }

  void _spawnAnalysisIsolate(AnalysisJob job) {
    Isolate.spawn((SendPort sendPort) {
      // 在 isolate 中执行分析
      // 通过 SendPort 发回进度
    }, mainIsolateReceivePort.sendPort);
  }
}
```

### 6.2 Isolate 间通信

```dart
// 主 Isolate
final receivePort = ReceivePort();
receivePort.listen((message) {
  if (message is AnalysisProgress) {
    // 更新 UI 进度（通过 Riverpod）
    ref.read(analysisProgressProvider.notifier).update(message);
  } else if (message is AnalysisCompleted) {
    // 分析完成，刷新列表
    ref.read(memeListProvider.notifier).refresh();
  }
});

// 后台 Isolate
void _runAnalysis(AnalysisJob job, SendPort sendPort) async {
  sendPort.send(AnalysisProgress(memeId: job.memeId, step: 'color'));
  // ...
  sendPort.send(AnalysisCompleted(memeId: job.memeId, success: true));
}
```

### 6.3 Workmanager 后台注册

```dart
// Android 后台周期性唤醒
@pragma('vm:entry-point')
void analysisCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    final scheduler = AnalysisQueueScheduler(/* 依赖注入 */);
    await scheduler.processBatchOnce();  // 只处理一批就退出
    return Future.value(true);
  });
}

// 在 main 中注册
WidgetsFlutterBinding.ensureInitialized();
await Workmanager().registerPeriodicTask(
  'meme-analysis',
  'periodicAnalysis',
  frequency: Duration(minutes: 15),
  constraints: Constraints(
    networkType: NetworkType.not_required,  // 不需要网络
    requiresBatteryNotLow: true,
  ),
);
```
