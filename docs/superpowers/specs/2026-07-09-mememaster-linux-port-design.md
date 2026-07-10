# MemeMaster Linux 端功能完善设计文档

**日期**: 2026-07-09
**目标**: Linux 端实现与 App 端功能对齐

---

## 一、OCR 识别

### 1.1 方案
使用 **Tesseract OCR** 替代 Google MLKit。

| 项目 | 说明 |
|------|------|
| Dart 包 | `tesseract_ocr` 或 `dart_tesseract_ocr` |
| 系统依赖 | `tesseract`, `leptonica` (Linux 系统包) |
| 安装命令 | `sudo dnf install tesseract leptonica` |
| 架构 | FFI 调用原生 so，与 MLKit API 设计类似 |

### 1.2 文件变更
- 新建 `lib/core/ocr/tesseract_ocr_service.dart`
- 修改 `lib/core/ocr/ocr_service.dart` 添加 Linux 平台分支
- 修改 `pubspec.yaml` 添加依赖

### 1.3 API 设计
```dart
// tesseract_ocr_service.dart
class TesseractOcrService {
  Future<OcrResult> recognize(String imagePath);
  Future<OcrResult> recognizeFromBytes(Uint8List bytes);
  void dispose();
}
```

---

## 二、本地 LLM 推理

### 2.1 方案
复用 Android 端 `meme_llm.cpp`，在 Linux 上重新编译。

| 项目 | 说明 |
|------|------|
| 源码复用 | `android/app/src/main/cpp/meme_llm.cpp` |
| 构建系统 | 新增 `linux/cpp/CMakeLists.txt` |
| 输出 | `libmeme_llm.so` |
| 加速支持 | CPU + Vulkan + OpenCL |

### 2.2 目录结构
```
linux/
├── cpp/
│   ├── CMakeLists.txt
│   ├── meme_llm.cpp (复用 android 源码)
│   └── third_party/
│       ├── llama.cpp/
│       └── mtmd/
└── runner/
    └── CMakeLists.txt (添加 cpp 编译)
```

### 2.3 依赖
- llama.cpp (git submodule 或脚本克隆)
- mtmd (多模态模型支持)
- Vulkan 驱动 (系统)
- OpenCL 驱动 (系统)

### 2.4 编译安装命令
```bash
# 系统依赖
sudo dnf install clang ninja-build vulkan-loader opencl-loader

# 克隆依赖
./scripts/init-third-party.sh --linux

# 构建
flutter build linux --release
```

---

## 三、剪贴板服务

### 3.1 方案
使用 `super_clipboard` 包实现跨平台统一 API。

| 项目 | 说明 |
|------|------|
| Dart 包 | `super_clipboard` |
| 功能 | 复制图片到剪贴板 |
| 跨平台 | Linux / macOS / Windows 统一 API |

### 3.2 文件变更
- 修改 `lib/services/clipboard_service.dart`
- 移除 Android MethodChannel 调用
- 使用 `super_clipboard` 替代

### 3.3 API 设计
```dart
// 复制图片到剪贴板
Future<bool> copyImageToClipboard(String filePath) async {
  final item = DataWriterItem();
  item.add(Formats.png(fileBytes));
  await SystemClipboard.instance?.write([item]);
}
```

---

## 四、ScanScreen 目录选择

### 4.1 方案
移除 Android 硬编码路径，提供 Linux 常用目录快捷入口。

### 4.2 目录映射

| Android 路径 | Linux 路径 |
|--------------|------------|
| `/storage/emulated/0/Download` | `~/Downloads` |
| `/storage/emulated/0/Pictures` | `~/Pictures` |
| `/storage/emulated/0/DCIM` | `~/DCIM` 或 `~/Pictures/DCIM` |
| `/storage/emulated/0/tencent/MicroMsg/Download` | 不适用 (微信) |

### 4.3 新增快捷目录
- `~/Downloads`
- `~/Pictures`
- `~/Desktop`
- `~/Images`
- "自定义目录" (调用 `getDirectoryPath()`)

### 4.4 文件变更
- 修改 `lib/features/scan/scan_screen.dart`
- 使用 `Platform.isLinux` 条件分支

---

## 五、导出位置配置

### 5.1 方案
新增 "默认导出目录" 设置项，默认值 `~/Downloads/MemeHelper`。

### 5.2 设置项
| 设置名 | 类型 | 默认值 |
|--------|------|--------|
| `default_export_path` | String | `~/Downloads/MemeHelper` |

### 5.3 UI 位置
- 设置 → 存储/导出相关设置页
- 或整合到现有 "配置导出/导入" 设置

### 5.4 回退逻辑
1. 用户已配置 → 使用配置路径
2. 用户未配置 → 首次导出时让用户选，之后记住

### 5.5 文件变更
- 修改 `lib/features/settings/settings_screen.dart` 添加设置项
- 修改 `lib/services/meme_export_service.dart` 使用配置路径
- 使用 `path_provider` + `path` 解析 `~`

---

## 六、Super Clipboard 补充

### 6.1 复制图片实现
```dart
import 'package:super_clipboard/super_clipboard.dart';

Future<bool> copyImageToClipboard(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return false;

  final bytes = await file.readAsBytes();
  final item = DataWriterItem();

  // 根据文件扩展名选择格式
  final ext = filePath.split('.').last.toLowerCase();
  if (ext == 'png') {
    item.add(Formats.png(bytes));
  } else if (ext == 'gif') {
    item.add(Formats.gif(bytes));
  } else {
    item.add(Formats.jpeg(bytes));
  }

  final clipboard = SystemClipboard.instance;
  if (clipboard == null) return false;

  await clipboard.write([item]);
  return true;
}
```

---

## 七、文件路径 ~ 扩展

### 7.1 实现
```dart
String expandPath(String path) {
  if (path.startsWith('~/')) {
    return path.replaceFirst('~', Platform.environment['HOME'] ?? '');
  }
  return path;
}
```

---

## 八、Tesseract 安装检测

### 8.1 启动时检测
```dart
Future<bool> checkTesseractInstalled() async {
  try {
    final result = await Process.run('tesseract', ['--version']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}
```

### 8.2 缺失提示
如果未安装，显示提示对话框：
```
Tesseract OCR 未安装。
请运行: sudo dnf install tesseract leptonica
```

---

## 九、测试计划

### 9.1 单元测试
- OCR 服务测试 (需要测试图片)
- 剪贴板服务测试
- 路径扩展测试

### 9.2 集成测试
- 完整导入流程测试
- 完整导出流程测试
- 扫描功能测试

### 9.3 手动测试
1. 构建: `flutter build linux --release`
2. 安装: `sudo dpkg -i build/linux/x64/release/bundle.deb` 或运行
3. 功能测试:
   - [ ] 图片导入
   - [ ] 剪贴板复制
   - [ ] Scan 扫描目录选择
   - [ ] 导出到 Downloads
   - [ ] OCR 文字识别
   - [ ] 本地 LLM 推理 (如果有模型)

---

## 十、依赖清单

### 10.1 系统依赖
```bash
sudo dnf install \
  clang \
  ninja-build \
  libsecret-devel \
  gtk3-devel \
  tesseract \
  leptonica \
  vulkan-loader \
  opencl-loader
```

### 10.2 Dart 依赖
```yaml
dependencies:
  super_clipboard: ^0.8.0  # 或最新版本
  tesseract_ocr: ^0.5.0    # 或 dart_tesseract_ocr
```

### 10.3 构建依赖
- CMake
- Ninja
- Git (克隆 llama.cpp)
