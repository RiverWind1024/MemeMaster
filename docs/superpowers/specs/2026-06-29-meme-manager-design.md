# Meme 表情包管理工具 — 设计方案

> 日期: 2026-06-29
> 技术栈: Flutter + llama.cpp + SQLite(sqlite-vec) + S3

---

## 1. 项目概述

一款面向个人的 Meme 表情包管理工具，解决"表情包太多难找"的痛点。核心能力是**智能理解 meme 内容**（OCR 识文 + LLM 理解语义 + 颜色提取），让用户通过自然语言或颜色就能快速定位到想要的表情包。

### 核心设计原则

- **离线优先**：核心功能（搜索、分析）全部本地完成，无 API 费用
- **后台渐进式索引**：导入即用，分析在后台完成，完成后自动纳入搜索
- **数据归用户所有**：支持 S3 协议多端同步，数据不锁定

---

## 2. 技术选型

| 层面 | 选型 | 理由 |
|------|------|------|
| UI 框架 | **Flutter 3.x (Material 3)** | 跨平台基础，一期内核 Android，后续可扩展 |
| 状态管理 | **Riverpod 2.x** | 声明式、编译安全、适合复杂异步状态 |
| 本地数据库 | **drift (SQLite ORM) + sqlite-vec** | 类型安全 ORM + 原生向量搜索支持 |
| 图像处理 | **Dart `image` 库** | 纯 Dart，无原生依赖，可做颜色量化 |
| OCR | **Google ML Kit Text Recognition** | 端侧 OCR，离线运行，中文识别优秀 |
| LLM 推理 | **llama.cpp (.so) → dart:ffi** | GGUF 模型格式，与 LM Studio/Ollama 生态兼容 |
| 多模态模型 | **LLaVA / Moondream 系列的 GGUF 版** | 可"看"图生成自然语言描述 |
| S3 同步 | **MinIO Dart SDK / AWS S3 SDK** | 兼容所有 S3 协议存储（AWS / Cloudflare R2 / 自建 MinIO） |
| 后台任务 | **workmanager + flutter_isolate** | Android 后台调度 + 隔离区计算不阻塞 UI |
| 导航 | **go_router** | 声明式路由，支持深度链接 |

---

## 3. 架构设计

### 3.1 分层架构

```
┌────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  Gallery Screen │ Search Screen │ Folder Screen │ Settings │
│  Import Dialog │ Color Picker │ Model Manager              │
└──────────────────────────┬─────────────────────────────────┘
                           │
┌──────────────────────────┴─────────────────────────────────┐
│                  State Management (Riverpod)                │
│  memeProvider │ searchProvider │ folderProvider             │
│  importProvider │ syncProvider │ analysisProvider           │
└──────────────────────────┬─────────────────────────────────┘
                           │
┌──────────────────────────┴─────────────────────────────────┐
│                    Service Layer                             │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐  │
│  │ImportSvc  │ │AnalysisSvc│ │SearchSvc  │ │SyncSvc    │  │
│  │(zip/batch)│ │(OCR+LLM+ │ │(semantic+ │ │(S3 diff)  │  │
│  │           │ │ color)   │ │ color)    │ │           │  │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘  │
└──────────────────────────┬─────────────────────────────────┘
                           │
┌──────────────────────────┴─────────────────────────────────┐
│                    Repository Layer                          │
│  MemeRepository │ FolderRepository │ TagRepository          │
│  ColorRepository │ EmbeddingRepository │ SyncStateRepo      │
└──────────────────────────┬─────────────────────────────────┘
                           │
┌──────────────────────────┴─────────────────────────────────┐
│                      Data Layer                              │
│  ┌────────────────┐ ┌──────────────┐ ┌──────────────────┐  │
│  │ SQLite (drift) │ │  File System  │ │  llama.cpp .so  │  │
│  │ metadata +     │ │  meme images │ │  GGUF models    │  │
│  │ vectors        │ │  + exports   │ │  + inference     │  │
│  └────────────────┘ └──────────────┘ └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 数据模型

```
┌─────────────────────────┐
│         memes           │
├─────────────────────────┤
│ id          UUID  ← PK  │
│ filename    TEXT        │
│ file_path   TEXT        │  ← App 内部相对路径
│ file_size   INTEGER     │
│ mime_type   TEXT        │  ← image/png, image/jpeg, image/gif, image/webp
│ width       INTEGER     │
│ height      INTEGER     │
│ folder_id   UUID  → FK  │
│ analysis_status TEXT    │  ← pending / processing / done / failed
│ file_hash   TEXT        │  ← SHA256 去重
│ created_at  INTEGER     │  ← unix 毫秒
│ updated_at  INTEGER     │
│ imported_at INTEGER     │
└──────────┬──────────────┘
           │
     ┌─────┼──────────┐
     │     │          │
     ▼     ▼          ▼
