# MemeMaster

表情包管理工具 —— 导入、组织、智能搜索、颜色识别、语义分析。支持 Linux / macOS / Windows / Android 多平台。

## 功能

- **图片导入** — 自动去重（SHA256 哈希），按日期归档存储
- **颜色搜索** — HSV 滑块选色，CIE Lab ΔE 色差匹配
- **OCR 文字识别** — Android: Google ML Kit / macOS: Apple Vision / Linux/Windows: Tesseract CLI，支持中英文
- **AI 标签与描述** — OpenAI / Ollama / 本地 LLM 驱动，根据 OCR 结果自动生成标签和文字描述
- **Token 用量追踪** — 记录每次 LLM 调用的 prompt/completion token 数，按日统计，支持查看今日用量和任意时间范围汇总
- **统计页面** — 用户使用数据总览，包含 GitHub 风格热度图（贡献日历）、日期范围选择器（7/30/365 天）、导入/复制/收藏/Token 用量趋势列表
- **S3 云同步** — 兼容 AWS S3、MinIO、Cloudflare R2，支持全量上传/下载和增量同步
- **配置导出/导入** — 一键备份/恢复 S3、LLM、颜色提取、主题、语言等全部配置，支持文件保存和分享
- **国际化支持** — 中英文双语界面，ARB 文件管理
- **文件夹管理** — 图片分组
- **定时同步** — 可配置的自动同步间隔（5 分钟 ~ 1 天）

## 快速开始

### Linux 桌面

#### 基本依赖

```bash
# 核心依赖
sudo dnf install clang ninja-build libsecret-devel gtk3-devel tesseract

# Vulkan GPU 加速依赖（可选，用于本地 LLM 加速）
sudo dnf install vulkan-loader glslc glslang

# Flutter 依赖 + 启动
flutter pub get
flutter run -d linux

# 或构建 release 版本
flutter build linux --release
# 产物: build/linux/x64/release/bundle/meme_master
```

#### Vulkan GPU 加速构建（可选）

如果需要本地 LLM 推理使用 GPU 加速，需要额外配置：

```bash
# 1. 确保 SPIRV-Headers 已构建
./scripts/init-third-party.sh

# 2. 使用 Vulkan 构建
SPIRV_HEADERS_DIR=/path/to/project/third_party/spirv-headers/install \
LLAMA_CPP_DIR=/path/to/project/third_party/llama.cpp \
ENABLE_VULKAN=ON \
flutter build linux --release
```

**验证 GPU 库**：
```bash
# 检查是否生成了包含 Vulkan 符号的 libmeme_llm.so
nm build/linux/x64/release/bundle/lib/libmeme_llm.so | grep vulkan
```

> **注意**:
> - Linux OCR 使用 Tesseract CLI（`google_mlkit_text_recognition` 不可用于 Linux）
> - 需要安装 `tesseract` 和中文语言包 `tesseract-lang`
> - Vulkan 模式需要 Intel/AMD/NVIDIA GPU 驱动支持

### macOS 桌面

#### 系统依赖

```bash
# Xcode Command Line Tools（必须）
xcode-select --install
# macOS OCR 使用 Apple Vision Framework（系统内置，无需额外安装）
```

#### 构建

```bash
# 克隆并构建 C++ 原生依赖
./scripts/init-third-party.sh

# 构建 C++ 原生库（Metal GPU）
./scripts/build-macos-llm.sh

# 构建 release 版本
flutter build macos --release
# 产物: build/macos/Build/Products/Release/meme_master
```

> **注意**: macOS OCR 使用 Apple Vision Framework（系统内置，无需额外安装 Tesseract）。
> **GPU 加速**: macOS 使用 Metal GPU 加速（Apple Silicon M1+ 推荐，Intel Mac 需 OpenCL）。

### Windows 桌面

#### 系统依赖

```bash
# Tesseract OCR (Chocolatey)
choco install tesseract -y

# 或者手动下载安装: https://github.com/UB-Mannheim/tesseract/wiki
```

#### 构建

