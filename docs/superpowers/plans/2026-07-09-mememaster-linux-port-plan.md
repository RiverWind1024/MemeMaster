# MemeMaster Linux 端功能完善实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan.

**Goal:** Linux 端实现与 App 端功能对齐 (OCR、剪贴板、本地 LLM、目录选择、导出配置)

**Architecture:** 在现有 Flutter 跨平台架构基础上，为 Linux 添加平台特定实现。核心业务逻辑在 Dart 层保持不变，平台差异通过条件编译或抽象接口处理。

**Tech Stack:**
- Tesseract OCR (tesseract_ocr 包 + 系统库)
- llama.cpp (原生 C++ 编译为 so)
- super_clipboard (Dart 跨平台剪贴板)
- file_selector (目录选择)

---

## Chunk 1: Dart 依赖添加

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加 super_clipboard 依赖**

```yaml
# 在 pubspec.yaml dependencies 中添加
super_clipboard: ^0.8.0
```

- [ ] **Step 2: 添加 tesseract_ocr 依赖**

```yaml
# 检查是否有 tesseract 相关的 dart 包
# 备选: tesseract_ocr 或 dart_tesseract_ocr
# 如果没有合适的包，可能需要用 process 执行 tesseract 命令
```

- [ ] **Step 3: 运行 flutter pub get**

```bash
cd /home/jiangzifeng/Project/MemeHelper
flutter pub get
```

- [ ] **Step 4: 验证依赖添加成功**

---

## Chunk 2: Tesseract OCR 服务实现

**Files:**
- Create: `lib/core/ocr/tesseract_ocr_service.dart`
- Modify: `lib/core/ocr/ocr_service.dart`

- [ ] **Step 1: 创建 TesseractOcrService 类**

```dart
// lib/core/ocr/tesseract_ocr_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

class TesseractOcrResult {
  final String text;
  final double confidence;

  TesseractOcrResult({required this.text, required this.confidence});
}

class TesseractOcrService {
  bool _disposed = false;

  /// 检查 tesseract 是否已安装
  static Future<bool> isInstalled() async {
    try {
      final result = await Process.run('tesseract', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 从图片文件识别文字
  Future<TesseractOcrResult?> recognize(String imagePath) async {
    if (_disposed) throw StateError('服务已释放');

    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', imagePath);
    }

    // tesseract img_path stdout -l chi_sim+eng --psm 6
    final result = await Process.run('tesseract', [
      imagePath,
      'stdout',
      '-l', 'chi_sim+eng',
      '--psm', '6',
    ]);

    if (result.exitCode != 0) {
      return null;
    }

    final text = result.stdout.toString().trim();
    return TesseractOcrResult(text: text, confidence: 0.9);
  }

  /// 从字节数据识别文字 (先写临时文件)
  Future<TesseractOcrResult?> recognizeFromBytes(Uint8List bytes) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(p.join(tempDir.path, 'ocr_temp_${DateTime.now().millisecondsSinceEpoch}.png'));
    await tempFile.writeAsBytes(bytes);
    try {
      return await recognize(tempFile.path);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void dispose() {
    _disposed = true;
  }
}
```

- [ ] **Step 2: 修改 ocr_service.dart 添加 Linux 平台分支**

```dart
// lib/core/ocr/ocr_service.dart
// 在现有 ocrServiceProvider 中添加 Linux 支持

import 'package:flutter/foundation.dart';
import 'dart:io';

import 'tesseract_ocr_service.dart';

// ... 现有代码 ...

final ocrServiceProvider = Provider<OcrService>((ref) {
  if (Platform.isAndroid || Platform.isIOS) {
    return GoogleMlKitOcrService(); // 现有实现
  } else if (Platform.isLinux) {
    return TesseractOcrService(); // 新实现
  } else {
    throw UnsupportedError('不支持的平台');
  }
});
```

- [ ] **Step 3: 运行 flutter analyze 检查**

```bash
cd /home/jiangzifeng/Project/MemeHelper
flutter analyze lib/core/ocr/
```

---

## Chunk 3: 剪贴板服务重构

**Files:**
- Modify: `lib/services/clipboard_service.dart`

- [ ] **Step 1: 重写 ClipboardService 使用 super_clipboard**

```dart
// lib/services/clipboard_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ClipboardService {
  static const _channel = MethodChannel('com.mememaster.app/clipboard');

  static Future<String?> readText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> copyImageToClipboard(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('ClipboardService: 文件不存在 $filePath');
        return false;
      }

      final bytes = await file.readAsBytes();

      // 使用 super_clipboard (跨平台统一)
      final item = DataWriterItem();
      final ext = filePath.split('.').last.toLowerCase();

      if (ext == 'png') {
        item.add(Formats.png(bytes));
      } else if (ext == 'gif') {
        item.add(Formats.gif(bytes));
      } else if (ext == 'webp') {
        item.add(Formats.webp(bytes));
      } else {
        item.add(Formats.jpeg(bytes));
      }

      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        print('ClipboardService: 系统剪贴板不可用');
        return false;
      }

      await clipboard.write([item]);
      return true;
    } catch (e) {
      print('复制到剪贴板失败: $e');
      return false;
    }
  }

  static Future<void> shareImage(String filePath) async {
    final file = XFile(filePath);
    await Share.shareXFiles([file], text: '分享表情包');
  }

  static Future<void> shareMultipleImages(List<String> filePaths) async {
    final files = filePaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(files, text: '分享表情包');
  }
}
```

