# MemeHelper 开发指南

## 目录

- [技术栈](#技术栈)
- [环境搭建](#环境搭建)
- [构建命令速查](#构建命令速查)
- [项目结构](#项目结构)
- [数据库](#数据库)
- [测试](#测试)
- [代码生成](#代码生成)
- [已知问题](#已知问题)

---

## 技术栈

| 层 | 技术 |
|---|---|
| UI 框架 | Flutter 3.x + Material 3 |
| 状态管理 | Riverpod 2.x (`flutter_riverpod`) |
| 路由 | go_router |
| 数据库 | Drift (SQLite ORM) |
| 图片处理 | `image` (Dart 原生编解码) |
| OCR | Google ML Kit Text Recognition |
| LLM | OpenAI / Ollama API |
| 对象存储 | MinIO SDK (S3 兼容) |
| 秘钥存储 | flutter_secure_storage |
| 测试 | flutter_test + mocktail |

---

## 环境搭建

### 1. Flutter SDK

确保 Flutter SDK ^3.12.0 已安装且 `flutter` 在 PATH 中。

```bash
flutter --version
```

### 2. Linux 桌面依赖

```bash
# 核心依赖
sudo dnf install clang ninja-build libsecret-devel gtk3-devel tesseract

# Vulkan GPU 加速（可选，用于本地 LLM）
sudo dnf install vulkan-loader glslc glslang
```

### 3. macOS 桌面依赖

```bash
# Xcode Command Line Tools
xcode-select --install

# macOS OCR 使用 Apple Vision Framework（系统内置，无需额外安装）
```

### 4. Android SDK

已配置在 `~/Software/android-sdk`，包含 platforms 33–36、build-tools、NDK 等。需设置环境变量：

```bash
export ANDROID_HOME="$HOME/Software/android-sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
```

### 4. 获取依赖

```bash
flutter pub get
```

### 5. 第三方 C++ 依赖（本地 LLM 需要）

如果需要本地 LLM 推理功能（包括 Vulkan GPU 加速），需要初始化第三方依赖：

```bash
# 克隆并构建 llama.cpp、SPIRV-Headers 等
./scripts/init-third-party.sh

# 构建完成后会输出类似：
# third_party/
# ├── llama.cpp/
# ├── SPIRV-Headers/
# └── spirv-headers-install/  ← CMake 会自动查找这个路径
```

---

## 构建命令速查

| 目标 | 命令 | 产物 |
|---|---|---|
| Linux 桌面 (调试) | `flutter build linux --debug` | `build/linux/x64/debug/bundle/meme_helper` |
| Linux 桌面 (运行) | `flutter run -d linux` | — |
| Linux 桌面 (Vulkan GPU) | 见下方「Linux GPU 构建」 | `build/linux/x64/release/bundle/` |
| macOS 桌面 (调试) | `flutter build macos --debug` | `build/macos/Build/Products/Debug/` |
| macOS 桌面 (运行) | `flutter run -d macos` | — |
| macOS 桌面 (Metal GPU) | 见下方「macOS GPU 构建」 | `build/macos/Build/Products/Release/` |
| Android APK (调试) | `flutter build apk --debug` | `build/app/outputs/flutter-apk/app-debug.apk` |
| Android APK (发布) | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android AAB | `flutter build appbundle` | `build/app/outputs/bundle/release/app-release.aab` |
| 安装到已连接设备 | `flutter install` | — |

### Linux GPU 构建

本地 LLM 使用 Vulkan GPU 加速需要特殊构建：

```bash
# 完整构建命令
rm -rf build/linux
SPIRV_HEADERS_DIR=/path/to/project/third_party/spirv-headers/install \
LLAMA_CPP_DIR=/path/to/project/third_party/llama.cpp \
ENABLE_VULKAN=ON \
flutter build linux --release

# 验证产物
ls -la build/linux/x64/release/bundle/lib/libmeme_llm.so
# 应该是 ~57MB（完整 Vulkan 版本），而不是 ~12KB（stub 版本）

# 验证 Vulkan 符号
nm build/linux/x64/release/bundle/lib/libmeme_llm.so | grep ggml_vulkan
```

**CPU-only 版本构建**（无 GPU 加速）：
```bash
rm -rf build/linux
flutter build linux --release
# 会生成 libmeme_llm_empty.so（stub 版本）
```

### macOS GPU 构建

macOS 本地 LLM 使用 Metal GPU 加速（Apple Silicon M1+ 推荐）：

```bash
# 1. 先构建 C++ 原生库
./scripts/build-macos-llm.sh

# 2. 然后构建 Flutter 应用
flutter build macos --release

# 验证产物
ls -la build/macos/Build/Products/Release/meme_master
ls -la build/macos/Build/Products/Release/lib/libmeme_llm.dylib

# 验证 Metal 符号
nm build/macos/Build/Products/Release/lib/libmeme_llm.dylib | grep ggml_metal
```

---

## 项目结构

```
lib/
├── main.dart                  # 应用入口
├── app.dart                   # MaterialApp + Riverpod ProviderScope
├── router.dart                # GoRouter 路由配置
│
├── core/                      # 核心逻辑（无 UI 依赖）
│   ├── database/              # Drift 数据库
│   │   ├── database.dart      # 数据库定义
│   │   ├── database.g.dart    # 生成代码
│   │   ├── tables/            # 表定义
│   │   └── daos/              # DAO
│   ├── llm/                   # LLM 客户端
│   │   ├── config.dart        # LLM 配置
│   │   ├── models.dart        # 请求/响应模型
│   │   ├── llm_service.dart   # 抽象接口
│   │   ├── openai_service.dart # OpenAI 实现
│   │   ├── ollama_service.dart # Ollama 实现
│   │   └── enricher.dart      # 标签/描述生成器
│   ├── image/
│   │   └── color_extractor.dart # 主色调提取（K-Means）
│   ├── models/                # 领域模型 (freezed)
│   ├── ocr/
│   │   └── ocr_service.dart   # Google ML Kit OCR
│   ├── repositories/          # 仓储层
│   └── utils/
│       └── color_utils.dart   # RGB ↔ Lab / ΔE 色差
│
├── services/                  # 应用服务
│   ├── import_service.dart    # 图片导入（去重 + 哈希）
│   ├── file_storage_service.dart # 文件存储管理
│   ├── analysis_queue_scheduler.dart # 分析管线调度
│   ├── search_service.dart    # 颜色搜索
│   ├── s3_config.dart         # S3 配置模型
│   └── s3_sync_service.dart   # S3 同步服务
│
├── features/                  # UI 页面
│   ├── gallery/               # 图库（网格 + 详情）
│   ├── import/                # 导入页
│   ├── search/                # 颜色搜索页（HSV 滑块）
│   ├── folders/               # 文件夹管理
│   ├── settings/              # 设置页
│   └── sync/                  # 同步页（TODO）
│
└── router/                    # 路由组件（空）
```

---

## 数据库

使用 Drift (SQLite ORM)，数据库定义在 `lib/core/database/database.dart`。

### 表结构

| 表 | 说明 |
|---|---|
| `memes` | 图片元数据（文件名、路径、尺寸、哈希、分析状态） |
| `tags` | 标签（来源：OCR / LLM / 手动） |
| `colors` | 主色调（Lab 值 + 比例） |
| `folders` | 文件夹 |
| `folder_memes` | 文件夹 - 图片关联 |
| `analysis_queue` | 分析队列 |

### 修改表结构

1. 修改 `lib/core/database/tables/` 下的表定义
2. 运行代码生成 → 见下方「代码生成」

---

## 测试

### 测试框架

- **flutter_test** — 官方测试框架
- **mocktail** — 模拟依赖

### 运行测试

```bash
flutter test                    # 全部测试
flutter test test/services/     # 某个目录
flutter test --coverage         # 带覆盖率
```

### 现有测试 (44 个)

```
test/
├── core/
│   ├── llm/
│   │   ├── models_test.dart       # LlmOptions/LlmMessage/Request/Response JSON 序列化
│   │   └── enricher_test.dart     # LlmEnricher enrich 流程（mock LLM 服务）
│   └── utils/
│       └── color_utils_test.dart  # ColorRgb/fromHex/rgbToLab/deltaE
├── services/
│   ├── s3_config_test.dart        # S3Config isValid/copyWith/Progress.fraction
│   └── search_service_test.dart   # 颜色搜索去重/排序/detectLevel
└── widget_test.dart               # 占位测试
```

---

## 代码生成

项目使用 `build_runner` 生成 Drift / Freezed / JSON 序列化 代码：

```bash
# 一次性生成
dart run build_runner build --delete-conflicting-outputs

# 监听模式（开发时自动重新生成）
dart run build_runner watch --delete-conflicting-outputs
```

生成的文件以 `.g.dart` 后缀标识，不应手动编辑。

---

## 已知问题

### Linux 构建：clang 弃用警告导致编译失败

`flutter_secure_storage_linux` 插件内嵌的 `json.hpp` 在 clang 19+ 下会触发 `-Wdeprecated-literal-operator` 警告，因 Flutter 编译启用 `-Werror` 导致失败。

**临时解决**：编辑 `linux/flutter/ephemeral/.plugin_symlinks/flutter_secure_storage_linux/linux/CMakeLists.txt`，移除 `-Werror`：

```cmake
# 修改前
target_compile_options(${TARGET} PRIVATE -Wall -Werror)

# 修改后
target_compile_options(${TARGET} PRIVATE -Wall)
```

### Linux 构建：安装路径权限

首次 `flutter build linux` 时 CMake 尝试安装到 `/usr/local/`。清理后重建即可：

```bash
rm -rf build/linux
flutter build linux --debug
```

### Linux Vulkan GPU 构建：llama.cpp 找不到

**现象**：CMake 输出 "llama.cpp not found"，生成 stub 版本。

**原因**：CMake 查找路径 `third_party/llama.cpp` 不对。

**解决**：设置环境变量明确指定路径：
```bash
LLAMA_CPP_DIR=/path/to/project/third_party/llama.cpp \
ENABLE_VULKAN=ON \
flutter build linux --release
```

### Linux Vulkan GPU 构建：glslc/glslangValidator 缺失

**现象**：CMake 输出 "glslc not found - Vulkan GPU acceleration disabled"

**原因**：缺少 Vulkan 着色器编译器。

**解决**：
```bash
sudo dnf install glslc glslang
```

### Linux Vulkan GPU 构建：SPIRV-Headers 找不到

**现象**：CMake 报错 "Could not find a package configuration file provided by SPIRV-Headers"

**原因**：`third_party/spirv-headers-install` 目录不存在。

**解决**：运行脚本构建并安装 SPIRV-Headers：
```bash
./scripts/init-third-party.sh
# 脚本会自动构建并安装到 third_party/spirv-headers-install
```

### Linux Vulkan GPU 构建：链接错误 R_X86_64_32S

**现象**：`relocation R_X86_64_32S against .rodata can not be used when making a shared object`

**原因**：llama.cpp 静态库未使用 -fPIC 编译。

**解决**：项目已添加 `CMAKE_POSITION_INDEPENDENT_CODE ON`，清理后重建：
```bash
rm -rf build/linux
flutter build linux --release
```

### Linux Vulkan GPU 构建：android/log.h 找不到

**现象**：编译错误 "fatal error: 'android/log.h' file not found"

**原因**：`linux/cpp/meme_llm.cpp` 中 `android/log.h` 缺少平台保护。

**解决**：项目已修复，将 `android/log.h` 放在 `#ifdef __ANDROID__` 保护下。

### Android 构建：首次 Gradle 下载慢

首次 Android 构建会下载 Gradle 依赖，可能耗时 10–20 分钟。后续增量构建会快得多。

### macOS 构建：llama.cpp 找不到

**现象**：CMake 输出 "llama.cpp not found at ..."

**解决**：确保已运行 `./scripts/init-third-party.sh`，然后检查 `LLAMA_CPP_DIR` 环境变量：

```bash
LLAMA_CPP_DIR=/path/to/project/third_party/llama.cpp \
./scripts/build-macos-llm.sh
```

### macOS Metal GPU 构建

**系统依赖**：
- Xcode Command Line Tools (`xcode-select --install`)
- macOS OCR 使用 Apple Vision Framework（系统内置，无需额外安装）

**Apple Silicon** (M1/M2/M3)：Metal 原生支持，开箱即用。

**Intel Mac**：Metal 支持有限，GPU 加速可能不可用，回退到 CPU。

### Linux Vulkan GPU 后端诊断

如果 GPU 加速不工作，可通过以下方式诊断：

1. **检查 Vulkan 驱动**：
   ```bash
   vulkaninfo --summary  # 或安装 vulkan-tools 包
   ```

2. **检查编译产物**：
   ```bash
   # 完整 Vulkan 版本应该 ~57MB
   ls -lh build/linux/x64/release/bundle/lib/libmeme_llm.so

   # 检查符号表
   nm build/linux/x64/release/bundle/lib/libmeme_llm.so | grep ggml_vulkan
   ```

3. **检查 CMake 配置**：
   ```bash
   # 在 build 目录查看配置日志
   grep -E "(VULKAN|llama|SPIRV)" build/linux/x64/release/CMakeCache.txt
   ```

4. **运行时日志**：启动应用后查看 LLM 相关日志，确认 GPU 后端是否加载。

---

## 问题排查记录

### 1. OCR 中文模型不稳定 → 降级到 Latin

**现象**：`TextRecognitionScript.chinese` 频繁返回空结果，导致图片认不出文字。

**根因**：Google ML Kit 的 Chinese 模型在某些设备/环境下识别率低，表现为 `blocks` 为空但无异常。

**解决**：`ocr_service.dart` 中优先尝试 Chinese，若返回空则自动降级到 `TextRecognitionScript.latin`，保障基本 OCR 能力。

### 2. R8 混淆导致 ML Kit OCR NullPointerException

**现象**：OCR 全部失败，日志报 `PlatformException: Attempt to invoke virtual method 'java.lang.Class java.lang.Object.getClass()' on a null object reference`，发生在 `TextRecognition.getClient()` 内部。

**根因**：Android 发布构建启用 R8（`isMinifyEnabled = true`）时，R8 认为 ML Kit 内部类未被直接引用（实际上通过反射加载），将它们混淆/移除。导致 `getClient()` 内部工厂为 null，`.getClass()` 触发 NPE。Chinese 和 Latin 均受影响。

**解决**：在 `proguard-rules.pro` 中加入官方推荐规则：

```
-keep class com.google.mlkit.** { *; }
```

仅增大 APK 约 0.1MB（35.7 → 35.8MB），不影响启动速度。

**教训**：
- 不要用手动猜测的 `internal.**` 规则，直接使用插件官方推荐的 `com.google.mlkit.**` 最稳妥。
- 初次遇到闪退时，同时改了 ProGuard + LogService + main.dart 三处，无法定位真凶。应该每次只改一个维度。

### 3. LogService 重启日志丢失 → 文件持久化

**现象**：每次重启 App 后 LogViewer 日志清空，无法追溯上次运行记录。

**解决**：使用 `dart:io` 以 JSON-Lines 格式追加写入 `<docDir>/logs/app.log`，启动时从文件尾部反向加载恢复。

**关键细节**：
- 同步写文件 + try-catch 兜底，持久化失败不影响内存日志
- 首次写入前 `file.parent.createSync(recursive: true)` 确保父目录存在
- 文件路径通过 `main.dart` → `initLogFilePath()` → Provider 注入，而非在 `LogService` 内部直接调用 `path_provider`

### 4. 重新分析删除用户自定义标签

**现象**：点击"重新分析"后，手动添加的标签（source='custom'）消失。

**根因**：`_reanalyze()` 调用 `repo.deleteTags(meme.id)` → `_tagDao.deleteByMemeId()` 无条件删除了 **所有** 标签。

**解决**：
- `TagDao` 新增 `deleteBySourcesForMeme(memeId, sources)`，按 source 列表过滤删除
- `MemeRepository` 新增 `deleteAutoTags(memeId)`，仅删除 `ocr`/`llm` 标签
- `_reanalyze()` 改用 `deleteAutoTags()`

### 5. 添加图片到相册 SnackBar 显示 "0 张"

**现象**：选中图片移入相册后，底部提示"已将 0 张图片添加到《xxx》"。

**根因**：`_exitSelectionMode()` 在 SnackBar 读取 `_selectedIds.length` **之前** 清空了集合。

**解决**：在 `_exitSelectionMode()` 之前 `final count = _selectedIds.length` 保存计数。

### 6. OCR 诊断日志不显示在 LogViewer

**现象**：`ocr_service.dart` 内部的调试信息（脚本类型、块数、截取文字）不出现在 LogViewer 中。

**根因**：使用了 `print()` 输出，但 LogViewer 只显示 `LogService` 的日志。

**解决**：在 `OcrResult` 中新增 `diagnostics` 字段收集诊断信息，`_runOcr()` 通过 `_log.info()` 输出到 LogService。

---

## 安全检查清单

后续修改涉及以下模块时需特别注意：

| 模块 | 风险点 |
|---|---|
| **`proguard-rules.pro`** | 错误规则可导致启动闪退；只加不删，优先使用官方推荐规则 |
| **`build.gradle.kts`** | `isMinifyEnabled` 与 `shrinkResources` 必须配对，Flutter Gradle 插件可能自动设置 |
| **`LogService`** | 同步文件 I/O 在构造器中执行，必须 try-catch 兜底 |
| **`main.dart` 启动流程** | Provider 依赖需在 `runApp` 前初始化完毕 |
| **`r8-map-id` 混淆栈** | 无法直接映射；可临时关闭 `isMinifyEnabled` 做调试版定位 |
