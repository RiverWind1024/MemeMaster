# MemeMaster

表情包管理工具 —— 导入、组织、智能搜索、颜色识别、语义分析。支持 Linux / Android 双平台。

## 功能

- **图片导入** — 自动去重（SHA256 哈希），按日期归档存储
- **颜色搜索** — HSV 滑块选色，CIE Lab ΔE 色差匹配
- **OCR 文字识别** — Google ML Kit，支持中英文
- **AI 标签与描述** — OpenAI / Ollama / 本地 LLM 驱动，根据 OCR 结果自动生成标签和文字描述
- **Token 用量追踪** — 记录每次 LLM 调用的 prompt/completion token 数，按日统计，支持查看今日用量和任意时间范围汇总
- **统计页面** — 用户使用数据总览，包含 GitHub 风格热度图（贡献日历）、日期范围选择器（7/30/365 天）、导入/复制/收藏/Token 用量趋势列表
- **S3 云同步** — 兼容 AWS S3、MinIO、Cloudflare R2，支持全量上传/下载和增量同步
- **配置导出/导入** — 一键备份/恢复 S3、LLM、颜色提取、主题、语言等全部配置，支持文件保存和分享
- **国际化支持** — 中英文双语界面，ARB 文件管理
- **文件夹管理** — 图片分组
- **定时同步** — 可配置的自动同步间隔（5 分钟 ~ 1 天）

## 快速开始

```bash
# 系统依赖（Linux）
sudo dnf install clang ninja-build libsecret-devel gtk3-devel

# 运行
flutter pub get
flutter run -d linux
```

## 详细文档

| 文档 | 内容 |
|---|---|
| [docs/USAGE.md](docs/USAGE.md) | 用户使用手册（导入/搜索/同步等完整功能） |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | 开发者指南（环境搭建/构建/测试/架构） |

## 路线图

- [ ] **UI 优化** — 改进热力图交互（点击查看详情）、更流畅的动画过渡、移动端适配
- [ ] **llama.cpp 本地推理性能优化** — GPU 加速（cuBLAS/Vulkan）、量化模型加载优化、批处理推理
- [ ] **Meme 检测 Benchmark** — 建立标准评测数据集，对比不同模型/提示词的效果指标（准确率/召回率/F1）
- [ ] **全平台构建测试** — Linux/Windows/iOS/macOS 跨平台构建验证，修复各平台特定问题
- [ ] **全数据导出 & 压缩包重建** — 将库中所有图片和元数据导出为可移植压缩包（ZIP/TAR），支持从压缩包完整重建
- [ ] **崩溃报告** — 自动捕获未处理的异常，发送到服务端以便远程诊断
- [ ] **检查更新 / 自动更新** — 从 GitHub Releases 检查新版本，支持一键下载和安装更新
