# MemeMaster macOS 端口实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建 macOS 版本 MemeMaster，功能与 Linux 端完全对齐

**Architecture:** 基于 Flutter 多平台架构，通过 Platform 条件分支复用跨平台代码，新增 macOS 特定 C++ 原生层（Metal GPU 加速）

**Tech Stack:** Flutter, Dart FFI, llama.cpp (Metal), Tesseract CLI, super_clipboard

---

## Chunk 1: 项目初始化

### Files

- Create: `macos/` 目录结构（通过 flutter create 生成）
- Modify: `.gitignore`（如需要）

### Steps

- [ ] **Step 1: 生成 macOS 目录结构**

```bash
cd /home/jiangzifeng/Project/MemeHelper
flutter create --platforms=macos .
```

Expected: 创建 macos/, macos/Runner/, macos/Runner/CMakeLists.txt 等标准目录

- [ ] **Step 2: 验证 flutter 环境**

```bash
flutter doctor
```

Expected: macOS development 工具链可用

- [ ] **Step 3: 尝试构建空白 macOS 项目**

```bash
flutter build macos --debug
```

Expected: 构建成功（即使空白项目）

- [ ] **Step 4: 提交**

```bash
git add macos/ .gitignore
git commit -m "feat(macos): initial macOS project scaffold

- flutter create --platforms=macos
- verify build success"
```

---

## Chunk 2: 原生 LLM - C++ 层（Metal GPU）

### Files

- Create: `macos/cpp/CMakeLists.txt`
- Create: `macos/cpp/meme_llm.cpp`（从 linux/cpp/ 复制）
- Create: `macos/cpp/meme_llm.h`（从 linux/cpp/ 复制）

### Steps

- [ ] **Step 1: 创建 macos/cpp 目录**

```bash
mkdir -p macos/cpp
```

- [ ] **Step 2: 复制 meme_llm 源文件**

```bash
cp linux/cpp/meme_llm.cpp macos/cpp/
cp linux/cpp/meme_llm.h macos/cpp/
```

- [ ] **Step 3: 创建 macos/cpp/CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.22.1)
project(meme_llm C CXX)

set(CMAKE_BUILD_PARALLEL_LEVEL 4)

# ===== llama.cpp 路径配置 =====
if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/llama.cpp")
    endif()
endif()

# ===== Metal GPU 加速选项 =====
option(ENABLE_METAL "Enable Metal GPU acceleration (macOS only)" ON)

# ===== 检查 llama.cpp =====
if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_DIR}. Run ./scripts/init-third-party.sh first")
endif()

# ===== 静态库配置 =====
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS OFF)
set(GGML_STATIC ON)
set(LLAMA_STATIC ON)
set(GGML_SHARED OFF)
set(LLAMA_SHARED OFF)
set(LLAMA_BUILD_TESTS OFF)
set(LLAMA_BUILD_EXAMPLES OFF)
set(LLAMA_BUILD_SERVER OFF)
set(LLAMA_INSTALL_VERSION "0.0.0")

# ===== Metal 配置 =====
if(APPLE AND ENABLE_METAL)
    set(GGML_METAL ON)
    set(GGML_METAL_EMBED_LIBRARY ON)
    set(GGML_METAL_USE_BF16 ON)
    set(GGML_BLAS_DEFAULT ON)

    # 查找 Metal 框架
    find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
    find_library(METAL_FRAMEWORK Metal REQUIRED)
    find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
    find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)

    message(STATUS "Metal GPU acceleration enabled")
    message(STATUS "  GGML_METAL: ${GGML_METAL}")
    message(STATUS "  GGML_METAL_EMBED_LIBRARY: ${GGML_METAL_EMBED_LIBRARY}")
    message(STATUS "  Metal frameworks found: Foundation, Metal, MetalKit, Accelerate")
endif()

# ===== 添加子项目 =====
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)

# ===== 头文件路径 =====
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
)

# ===== 构建共享库 =====
add_library(meme_llm SHARED meme_llm.cpp)

# ===== 链接库 =====
set(MEME_LLM_LIBS llama ggml mtmd pthread dl m)

if(APPLE AND ENABLE_METAL)
    list(APPEND MEME_LLM_LIBS
        ${FOUNDATION_LIBRARY}
        ${METAL_FRAMEWORK}
        ${METALKIT_FRAMEWORK}
        ${ACCELERATE_FRAMEWORK}
    )
