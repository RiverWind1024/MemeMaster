# MemeMaster macOS 端口设计文档

**日期**: 2026-07-10
**目标**: 构建 macOS 版本，功能与 Linux 端完全对齐
**策略**: 完整功能版（一次性完成所有功能）

---

## 一、现状分析

### 1.1 项目平台支持

| 平台 | 状态 | 分支 |
|------|-------|------|
| Linux | ✅ 已完成 | feat-linux-port |
| Android | ✅ 已完成 | master |
| macOS | ❌ 待开发 | feat-macos-port (新建) |

### 1.2 Linux 端功能清单

#### 跨平台功能（macOS 直接复用）
- 图片导入（SHA256 去重、日期归档）
- 颜色搜索（HSV 滑块、CIE Lab ΔE 色差）
- AI 标签与描述生成（OpenAI/Ollama/本地 LLM）
- Token 用量追踪与统计
- 用户统计页面（贡献日历、趋势图）
- S3 云同步（全量/增量，兼容 AWS S3/MinIO/Cloudflare R2）
- 配置导出/导入
- 国际化（中英文）
- 文件夹/相册管理
- 定时同步
- 日志查看器
- 模型管理

#### Linux 特定功能（macOS 需适配）
| 功能 | Linux 实现 | macOS 实现 |
|------|-----------|------------|
| OCR | Tesseract CLI | **Tesseract CLI**（相同） |
| 本地 LLM | Vulkan GPU + CPU | **Metal GPU + CPU** |
| 剪贴板 | super_clipboard | **super_clipboard**（相同） |
| FFI 库加载 | `.so` | **`.dylib`** |

### 1.3 关键技术差异

| 组件 | Linux | macOS |
|------|-------|-------|
| GPU 加速 | Vulkan | **Metal** |
| 库文件扩展名 | `.so` | **`.dylib`** |
| OCR | Tesseract CLI | Tesseract CLI |
| 原生 UI 框架 | GTK | Cocoa |
| 系统包管理 | DNF | Homebrew |

---

## 二、架构设计

### 2.1 目录结构

```
macos/
├── CMakeLists.txt              # Flutter macOS 主构建配置
├── Runner/
│   ├── CMakeLists.txt         # Runner 构建配置
│   ├── main.cc               # 应用入口
│   ├── AppDelegate.swift      # macOS 应用代理
│   └── Info.plist            # 应用配置
├── cpp/                       # C++ 原生代码
│   ├── CMakeLists.txt         # C++ 构建配置（Metal GPU）
│   ├── meme_llm.cpp          # 复用 linux/cpp/meme_llm.cpp
│   └── meme_llm.h            # 复用 linux/cpp/meme_llm.h
└── ...                       # 其他标准 macOS 目录
```

### 2.2 平台特定代码模式

项目已有平台分离模式，遵循相同模式：

```dart
// OCR 服务（ocr_service.dart）
factory OcrService() {
  if (Platform.isAndroid || Platform.isIOS) {
    return OcrService._(mlKitService: _MlKitOcrService());
  } else if (Platform.isLinux) {
    return OcrService._(linuxService: _LinuxOcrService());
  } else if (Platform.isMacOS) {           // ← 新增
    return OcrService._(macosService: _MacOSOcrService());  // Tesseract
  }
  throw UnsupportedError('不支持的平台');
}

// 本地 LLM FFI（native_bindings.dart）
DynamicLibrary openLibmemeLl() {
  if (Platform.isLinux) {
    return DynamicLibrary.open('libmeme_llm.so');
  } else if (Platform.isMacOS) {            // ← 新增
    return DynamicLibrary.open('libmeme_llm.dylib');
  }
  // ...
}
```

---

## 三、任务分解

### Phase 1: 项目初始化

- [ ] 1.1 从 feat-linux-port 创建新分支 `feat-macos-port`
- [ ] 1.2 生成 macOS 目录结构
  ```bash
  flutter create --platforms=macos .
  ```
- [ ] 1.3 验证空白 macOS 项目能编译

### Phase 2: 原生 LLM 支持

- [ ] 2.1 创建 `macos/cpp/CMakeLists.txt`
  - 启用 `GGML_METAL=ON`
  - 链接 Metal/MetalKit/Accelerate 框架
  - 复用 `linux/cpp/meme_llm.cpp`
- [ ] 2.2 修改 `native_bindings.dart`
  - 添加 `.dylib` 平台判断
- [ ] 2.3 验证 libmeme_llm.dylib 生成（~57MB Metal 版本）

### Phase 3: OCR 支持

- [ ] 3.1 修改 `ocr_service.dart`
  - 添加 `Platform.isMacOS` 分支
  - 复用 `_LinuxOcrService` 实现（Tesseract CLI）
- [ ] 3.2 添加 macOS Tesseract 安装检测

### Phase 4: 剪贴板支持

- [ ] 4.1 检查 `clipboard_service.dart`
  - 已有 `Platform.isMacOS` 分支（使用 super_clipboard）
  - 应可直接用

### Phase 5: 文档与验证

- [ ] 5.1 更新 README.md 添加 macOS 构建说明
- [ ] 5.2 更新 DEVELOPMENT.md 添加 macOS 构建步骤
- [ ] 5.3 验证完整功能构建

---

## 四、关键文件变更

### 4.1 新建文件