┌───────────┐ ┌──────────┐ ┌──────────────┐
│   tags    │ │  colors  │ │  embeddings  │
├───────────┤ ├──────────┤ ├──────────────┤
│ id  PK    │ │ id  PK   │ │ meme_id  PK  │
│ meme_id   │ │ meme_id  │ │ vector BLOB  │
│ source    │ │ hex_color│ │ model_id     │
│ content   │ │ lab_l    │ │ updated_at   │
│ confidence│ │ lab_a    │ │              │
│           │ │ lab_b    │ │              │
│           │ │ ratio    │ │              │
│           │ └──────────┘ └──────────────┘
│ created_at│
└───────────┘

┌──────────────────────┐
│       folders        │
├──────────────────────┤
│ id         UUID  PK  │
│ name       TEXT      │
│ parent_id  UUID  FK  │
│ sort_order INTEGER   │
│ icon       TEXT      │
│ created_at INTEGER   │
└──────────────────────┘

┌──────────────────────┐
│    analysis_queue    │
├──────────────────────┤
│ id         UUID  PK  │
│ meme_id    UUID  FK  │
│ status     TEXT      │  ← queued / running / done / failed
│ priority   INTEGER   │  ← 默认 0，用户手动触发的分析可设为更高优先级
│ retry_count INTEGER  │
│ error_msg  TEXT      │
│ created_at INTEGER   │
│ started_at INTEGER   │
│ done_at    INTEGER   │
└──────────────────────┘

┌──────────────────────┐
│    sync_state        │
├──────────────────────┤
│ id         TEXT  PK  │  ← 'last_sync_time'
│ value      TEXT      │
│ updated_at INTEGER   │
└──────────────────────┘
```

### 3.3 字段说明

**`memes.analysis_status` 状态机**:

```
pending ──→ processing ──→ done
                │
                └──→ failed (可重试)
```

- **pending**: 刚导入，尚未分析
- **processing**: 正在后台分析中
- **done**: 已完成分析，纳入搜索
- **failed**: 分析失败（模型未下载、图片损坏等），可手动重试

**`tags.source` 来源**:

| 来源 | 说明 | 示例 |
|------|------|------|
| `ocr` | OCR 从图片中提取的文字 | "我太难了", "Sad Frog" |
| `llm` | 多模态 LLM 生成的描述 | "悲伤的青蛙表情，绿色背景，表达无奈情绪" |
| `color` | 自动生成的颜色标签 | "蓝色主调", "暖色调" |
| `user` | 用户手动标注的标签 | "工作群", "搞笑" |

---

## 4. 核心流程设计

### 4.1 导入 → 后台分析 → 可搜索

```
用户操作: 导入 meme（多选 / ZIP / 目录选择）
    │
    ▼
① App 将原图复制到内部存储 (app_dir/memes/{yyyy}/{mm}/{uuid}.{ext})
② 写入 memes 表 (analysis_status = 'pending')
③ 写入 analysis_queue 表 (status = 'queued')
④ 触发后台分析任务
    │
    ▼
后台 Isolate (并发控制: 最多 2 个 isolate 同时运行):
  ⑤ 更新 status = 'processing'
  ⑥ ⬛ 颜色提取 (必须): 量化图片为 3-5 个主色调 → 写入 colors 表
   │
   ├─ ⑦ [可选] OCR: 若已开启"OCR 识别"且有 OCR 模型
   │      用 ML Kit 识别图片中文字 → 写入 tags(source=ocr)
   │
   ├─ ⑧ [可选] LLM 描述: 若已开启"LLM 识别"且有 LLM 模型
   │      用多模态 LLM 生成图片描述 → 写入 tags(source=llm)
   │
   └─ ⑨ [可选] Embedding: 若已下载 embedding 模型
         将已有描述文本(OCR+LLM+标签)合并后生成向量 → 写入 embeddings 表
   │
  ⑩ 更新 status = 'done'
    │
    ▼
