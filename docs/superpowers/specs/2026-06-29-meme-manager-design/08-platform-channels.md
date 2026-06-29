# MemeHelper 平台通道 API 契约

> 所属项目: MemeHelper
> 文档编号: 08-platform-channels.md
> 用途: Flutter ↔ Android Native 之间的 MethodChannel 接口定义

---

## 1. 概述

MemeHelper 需要 3 个平台通道与 Android 原生层通信：

| Channel | 用途 | 方向 |
|---------|------|------|
| `meme_helper/ocr` | 调用 ML Kit 进行端侧 OCR | Flutter → Native |
| `meme_helper/file_picker` | 调用系统文件选择器（SAF） | Flutter → Native |
| `meme_helper/app_lifecycle` | 获取 App 生命周期事件（可选） | Native → Flutter |

llama.cpp 的直接通过 Dart FFI 调用 `.so`，不需要平台通道。

---

## 2. OCR Channel

### 2.1 Channel 名称

```
meme_helper/ocr
```

### 2.2 方法: recognizeText

```yaml
方法名: recognizeText

参数:
  imagePath:
    类型: String
    必填: true
    说明: Android 文件系统上的绝对路径
    示例: "/data/data/com.memehelper.app/files/memes/2026/06/xxx.png"

  languages:
    类型: List<String>
    必填: false
    默认: ["zh", "en"]
    说明: 识别语言列表，按优先级排序

返回值 (成功):
  类型: Map<String, dynamic>
  结构:
    blocks: [
      {
        text: "我太难了",               # 识别文字
        confidence: 0.95,              # 置信度 0.0 ~ 1.0
        left: 100,                     # 边界框 (像素)
        top: 200,
        width: 300,
        height: 50,
        language: "zh"                 # 检测到的语言
      },
      ...
    ]
    fullText: "我太难了\n真的"          # 完整拼接文本

错误码:
  OCR_ERROR:       识别过程出错（图片损坏、格式不支持）
  PERMISSION_ERROR: 无文件读取权限
  MODEL_NOT_READY:  ML Kit 模型未就绪（首次需要下载）

调用示例:
  final result = await _channel.invokeMethod('recognizeText', {
    'imagePath': '/path/to/meme.png',
    'languages': ['zh', 'en'],
  });
```

### 2.3 Android 端实现契约

```kotlin
// android/app/src/main/kotlin/.../OcrPlugin.kt
class OcrPlugin : FlutterPlugin, MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "recognizeText" -> handleRecognizeText(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleRecognizeText(call: MethodCall, result: Result) {
        val imagePath = call.argument<String>("imagePath")
            ?: return result.error("INVALID_ARGS", "imagePath required", null)

        val languages = call.argument<List<String>>("languages") ?: listOf("zh", "en")

        // 1. 创建 InputImage
        val inputImage: InputImage
        try {
            inputImage = InputImage.fromFilePath(context, imagePath)
        } catch (e: Exception) {
            return result.error("OCR_ERROR", "无法读取图片: ${e.message}", null)
        }

        // 2. 配置 Recognizer
        val options = ChineseTextRecognizerOptions.Builder().build()
        val recognizer = TextRecognition.getClient(options)

        // 3. 执行识别
        recognizer.process(inputImage)
            .addOnSuccessListener { visionText ->
                val blocks = visionText.textBlocks.map { block ->
                    val box = block.boundingBox
                    mapOf(
                        "text" to block.text,
                        "confidence" to (block.confidence ?: 0.0),
                        "left" to box?.left,
                        "top" to box?.top,
                        "width" to box?.width(),
                        "height" to box?.height(),
                        "language" to block.recognizedLanguages.firstOrNull()?.languageCode ?: "unknown"
                    )
                }
                result.success(mapOf(
                    "blocks" to blocks,
                    "fullText" to visionText.text
                ))
            }
            .addOnFailureListener { e ->
                result.error("OCR_ERROR", e.message, null)
            }
    }
}
```