| 文件 | 说明 |
|------|------|
| `macos/CMakeLists.txt` | Flutter macOS 构建配置 |
| `macos/Runner/CMakeLists.txt` | Runner 构建配置 |
| `macos/cpp/CMakeLists.txt` | Metal GPU 构建配置 |
| `macos/cpp/meme_llm.cpp` | 复用 linux/cpp/（软链接或复制） |
| `macos/cpp/meme_llm.h` | 复用 linux/cpp/ |

### 4.2 修改文件

| 文件 | 修改内容 |
|------|----------|
| `lib/core/ocr/ocr_service.dart` | 添加 `Platform.isMacOS` 分支 |
| `lib/core/llm/native_bindings.dart` | 添加 `.dylib` 加载逻辑 |
| `pubspec.yaml` | 可能需要调整插件依赖 |
| `README.md` | 添加 macOS 构建说明 |
| `docs/DEVELOPMENT.md` | 添加 macOS 构建步骤 |

### 4.3 复用文件（不修改）

以下文件 macOS 直接复用，无需修改：
- `lib/features/*` - 全部跨平台 UI
- `lib/core/database/*` - Drift 数据库
- `lib/services/s3_sync_service.dart` - S3 同步
- `lib/services/search_service.dart` - 搜索服务

---

## 五、macOS Metal 构建配置

### 5.1 CMakeLists.txt 核心配置

```cmake
cmake_minimum_required(VERSION 3.22.1)
project(meme_llm C CXX)

# ===== llama.cpp 路径 =====
if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/llama.cpp")
    endif()
endif()

# ===== Metal GPU 加速 =====
option(ENABLE_METAL "Enable Metal GPU acceleration" ON)

# ===== 检查 llama.cpp =====
if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_DIR}")
endif()

# ===== 静态库配置 =====
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS OFF)
set(GGML_STATIC ON)
set(LLAMA_STATIC ON)

# ===== Metal 配置 =====
if(APPLE AND ENABLE_METAL)
    set(GGML_METAL ON)
    set(GGML_METAL_EMBED_LIBRARY ON)
    set(GGML_METAL_USE_BF16 ON)

    # 查找 Metal 框架
    find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
    find_library(METAL_FRAMEWORK Metal REQUIRED)
    find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
    find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)
endif()

# ===== 添加子项目 =====
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)

# ===== 构建共享库 =====
add_library(meme_llm SHARED meme_llm.cpp)
target_link_libraries(meme_llm PRIVATE
    llama ggml mtmd pthread dl m
    ${FOUNDATION_LIBRARY}
    ${METAL_FRAMEWORK}
    ${METALKIT_FRAMEWORK}
    ${ACCELERATE_FRAMEWORK}
)
```

### 5.2 系统依赖

```bash
# Xcode Command Line Tools（必须）
xcode-select --install

# Tesseract OCR（Homebrew）
brew install tesseract tesseract-langpack-chi_sim leptonica

# CMake（可选，已有系统版本）
brew install cmake
```

---

## 六、验证清单

### 6.1 构建验证

- [ ] `flutter build macos --release` 成功
- [ ] `build/macos/Build/Products/Release/meme_master` 生成
- [ ] `libmeme_llm.dylib` (~57MB Metal 版本) 存在

### 6.2 功能验证

- [ ] 应用启动无崩溃
- [ ] 图片导入功能正常
- [ ] 颜色搜索正常
- [ ] Tesseract OCR 能识别文字
- [ ] 本地 LLM 能加载模型（Metal GPU）
- [ ] 剪贴板复制/粘贴正常
- [ ] S3 同步功能正常

---

## 七、风险与注意事项

### 7.1 Apple Silicon vs Intel Mac

- **Apple Silicon (M1+)**: Metal 使用 simdgroup_matrix 加速，性能最优
- **Intel Mac**: Metal 通过 MoltenVK 运行，可能不如 CPU
- 建议在构建时自动检测，Intel Mac 可选禁用 Metal

### 7.2 macOS 版本要求

- **最低版本**: macOS 13.3 (Ventura)
- **原因**: Metal 完整功能需要此版本

### 7.3 Homebrew 依赖

- macOS 用户使用 Homebrew，需确保安装命令兼容
- Tesseract 语言包: `tesseract-langpack-chi_sim`

---

## 八、构建命令速查

```bash
# 1. 安装系统依赖
xcode-select --install
brew install tesseract tesseract-langpack-chi_sim

# 2. 创建分支
git checkout feat-linux-port
git checkout -b feat-macos-port

# 3. 生成 macOS 目录
flutter create --platforms=macos .

# 4. 添加原生代码
mkdir -p macos/cpp
cp linux/cpp/meme_llm.cpp macos/cpp/
cp linux/cpp/meme_llm.h macos/cpp/

# 5. 修改代码
# (见 4.2 节)

# 6. 构建
flutter build macos --release

# 7. 验证 Metal 符号
nm build/macos/Build/Products/Release/libmeme_llm.dylib | grep ggml_metal
```

---

## 九、里程碑

| 里程碑 | 内容 | 预期交付 |
|--------|------|----------|
| M1 | macOS 项目骨架可编译 | Day 1 |
| M2 | 原生 LLM Metal 支持 | Day 2 |
| M3 | OCR Tesseract 集成 | Day 2 |
| M4 | 功能验证通过 | Day 3 |
| M5 | 文档完善 | Day 3 |
