# GPU 加速修复指南

本文档涵盖 Android 和 Linux 平台的 llama.cpp GPU 加速配置与排错。

---

## Linux Vulkan GPU 加速

### 系统依赖

```bash
# Fedora/RHEL/CentOS
sudo dnf install vulkan-loader glslc glslang

# Ubuntu/Debian
sudo apt install libvulkan1 glslang-tools spirv-tools
```

### 第三方依赖

```bash
# 克隆并构建 llama.cpp、SPIRV-Headers 等
./scripts/init-third-party.sh
```

### 构建命令

```bash
# 清理之前的构建
rm -rf build/linux

# 构建带 Vulkan GPU 加速的 Linux 版本
SPIRV_HEADERS_DIR=/path/to/project/third_party/spirv-headers/install \
LLAMA_CPP_DIR=/path/to/project/third_party/llama.cpp \
ENABLE_VULKAN=ON \
flutter build linux --release
```

### 验证 GPU 加速

```bash
# 检查库文件大小（完整 Vulkan 版本 ~57MB，stub 版本 ~12KB）
ls -lh build/linux/x64/release/bundle/lib/libmeme_llm.so

# 检查 Vulkan 符号
nm build/linux/x64/release/bundle/lib/libmeme_llm.so | grep ggml_vulkan
```

### 已知问题与解决

| 问题 | 原因 | 解决 |
|------|------|------|
| "llama.cpp not found" | CMake 路径解析问题 | 设置 `LLAMA_CPP_DIR` 环境变量 |
| "glslc not found" | 缺少着色器编译器 | `sudo dnf install glslc glslang` |
| "SPIRV-Headers not found" | 未构建安装 | 运行 `./scripts/init-third-party.sh` |
| "R_X86_64_32S relocation error" | 静态库未用 -fPIC | 项目已修复，清理重建 |
| android/log.h 找不到 | 缺少平台保护 | 项目已修复 |

---

## Android GPU 加速修复指南

## 重要说明

> **OpenCL 后端状态**: 实验性功能，尚未在真实设备上验证。仅 Snapdragon 8 Gen 3/Elite 等高端芯片可能支持。
> 
> **Vulkan 后端状态**: 已在 Adreno 710 上验证，GPU 模式工作正常。但通常比 CPU 慢，不建议在移动端使用。

## 问题总结

**根本原因**：虽然 Gradle 构建配置中启用了 `-DENABLE_OPENCL=ON`，但 llama.cpp 的 OpenCL 后端**没有正确编译进 APK**。导致运行时 `ggml_backend_load_all()` 只加载了 CPU 后端，GPU 检测失败，回退到 CPU 模式。而 CPU 加载大模型非常慢，超过 60 秒超时限制，导致"模型加载超时"。

## 已修复的文件

### 1. `android/app/src/main/cpp/CMakeLists.txt`

**修复内容**：
- 添加了 `GGML_OPENCL_EMBED_KERNELS ON` 和 `GGML_OPENCL_USE_ADRENO_KERNELS ON` 选项，确保 OpenCL kernel 被静态编译进库
- 完善了 OpenCL 头文件和库的查找逻辑，支持预编译的 ICD Loader
- 添加了更详细的链接库配置

### 2. `android/app/src/main/cpp/meme_llm.cpp`

**修复内容**：
- 添加了更详细的 GPU 诊断日志，当 GPU 未检测到时输出可能原因
- 帮助用户快速定位问题（设备不支持 vs 编译配置错误）

### 3. `android/app/build.gradle.kts`

**修复内容**：
- 添加了注释说明 Vulkan 通常比 CPU 慢，不建议使用
- 添加了 GPU 后端编译优化标志注释

## 构建步骤

### 前提条件

1. 运行脚本自动下载并构建所有依赖：
```bash
cd <REPO_ROOT>
./scripts/init-third-party.sh
```

**脚本会自动完成：**
- 克隆 llama.cpp、OpenCL-Headers、OpenCL-ICD-Loader、SPIRV-Headers
- 构建并安装 SPIRV-Headers（Vulkan 需要）
- 交叉编译 OpenCL-ICD-Loader for Android（需要 ANDROID_NDK 环境变量）

2. 确保 ANDROID_NDK 环境变量已设置（可选，仅 OpenCL 需要）：
```bash
export ANDROID_NDK=<NDK_PATH>
```

### 构建 APK

```bash
cd <REPO_ROOT>

# 清理之前的构建
flutter clean

# 构建 release APK（启用 OpenCL）
flutter build apk --release

# 验证 APK 中是否包含 GPU 后端
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -E "(libmeme_llm|libOpenCL)"
```

## 验证 GPU 是否工作

### 方法 1：查看日志

安装 APK 后，使用 adb 查看日志：

```bash
adb logcat -s meme_llm:D
```

期望看到类似日志：
```
mllm_init: ggml_backend_load_all() 完成, backends=2, devices=2
  backend[0]: "CPU" (1 devices)
    device[0]: "CPU" - ...
  backend[1]: "OpenCL" (1 devices)
    device[0]: "Adreno" - ...
mllm_init: GPU 加速已启用, n_gpu_layers=-1
```

