# Meme 批量导出/导入功能实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在图库多选模式下添加导出功能，以及通过加号菜单添加导入表情包功能

**Architecture:**
- 导出服务 `MemeExportService`：将选中 meme 打包为 zip（每个 meme 单独文件夹，包含图片和 json 元数据）
- 导入服务 `MemeImportService`：解压 zip，解析元数据，创建 meme 记录（不触发分析队列）
- UI 修改：多选 AppBar 添加导出按钮，加号菜单添加导入入口

**Tech Stack:** archive 包（已在 pubspec.yaml）, FileStorageService, MemeRepository, MethodChannel (writeToDownloads)

---

## Chunk 1: 创建 MemeExportService

**Files:**
- Create: `lib/services/meme_export_service.dart`

### 任务 1: 创建 MemeExportService 导出服务

- [ ] **Step 1: 创建 meme_export_service.dart**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../core/database/database.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';

/// 导出数据包格式
class MemeExportItem {
  final String hash;
  final String filename;
  final String imagePath;
  final List<ColorEntry> colors;
  final List<TagEntry> tags;
  final String? description;

  MemeExportItem({
    required this.hash,
    required this.filename,
    required this.imagePath,
    required this.colors,
    required this.tags,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'colors': colors.map((c) => {
      'hexColor': c.hexColor,
      'labL': c.labL,
      'labA': c.labA,
      'labB': c.labB,
      'ratio': c.ratio,
    }).toList(),
    'tags': tags.map((t) => {
      'source': t.source,
      'content': t.content,
      'confidence': t.confidence,
    }).toList(),
    'description': description,
  };
}

/// Meme 导出服务
class MemeExportService {
  final MemeRepository _memeRepo;
  final FileStorageService _storage;

  MemeExportService({
    required MemeRepository memeRepo,
    required FileStorageService storage,
  })  : _memeRepo = memeRepo,
        _storage = storage;

  /// 导出 memes 到 zip 文件
  /// 返回 zip 文件路径
  Future<String> exportMemes({
    required List<String> memeIds,
    required String outputPath,
    void Function(int current, int total)? onProgress,
  }) async {
    final archive = Archive();
    final memes = <MemeExportItem>[];

    // 1. 收集 meme 数据
    for (int i = 0; i < memeIds.length; i++) {
      final id = memeIds[i];
      final meme = await _memeRepo.getById(id);
      if (meme == null) continue;

      final colors = await _memeRepo.getColors(id);
      final tags = await _memeRepo.getTags(id);

      memes.add(MemeExportItem(
        hash: meme.fileHash,
        filename: meme.filename,
        imagePath: meme.filePath,
        colors: colors,
        tags: tags,
        description: meme.description,
      ));

      onProgress?.call(i + 1, memeIds.length);
    }

    // 2. 添加 manifest.json
    final manifest = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': memes.length,
    };
    archive.addFile(ArchiveFile(
      'manifest.json',
      utf8.encode(jsonEncode(manifest)).length,
      utf8.encode(jsonEncode(manifest)),
    ));

    // 3. 添加每个 meme 的图片和元数据
    for (final meme in memes) {
      final imageFile = await _storage.getImage(meme.imagePath);
      if (await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();
        archive.addFile(ArchiveFile(
          'memes/${meme.hash}.png',
          imageBytes.length,
          imageBytes,
        ));
      }

      final jsonBytes = utf8.encode(jsonEncode(meme.toJson()));
      archive.addFile(ArchiveFile(
        'memes/${meme.hash}.json',
        jsonBytes.length,
        jsonBytes,
      ));
    }

    // 4. 编码为 zip
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception('Failed to encode zip');

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(zipData);

