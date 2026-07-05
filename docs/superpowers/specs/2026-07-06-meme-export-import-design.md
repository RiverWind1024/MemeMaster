# Meme 批量导出/导入功能设计

## 1. 概述

为 MemeHelper 图库添加两个功能：
1. **批量导出**：在多选模式下，将选中表情包的图片、主色调、OCR标签、AI标签、自定义标签导出为 zip 压缩包
2. **导入表情包**：通过加号菜单导入他人分享的 zip 格式表情包，不触发分析队列

## 2. 导出功能

### 2.1 zip 文件结构

```
{用户命名}.zip
└── memes/
    ├── {hash1}.png
    ├── {hash1}.json
    ├── {hash2}.png
    ├── {hash2}.json
    └── ...
manifest.json
```

### 2.2 元数据格式

**memes/{hash}.json**：
```json
{
  "filename": "xxx.png",
  "colors": [
    {"hexColor": "#FF5733", "labL": 50.0, "labA": 30.0, "labB": -40.0, "ratio": 0.6}
  ],
  "tags": [
    {"source": "ocr", "content": "哈哈哈", "confidence": 0.95},
    {"source": "llm", "content": "表情包", "confidence": 0.88},
    {"source": "manual", "content": "收藏", "confidence": 1.0}
  ],
  "description": "AI生成的描述"
}
```

**manifest.json**：
```json
{
  "version": 1,
  "exportedAt": "2026-07-06T10:30:00Z",
  "count": 10
}
```

### 2.3 用户交互

1. 长按图片进入多选模式
2. 选择要导出的表情包
3. 点击 AppBar 右侧的「导出」按钮
4. 弹出命名对话框，输入导出文件名
5. 显示进度对话框
6. 完成后保存到 download 文件夹，弹出成功提示

## 3. 导入功能

### 3.1 导入流程

1. 点击加号旋钮菜单 → 选择「导入表情包」
2. 文件选择器选择 `.zip` 文件
3. 解压到临时目录
4. 校验 `manifest.json` 存在
5. 遍历 `memes/` 目录，对每个 `{hash}.png` + `{hash}.json`：
   - 检查 hash 是否已存在（去重）
   - 复制图片到应用存储
   - 解析 json，创建 meme 记录
   - 解析并创建关联的 colors/tags
6. 清理临时目录
7. 刷新图库，弹出导入结果

### 3.2 关键约束

- 导入后**不触发分析队列**（标签已在导出时保留）
- 支持增量导入（同 hash 跳过）
- 验证 zip 结构完整性

## 4. 新增代码

| 文件 | 说明 |
|------|------|
| `lib/services/meme_export_service.dart` | 导出服务：打包 zip |
| `lib/services/meme_import_service.dart` | 导入服务：解压 + 解析 + 入库 |
| `lib/features/gallery/gallery_screen.dart` | 添加导出按钮、导入菜单项 |
| `lib/l10n/app_localizations_zh.dart` | 中文翻译 |
| `lib/l10n/app_localizations_en.dart` | 英文翻译 |

## 5. 复用现有代码

- `FileStorageService` - 图片存储
- `MemeRepository` - meme CRUD
- `MemeDao` / `TagDao` / `ColorDao` - 数据库操作
- Android `writeToDownloads` MethodChannel - 写入公共下载目录
- `archive` 包（pubspec.yaml 已依赖）- zip 压缩

## 6. 进度

- [x] 设计完成
- [ ] 实现导出服务
- [ ] 实现导入服务
- [ ] 修改 GalleryScreen UI
- [ ] 添加国际化字符串
- [ ] 测试