- [ ] **Step 2: 运行 flutter analyze 检查**

```bash
flutter analyze lib/services/clipboard_service.dart
```

---

## Chunk 4: ScanScreen Linux 目录选择

**Files:**
- Modify: `lib/features/scan/scan_screen.dart`

- [ ] **Step 1: 替换 Android 硬编码路径为 Linux 路径**

定位 `_pickDir()` 方法，替换为：

```dart
Future<void> _pickDir() async {
  if (Platform.isLinux) {
    // Linux: 常用目录快捷入口 + 自定义
    final dir = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(S.of(context).selectScanDirectory),
        children: [
          _buildDirOption(ctx, '~/Pictures', Icons.photo_library),
          _buildDirOption(ctx, '~/Downloads', Icons.download),
          _buildDirOption(ctx, '~/Desktop', Icons.desktop_windows),
          _buildDirOption(ctx, '~/Images', Icons.image),
          const Divider(height: 1),
          _buildDirOption(ctx, 'CUSTOM', Icons.folder_open),
        ],
      ),
    );

    if (dir == 'CUSTOM') {
      final customDir = await _pickDirectoryWithFileSelector();
      if (customDir != null && mounted) {
        setState(() {
          _scanDir = customDir;
          _allImages = [];
          _memes = [];
          _progress = null;
        });
        _startScan();
      }
      return;
    }

    if (dir != null && mounted) {
      setState(() {
        _scanDir = dir;
        _allImages = [];
        _memes = [];
        _progress = null;
      });
      _startScan();
    }
  } else {
    // Android: 保留原有逻辑
    // ... 原有代码 ...
  }
}

Widget _buildDirOption(BuildContext context, String path, IconData icon) {
  final expandedPath = path == 'CUSTOM' ? path : _expandPath(path);
  return SimpleDialogOption(
    onPressed: () => Navigator.pop(context, expandedPath),
    child: ListTile(
      leading: Icon(icon),
      title: Text(path == 'CUSTOM' ? S.of(context).selectDirectoryEllipsis : expandedPath),
    ),
  );
}

String _expandPath(String path) {
  if (path.startsWith('~/')) {
    final home = Platform.environment['HOME'] ?? '';
    return path.replaceFirst('~', home);
  }
  return path;
}
```

- [ ] **Step 2: 添加 Platform import**

```dart
import 'dart:io';
```

- [ ] **Step 3: 运行 flutter analyze 检查**

---

## Chunk 5: 导出目录设置

**Files:**
- Create: `lib/services/export_path_service.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/services/meme_export_service.dart`

- [ ] **Step 1: 创建 ExportPathService**

```dart
// lib/services/export_path_service.dart
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ExportPathService {
  static const _key = 'default_export_path';

  /// 获取默认导出路径
  /// 默认: ~/Downloads/MemeHelper
  static Future<String> getDefaultExportPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key);
    if (path != null && path.isNotEmpty) {
      return _expandPath(path);
    }
    return _expandPath('~/Downloads/MemeHelper');
  }

  /// 设置默认导出路径
  static Future<void> setDefaultExportPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  /// 展开 ~ 路径
  static String _expandPath(String path) {
    if (path.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '';
      return path.replaceFirst('~', home);
    }
    return path;
  }

  /// 确保导出目录存在
  static Future<String> ensureExportDir() async {
    final path = await getDefaultExportPath();
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }
}
```

- [ ] **Step 2: 在设置页面添中加导出目录设置项**

在 settings_screen.dart 中添加：

```dart
// 在存储相关设置区域添加
ListTile(
  leading: const Icon(Icons.folder),
  title: Text(S.of(context).defaultExportPath),
  subtitle: Text(_exportPath),
  onTap: () async {
    final dir = await getDirectoryPath();
    if (dir != null) {
      await ExportPathService.setDefaultExportPath(dir);
      setState(() => _exportPath = dir);
    }
  },
),
```

- [ ] **Step 3: 修改 meme_export_service.dart 使用配置路径**

```dart
// 在 exportMemes 方法中
final exportPath = await ExportPathService.ensureExportDir();
final outputFile = File('$exportPath/$filename.zip');
```

- [ ] **Step 4: 添加国际化字符串**

在 `app_en.arb` 和 `app_zh.arb` 中添加：
```json
"defaultExportPath": "默认导出目录",
"defaultExportPathZh": "默认导出目录"
```

---

## Chunk 6: 本地 LLM llama.cpp 编译

**Files:**
- Create: `linux/cpp/CMakeLists.txt`
- Create: `linux/cpp/meme_llm.cpp` (从 android 复制)
- Modify: `linux/runner/CMakeLists.txt`