```bash
# 克隆并构建 C++ 原生依赖
./scripts/init-third-party.sh

# 构建 C++ 原生库（CPU only，Vulkan GPU 可在 Phase 2 启用）
# Windows 使用 CMake 构建 DLL
mkdir -p build/windows-llm
cd build/windows-llm
cmake ../../windows/cpp -DENABLE_VULKAN=OFF
cmake --build . --config Release

# 构建 release 版本
flutter build windows --release
# 产物: build/windows/x64/release/bundle/meme_master.exe
```

> **注意**: Windows OCR 使用 Tesseract CLI（`google_mlkit_text_recognition` 不可用于 Windows）。
> **GPU 加速**: Phase 1 仅支持 CPU 推理，Vulkan GPU 加速在 Phase 2 提供。

### Android (首次构建必读)

Android 构建除了 Flutter 依赖外,还需要把 C++ 原生依赖准备好(llama.cpp、Vulkan SPIRV-Headers、可选 OpenCL),脚本会从 GitHub 克隆并自动构建。

```bash
# 1. 系统依赖 (同 Linux)
sudo dnf install clang ninja-build libsecret-devel gtk3-devel

# 2. Flutter 依赖
flutter pub get

# 3. Android SDK 路径设置 (本项目约定 ~/Software/android-sdk)
export ANDROID_HOME="$HOME/Software/android-sdk"
export ANDROID_NDK="$ANDROID_NDK"  # 启用 OpenCL/Vulkan GPU 加速时必填
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

# 4. 克隆并构建 C++ 原生依赖 (llama.cpp / SPIRV-Headers / OpenCL-*)
./scripts/init-third-party.sh
#    国内网络可配 Gitee 镜像,编辑 DEPS 数组

# 5. 构建 APK
flutter build apk --release       # 产物: build/app/outputs/flutter-apk/app-release.apk
flutter install                  # 安装到已连接设备
```

> 后续更新只需重跑 `flutter pub get` + `init-third-party.sh`(已克隆的依赖会跳过)。

### 环境变量速查

| 变量 | 必填 | 作用 |
|---|---|---|
| `ANDROID_HOME` | Android 编译 | Android SDK 根目录,Gradle 自动检测 |
| `ANDROID_NDK` | GPU 加速 | NDK 根目录,OpenCL 交叉编译需要 |
| `LLAMA_CPP_DIR` | 一般不用 | 覆盖默认 `third_party/llama.cpp` 位置 |

CPU-only 构建只需 `ANDROID_HOME`,GPU 加速(`cmake/build.gradle.kts` 中 `-DENABLE_VULKAN=ON` / `-DENABLE_OPENCL=ON`)还需 `ANDROID_NDK`。

完整环境配置见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md),GPU 加速配置见 [docs/GPU_ACCELERATION_FIX.md](docs/GPU_ACCELERATION_FIX.md)。

## 详细文档

| 文档 | 内容 |
|---|---|
| [docs/USAGE.md](docs/USAGE.md) | 用户使用手册（导入/搜索/同步等完整功能） |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | 开发者指南（环境搭建/构建/测试/架构） |
| [docs/GPU_ACCELERATION_FIX.md](docs/GPU_ACCELERATION_FIX.md) | GPU 加速（Vulkan/OpenCL）配置与排错 |

## 路线图

- [ ] **UI 优化** — 改进热力图交互（点击查看详情）、更流畅的动画过渡、移动端适配
- [ ] **llama.cpp 本地推理性能优化** — GPU 加速（cuBLAS/Vulkan）、量化模型加载优化、批处理推理
- [ ] **Meme 检测 Benchmark** — 建立标准评测数据集，对比不同模型/提示词的效果指标（准确率/召回率/F1）
- [ ] **全平台构建测试** — Linux/Windows/iOS/macOS 跨平台构建验证，修复各平台特定问题
- [ ] **全数据导出 & 压缩包重建** — 将库中所有图片和元数据导出为可移植压缩包（ZIP/TAR），支持从压缩包完整重建
- [ ] **崩溃报告** — 自动捕获未处理的异常，发送到服务端以便远程诊断
- [ ] **检查更新 / 自动更新** — 从 GitHub Releases 检查新版本，支持一键下载和安装更新
