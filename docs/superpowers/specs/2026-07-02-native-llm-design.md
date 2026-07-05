# 原生 LLM 推理：抛弃 llamafu，直接使用 llama.cpp

## 背景

`llamafu-0.1.0` 是一个 Flutter FFI 插件，封装 llama.cpp 为 Dart API。问题：
- 5 个月未更新，已不维护
- C++ 封装层与最新 llama.cpp API 不兼容（`llama_set_adapter_lora`、`clip_image_u8_init` 等函数已重命名/移除）
- 发布到 pub.dev 时不包含 llama.cpp submodule，需要用户自行提供源码
- 封装了大量本项目不需要的功能（LoRA、Grammar、Audio、Tool Calling 等）

## 方案

**极简 C 封装 + Dart FFI**：写一个 ~200 行的 C 封装层，只暴露本项目需要的 4 个函数，直接编译 llama.cpp 源码。

## 架构

```
┌─────────────────────────────────────┐
│     LocalLlmService (Dart)          │  现有接口，不变
├─────────────────────────────────────┤
│     NativeLlmBindings (Dart FFI)    │  新增 ~150 行
│     dart:ffi → libmeme_llm.so       │
├─────────────────────────────────────┤
│     meme_llm.h / meme_llm.c         │  新增 ~200 行
│     极简 C 封装，4 个导出函数         │
├─────────────────────────────────────┤
│     llama.cpp (C API)               │  外部源码
│     llama.h + mtmd.h                │
└─────────────────────────────────────┘
```

## C API 设计（meme_llm.h）

只暴露 4 个函数，结构体对外不透明：

```c
// 初始化：加载模型 + 可选 mmproj
// 返回 opaque handle，失败返回 NULL
void* mllm_init(const char* model_path,
                const char* mmproj_path,   // 可传 NULL
                int n_threads,
                int n_ctx);

// 纯文本补全
// 返回生成的文本（调用方须 mllm_free_string 释放），失败返回 NULL
char* mllm_complete(void* handle,
                    const char* prompt,
                    int max_tokens,
                    float temperature);

// 多模态补全（文本 + 图片）
// image_data: RGB 像素数据；image_data_size: 数据字节数
// image_width/height: 图片尺寸
// 返回生成的文本（调用方须 mllm_free_string 释放），失败返回 NULL
char* mllm_multimodal_complete(void* handle,
                               const char* prompt,
                               const unsigned char* image_data,
                               size_t image_data_size,
                               int image_width,
                               int image_height,
                               int max_tokens,
                               float temperature);

// 释放资源
void mllm_close(void* handle);

// 释放 mllm_complete/mllm_multimodal_complete 返回的字符串
void mllm_free_string(char* str);
```

**设计决策：**
- handle 不透明，Dart 侧只传 `Pointer<Void>`
- 图片用原始 RGB 像素传入，避免在 C 侧引入图片解码库
- 错误通过返回 NULL 表示（简单，不需要错误码枚举）
- 字符串所有权遵循 "谁分配谁释放" 原则

## C 实现要点（meme_llm.c）

内部持有 llama.cpp 的资源：

```c
typedef struct {
    struct llama_model*  model;
    struct llama_context* ctx;
    struct llama_sampler* sampler;
    struct llama_vocab*   vocab;
    mtmd_context*         mtmd_ctx;   // 多模态上下文，可选
} MllmHandle;
```

**mllm_init 实现流程：**
1. `llama_backend_init()`
2. `llama_model_load_from_file()` + `llama_model_default_params()`
3. `llama_init_from_model()` + `llama_context_default_params()`
4. 创建 sampler chain：`llama_sampler_chain_init()` → add temp → add dist
5. 如果 mmproj_path 非空：`mtmd_init_from_file()`

**mllm_complete 实现流程：**
1. tokenize prompt → `llama_vocab_tokenize()`
2. 创建 batch → `llama_batch_get_one()`
3. 循环 `llama_decode()` + `llama_sampler_sample()` + `llama_sampler_accept()`
4. 遇到 EOS 或达到 max_tokens 时停止
5. detokenize → 拼接结果字符串

