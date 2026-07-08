# 原生 LLM 推理实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 抛弃 llamafu，用极简 C 封装直接调用 llama.cpp C API，编译到 Android APK 中。

**Architecture:** 写一个 ~200 行的 meme_llm.c 封装层暴露 4 个函数（init/complete/multimodal_complete/close），通过 Dart FFI 调用。CMake 直接编译 llama.cpp 源码。

**Tech Stack:** C (llama.h + mtmd.h API), Dart FFI, CMake/NDK, Flutter

---

## Chunk 1: 准备 llama.cpp 源码

### Task 1: 解压 llama.cpp 并配置 .gitignore

**Files:**
- External: `llama.cpp/` (项目根目录)
- Modify: `.gitignore`

- [ ] **Step 1: 解压 llama.cpp-master.zip 到项目根目录**

```bash
unzip -q <DOWNLOADS>/llama.cpp-master.zip -d <REPO_ROOT>/
mv <REPO_ROOT>/llama.cpp-master <REPO_ROOT>/llama.cpp
```

- [ ] **Step 2: 验证 llama.cpp/CMakeLists.txt 存在**

- [ ] **Step 3: 添加 llama.cpp/ 到 .gitignore**

在 `.gitignore` 末尾添加：
```
# llama.cpp 源码（外部依赖，不提交）
llama.cpp/
```

---

## Chunk 2: C 封装层

### Task 2: 创建 meme_llm.h

**Files:**
- Create: `android/app/src/main/cpp/meme_llm.h`

- [ ] **Step 1: 创建头文件**

```c
#ifndef MEME_LLM_H
#define MEME_LLM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 初始化：加载模型 + 可选 mmproj
// 返回 opaque handle，失败返回 NULL
void* mllm_init(const char* model_path,
                const char* mmproj_path,
                int n_threads,
                int n_ctx);

// 纯文本补全
// 返回生成的文本（调用方须 mllm_free_string 释放），失败返回 NULL
char* mllm_complete(void* handle,
                    const char* prompt,
                    int max_tokens,
                    float temperature);

// 多模态补全（文本 + 图片）
// image_data: RGB 像素数据
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

// 释放 mllm_complete / mllm_multimodal_complete 返回的字符串
void mllm_free_string(char* str);

#ifdef __cplusplus
}
#endif

#endif // MEME_LLM_H
```

### Task 3: 创建 meme_llm.c

**Files:**
- Create: `android/app/src/main/cpp/meme_llm.c`

- [ ] **Step 1: 创建 C 实现文件**

关键 llama.cpp API 调用：
- `llama_backend_init()` / `llama_backend_free()`
- `llama_model_load_from_file()` / `llama_model_free()`
- `llama_init_from_model()` / `llama_free()`
- `llama_model_default_params()` / `llama_context_default_params()`
- `llama_sampler_chain_init()` / `llama_sampler_chain_add()` / `llama_sampler_free()`
- `llama_sampler_init_temp()` / `llama_sampler_init_dist()`
- `llama_tokenize()` / `llama_token_to_piece()`
- `llama_batch_get_one()` / `llama_batch_free()`
- `llama_decode()` / `llama_sampler_sample()` / `llama_sampler_accept()`
- `llama_vocab_is_eog()` / `llama_model_get_vocab()`
- `mtmd_init_from_file()` / `mtmd_free()` / `mtmd_tokenize()` / `mtmd_encode_chunk()`
- `mtmd_bitmap_init()` / `mtmd_bitmap_free()`
- `mtmd_input_chunks_init()` / `mtmd_input_chunks_free()`
- `mtmd_input_chunk_get_type()` / `mtmd_input_chunk_get_tokens_text()`

---

## Chunk 3: CMake + Gradle 构建

### Task 4: 创建 CMakeLists.txt

**Files:**
- Create: `android/app/src/main/cpp/CMakeLists.txt`

### Task 5: 修改 build.gradle.kts

**Files:**
- Modify: `android/app/build.gradle.kts`

- [ ] **Step 1: 添加 externalNativeBuild 配置**

在 `android {}` 块中添加 CMake 配置，指定 LLAMA_CPP_DIR 路径。

---

## Chunk 4: Dart 侧

### Task 6: 创建 native_bindings.dart

**Files:**
- Create: `lib/core/llm/native_bindings.dart`

### Task 7: 修改 local_service.dart

**Files:**
- Modify: `lib/core/llm/local_service.dart`

- [ ] **Step 1: 替换 llamafu import 为 native_bindings**
- [ ] **Step 2: 替换 Llamafu engine 为 Pointer<Void> handle**
- [ ] **Step 3: 重写 _ensureLoaded / complete / chat / dispose**

### Task 8: 修改 pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 移除 llamafu 依赖**

---

## Chunk 5: 构建验证

### Task 9: 构建 release APK

- [ ] **Step 1: flutter build apk --release**
- [ ] **Step 2: 验证 APK 中包含 libmeme_llm.so**
- [ ] **Step 3: 检查 APK 大小变化**