endif()

target_link_libraries(meme_llm PRIVATE ${MEME_LLM_LIBS})
target_link_options(meme_llm PRIVATE -Wl,-soname,libmeme_llm.so.1)

# ===== 安装规则 =====
install(TARGETS meme_llm LIBRARY DESTINATION lib COMPONENT runtime)
install(FILES meme_llm.cpp DESTINATION include COMPONENT headers RENAME meme_llm.h)

message(STATUS "=== meme_llm build configuration (macOS) ===")
message(STATUS "LLAMA_CPP_DIR: ${LLAMA_CPP_DIR}")
message(STATUS "ENABLE_METAL: ${ENABLE_METAL}")
message(STATUS "=================================================")
```

- [ ] **Step 4: 修改 macos/Runner/CMakeLists.txt 集成 cpp 构建**

检查并修改 `macos/Runner/CMakeLists.txt`，添加：

```cmake
# 在文件顶部添加
set(MACOS_LLM_DIR "${CMAKE_SOURCE_DIR}/../cpp")

# 在 add_subdirectory(runner) 之前添加
add_subdirectory(${MACOS_LLM_DIR} llm EXCLUDE_FROM_ALL)

# 在 target_link_libraries 中添加
target_link_libraries(meme_master PRIVATE meme_llm)
```

- [ ] **Step 5: 验证 CMake 配置**

```bash
cd /home/jiangzifeng/Project/MemeHelper
rm -rf build/macos
mkdir -p build/macos
cd build/macos

LLAMA_CPP_DIR=$HOME/Project/MemeHelper/third_party/llama.cpp \
cmake -DENABLE_METAL=ON ../macos 2>&1 | grep -E "(llama|Metal|ERROR)"
```

Expected: "llama.cpp found" + "Metal GPU acceleration enabled"

- [ ] **Step 6: 提交**

```bash
git add macos/cpp/
git commit -m "feat(macos): add llama.cpp C++ layer with Metal GPU support

- add macos/cpp/CMakeLists.txt with GGML_METAL enabled
- copy meme_llm.cpp and meme_llm.h from linux/cpp/
- integrate with macos/Runner/CMakeLists.txt"
```

---

## Chunk 3: 原生 LLM - Dart FFI 层

### Files

- Modify: `lib/core/llm/native_bindings.dart`

### Steps

- [ ] **Step 1: 修改 native_bindings.dart 添加 macOS 支持**

找到当前的库加载逻辑，添加 Platform.isMacOS 分支：

在文件开头的 import 后添加：
```dart
import 'dart:io' show Platform, DynamicLibrary;
```

找到 `DynamicLibrary.open('libmeme_llm.so')` 调用，修改为：

```dart
class NativeLlmBindings {
  DynamicLibrary? _dylib;