    return outputPath;
  }
}
```

- [ ] **Step 2: 验证代码无语法错误**

Run: `cd <REPO_ROOT> && flutter analyze lib/services/meme_export_service.dart`
Expected: No issues found

---

## Chunk 2: 创建 MemeImportService

**Files:**
- Create: `lib/services/meme_import_service.dart`

### 任务 2: 创建 MemeImportService 导入服务

- [ ] **Step 1: 创建 meme_import_service.dart**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/database/database.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';

/// 导入结果
class MemeImportResult {
  final int success;
  final int skipped;
  final List<String> errors;

  MemeImportResult({
    required this.success,
    required this.skipped,
    required this.errors,
  });
}

/// Meme 导入服务
class MemeImportService {
  final MemeRepository _memeRepo;
  final FileStorageService _storage;
  final Uuid _uuid = const Uuid();

  MemeImportService({
    required MemeRepository memeRepo,
    required FileStorageService storage,
  })  : _memeRepo = memeRepo,
        _storage = storage;

  /// 从 zip 文件导入 memes
  /// 返回导入结果
  Future<MemeImportResult> importFromZip({
    required String zipPath,
    void Function(int current, int total)? onProgress,
  }) async {
    int success = 0;
    int skipped = 0;
    final errors = <String>[];

    // 1. 解压到临时目录
    final tempDir = Directory.systemTemp.createTempSync('meme_import_');
    try {
      final zipFile = File(zipPath);
      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // 解压所有文件
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final outputFile = File(p.join(tempDir.path, filename));
          await outputFile.create(recursive: true);
          await outputFile.writeAsBytes(file.content as List<int>);
        }
      }

      // 2. 读取 manifest.json
      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        return MemeImportResult(
          success: 0,
          skipped: 0,
          errors: ['Invalid zip: manifest.json not found'],
        );
      }

      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
      final count = manifest['count'] as int? ?? 0;

      // 3. 遍历 memes/ 目录导入每个 meme
      final memesDir = Directory(p.join(tempDir.path, 'memes'));
      if (!await memesDir.exists()) {
        return MemeImportResult(
          success: 0,
          skipped: 0,
          errors: ['Invalid zip: memes/ directory not found'],
        );
      });

      int processed = 0;
      await for (final entity in memesDir.list()) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          if (filename.endsWith('.png')) {
            final hash = p.basenameWithoutExtension(filename);
            final jsonFile = File(p.join(memesDir.path, '$hash.json'));

            if (await jsonFile.exists()) {
              try {
                final result = await _importSingleMeme(
                  imageFile: entity,
                  jsonFile: jsonFile,
                  hash: hash,
                );
                if (result == 'success') {
                  success++;
                } else if (result == 'skipped') {
                  skipped++;
                }
              } catch (e) {
                errors.add('$hash: $e');
              }
            }
          }
        }

        processed++;
        onProgress?.call(processed, count);
      }

      return MemeImportResult(
        success: success,
        skipped: skipped,
        errors: errors,
      );
    } finally {
      // 4. 清理临时目录
      await tempDir.delete(recursive: true);
    }
  }

  /// 导入单个 meme
  /// 返回: 'success', 'skipped', 或抛出异常
  Future<String> _importSingleMeme({
    required File imageFile,
    required File jsonFile,
    required String hash,
  }) async {
    // 检查是否已存在（通过 hash 去重）
    final existing = await _memeRepo.getByFileHash(hash);
    if (existing != null) {
      return 'skipped';
    }

    // 解析元数据
    final jsonContent = await jsonFile.readAsString();
    final data = jsonDecode(jsonContent) as Map<String, dynamic>;

    // 复制图片到存储
    final storedPath = await _storage.storeImage(imageFile.path, hash);
    final fileSize = await imageFile.length();

    // 获取图片尺寸（简单通过文件名判断）
    final filename = data['filename'] as String? ?? '$hash.png';
    final ext = p.extension(filename).toLowerCase();
    final mimeType = _extToMimeType(ext);

    // 创建 meme 记录
    final now = DateTime.now().millisecondsSinceEpoch;
    final meme = Meme(
      id: _uuid.v4(),
      filename: filename,
      filePath: storedPath,
      fileSize: fileSize,
      mimeType: mimeType,
      width: 0, // 导入时不确定，留空或后续补充
      height: 0,
      analysisStatus: 'done', // 标记为已完成，不触发分析
      colorAnalysisStatus: 'done',
      ocrAnalysisStatus: 'done',
      aiAnalysisStatus: 'done',
      fileHash: hash,
      copyCount: 0,
      createdAt: now,
      updatedAt: now,
      importedAt: now,
      description: data['description'] as String?,
      source: 'imported',
    );

    await _memeRepo.create(
      filename: meme.filename,
      filePath: meme.filePath,
      fileSize: meme.fileSize,
      mimeType: meme.mimeType,
      width: meme.width,
      height: meme.height,
      fileHash: meme.fileHash,
    );

    // 保存 colors
    final colors = data['colors'] as List<dynamic>? ?? [];
    for (final c in colors) {
      final colorMap = c as Map<String, dynamic>;
      await _memeRepo.saveColors([
        ColorEntry(
          id: _uuid.v4(),
          memeId: meme.id,
          hexColor: colorMap['hexColor'] as String,
          labL: (colorMap['labL'] as num).toDouble(),
          labA: (colorMap['labA'] as num).toDouble(),
          labB: (colorMap['labB'] as num).toDouble(),
          ratio: (colorMap['ratio'] as num).toDouble(),
        ),
      ]);
    }

    // 保存 tags
    final tags = data['tags'] as List<dynamic>? ?? [];
    for (final t in tags) {
      final tagMap = t as Map<String, dynamic>;
      await _memeRepo.saveTags([
        TagEntry(
          id: _uuid.v4(),
          memeId: meme.id,
          source: tagMap['source'] as String,
          content: tagMap['content'] as String,
          confidence: (tagMap['confidence'] as num?)?.toDouble() ?? 1.0,
        ),
      ]);
    }

    return 'success';
  }

  String _extToMimeType(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'image/png';
    }
  }
}
```