用户搜索时: 根据已有数据提供不同级别的搜索能力
```

**管线模块化设计 (Pipeline Toggles)**:

| 步骤 | 默认 | 是否可关 | 依赖条件 |
|------|------|---------|---------|
| 颜色提取 | ✅ 开启 | ❌ 不可关（始终执行） | 无 |
| OCR 文字识别 | ❌ 关闭 | ✅ 可开关 | 设备需支持 (ML Kit 自动下载) |
| LLM 描述生成 | ❌ 关闭 | ✅ 可开关 | 需下载多模态 LLM 模型 |
| Embedding 向量化 | n/a | n/a | 需下载 embedding 模型（有描述文本后才需要） |

**搜索能力级别 (根据已有数据自动适配)**:

| 已有数据 | 可用搜索方式 |
|---------|-------------|
| 仅颜色 | 颜色搜索 + 文件名搜索 |
| 颜色 + OCR 标签 | 颜色搜索 + 关键词搜索 (匹配 OCR 文本) |
| 颜色 + LLM 描述 | 颜色搜索 + 关键词搜索 (匹配 LLM 描述 + 标签) |
| 颜色 + OCR + LLM + Embedding | 以上全部 + 语义向量搜索 |

**模型角色说明**:
- **多模态 LLM（如 LLaVA）**: 负责将 meme 图片→自然语言描述，管线中最重的步骤（2-8GB），可选
- **Embedding 模型（如 all-MiniLM-L6-v2）**: 负责将文本→向量，模型小（~50MB），可选
- 两者独立：没有 LLM → 只用 OCR 文本做 embedding/keyword；没有 embedding → 只有颜色 + 关键词搜索
- **所有模型均非必须**：App 在无任何模型的情况下仍可正常工作（颜色搜索 + 文件名搜索）

**并发与资源管理**:
- 最多同时启动 2 个 flutter_isolate 执行分析任务，避免 OOM
- llama.cpp 模型实例是单例，同一时间只接受一个推理请求，使用内部请求队列
- 模型下载任务单独运行，不占用分析 isolate
- 若系统内存不足，iOS/Android 可能杀掉后台进程 —— workmanager 会在下次触发时恢复队列中未完成的任务
- 如果 OCR/LLM 被用户关闭，对应步骤自动跳过，不报错
- 如果 OCR/LLM 开启但模型未下载，分析正常进行但 SnackBar 提示"XXX 模型未下载，该功能暂不可用"

### 4.2 混合搜索 (自动降级)

```
用户输入: "悲伤的青蛙表情"
    │
    ▼
① 查询组装:
   ├─ 是否已下载 Embedding 模型？
   │  ├─ 是 → 混合搜索模式 (语义 + 关键词 + 颜色)
   │  └─ 否 → 基础搜索模式 (关键词 + 颜色)
   │
   ▼
② [如果有 Embedding 模型] 生成查询向量:
   输入查询文本 → 调用 llama.cpp embedding 模式 → 生成查询向量
   sqlite-vec 余弦相似度搜索:
   SELECT m.*, vec_distance_cosine(e.vector, ?) AS distance
   FROM embeddings e JOIN memes m ON m.id = e.meme_id
   WHERE m.analysis_status = 'done'
   ORDER BY distance ASC
   LIMIT 50
    │
    ▼
③ 关键词搜索 (无论如何都会执行):
   SELECT m.* FROM memes m
   JOIN tags t ON t.meme_id = m.id
   WHERE m.analysis_status = 'done'
   AND (t.content LIKE '%悲伤%' OR t.content LIKE '%青蛙%')
   GROUP BY m.id
   ORDER BY COUNT(t.id) DESC  -- 匹配标签越多越靠前
   LIMIT 50
    │
    ▼
④ 颜色搜索 (若有颜色条件):
   若查询中检测到颜色词(如"蓝色") → 映射到色值 → 执行 ΔE 颜色搜索
   或无颜色条件时跳过此步骤
    │
    ▼
⑤ 结果合并:
   ├─ 混合搜索: 语义结果(权重0.6) + 关键词结果(权重0.3) + 颜色结果(权重0.1)
   ├─ 基础搜索: 关键词结果(权重0.7) + 颜色结果(权重0.3)
   └─ 仅颜色: 按 ΔE 色差升序
    │
    ▼