---

## 3. 文件选择器 Channel

### 3.1 Channel 名称

```
meme_helper/file_picker
```

### 3.2 方法: pickImages

```yaml
方法名: pickImages

参数:
  allowMultiple:
    类型: bool
    必填: false
    默认: true
    说明: 是否允许多选

  mimeTypes:
    类型: List<String>
    必填: false
    默认: ["image/png", "image/jpeg", "image/gif", "image/webp"]
    说明: 允许的文件类型

返回值 (成功):
  类型: List<Map<String, dynamic>>
  结构:
    [
      {
        uri: "content://media/external/images/media/123",
        path: "/storage/emulated/0/DCIM/Camera/meme.jpg",
        displayName: "meme.jpg",
        mimeType: "image/jpeg",
        size: 255432
      },
      ...
    ]

错误码:
  USER_CANCELLED: 用户取消了选择
  PICKER_ERROR:   选择器打开失败

调用示例:
  final files = await _channel.invokeMethod('pickImages', {
    'allowMultiple': true,
    'mimeTypes': ['image/png', 'image/jpeg'],
  });
```

### 3.3 方法: pickZip

```yaml
方法名: pickZip

参数: 无

返回值 (成功):
  类型: Map<String, dynamic>
  结构:
    {
      uri: "content://com.android.externalstorage/doc/home/memes.zip",
      path: "/storage/emulated/0/Download/memes.zip",
      displayName: "memes.zip",
      size: 5242880
    }

错误码:
  USER_CANCELLED: 用户取消了选择
  PICKER_ERROR:   选择器打开失败
```

### 3.4 方法: pickDirectory

```yaml
方法名: pickDirectory

参数: 无

返回值 (成功):
  类型: Map<String, dynamic>
  结构:
    {
      uri: "content://com.android.externalstorage/doc/home/memes",
      path: "/storage/emulated/0/memes",
      displayName: "memes"
    }

错误码:
  USER_CANCELLED: 用户取消了选择

说明:
  返回目录 URI 后，Android 端需要递归遍历目录下所有图片文件，
  通过另一个方法返回文件列表。
```

### 3.5 方法: listDirectoryContents

```yaml
方法名: listDirectoryContents

参数:
  dirUri:
    类型: String
    必填: true
    说明: pickDirectory 返回的 URI
    示例: "content://com.android.externalstorage/doc/home/memes"

  recursive:
    类型: bool
    必填: false
    默认: true
    说明: 是否递归子目录

返回值:
  类型: List<Map<String, dynamic>>
  结构: 同 pickImages 的文件列表
  说明: 包含所有子目录中的图片文件

错误码:
  PERMISSION_ERROR: 无目录读取权限
  IO_ERROR:         读取目录失败
```

### 3.6 Android 端实现契约（SAF 方式）

```kotlin
class FilePickerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "pickImages" -> {
                pendingResult = result
                val intent = Intent(Intent.ACTION_PICK).apply {
                    type = "image/*"
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                }
                activity?.startActivityForResult(intent, REQUEST_PICK_IMAGES)
            }
            "pickZip" -> {
                pendingResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    type = "application/zip"
                }
                activity?.startActivityForResult(intent, REQUEST_PICK_ZIP)
            }
            else -> result.notImplemented()
        }
    }

    // 在 onActivityResult 中处理返回
    // 将 content:// URI 转换为可读路径
    private fun resolvePath(uri: Uri): String? {
        // 使用 ContentResolver + OpenableColumns 获取路径
        // 对于 content:// URI，可能需要复制到缓存目录获取真实路径
    }
}
```

---

## 4. llama.cpp 本地调用（非 Channel）

llama.cpp **不走 MethodChannel**，而是通过 Dart FFI 直接加载 `.so`。

### 4.1 .so 文件位置