- [ ] **Step 1: 创建 linux/cpp 目录结构**

```bash
mkdir -p linux/cpp/third_party
```

- [ ] **Step 2: 创建 linux/cpp/CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.13)
project(meme_llm LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 编译选项
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror")

# llama.cpp 路径
set(LLAMA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/llama.cpp")
set(MTMD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/mtmd")

# 查找系统 Vulkan 和 OpenCL
find_package(Vulkan REQUIRED)
find_package(OpenCL REQUIRED)

# 添加 llama.cpp 子目录
add_subdirectory(${LLAMA_DIR} llama.cpp_build)

# mtmd 头文件路径
include_directories(
  ${LLAMA_DIR}
  ${MTMD_DIR}/include
)

# 源文件
set(SOURCES
  meme_llm.cpp
)

# 构建共享库
add_library(meme_llm SHARED ${SOURCES})

# 链接
target_link_libraries(meme_llm
  PRIVATE
    llama
    Vulkan::Vulkan
    OpenCL::OpenCL
    pthread
)

# 安装
install(TARGETS meme_llm LIBRARY DESTINATION lib)

# 定义导出宏
target_compile_definitions(meme_llm PRIVATE MLLM_EXPORTS)
```

- [ ] **Step 3: 复制 android 端的 meme_llm.cpp**

```bash
cp android/app/src/main/cpp/meme_llm.cpp linux/cpp/meme_llm.cpp
```

- [ ] **Step 4: 创建克隆脚本**

```bash
# scripts/init-linux-third-party.sh
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LINUX_CPP_DIR="$PROJECT_DIR/linux/cpp/third_party"

mkdir -p "$LINUX_CPP_DIR"

# 克隆 llama.cpp
if [ ! -d "$LINUX_CPP_DIR/llama.cpp" ]; then
  git clone --depth 1 https://github.com/ggerganov/llama.cpp.git "$LINUX_CPP_DIR/llama.cpp"
fi

# 克隆 mtmd (如果需要)
if [ ! -d "$LINUX_CPP_DIR/mtmd" ]; then
  git clone --depth 1 https://github.com/ggerganov/mtmd.git "$LINUX_CPP_DIR/mtmd"
fi
```

- [ ] **Step 5: 修改 linux/runner/CMakeLists.txt 添加 cpp 构建**

在 `add_subdirectory("runner")` 之前添加：

```cmake
# 本地 LLM (llama.cpp)
set(LOCAL_LLM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cpp")
if(EXISTS "${LOCAL_LLM_DIR}/CMakeLists.txt")
  add_subdirectory(${LOCAL_LLM_DIR} cpp_build)
endif()
```

- [ ] **Step 6: 验证 CMake 配置**

```bash
cd /home/jiangzifeng/Project/MemeHelper
# 运行克隆脚本
chmod +x scripts/init-linux-third-party.sh
./scripts/init-linux-third-party.sh

# 测试 CMake
mkdir -p build/linux
cd build/linux
cmake ../linux -DCMAKE_BUILD_TYPE=Release
```

---

## Chunk 7: 验证与测试

**Files:**
- Modify: `linux/CMakeLists.txt` (如有需要)

- [ ] **Step 1: 构建 Linux 应用**

```bash
cd /home/jiangzifeng/Project/MemeHelper
flutter clean
flutter pub get
flutter build linux --release
```

- [ ] **Step 2: 检查构建产物**

```bash
ls -la build/linux/x64/release/bundle/lib/
# 应该看到 libmeme_llm.so (如果编译成功)
# 应该看到 super_clipboard 相关的 so
```

- [ ] **Step 3: 运行应用测试功能**

```bash
# 安装 tesseract (如果未安装)
sudo dnf install -y tesseract leptonica

# 运行应用
./build/linux/x64/release/bundle/meme_master
```

- [ ] **Step 4: 手动功能测试清单**

- [ ] 图片导入功能
- [ ] 剪贴板复制图片
- [ ] Scan 扫描选择 Linux 目录
- [ ] 导出到 ~/Downloads/MemeHelper
- [ ] OCR 文字识别
- [ ] 本地 LLM 推理 (如果模型可用)

---

## Chunk 8: 文档更新

**Files:**
- Modify: `README.md`
- Modify: `docs/DEVELOPMENT.md`

- [ ] **Step 1: 更新 README.md Linux 依赖**

```markdown
### Linux 桌面

```bash
# 系统依赖
sudo dnf install clang ninja-build libsecret-devel gtk3-devel tesseract leptonica vulkan-loader opencl-loader

# Flutter 依赖 + 启动
flutter pub get
flutter run -d linux
```
```

- [ ] **Step 2: 更新 DEVELOPMENT.md 添加 Linux 构建说明**

---

## 依赖安装命令汇总

```bash
# 系统依赖
sudo dnf install \
  clang \
  ninja-build \
  libsecret-devel \
  gtk3-devel \
  tesseract \
  leptonica \
  vulkan-loader \
  opencl-loader

# 克隆 Linux 专用依赖
./scripts/init-linux-third-party.sh

# 构建
flutter build linux --release
```