如果只看到 `backend[0]: "CPU"`，说明 GPU 后端没有正确编译。

### 方法 2：使用测试功能

在应用设置中启用 GPU 加速，然后运行模型测试。如果 GPU 工作正常，模型加载速度应该明显快于 CPU 模式。

## 常见问题

### Q: 为什么模型加载还是超时？

**A**: 检查以下几点：
1. **设备是否支持**：OpenCL 仅支持 Snapdragon 8 Gen 3/Elite 等高端芯片。低端设备不支持。
2. **APK 是否重新构建**：修改 CMake 后必须重新构建 APK。
3. **日志确认**：查看 adb logcat 确认 GPU 后端是否被加载。

### Q: 为什么 GPU 比 CPU 慢？

**A**: 根据 llama.cpp 社区反馈，Android 上的 GPU 加速情况：
- **OpenCL**：在 Snapdragon 8 Gen 3/Elite 上表现良好，其他设备可能不如 CPU
- **Vulkan**：通常比 CPU 慢，不建议使用
- **CPU**：在大多数 Android 设备上，CPU 推理反而更快

### Q: 如何禁用 GPU 加速？

**A**: 在 `android/app/build.gradle.kts` 中：
```kotlin
arguments += listOf("-DENABLE_OPENCL=OFF")
```

或者在应用设置中关闭 GPU 加速选项。

## Vulkan 诊断

Vulkan 诊断功能已添加到 GPU 诊断工具中。在设置页面运行"GPU 加速诊断"后，日志中会包含：

- **libvulkan.so 查找**：检查 Vulkan 系统库是否存在
- **Vulkan HW 驱动库**：检查 `/vendor/lib64/hw/vulkan.qcom.so` 等实际驱动文件
- **Vulkan ICD JSON 配置**：检查 `/vendor/etc/vulkan/icd.d/` 下是否有 JSON 格式的 ICD 配置文件
- **DynamicLibrary.open 测试**：实际加载 libvulkan.so 并检查 `vkCreateInstance` 等核心符号
- **C++ 端 dlopen 测试**：`mllm_run_diagnostics` 中的步骤 5，尝试从多个路径 dlopen libvulkan.so，检查 5 个 Vulkan 核心 API 符号

### 在 Android 上启用 Vulkan 后端

1. 在 `android/app/build.gradle.kts` 中取消 `ENABLE_VULKAN` 的注释：
```kotlin
arguments += listOf("-DENABLE_VULKAN=ON")
```
2. 重新构建 APK：
```bash
flutter clean && flutter build apk --release
```
3. 运行 GPU 诊断，在日志中确认 Vulkan 后端被加载。

> **注意**：根据 llama.cpp 社区反馈，Android 上的 Vulkan 后端在大多数设备上推理速度**不如 CPU**，不建议在移动端使用。OpenCL 后端仅在 Snapdragon 8 Gen 3/Elite 等高端芯片上表现良好。

## OpenCL 后端（实验性 / 未验证）

### 当前状态

OpenCL 后端代码已集成到构建系统中，但**尚未在真实设备上验证**。相关代码包括：

- `android/app/build.gradle.kts` 中的 `-DENABLE_OPENCL=ON`
- `android/app/src/main/cpp/CMakeLists.txt` 中的 OpenCL 头文件和库查找
- `lib/services/opencl_diagnostic.dart` 中的 OpenCL 诊断工具
- `android/app/src/main/cpp/meme_llm.cpp` 中的 `mllm_run_diagnostics` OpenCL 测试

### 验证需求

要验证 OpenCL 后端，需要：
1. 支持 OpenCL 的 Android 设备（如 Snapdragon 8 Gen 3/Elite）
2. 预编译的 OpenCL ICD Loader（`third_party/OpenCL-ICD-Loader/build_ndk/libOpenCL.so`）
3. 运行 GPU 诊断，确认 `libOpenCL.so` 能正常加载

### 已知问题

- **Adreno 710 不支持 OpenCL**：当前测试设备（Adreno 710）没有 OpenCL 支持
- **ICD Loader 需要手动编译**：`init-third-party.sh` 只下载源码，需要手动交叉编译
- **性能未知**：OpenCL 在 Android 上的推理性能尚未测试

## 性能优化建议

1. **使用量化模型**：Q4_0 或 Q4_K_M 量化格式比 FP16 快得多
2. **调整 batch 大小**：根据设备内存调整 `n_batch` 和 `n_ubatch`
3. **关闭 mmap**：Android 上 `use_mmap=0` 通常更稳定
4. **使用小模型**：7B 参数以下的模型在手机上更实用

## 参考文档

- [llama.cpp 构建指南（Vulkan 章节）](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#vulkan)
- [llama.cpp OpenCL 后端文档](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/OPENCL.md)
- [llama.cpp Vulkan 后端文档](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/VULKAN.md)
- [llama.cpp Android 构建指南](https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md)
- [llama.cpp GPU 支持讨论](https://github.com/ggml-org/llama.cpp/discussions/16606)