```
android/app/src/main/jniLibs/
└── arm64-v8a/
    ├── libllama.so          # 核心推理
    ├── libggml.so           # 张量计算
    └── libggml-base.so      # 基础运算
```

### 4.2 Dart FFI 接口签名

```dart
// dart:ffi 绑定的 C 函数签名（已包含在 03-llm-pipeline.md 中）
// 此处为参考汇总

// 模型生命周期
void* llama_model_load(const char* model_path, int n_ctx);
void  llama_model_free(void* model);

// 文本生成
char* llama_eval(void* model, const char* prompt, int n_threads);

// Embedding
void  llama_embed(void* model, const char* text, float* out, int n_threads);

// 多模态
char* llama_eval_with_image(void* model, const char* image_path,
                             const char* prompt, int n_threads);

// 工具
int   llama_n_embd(void* model);     // 返回 embedding 维度
void  llama_free_str(char* str);      // 释放 C 字符串
```

### 4.3 无需额外 Channel 的理由

| 能力 | 方式 | 理由 |
|------|------|------|
| 模型加载 | dart:ffi | 纯 CPU 计算，不涉及 Android API |
| 推理执行 | dart:ffi | 无 UI 交互，不涉及生命周期 |
| 模型下载 | Flutter HTTP | 纯 Dart 实现，无需原生代码 |
| 文件路径传递 | Dart IO | 路径是标准文件系统路径 |

---

## 5. 生命周期 Channel（可选）

### 5.1 Channel 名称

```
meme_helper/lifecycle
```

### 5.2 事件: appLifecycleChanged

```yaml
事件名: appLifecycleChanged

参数（Native → Flutter）:
  state:
    类型: String
    可选值:
      - "background"   # App 进入后台
      - "foreground"   # App 回到前台
      - "memory_warning"  # 系统内存不足

用途:
  - 进入后台: 暂停分析队列中的非关键任务
  - 回到前台: 恢复暂停的分析队列
  - 内存警告: 主动卸载未使用的 LLM 模型
```

---

## 6. 错误码汇总

| Channel | 错误码 | 含义 | Flutter 端处理 |
|---------|--------|------|---------------|
| ocr | `OCR_ERROR` | OCR 识别失败 | 跳过 OCR 步骤，继续其他分析 |
| ocr | `PERMISSION_ERROR` | 无图片读取权限 | 提示用户授权 |
| ocr | `MODEL_NOT_READY` | ML Kit 模型未就绪 | 等待后重试 |
| file_picker | `USER_CANCELLED` | 用户取消了选择 | 无操作，返回空列表 |
| file_picker | `PICKER_ERROR` | 打开文件选择器失败 | 显示错误 Toast |
| file_picker | `PERMISSION_ERROR` | 无目录权限 | 引导用户授予权限 |
| file_picker | `IO_ERROR` | 读取文件/目录失败 | 提示文件可能已被移动 |

---

## 7. 开发与测试

### 7.1 模拟平台通道（单元测试）

```dart
// test/core/ocr/ocr_service_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrService', () {
    late OcrService service;

    setUp(() {
      service = OcrService();

      // 模拟平台通道返回值
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        service.channel,
        (MethodCall call) async {
          if (call.method == 'recognizeText') {
            return {
              'blocks': [
                {'text': '我太难了', 'confidence': 0.95},
              ],
              'fullText': '我太难了',
            };
          }
          return null;
        },
      );
    });

    test('OCR 识别返回正确格式', () async {
      final results = await service.recognize('/fake/path.png');
      expect(results.length, 1);
      expect(results.first.text, '我太难了');
    });
  });
}
```

### 7.2 Android 端单元测试

```kotlin
// android/app/src/test/kotlin/.../OcrPluginTest.kt
class OcrPluginTest {
    @Test
    fun `recognizeText 返回正确结构`() {
        // 使用 Robolectric 模拟 Android 环境
        // mock InputImage 和 TextRecognizer
        // 验证返回值包含 blocks 和 fullText
    }
}
```