- [ ] **Step 2: 验证代码无语法错误**

Run: `cd <REPO_ROOT> && flutter analyze lib/services/meme_import_service.dart`
Expected: No issues found

---

## Chunk 3: 修改 GalleryScreen UI

**Files:**
- Modify: `lib/features/gallery/gallery_screen.dart`

### 任务 3: 添加导出按钮到多选 AppBar

- [ ] **Step 1: 添加导出方法**

在 `_GalleryScreenState` 类中添加以下方法：

```dart
Future<void> _exportSelected() async {
  if (_selectedIds.isEmpty) return;

  // 1. 弹出命名对话框
  final controller = TextEditingController(
    text: 'meme_export_${DateTime.now().millisecondsSinceEpoch}',
  );
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.of(context).exportMemes),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: S.of(context).exportFileName,
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(S.of(context).cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(S.of(context).export),
        ),
      ],
    ),
  );

  if (name == null || name.isEmpty) return;

  // 2. 获取 download 目录路径
  // Android 使用 MethodChannel，iOS/其他平台使用 getDownloadsDirectory
  String downloadPath;
  if (Platform.isAndroid) {
    // 调用原生方法写入 Downloads 目录
    downloadPath = await _getAndroidDownloadPath('$name.zip');
  } else {
    final dir = await getDownloadsDirectory();
    downloadPath = p.join(dir!.path, '$name.zip');
  }

  // 3. 显示进度对话框
  final progressController = StreamController<double>();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StreamBuilder<double>(
      stream: progressController.stream,
      builder: (context, snapshot) {
        final progress = snapshot.data ?? 0.0;
        return AlertDialog(
          title: Text(S.of(context).exporting),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Text('${(progress * 100).toInt()}%'),
            ],
          ),
        );
      },
    ),
  );

  try {
    // 4. 执行导出
    final exportService = MemeExportService(
      memeRepo: ref.read(memeRepositoryProvider),
      storage: ref.read(fileStorageServiceProvider),
    );

    await exportService.exportMemes(
      memeIds: _selectedIds.toList(),
      outputPath: downloadPath,
      onProgress: (current, total) {
        progressController.add(current / total);
      },
    );

    if (mounted) {
      Navigator.pop(context); // 关闭进度对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).exportSuccess(downloadPath))),
      );
    }
  } catch (e) {
    if (mounted) {
      Navigator.pop(context); // 关闭进度对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).exportFailed(e.toString()))),
      );
    }
  } finally {
    await progressController.close();
    _exitSelectionMode();
  }
}

Future<String> _getAndroidDownloadPath(String filename) async {
  const channel = MethodChannel('com.memehelper.app/downloads');
  final result = await channel.invokeMethod<String>('getDownloadPath', {
    'filename': filename,
  });
  return result ?? (await getTemporaryDirectory()).path + '/$filename';
}
```

- [ ] **Step 2: 在 _buildSelectionAppBar 中添加导出按钮**

找到 `_buildSelectionAppBar` 方法，在 actions 中添加导出按钮（在删除按钮之前）：

```dart
IconButton(
  icon: const Icon(Icons.archive_outlined),
  onPressed: _exportSelected,
  tooltip: S.of(context).export,
),
```

- [ ] **Step 3: 添加 archive 导入**

在文件顶部添加：

```dart
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
```

- [ ] **Step 4: 验证代码无语法错误**

Run: `cd <REPO_ROOT> && flutter analyze lib/features/gallery/gallery_screen.dart`
Expected: No issues found

### 任务 4: 添加导入菜单项到加号旋钮

- [ ] **Step 1: 添加导入方法**

在 `_GalleryScreenState` 类中添加：