⑥ 返回排序后的 Meme 列表
```

### 4.3 颜色搜索

```
用户选择: 蓝色系 (#1565C0)
  + 可选: 第二配色白色
    │
    ▼
① 取目标颜色的 LAB 值 (CIE Lab 色彩空间) —— colors 表存的是 hex(RGB),
   查询时在内存中完成 RGB→LAB 转换，每色仅需一次转换
② 遍历 colors 表，计算每个 meme 主色调与目标色的 ΔE 色差

   性能优化:
   - 颜色空间离散化: 将 LAB 空间量化为 360 个色相桶(hue bin)，
     搜索时先筛选同色相桶的 meme（索引加速），再精确计算 ΔE
   - 预计算: 在分析阶段除了存 hex_color，也预存 LAB 值(l_channel,
     a_channel, b_channel 字段) 到 colors 表，避免搜索时重复转换
   - 结果缓存: 常用颜色搜索条件缓存前 100 条结果，30 秒过期

③ 多色模式: 取颜色组合的加权相似度（若只有一个主色调匹配则加权降级）
④ 按色差升序排序，取 TOP 100
⑤ 结果可按 "配色相似度" 与 "语义相关度" 加权组合排序（权重可调）
⑥ 返回结果
```

### 4.4 导入 ZIP / 目录

```
ZIP 导入:
① 用户选择 .zip 文件
② App 解压到临时目录
③ 遍历所有图片文件（支持的格式: png/jpg/jpeg/gif/webp）
④ 逐张执行标准导入流程（复制+写库+入队）
⑤ 清理临时目录
⑥ 报告: "成功导入 N 张，跳过 M 张（重复/格式不支持）"

目录导入:
① 用户选择手机上的目录
② 递归扫描所有图片文件
③ 保留相对目录结构 → 在 App 内创建对应文件夹
④ 逐张执行标准导入流程
⑤ 报告导入结果
```

### 4.5 S3 多端同步

```
配置阶段:
  用户填写: Endpoint / Bucket / Access Key / Secret Key / Region
  验证连通性 → 保存配置

同步方向: 双向

同步数据范围:
  同步的: memes 表 + tags 表 + colors 表 + folders 表（含图片文件）
  不同步的: embeddings 表（每端各自本地 LLM 重新生成）、LLM 模型文件、临时文件/缓存

同步流程:
  ① 从 SQLite 导出 memes/folders/tags/colors 数据为 JSON（排除 embeddings 和二进制数据）
  ② 计算差异: 对比本地同步状态与远端文件清单
  ③ 上传: 新增/changed 的 meme 图片 + 增量 JSON 导出（用 memes.updated_at 判断变更）
  ④ 下载: 远端有而本地没有的 meme 图片 + 增量 JSON
  ⑤ 合并策略:
     - 记录级别: 以 updated_at 较新的记录覆盖较旧的
     - 关联表处理: tags/colors 跟随 memes 整体替换（不独立逐字段合并），避免数据不一致
     - 删除冲突: 若 A 端删除了某 meme，B 端同时修改了它 → 以"后操作者"为准，记录删除标记
  ⑥ 下载的 meme 不自动触发分析（保持 analysis_status=pending），由后台分析队列自行处理
  ⑦ 记录同步时间

回退与重试:
  - 同步中若网络中断，回滚本次同步变更，标记同步状态为"last_failed"
  - 下次同步自动重试，最多重试 3 次，超过后通知用户手动处理

触发条件:
  - 手动触发（"立即同步"按钮）
  - 后台自动: WiFi 连接 + 电量充足时
  - App 启动时检查（仅检查，不自动拉取，需用户确认）
```

---

## 5. 模块划分

| 模块 | 职责 | 关键文件 |
|------|------|---------|
| **core/database** | SQLite 数据库定义、表结构、migration（drift schema version 管理） | `lib/core/database/` |
| **core/llm** | llama.cpp FFI 封装、模型管理 | `lib/core/llm/llm_service.dart` |
| **core/ocr** | ML Kit OCR 封装 | `lib/core/ocr/ocr_service.dart` |
| **core/image** | 颜色提取、缩略图生成 | `lib/core/image/color_extractor.dart` |
| **core/embedding** | 向量生成与搜索 | `lib/core/embedding/embedding_service.dart` |
| **features/import** | 批量/ ZIP / 目录导入 UI + 逻辑 | `lib/features/import/` |
| **features/gallery** | Meme 网格/列表展示 | `lib/features/gallery/` |
| **features/search** | 语义/颜色/组合搜索 UI | `lib/features/search/` |
| **features/folders** | 文件夹管理 | `lib/features/folders/` |
| **features/sync** | S3 同步配置与执行 | `lib/features/sync/` |
| **features/settings** | 设置、模型管理、关于 | `lib/features/settings/` |

---

## 6. 一期（Android）交付范围

### 必须包含

- [x] Meme 列表（网格视图）和详情页
- [x] Meme 增删改查（重命名、删除、移动）
- [x] 批量导入（系统文件选择器多选）
- [x] ZIP 压缩包导入（解压 + 自动去重）
- [x] 文件夹管理（创建/重命名/移动/删除）
- [x] 颜色搜索（主色调拾取器 + 相似度排序）
- [x] 语义搜索（自然语言输入 + 向量检索）
- [x] 后台分析任务队列（导入后自动排队）
- [x] LLM 模型管理（下载 GGUF / 删除 / 切换模型）
- [x] OCR 自动识别（ML Kit，无需下载模型）
- [x] S3 同步（配置 / 手动触发 / 自动后台同步）
- [x] 导入去重（基于文件 SHA256 hash）

### 不包含（后续迭代）

- iOS / iPadOS 支持
- Windows / macOS 桌面版
- Web 版
- GIF 帧级别分析
- 批量导出 / 分享到社交媒体
- Meme 模板制作
- 动图编辑

---

## 7. 数据目录结构

```
app_internal_dir/
├── memes/
│   ├── 2026/
│   │   ├── 06/
│   │   │   ├── {uuid1}.png
│   │   │   ├── {uuid2}.jpg
│   │   │   └── ...
│   │   └── 07/
│   └── ...
├── models/
│   ├── llava-v1.6.Q4_K_M.gguf
│   └── all-MiniLM-L6-v2.Q4_K_M.gguf  ← embedding 模型
├── temp/
│   └── ... (解压临时文件)
├── exports/
│   └── ... (同步导出缓存)
└── database/
    └── meme_helper.db
```

---

## 8. 风险与缓解

| 风险 | 影响 | 缓解方案 |
|------|------|---------|
| 移动端 LLM 推理速度慢 | 分析一张 meme 可能需要 10-30 秒 | 后台队列 + 渐进式索引，不阻塞用户操作 |
| GGUF 模型文件大（2-8GB） | 首次安装后需要额外下载，占用存储 | 选择量化版 (Q4_K_M)，提供模型下载管理器 |
| Android 后台任务被系统杀死 | 分析任务中断 | workmanager 周期性重试 + 断点续传分析 |
| OCR 中英文混排识别率低 | 标签不准确导致搜索效果差 | 结合 LLM 双重验证，LLM 可纠正 OCR 错误 |
| SQLite 向量搜索在万级数据后变慢 | 搜索延迟增加 | sqlite-vec 支持 IVFFlat 索引，可扩展到百万级 |
| S3 同步中途失败/网络中断 | 数据状态不一致 | 事务性同步: 全量下载后再覆盖本地，失败则整体回滚 |
| 数据库 Schema 升级 | App 更新后旧数据与新 Schema 不兼容 | drift 内置 migration 支持，每次变更写 migration 测试 |
| 多个 isolate 同时调用 llama.cpp 导致 OOM | App 闪退 | 最多 2 个并发 isolate，llama.cpp 实例单例串行化 |
| 存储空间不足 | 导入/解压/模型下载失败 | 导入前检查剩余空间，低于 500MB 时提示用户 |

---

## 9. 后续规划

```
一期 (当前)        二期              三期
───────────────────────────────────────────>
Android 单平台    iOS 支持          桌面版
核心功能完整      视频 meme 支持    本地网络发现
S3 同步          分享/导出         插件系统
                  GIF 帧分析        API 接口
                  iCloud 同步
```

---

*本文档为 MemeHelper 项目的设计方案，后续将基于此方案输出详细的实施计划。*
