# macOS Tesseract OCR 打包方案设计

**日期**: 2026-07-18
**状态**: 设计完成
**负责人**: MemeHelper 团队

## 背景

MemeHelper 在 Android/iOS 上使用 Google ML Kit 进行 OCR，在 Linux 上已实现从源码构建 Tesseract 动态库。macOS 目前依赖 Homebrew 安装的 Tesseract CLI，这对用户造成不便：

- **问题**: macOS 用户必须手动运行 `brew install tesseract tesseract-lang`
- **约束1**: 用户不应需要手动安装 Tesseract
- **约束2**: 不需要 admin/sudo 权限
- **约束3**: `flutter build macos --release` 后即可直接运行
- **约束4**: App Store 分发可能有额外要求

## 现有架构分析

### 当前 OCR 架构

```
OcrService (平台分发)
├── Android/iOS → _MlKitOcrService (google_mlkit_text_recognition)
├── Linux       → _LinuxOcrService (tesseract CLI) [typedef to _MacOSOcrService]
├── macOS       → _MacOSOcrService (tesseract CLI)  [typedef to _LinuxOcrService]
└── Windows     → _WindowsOcrService (tesseract CLI)
```

### 已有 Tesseract FFI 实现

项目已有完整的 Tesseract C API 封装 (`linux/cpp/tesseract_ocr.cpp/.h`)，但当前 macOS 实现并未使用，仍通过 CLI 调用：

```cpp
// linux/cpp/tesseract_ocr.h - 现有 C API
void* tess_create();
int tess_init(void* handle, const char* datapath, const char* language);
int tess_set_image_file(void* handle, const char* filename);
char* tess_get_utf8_text(void* handle);
void tess_free_text(char* text);
const char* tess_version();
```

## 四种方案对比

### Option A: 使用 Homebrew Tesseract dylib

**描述**: 提取 Homebrew 安装的 Tesseract 动态库，随 app 打包

**优点**:
- 无需从源码编译，节省 CI 时间
- 简单直接

**缺点**:
- Homebrew 路径不固定（Intel Mac: `/usr/local/lib/`，Apple Silicon: `/opt/homebrew/lib/`）
- Homebrew 库可能依赖系统库，跨机器兼容性差
- 用户必须先安装 Homebrew 才能获取 dylib
- App Store 审核可能拒绝包含 Homebrew 库的应用
- **违反约束**: 用户仍需先安装 Homebrew

**结论**: ❌ 不可行

---

### Option B: 从源码构建 Tesseract 共享库

**描述**: 仿照 Linux 方案，在 CI 中从源码构建 Tesseract + Leptonica 为 macOS dylib

**优点**:
- 完全自包含，无需用户手动安装
- 与 Linux 实现一致，便于维护
- 不依赖 Homebrew
- 兼容 App Store 分发要求

**缺点**:
- 首次构建时间较长（~5-10 分钟）
- 需要在 CI 中构建两个库（Tesseract + Leptonica）
- Leptonica 依赖的 PNG/JPEG/TIFF 库需要处理

**实现复杂度**: 中等

**结论**: ✅ 推荐

---

### Option C: flusseract 包

**描述**: 使用 `flusseract` Flutter 插件

**优点**:
- 封装良好，使用简单

**缺点**:
- GitHub issues 报告大量 macOS 构建问题
- 首次构建约 10 分钟
- 依赖系统已安装 Tesseract（不解决核心问题）
- 可能与项目现有 FFI 实现冲突

**结论**: ❌ 不推荐

---

### Option D: 系统 Tesseract 检测 + 改进 UX

**描述**: 检测系统 Tesseract，未安装时提供更好的提示

**优点**:
- 实现简单

**缺点**:
- **违反核心约束**: 用户仍需手动安装 Tesseract

**结论**: ❌ 不满足需求

---

## 推荐方案: Option B

### 实现策略

1. **克隆 Tesseract + Leptonica** 到 `third_party/` 目录
2. **构建为共享库** (`libtesseract.dylib`, `libleptonica.dylib`)
3. **修改 macOS CMakeLists.txt** 添加 Tesseract/Leptonica 子项目
4. **App Bundle 配置** 将 dylib 复制到 `Contents/Frameworks/`
5. **Dart FFI 绑定** 复用现有的 `tesseract_ocr.h` 接口

### 与 Linux 实现对比

| 项目 | Linux | macOS |
|------|-------|-------|
| 构建工具 | CMake + pkg-config | CMake + find_library |
| GPU 后端 | Vulkan/OpenCL | Metal (LLM) |
| OCR 库 | libtesseract.so | libtesseract.dylib |
| 安装路径 | `@rpath` | `@executable_path/../Frameworks` |
| 系统检测 | `pkg_check_modules` | `find_library` |

### 构建依赖关系

```
libtesseract.dylib
├── libleptonica.dylib
│   └── libpng, libjpeg, libtiff (系统库)
└── libarchive, libwebp (Leptonica 依赖)
```

### 语言数据文件

Tesseract 需要语言数据文件 (`.traineddata`):
- 位置: `tessdata/` 目录
- 建议: 打包 `chi_sim.traineddata` + `eng.traineddata` 到 `Contents/Resources/`
- 下载: https://github.com/tesseract-ocr/tessdata