  NativeLlmBindings() {
    try {
      if (Platform.isLinux) {
        _dylib = DynamicLibrary.open('libmeme_llm.so');
      } else if (Platform.isMacOS) {
        _dylib = DynamicLibrary.open('libmeme_llm.dylib');
      } else if (Platform.isAndroid) {
        _dylib = DynamicLibrary.open('libmeme_llm.so');
      } else {
        throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
      }
      // ... 后续 lookupFunction 调用保持不变
    } catch (e) {
      // 加载失败时不抛异常，后续调用通过 mllmInit==null 判断不可用
    }
  }
```

- [ ] **Step 2: 验证修改语法**

```bash
cd /home/jiangzifeng/Project/MemeHelper
flutter analyze lib/core/llm/native_bindings.dart
```

Expected: 无错误

- [ ] **Step 3: 提交**

```bash
git add lib/core/llm/native_bindings.dart
git commit -m "feat(macos): add .dylib support in native_bindings.dart

- DynamicLibrary.open now handles macOS .dylib extension
- follows existing Platform.isLinux pattern"
```

---

## Chunk 4: OCR 支持（Tesseract CLI）

### Files

- Modify: `lib/core/ocr/ocr_service.dart`

### Steps

- [ ] **Step 1: 修改 ocr_service.dart 添加 macOS 分支**

找到工厂构造函数，修改为：

```dart
factory OcrService() {
  if (Platform.isAndroid || Platform.isIOS) {
    return OcrService._(mlKitService: _MlKitOcrService());
  } else if (Platform.isLinux) {
    return OcrService._(linuxService: _LinuxOcrService());
  } else if (Platform.isMacOS) {
    // macOS 与 Linux 相同，使用 Tesseract CLI
    return OcrService._(macosService: _MacOSOcrService());
  } else {
    throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
  }
}
```

添加 `_MacOSOcrService` 类（可以直接复用 `_LinuxOcrService`，或创建新类但复用相同逻辑）：

由于 macOS Tesseract 与 Linux Tesseract 行为相同，最简单的方式是：

```dart
// 在文件末尾添加类型别名
typedef _MacOSOcrService = _LinuxOcrService;
```

- [ ] **Step 2: 添加 macOS Tesseract 检测方法**

在 `OcrService` 类中添加：

```dart
/// macOS: 检查 Tesseract 是否已安装
static Future<bool> macOSCheckInstalled() async {
  if (!Platform.isMacOS) return false;
  return _LinuxOcrService.isInstalled();
}

/// macOS: 后台检测 Tesseract
static void macOSCheckAndNotify() {
  if (!Platform.isMacOS) return;
  Future.microtask(() async {
    final installed = await _LinuxOcrService.isInstalled();
    if (!installed) {
      debugPrint('[macOS] Tesseract not found. To install run:');
      debugPrint('[macOS]   brew install tesseract tesseract-lang');
    }
  });
}
```

- [ ] **Step 3: 验证修改**

```bash
flutter analyze lib/core/ocr/ocr_service.dart
```

- [ ] **Step 4: 提交**

```bash
git add lib/core/ocr/ocr_service.dart
git commit -m "feat(macos): add Tesseract OCR support for macOS

- factory constructor adds Platform.isMacOS branch
- reuses _LinuxOcrService implementation (identical behavior)
- adds macOSCheckInstalled and macOSCheckAndNotify helpers"
```

---

## Chunk 5: 剪贴板支持（验证）

### Files

- 检查: `lib/services/clipboard_service.dart`

### Steps

- [ ] **Step 1: 检查 clipboard_service.dart**

```bash
grep -n "Platform.isMacOS" lib/services/clipboard_service.dart
```

Expected: 已有 `Platform.isMacOS` 分支，使用 super_clipboard

- [ ] **Step 2: 如果需要修改，进行修改**

如果 `Platform.isMacOS` 分支不存在或逻辑不正确，修改为：

```dart
// super_clipboard 跨平台实现，适用于 Linux/macOS/Windows
if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
  // 使用 super_clipboard
}
```

- [ ] **Step 3: 验证**

```bash
flutter analyze lib/services/clipboard_service.dart
```

- [ ] **Step 4: 提交（如有修改）**

```bash
git add lib/services/clipboard_service.dart
git commit -m "feat(macos): verify clipboard_service works on macOS"
```

---

## Chunk 6: 其他平台特定代码检查

### Files

- 检查: 多个文件中 Platform.isLinux 分支

### Steps

- [ ] **Step 1: 查找所有 Platform.isLinux 分支**

```bash
grep -rn "Platform.isLinux" lib/ --include="*.dart"
```

Expected: 应该在以下文件中：
- `lib/main.dart` - Tesseract 检测
- `lib/features/settings/settings_screen.dart` - Linux OCR 安装提示
- `lib/features/scan/scan_screen.dart` - Linux 特定目录处理

- [ ] **Step 2: 审查并修改必要的文件**

对于 `lib/main.dart` 中的 Tesseract 检测：
- 添加对应的 macOS 检测

对于 `lib/features/scan/scan_screen.dart`：
- macOS 也使用类似 Linux 的目录选择逻辑

对于 `lib/features/settings/settings_screen.dart`：
- Linux OCR 安装提示可能需要 macOS 版本

- [ ] **Step 3: 提交**

```bash
git add lib/main.dart lib/features/scan/scan_screen.dart lib/features/settings/settings_screen.dart
git commit -m "feat(macos): add macOS platform checks where needed"
```

---

## Chunk 7: 构建验证

### Steps

- [ ] **Step 1: 尝试完整构建**

```bash
cd /home/jiangzifeng/Project/MemeHelper
rm -rf build/macos