**mllm_multimodal_complete 实现流程：**
1. 从 image_data 创建 `mtmd_bitmap`
2. `mtmd_tokenize()` → 得到 input_chunks
3. 对每个 chunk：如果是图片 chunk → `mtmd_encode_chunk()`；然后 `llama_decode()`
4. 后续同 mllm_complete 的 sample 循环

## Dart FFI 绑定（native_bindings.dart）

```dart
class NativeLlmBindings {
  final DynamicLibrary _dylib;

  NativeLlmBindings() : _dylib = DynamicLibrary.open('libmeme_llm.so');

  Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Int32, Int32)
      get mllmInit => _dylib.lookupFunction<...>('mllm_init');

  Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Int32, Float)
      get mllmComplete => _dylib.lookupFunction<...>('mllm_complete');

  // ... multimodal, close, freeString
}
```

## 修改 LocalLlmService

替换 `Llamafu` 为 `NativeLlmBindings`：

```dart
class LocalLlmService implements LlmService {
  final LocalLlmConfig _config;
  Pointer<Void>? _handle;

  // _ensureLoaded → mllmInit
  // complete/chat → mllmComplete / mllmMultimodalComplete
  // dispose → mllmClose
}
```

## CMake 构建配置

在 `android/app/` 下添加 CMakeLists.txt：

```cmake
cmake_minimum_required(VERSION 3.22.1)
project(meme_llm)

set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../llama.cpp")
# 或从环境变量读取

# 只编译 CPU 后端（Android ARM64）
set(GGML_STATIC ON)
set(LLAMA_STATIC ON)
set(LLAMA_BUILD_TESTS OFF)
set(LLAMA_BUILD_EXAMPLES OFF)
set(LLAMA_BUILD_SERVER OFF)

add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)

# 编译 mtmd（多模态）
add_subdirectory(${LLAMA_CPP_DIR}/tools/mtmd mtmd EXCLUDE_FROM_ALL)

add_library(meme_llm SHARED meme_llm.c)
target_include_directories(meme_llm PRIVATE
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/tools/mtmd
)
target_link_libraries(meme_llm llama ggml mtmd android log)
```

在 `android/app/build.gradle.kts` 中添加：

```kotlin
android {
    // ...
    defaultConfig {
        // ...
        externalNativeBuild {
            cmake {
                arguments += listOf("-DLLAMA_CPP_DIR=${System.getenv("LLAMA_CPP_DIR") ?: project.findProperty("llama.cpp.dir")?.toString() ?: "${project.rootDir}/../llama.cpp"}")
                cppFlags += listOf("-O3", "-DNDEBUG")
            }
        }
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}
```

## 文件清单

| 操作 | 文件 | 说明 |
|------|------|------|
| 新增 | `android/app/src/main/cpp/meme_llm.h` | C API 头文件 |
| 新增 | `android/app/src/main/cpp/meme_llm.c` | C 实现 |
| 新增 | `android/app/src/main/cpp/CMakeLists.txt` | CMake 构建 |
| 新增 | `lib/core/llm/native_bindings.dart` | Dart FFI 绑定 |
| 修改 | `android/app/build.gradle.kts` | 添加 externalNativeBuild |
| 修改 | `lib/core/llm/local_service.dart` | 替换 llamafu → native_bindings |
| 修改 | `pubspec.yaml` | 移除 llamafu 依赖 |
| 外部 | `llama.cpp/` | 项目根目录，从 zip 解压 |

## llama.cpp 源码管理

- 解压用户下载的 `llama.cpp-master.zip` 到项目根目录 `llama.cpp/`
- `.gitignore` 中添加 `llama.cpp/`（不提交到 git）
- 构建时通过 `LLAMA_CPP_DIR` 环境变量或 gradle property 指定路径

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| llama.cpp C API 未来变更 | 我们控制封装层，只需更新 meme_llm.c 适配 |
| 编译时间较长（首次 ~10 分钟） | 后续增量编译快；可加 Gradle 缓存 |
| APK 体积增加 | 只编译 CPU 后端 + ARM64，预计增加 3-5MB |
| mtmd API 标注为 experimental | 核心功能稳定，实验性标记是保守声明 |