---

## 实现步骤

### 步骤 1: 更新 `scripts/init-third-party.sh`

添加 Tesseract 和 Leptonica 的克隆逻辑（macOS 平台）：

```bash
# 在 DEPS 数组中添加:
"Tesseract|https://github.com/tesseract-ocr/tesseract.git||tesseract"
"Leptonica|https://github.com/DanBloomberg/leptonica.git||leptonica"
```

**注意**: Tesseract 5.x 使用 CMake 构建，与 Linux 一致。

### 步骤 2: 创建 `macos/cpp/tesseract_ocr.cpp`

复制 `linux/cpp/tesseract_ocr.cpp` 到 `macos/cpp/`，内容相同（纯 C API 封装）。

### 步骤 3: 更新 `macos/cpp/CMakeLists.txt`

添加 Tesseract/Leptonica 构建配置：

```cmake
# ===== Tesseract/Leptonica 配置 =====
option(ENABLE_TESSERACT "Enable Tesseract OCR" ON)

if(ENABLE_TESSERACT)
    # Leptonica 配置
    set(LEPTONICA_SYSTEM OFF)
    find_library(LEPTONICA_LIBRARY leptonica)
    if(NOT LEPTONICA_LIBRARY)
        set(LEPTONICA_SYSTEM OFF)
        message(STATUS "Building Leptonica from source")
    endif()

    # Tesseract 配置
    set(TESSERACT_SYSTEM OFF)
    find_library(TESSERACT_LIBRARY tesseract)
    if(NOT TESSERACT_LIBRARY)
        set(TESSERACT_SYSTEM OFF)
        message(STATUS "Building Tesseract from source")
    endif()

    # 从源码构建
    if(NOT TESSERACT_SYSTEM)
        # Leptonica 子项目
        add_subdirectory(${LEPTONICA_DIR} leptonica EXCLUDE_FROM_ALL)
        # Tesseract 子项目
        add_subdirectory(${TESSERACT_DIR} tesseract EXCLUDE_FROM_ALL)
    endif()
endif()
```

### 步骤 4: 配置 App Bundle

修改 Flutter macOS runner 的 `Debug/Release.entitlements` 或 `Info.plist` 确保 dylib 可加载：

```xml
<!-- MacOSX.entitlements -->
<key>com.apple.security.app-sandbox</key>
<false/>
```

**注意**: App Store 分发需要启用 Sandbox，此时 `@executable_path` 路径访问受限。

### 步骤 5: 语言数据打包

在 Flutter 构建后处理阶段复制语言文件：

```bash
# 复制到 App Bundle
cp third_party/tesseract/tessdata/chi_sim.traineddata \
   build/macos/Build/Products/Release/meme_master.app/Contents/Resources/
```

---

## 构建时间估算

| 组件 | 首次构建 | 增量构建 |
|------|----------|----------|
| Leptonica | ~1 min | ~10s |
| Tesseract | ~3 min | ~30s |
| meme_llm (Metal) | ~5 min | ~1 min |
| **总计** | **~9 min** | **~1.5 min** |

CI macOS runner (macos-latest) 规格：
- CPU: 3 GHz Apple Silicon (M1/M2/M3)
- RAM: 6 GB
- 构建并行度: 4

---

## 风险与缓解

### 风险 1: Leptonica 系统库依赖

**问题**: Leptonica 需要 libpng, libjpeg, libtiff 等系统库

**缓解**: 使用 Homebrew 的库，或在 CMake 中设置 `SYSTEM_LIBS=OFF`

### 风险 2: App Store 分发

**问题**: App Sandbox 环境下 dylib 加载限制

**缓解**:
- 将 dylib 放入 `Contents/Frameworks/`
- 使用 `@executable_path/../Frameworks/` 相对路径
- 如需严格沙盒，考虑内嵌资源方案

### 风险 3: Apple Silicon 与 Intel Mac 兼容

**问题**: 不同架构的 dylib 不兼容

**缓解**:
- CI 构建使用 `macos-latest` (Apple Silicon)
- 提供 Intel Mac 的 fat binary 或单独构建

---

## 替代方案：静态链接

如果动态库方案过于复杂，可考虑静态链接：

```cmake
# CMakeLists.txt
set(BUILD_SHARED_LIBS OFF)
set(Leptonica_BUILD_SHARED_LIBS OFF)
set(TESSERACT_BUILD_SHARED_LIBS OFF)
```

**优点**: 简化分发，避免 dylib 加载问题
**缺点**: 应用体积增大 (~50-100 MB)

---

## 结论

**推荐方案**: Option B - 从源码构建 Tesseract 共享库

**理由**:
1. 完全满足核心约束（用户无需手动安装）
2. 与 Linux 实现保持一致
3. 兼容 App Store 分发
4. 维护成本低

**后续步骤**:
1. 更新 `scripts/init-third-party.sh` 添加 Tesseract/Leptonica
2. 创建 `macos/cpp/tesseract_ocr.cpp`
3. 更新 `macos/cpp/CMakeLists.txt`
4. 在 CI 中验证构建
5. 测试语言文件打包