```dart
Future<void> _importMemePack() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['zip'],
  );

  if (result == null || result.files.isEmpty) return;

  final zipPath = result.files.first.path;
  if (zipPath == null) return;

  // 显示导入进度
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(S.of(context).importing),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(S.of(context).pleaseWait),
        ],
      ),
    ),
  );

  try {
    final importService = MemeImportService(
      memeRepo: ref.read(memeRepositoryProvider),
      storage: ref.read(fileStorageServiceProvider),
    );

    final importResult = await importService.importFromZip(zipPath: zipPath);

    if (mounted) {
      Navigator.pop(context); // 关闭进度对话框
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          S.of(context).importMemePackResult(
            importResult.success,
            importResult.skipped,
            importResult.errors.length,
          ),
        )),
      );
    }
  } catch (e) {
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).importMemePackFailed(e.toString()))),
      ),
    );
  }
}
```

- [ ] **Step 2: 添加 file_picker 导入**

在文件顶部添加：

```dart
import 'package:file_picker/file_picker.dart';
```

- [ ] **Step 3: 在 _buildFab 中添加导入菜单项**

找到 `_buildFab` 方法中的 `fabActions` 列表，添加导入菜单项：

```dart
final fabActions = [
  _SpeedDialAction(Icons.search, s.scanFolder),
  _SpeedDialAction(Icons.add_photo_alternate, s.importImage),
  _SpeedDialAction(Icons.content_paste, s.importFromClipboard),
  _SpeedDialAction(Icons.photo_library, s.newAlbumShort),
  _SpeedDialAction(Icons.archive, s.importMemePack), // 新增
];
```

然后在 switch 中添加 case：

```dart
case 4:
  _importMemePack();
```

---

## Chunk 4: 添加国际化字符串

**Files:**
- Modify: `lib/l10n/app_localizations_zh.dart`
- Modify: `lib/l10n/app_localizations_en.dart`
- Modify: `lib/l10n/app_localizations.dart`

### 任务 5: 添加中英文国际化字符串

- [ ] **Step 1: 在 app_localizations.dart 中添加方法声明**

在 `S` 类中添加：

```dart
String get exportMemes;
String get export;
String get exportFileName;
String get exporting;
String get exportSuccess(String path);
String get exportFailed(String error);
String get importMemePack;
String get importMemePackResult(int success, int skipped, int errors);
String get importMemePackFailed(String error);
String get pleaseWait;
```

- [ ] **Step 2: 在 app_localizations_zh.dart 中添加中文实现**

```dart
@override
String get exportMemes => '导出表情包';

@override
String get export => '导出';

@override
String get exportFileName => '文件名';

@override
String get exporting => '正在导出...';

@override
String exportSuccess(String path) => '导出成功: $path';

@override
String exportFailed(String error) => '导出失败: $error';

@override
String get importMemePack => '导入表情包';

@override
String importMemePackResult(int success, int skipped, int errors) {
  if (errors > 0) {
    return '导入完成: 成功 $success, 跳过 $skipped, 失败 $errors';
  }
  return '导入完成: 成功 $success, 跳过 $skipped';
}

@override
String importMemePackFailed(String error) => '导入失败: $error';

@override
String get pleaseWait => '请稍候...';
```

- [ ] **Step 3: 在 app_localizations_en.dart 中添加英文实现**

```dart
@override
String get exportMemes => 'Export Memes';

@override
String get export => 'Export';

@override
String get exportFileName => 'File name';

@override
String get exporting => 'Exporting...';

@override
String exportSuccess(String path) => 'Export successful: $path';

@override
String exportFailed(String error) => 'Export failed: $error';

@override
String get importMemePack => 'Import Meme Pack';

@override
String importMemePackResult(int success, int skipped, int errors) {
  if (errors > 0) {
    return 'Import complete: $success success, $skipped skipped, $errors failed';
  }
  return 'Import complete: $success success, $skipped skipped';
}

@override
String importMemePackFailed(String error) => 'Import failed: $error';

@override
String get pleaseWait => 'Please wait...';
```

---

## Chunk 5: 验证和测试

### 任务 6: 整体验证

- [ ] **Step 1: 运行 flutter analyze**

Run: `cd <REPO_ROOT> && flutter analyze`
Expected: No errors

- [ ] **Step 2: 提交代码**

```bash
git add -A && git commit -m "feat: 添加 meme 批量导出/导入功能
- 新增 MemeExportService 导出服务
- 新增 MemeImportService 导入服务
- 多选模式下添加导出按钮
- 加号菜单添加导入表情包入口"
```

---

## 依赖检查

确认 pubspec.yaml 已包含必要依赖：
- `archive: ^3.6.0` (已有)
- `file_picker: ^11.0.2` (已有)
- `path_provider: ^2.1.5` (已有)
- `path: ^1.9.1` (已有)