LLAMA_CPP_DIR=/home/jiangzifeng/Project/MemeHelper/third_party/llama.cpp \
flutter build macos --release 2>&1 | tail -50
```

Expected: 构建成功

- [ ] **Step 2: 验证产物**

```bash
ls -la build/macos/Build/Products/Release/meme_master
file build/macos/Build/Products/Release/meme_master
```

Expected: ELF/mach-o 可执行文件

- [ ] **Step 3: 检查 libmeme_llm.dylib**

```bash
find build/macos -name "libmeme_llm*" 2>/dev/null
ls -lh build/macos/Build/Products/Release/lib/libmeme_llm.dylib 2>/dev/null || echo "libmeme_llm.dylib location different"
```

Expected: libmeme_llm.dylib 存在，大小 ~57MB（Metal 版本）

- [ ] **Step 4: 验证 Metal 符号**

```bash
nm build/macos/Build/Products/Release/lib/libmeme_llm.dylib 2>/dev/null | grep ggml_metal | head -5
```

Expected: 有 ggml_metal 相关符号

- [ ] **Step 5: 提交构建产物验证**

```bash
git add -A
git commit -m "feat(macos): verify full build succeeds with Metal GPU support"
```

---

## Chunk 8: 文档更新

### Files

- Modify: `README.md`
- Modify: `docs/DEVELOPMENT.md`

### Steps

- [ ] **Step 1: 更新 README.md**

在 "Linux 桌面" 部分后添加 "macOS 桌面" 部分：

```markdown
### macOS 桌面

#### 系统依赖

```bash
# Xcode Command Line Tools（必须）
xcode-select --install

# Tesseract OCR（Homebrew）
brew install tesseract tesseract-lang leptonica
```

#### 构建

```bash
# 克隆并构建 C++ 原生依赖
./scripts/init-third-party.sh

# 构建 release 版本
flutter build macos --release
# 产物: build/macos/Build/Products/Release/meme_master
```

> **注意**: macOS OCR 使用 Tesseract CLI（`google_mlkit_text_recognition` 不可用于 macOS）。
> **GPU 加速**: macOS 使用 Metal GPU 加速（Apple Silicon M1+ 推荐）。
```

- [ ] **Step 2: 更新 docs/DEVELOPMENT.md**

在 "环境搭建" 部分添加 macOS 依赖：

```markdown
### 2.1 macOS 桌面依赖

```bash
# Xcode Command Line Tools
xcode-select --install

# Tesseract OCR
brew install tesseract tesseract-lang leptonica
```
```

在 "构建命令速查" 表添加：

```markdown
| macOS 桌面 (运行) | `flutter run -d macos` | — |
| macOS 桌面 (Metal GPU) | `flutter build macos --release` | `build/macos/Build/Products/Release/` |
```

在 "已知问题" 部分添加 macOS 相关问题：

```markdown
### macOS 构建：llama.cpp 找不到

**现象**：CMake 输出 "llama.cpp not found"

**解决**：运行 `./scripts/init-third-party.sh` 克隆依赖，并设置 `LLAMA_CPP_DIR` 环境变量。

### macOS Metal GPU 构建

**系统依赖**：
```bash
xcode-select --install
```

**构建命令**：
```bash
LLAMA_CPP_DIR=/path/to/project/third_party/llama.cpp \
flutter build macos --release
```
```

- [ ] **Step 3: 提交文档**

```bash
git add README.md docs/DEVELOPMENT.md
git commit -m "docs: add macOS build instructions and troubleshooting"
```

---

## 最终验证

### 构建验证

- [ ] `flutter build macos --release` 成功
- [ ] `build/macos/Build/Products/Release/meme_master` 存在
- [ ] `libmeme_llm.dylib` 存在（~57MB Metal 版本）

### 功能验证（需手动测试）

- [ ] 应用启动无崩溃
- [ ] 图片导入功能正常
- [ ] Tesseract OCR 能识别文字
- [ ] 本地 LLM 能加载模型（Metal GPU）
- [ ] 剪贴板复制/粘贴正常

---

## 提交历史

预期提交顺序：

1. `feat(macos): initial macOS project scaffold`
2. `feat(macos): add llama.cpp C++ layer with Metal GPU support`
3. `feat(macos): add .dylib support in native_bindings.dart`
4. `feat(macos): add Tesseract OCR support for macOS`
5. `feat(macos): verify clipboard_service works on macOS`
6. `feat(macos): add macOS platform checks where needed`
7. `feat(macos): verify full build succeeds with Metal GPU support`
8. `docs: add macOS build instructions and troubleshooting`
