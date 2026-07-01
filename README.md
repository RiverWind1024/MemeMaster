# MemeHelper

表情包/图片管理工具 —— 智能搜索、颜色识别、语义分析。

## 功能

- **图片导入** — 自动去重（SHA256 哈希），按日期归档存储
- **颜色搜索** — HSV 滑块选色，CIE Lab ΔE 色差匹配
- **OCR 文字识别** — Google ML Kit，支持中英文
- **AI 标签与描述** — OpenAI / Ollama 驱动，根据 OCR 结果自动生成
- **S3 云同步** — 兼容 AWS S3、MinIO、Cloudflare R2
- **文件夹管理** — 图片分组
- **Linux / Android 双平台**支持

## 快速开始

```bash
# 系统依赖（Linux）
sudo dnf install clang ninja-build libsecret-devel gtk3-devel

# 运行
flutter pub get
flutter run -d linux
```

详细说明请参阅：

| 文档 | 内容 |
|---|---|
| [docs/USAGE.md](docs/USAGE.md) | 用户使用手册（导入/搜索/同步等完整功能） |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | 开发者指南（环境搭建/构建/测试/架构） |
