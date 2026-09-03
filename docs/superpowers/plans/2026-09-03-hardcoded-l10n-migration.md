# 存量硬编码 UI 中文迁移到 i18n —— 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 10 个文件中 89 处用户可见硬编码 UI 中文全部迁移到 l10n（`S.of(context)`），保持 zh/en 同步，视觉零变化。

**Architecture:** 复用优先 + 逐字保留。硬编码词能对应现有 arb key（如 `ok`/`cancel`/`download`/`searchFailed`/`downloadFailed`/`modelDownloadComplete`/`logCount`/`downloading`/`recommendedModels`/`runLogs`/`userStatsTitle`/`save`/`shareMeme` 等）直接复用；仅对无现有 key 的文案新建，按功能前缀命名。带插值字符串用 ARB `{param}` 占位符。每批独立 `gen-l10n` + 同步断言 + `analyze` + commit。

**Tech Stack:** Flutter, l10n (gen-l10n, template=app_zh.arb, output-class=S), Dart

**分支：** 当前分支 `polish/product-details`（用户已确认在本分支继续，不新建分支）。

---

## 背景速览（零上下文还原）

- l10n 配置 `l10n.yaml`：`arb-dir: lib/l10n`、`template-arb-file: app_zh.arb`（中文为模板）、`output-class: S`、`nullable-getter: false`。
- 生成命令：`flutter gen-l10n` → 生成 `lib/l10n/app_localizations.dart`。
- `S.of(context)` import：`import '../../l10n/app_localizations.dart';`（按文件相对层级）。
- 使用时：`S.of(context).someKey`；带占位符的 key 生成带参方法，如 `S.of(context).searchFailed(e)`。
- zh/en 各 379 key 完全同步；每批新增 key 后必须保持 zh/en 同步（断言脚本见 Task A）。
- `app.dart:358-364` 已配 `S.delegate` + `GlobalMaterialLocalizations` + `supportedLocales`，英文 locale 真正生效。

## 新增 key 总表（本计划一次性全部新增，随后各 Task 逐文件替换使用）

> 新增 key 集中在**第一批之前**一次性加进 `app_zh.arb` 与 `app_en.arb`，再 `gen-l10n`。之后各 Task 只改 Dart 调用点，不再动 arb（少数例外见具体 Task，例如复用后才发现需要拆分）。

### 按功能前缀命名的新建 key

**通用（无前缀）：**
| key | zh | en |
|---|---|---|
| `close` | 关闭 | Close |
| `retry` | 重试 | Retry |
| `loadMore` | 加载更多 | Load More |
| `enabled` | 启用 | Enabled |
| `disabled` | 禁用 | Disabled |
| `restoreDefaults` | 恢复默认 | Restore Defaults |
| `cancelDownload` | 取消下载 | Cancel Download |
| `errorWithError` | 错误: {error} | Error: {error} |

**modelManager\*（模型管理）：**
| key | zh | en |
|---|---|---|
| `modelManagerSearchResult` | 搜索结果 | Search Results |
| `modelManagerDownloading` | 下载中 | Downloading |（注：已存在 `downloading`=下载中，直接复用 `downloading`，此 key 不建）
| `modelManagerSelectFileToDownload` | 选择要下载的文件 | Select File to Download |
| `modelManagerFetchFileListFailed` | 获取文件列表失败 | Failed to Fetch File List |
| `modelManagerNoGgufFile` | 未找到 GGUF 文件 | No GGUF File Found |
| `modelManagerNoGgufInRepo` | 该模型仓库中没有找到 .gguf 文件。 | No .gguf file found in this model repository. |
| `modelManagerDownloadCount` | {count} 次下载 | {count} downloads |
| `modelManagerPausedPct` | 已暂停 {pct}% | Paused {pct}% |
| `modelManagerPctPaused` | {pct}% {status} | {pct}% {status} |
| `modelManagerPausedStatus` | （已暂停） | (Paused) |
| `modelManagerViewModelFiles` | 查看模型文件 | View Model Files |
| `modelManagerDeleteModelTooltip` | 删除模型 | Delete Model |
| `modelManagerModelFiles` | 模型文件 | Model Files |
| `modelManagerNoFilesInDirectory` | 该模型目录下没有文件 | No files in this model directory |

**aiConfig\*（AI 分析配置）：**
| key | zh | en |
|---|---|---|
| `aiConfigLocalModelConfig` | 本地模型配置 | Local Model Config |
| `aiConfigGpuAppliedNext` | GPU 设置已修改，下次分析时生效 | GPU settings changed, effective on next analysis |
| `aiConfigGpuLayers` | GPU 层数 | GPU Layers |
| `aiConfigAllLayers` | 全部 (-1) | All (-1) |
| `aiConfigCpuOnly` | 仅 CPU (0) | CPU Only (0) |
| `aiConfigLayerCount` | {n} 层 | {n} layers |
| `aiConfigContextAppliedNext` | 上下文长度已修改，下次分析时生效 | Context length changed, effective on next analysis |
| `aiConfigAdvanced` | 高级性能配置 | Advanced Performance |
| `flashAttnAuto` | 自动（根据 GPU 决定） | Auto (decided by GPU) |
| `kvF16` | F16（精度高） | F16 (high precision) |
| `kvQ40` | Q4_0（省内存） | Q4_0 (saves memory) |
| `aiConfigUseMmap` | 使用 mmap 加载 | Use mmap loading |
| `aiConfigMmapHint` | 内存映射文件加载（Android 低内存设备建议关闭） | Memory-mapped file loading (recommended off on low-memory Android devices) |

**settings\*（调试菜单/OCR/导出）：**
| key | zh | en |
|---|---|---|
| `settingsDebugMenu` | 调试菜单 | Debug Menu |
| `settingsColorExtraction` | 颜色提取算法 | Color Extraction Algorithm |
| `settingsColorExtractionSubtitle` | 配色参数配置 | Color parameter configuration |
| `settingsGpuDiagnose` | GPU 加速诊断 | GPU Acceleration Diagnostic |
| `settingsGpuDiagnoseSubtitle` | 检测 OpenCL（libOpenCL.so）和 Vulkan（libvulkan.so）支持 | Detect OpenCL (libOpenCL.so) and Vulkan (libvulkan.so) support |
| `settingsGpuDiagnoseStarted` | 诊断已开始，结果会写入运行日志（OpenCLDiag 标签，含 OpenCL + Vulkan） | Diagnostics started; results are written to the run log (OpenCLDiag tag, OpenCL + Vulkan) |
| `settingsGpuDiagnoseDone` | 诊断完成，请到"运行日志"查看结果 | Diagnostics complete, see results in Run Log |
| `settingsGpuDiagnoseFailed` | 诊断失败: {error} | Diagnostics failed: {error} |
| `settingsExportChoice` | 选择导出方式 | Choose Export Method |
| `settingsExportToFile` | 保存为文件 | Save as File |
| `settingsShare` | 分享 | Share |
| `settingsTesseractNotLoaded` | Tesseract FFI 未加载，请检查 DLL 是否正确打包 | Tesseract FFI not loaded, check that the DLL is packaged correctly |
| `settingsOcrStatus` | OCR 状态 | OCR Status |
| `settingsOcrChecking` | 检查中... | Checking... |
| `settingsOcrRedetect` | 重新检测 | Re-detect |
| `settingsOcrInstall` | 安装 | Install |

**llm\*（LLM 设置）：**
| key | zh | en |
|---|---|---|
| `llmLlLoading` | 正在加载… | Loading… |
| `llmLlConfiguredAutoLoad` | 已配置，分析时自动加载 | Configured, auto-loads for analysis |
| `llmLlWaitingLog` | 等待日志… | Waiting for logs… |
| `llmLlFileMissing` | 模型文件不存在，请检查模型路径或重新下载 | Model file does not exist; check the model path or re-download |
| `llmLlLoaded` | 模型加载成功 | Model loaded successfully |
| `llmLlSwitchToLocalFirst` | 请先切换到本地模型模式 | Switch to local model mode first |
| `llmLlLoadFailed` | 模型加载失败: {error} | Model load failed: {error} |

**userStats\*（用户统计）：**
| key | zh | en |
|---|---|---|
| `userStatsActivity` | Meme 活跃度 · {heatmap} | Meme Activity · {heatmap} |
| `userStatsDailyDetail` | 每日明细 | Daily Detail |
| `userStatsCumulativeTotal` | 累计总计 | Cumulative Total |
| `userStatsEdit` | 修改 | Edit |

**gallery\* / memeDetail\*（图库）：**
| key | zh | en |
|---|---|---|
| `galleryReindexing` | 重新索引中... 已处理 {processed} 个，已入队 {enqueued} 个 | Re-indexing... {processed} processed, {enqueued} queued |
| `galleryPleaseWait` | 请稍候... | Please wait... |
| `galleryDeleteFailed` | 删除失败: {error} | Delete failed: {error} |
| `colorExtractionConfigTitle` | 颜色提取算法配置 | Color Extraction Algorithm Config |

**s3\*（同步）：**
| key | zh | en |
|---|---|---|
| `s3SyncFailed` | 同步失败: {error} | Sync failed: {error} |

### 复用现有 key 映射（不新建）

| 硬编码（文件:行） | 复用 key |
|---|---|
| `搜索失败: $e`（model_manager:90） | `searchFailed(e)` |
| `推荐模型`（model_manager:142） | `recommendedModels` |
| `搜索`（model_manager:231） | `search` |
| `下载中`（model_manager:282） | `downloading` |
| `下载失败`（model_manager:291） | `downloadFailed`（zh 带 {error}，需传参；见下） |
| `已下载`（model_manager:312, 673） | `downloaded` |
| `确定`（model_manager:371, 423） | `ok` |
| `{model.name} {mmproj/gguf} 下载完成`（model_manager:472） | `modelDownloadComplete(name)`，name 传 `'${model.name} ${isMmproj ? "mmproj" : "gguf"}'` |
| `下载失败: $e`（model_manager:479） | `downloadFailed(e)` |
| `下载`（model_manager:612, 683） | `download` |
| `删除模型`（model_manager:917） | `manage`？→ 否，zh=管理不符；此处置为新建 `modelManagerDeleteModelTooltip`（见上表） |
| `运行日志`（settings:94） | `runLogs` |
| `共 $count 条`（settings:96） | `logCount(count)` |
| `用户统计`（settings:66） | `userStatsTitle` |
| `保存为文件`*（settings:243） | 见注 |
| `分享`（settings:247） | `shareMeme` |
| `重新索引中... 已处理 {processed} 个...`（gallery:550，不在 89 处扫描中，属已在用？见注） | — |

> **注：** settings:243 `保存为文件` 与 settings:66 `用户统计` 等在设计中复用；因逐字保留原则，凡语义匹配的复用，不匹配的新建。导入导出相关的 `exportToFile`（`export` 前缀）尚未核实，实施时以「语义精确匹配则复用，否则按前缀新建」为准，并在 commit message 记录。

## 关键规则（每批都要遵守）

1. 每批改完 Dart 后运行 `flutter gen-l10n`（如需新增 key）→ `flutter analyze lib/features/...` 目标文件（0 error）→ arb 同步断言 → commit。
2. 复用 key 前必须核对语义（zh 原文 + en）。歧义一律新建，不强行复用。
3. `const Text('...')` 改 `Text(S.of(...))` 时需去掉 `const`。
4. 带占位符的 key 生成带参方法，参数名见上表。
5. 逐字保留 zh。en 为译文。
6. 不迁移日志（`debugPrint`/`LogService`/抛异常）——不在本计划范围。

---

## Chunk 1: arb 基础设施与断言脚本

### Task A: 新增全部 arb key + 断言脚本

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Test: 内联 python 断言（不落盘）

- [ ] **Step 1: 在 `app_zh.arb` 与 `app_en.arb` 中新增上表全部新 key**（通用 7 + modelManager 12 + aiConfig 13 + settings 16 + llm 7 + userStats 4 + gallery 4 + s3 1 ≈ 64 个；modelManagerDownloading 不建，复用 `downloading`）。zh 逐字，en 译文。带占位符的 key 在 arb 中写 `{param}` 形式（zh/zh 模板还要加 `@key` 元数据定义占位符及 type，见 Step 2）。
- [ ] **Step 2: 为带占位符的新 key 在 `app_zh.arb`（模板）添加 `@` 元数据**

```jsonc
"modelManagerDownloadCount": "{count} 次下载",
"@modelManagerDownloadCount": { "placeholders": { "count": { "type": "int" } } },
// 字符串型占位符的 type 为 "String"，如：
"galleryDeleteFailed": "删除失败: {error}",
"@galleryDeleteFailed": { "placeholders": { "error": { "type": "String" } } },
// en 文件无需 @ 元数据（继承模板 placeholders）
```
> 已知字符串型占位符：`errorWithError`、`settingsGpuDiagnoseFailed`、`llmLlLoadFailed`、`galleryDeleteFailed`、`galleryReindexing`、`s3SyncFailed`、`userStatsActivity`、`modelManagerPausedPct`、`modelManagerPctPaused`、`modelManagerPausedStatus`、`modelManagerDeleteModelTooltip`* 等；整数型：`modelManagerDownloadCount`、`aiConfigLayerCount`、`logCount`(已有)。具体以 key 的 `{param}` 为准。

- [ ] **Step 3: 运行 gen-l10n 并断言 zh/en 同步**

Run:
```bash
flutter gen-l10n
python3 -c "
import json
zh=json.load(open('lib/l10n/app_zh.arb'))
en=json.load(open('lib/l10n/app_en.arb'))
zk={k for k in zh if not k.startswith('@')}
ek={k for k in en if not k.startswith('@')}
assert zk==ek, (sorted(zk-ek), sorted(ek-zk))
print('sync OK:', len(zk))
"
```
Expected: `sync OK: <>=443`

- [ ] **Step 4: `flutter analyze`（确认新 key 生成无错误，Dart 尚未引用无碍）**

Run: `flutter analyze`
Expected: 0 `error •`（存在 ~300 存量 info/warn 可忽略）

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "feat(i18n): add keys for hardcoded UI Chinese migration"
```

---

## Chunk 2: model_manager_screen（31 处）

### Task B: 迁移 `model_manager_screen.dart`

**Files:**
- Modify: `lib/features/settings/model_manager_screen.dart`
- Modify: `lib/l10n/app_zh.arb` / `app_en.arb`（如需）
- Add import: `import '../../l10n/app_localizations.dart';`

- [ ] **Step 1: 添加 import**（若文件还没有 `S.of` 使用）
- [ ] **Step 2: 逐处替换（保持语义/const 处理）**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 90 | `Text('搜索失败: $e')` | `Text(S.of(context).searchFailed(e))` |
| 127 | `Text('搜索结果', ...)` | `Text(S.of(context).modelManagerSearchResult, ...)` |
| 142 | `Text('推荐模型', ...)` | `Text(S.of(context).recommendedModels, ...)` |
| 231 | `label: const Text('搜索')` | `label: Text(S.of(context).search)`（去 const） |
| 282 | `Text('下载中', ...)` | `Text(S.of(context).downloading, ...)` |
| 291 | `Text('下载失败', ...)` | `Text(S.of(context).downloadFailed(...))`（见注意） |
| 312 | `Text('已下载', ...)` | `Text(S.of(context).downloaded, ...)` |
| 366 | `title: const Text('未找到 GGUF 文件')` | `title: Text(S.of(context).modelManagerNoGgufFile)` |
| 367 | `content: const Text('该模型仓库中没有找到 .gguf 文件。')` | `content: Text(S.of(context).modelManagerNoGgufInRepo)` |
| 371 | `child: const Text('确定')` | `child: Text(S.of(context).ok)` |
| 385 | `title: Text('选择要下载的文件')` | `title: Text(S.of(context).modelManagerSelectFileToDownload)` |
| 418 | `title: const Text('获取文件列表失败')` | `title: Text(S.of(context).modelManagerFetchFileListFailed)` |
| 419 | `content: Text('错误: $e')` | `content: Text(S.of(context).errorWithError(e))` |
| 423 | `child: const Text('确定')` | `child: Text(S.of(context).ok)` |
| 472 | `SnackBar(content: Text('${model.name} ${isMmproj ? "mmproj" : "gguf"} 下载完成'))` | `SnackBar(content: Text(S.of(context).modelDownloadComplete('${model.name} ${isMmproj ? "mmproj" : "gguf"}')))` |
| 479 | `SnackBar(content: Text('下载失败: $e'))` | `SnackBar(content: Text(S.of(context).downloadFailed(e)))` |
| 522 | `label: const Text('加载更多')` | `label: Text(S.of(context).loadMore)` |
| 564 | `Text('${model.downloads} 次下载', ...)` | `Text(S.of(context).modelManagerDownloadCount(model.downloads), ...)` |
| 612 | `label: const Text('下载')` | `label: Text(S.of(context).download)` |
| 666 | `Text('已暂停 ${(progress * 100).toStringAsFixed(2)}%', ...)` | `Text(S.of(context).modelManagerPausedPct('${(progress * 100).toStringAsFixed(2)}%'), ...)` |
| 673 | `Text('已下载', ...)` | `Text(S.of(context).downloaded, ...)` |
| 683 | `label: const Text('下载')` | `label: Text(S.of(context).download)` |
| 739 | `Text('${(state.progress * 100).toStringAsFixed(1)}% ${isPaused ? "(已暂停)" : ""}')` | `Text(S.of(context).modelManagerPctPaused('${(state.progress * 100).toStringAsFixed(1)}%', isPaused ? S.of(context).modelManagerPausedStatus : ''))` |
| 754 | `tooltip: '取消下载'` | `tooltip: S.of(context).cancelDownload` |
| 819 | `label: const Text('重试')` | `label: Text(S.of(context).retry)` |
| 824 | `tooltip: '取消下载'` | `tooltip: S.of(context).cancelDownload` |
| 911 | `tooltip: '查看模型文件'` | `tooltip: S.of(context).modelManagerViewModelFiles` |
| 917 | `tooltip: '删除模型'` | `tooltip: S.of(context).modelManagerDeleteModelTooltip` |
| 951 | `title: const Text('模型文件')` | `title: Text(S.of(context).modelManagerModelFiles)` |
| 968 | `child: Text('该模型目录下没有文件')` | `child: Text(S.of(context).modelManagerNoFilesInDirectory)` |
| 1008 | `child: const Text('关闭')` | `child: Text(S.of(context).close)` |

> **注意 291 行**：现有 `downloadFailed` = `下载失败: {error}` 带占位符，但 291 行是 `下载失败`（无 $e）。需核对 291 上下文是否有可用 error 变量；若无，新建 `downloadFailed` 无参变体不可行（key 已被 479 用）。方案：291 若无可传 error，则新增 `modelManagerDownloadFailedLabel` = `下载失败` / `Download Failed`（en 用独立 key 避免与涨价 `{error}` 冲突）。实施时按上下文决定，优先传 `e`（若可得）复用 `downloadFailed(e)`。

- [ ] **Step 3: gen-l10n（如新增 key）+ arb 同步断言**
- [ ] **Step 4: `flutter analyze`** 目标文件
- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/model_manager_screen.dart lib/l10n/
git commit -m "refactor(i18n): migrate model_manager_screen hardcoded Chinese"
```

---

## Chunk 3: ai_analysis_config_screen（22 处）

### Task C: 迁移 `ai_analysis_config_screen.dart`

**Files:**
- Modify: `lib/features/settings/ai_analysis_config_screen.dart`
- Add: `import '../../l10n/app_localizations.dart';`

- [ ] **Step 1: 添加 import**
- [ ] **Step 2: 逐处替换**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 281 | `child: const Text('恢复默认')` | `child: Text(S.of(context).restoreDefaults)` |
| 335 | `child: const Text('恢复默认')` | `child: Text(S.of(context).restoreDefaults)` |
| 369 | `Text('本地模型配置', ...)` | `Text(S.of(context).aiConfigLocalModelConfig, ...)` |
| 389 | `content: Text('GPU 设置已修改，下次分析时生效')` | `content: Text(S.of(context).aiConfigGpuAppliedNext)` |
| 403 | `title: const Text('GPU 层数')` | `title: Text(S.of(context).aiConfigGpuLayers)` |
| 417 | `child: Text('全部 (-1)')` | `child: Text(S.of(context).aiConfigAllLayers)` |
| 418 | `child: Text('仅 CPU (0)')` | `child: Text(S.of(context).aiConfigCpuOnly)` |
| 419 | `child: Text('4 层')` | `child: Text(S.of(context).aiConfigLayerCount(4))` |
| 420 | `child: Text('8 层')` | `child: Text(S.of(context).aiConfigLayerCount(8))` |
| 421 | `child: Text('12 层')` | `child: Text(S.of(context).aiConfigLayerCount(12))` |
| 422 | `child: Text('16 层')` | `child: Text(S.of(context).aiConfigLayerCount(16))` |
| 423 | `child: Text('20 层')` | `child: Text(S.of(context).aiConfigLayerCount(20))` |
| 424 | `child: Text('24 层')` | `child: Text(S.of(context).aiConfigLayerCount(24))` |
| 457 | `content: Text('上下文长度已修改，下次分析时生效')` | `content: Text(S.of(context).aiConfigContextAppliedNext)` |
| 472 | `Text('高级性能配置', ...)` | `Text(S.of(context).aiConfigAdvanced, ...)` |
| 489 | `child: Text('自动（根据 GPU 决定）')` | `child: Text(S.of(context).flashAttnAuto)` |
| 490 | `child: Text('启用')` | `child: Text(S.of(context).enabled)` |
| 491 | `child: Text('禁用')` | `child: Text(S.of(context).disabled)` |
| 509 | `child: Text('F16（精度高）')` | `child: Text(S.of(context).kvF16)` |
| 510 | `child: Text('Q4_0（省内存）')` | `child: Text(S.of(context).kvQ40)` |
| 530 | `title: const Text('使用 mmap 加载')` | `title: Text(S.of(context).aiConfigUseMmap)` |
| 531 | `subtitle: Text('内存映射文件加载（Android 低内存设备建议关闭）', ...)` | `subtitle: Text(S.of(context).aiConfigMmapHint, ...)` |

- [ ] **Step 3: gen-l10n（如新增 key）+ 同步断言 + `flutter analyze`**
- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/ai_analysis_config_screen.dart lib/l10n/
git commit -m "refactor(i18n): migrate ai_analysis_config_screen hardcoded Chinese"
```

---

## Chunk 4: settings_screen（19 处）+ 删除死文件

### Task D: 迁移 `settings_screen.dart` 并删除 `overlay_toggle_button.dart`

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Delete: `lib/features/overlay/overlay_toggle_button.dart`
- Modify: `lib/l10n/*.arb`（如需）

- [ ] **Step 1: 删除死文件**

```bash
rm lib/features/overlay/overlay_toggle_button.dart
# 确认无其他引用：
grep -rn "OverlayToggleButton" lib/ || echo "no references"
```
Expected: `no references`

- [ ] **Step 2: 添加 import 并逐处替换 settings_screen**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 59 | `title: const Text('调试菜单')` | `title: Text(S.of(context).settingsDebugMenu)` |
| 66 | `title: const Text('用户统计')` | `title: Text(S.of(context).userStatsTitle)` |
| 74 | `title: const Text('颜色提取算法')` | `title: Text(S.of(context).settingsColorExtraction)` |
| 75 | `subtitle: const Text('配色参数配置')` | `subtitle: Text(S.of(context).settingsColorExtractionSubtitle)` |
| 94 | `title: const Text('运行日志')` | `title: Text(S.of(context).runLogs)` |
| 96 | `subtitle: Text('共 $count 条')` | `subtitle: Text(S.of(context).logCount(count))` |
| 105 | `title: const Text('GPU 加速诊断')` | `title: Text(S.of(context).settingsGpuDiagnose)` |
| 106 | `subtitle: const Text('检测 OpenCL...Vulkan（libvulkan.so）支持')` | `subtitle: Text(S.of(context).settingsGpuDiagnoseSubtitle)` |
| 145 | `content: Text('诊断已开始，结果会写入运行日志（OpenCLDiag 标签，含 OpenCL + Vulkan）')` | `content: Text(S.of(context).settingsGpuDiagnoseStarted)` |
| 157 | `content: Text('诊断完成，请到"运行日志"查看结果')` | `content: Text(S.of(context).settingsGpuDiagnoseDone)` |
| 166 | `SnackBar(content: Text('诊断失败: $e'))` | `SnackBar(content: Text(S.of(context).settingsGpuDiagnoseFailed(e)))` |
| 239 | `content: const Text('选择导出方式')` | `content: Text(S.of(context).settingsExportChoice)` |
| 243 | `child: const Text('保存为文件')` | `child: Text(S.of(context).settingsExportToFile)` |
| 247 | `child: const Text('分享')` | `child: Text(S.of(context).shareMeme)` |
| 747 | `content: Text('Tesseract FFI 未加载，请检查 DLL 是否正确打包')` | `content: Text(S.of(context).settingsTesseractNotLoaded)` |
| 830 | `title: const Text('OCR 状态')` | `title: Text(S.of(context).settingsOcrStatus)` |
| 831 | `subtitle: const Text('检查中...')` | `subtitle: Text(S.of(context).settingsOcrChecking)` |
| 854 | `tooltip: '重新检测'` | `tooltip: S.of(context).settingsOcrRedetect` |
| 859 | `child: const Text('安装')` | `child: Text(S.of(context).settingsOcrInstall)` |

> **注意 247 行 `分享`**：复用 `shareMeme`（zh=分享表情包）。若"分享"此处是通用动词且上下文为"分享导出结果"，`shareMeme` 语义"分享表情包"可能不符 → **优先新建 `settingsShare`**（zh=分享 / en=Share）。实施时按上下文语义决定，复用或新建均可，以「语义精确」为准。settingsExportToFile/settingsShare 已在上表声明，默认用新 key。

- [ ] **Step 3: gen-l10n + 同步断言 + `flutter analyze`**
- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/settings_screen.dart lib/features/overlay/ lib/l10n/
git commit -m "refactor(i18n): migrate settings_screen hardcoded Chinese; remove dead overlay_toggle_button"
```

---

## Chunk 5: llm_settings_screen（7 处）

### Task E: 迁移 `llm_settings_screen.dart`

**Files:**
- Modify: `lib/features/settings/llm_settings_screen.dart`
- Add: `import '../../l10n/app_localizations.dart';`

- [ ] **Step 1: 添加 import**
- [ ] **Step 2: 逐处替换**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 221 | `Text('正在加载…', ...)` | `Text(S.of(context).llmLlLoading, ...)` |
| 224 | `Text('已配置，分析时自动加载', ...)` | `Text(S.of(context).llmLlConfiguredAutoLoad, ...)` |
| 266 | `Text('等待日志…', ...)` | `Text(S.of(context).llmLlWaitingLog, ...)` |
| 339 | `const SnackBar(content: Text('模型文件不存在，请检查模型路径或重新下载'))` | `SnackBar(content: Text(S.of(context).llmLlFileMissing))`（去 const） |
| 376 | `const SnackBar(content: Text('模型加载成功'))` | `SnackBar(content: Text(S.of(context).llmLlLoaded))`（去 const） |
| 383 | `const SnackBar(content: Text('请先切换到本地模型模式'))` | `SnackBar(content: Text(S.of(context).llmLlSwitchToLocalFirst))`（去 const） |
| 392 | `SnackBar(content: Text('模型加载失败: $e'))` | `SnackBar(content: Text(S.of(context).llmLlLoadFailed(e)))` |

- [ ] **Step 3: gen-l10n + 同步断言 + `flutter analyze`**
- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/llm_settings_screen.dart lib/l10n/
git commit -m "refactor(i18n): migrate llm_settings_screen hardcoded Chinese"
```

---

## Chunk 6: 其余小文件（8 处）

### Task F: 迁移 user_stats / gallery / meme_detail / s3 / color_extraction

**Files:**
- Modify: `lib/features/settings/user_stats_screen.dart`
- Modify: `lib/features/gallery/gallery_screen.dart`
- Modify: `lib/features/gallery/meme_detail_screen.dart`
- Modify: `lib/features/settings/s3_sync_screen.dart`
- Modify: `lib/features/settings/color_extraction_screen.dart`

- [ ] **Step 1: user_stats_screen.dart（4 处）**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 49 | `Text('Meme 活跃度 · ${s.heatmap}', ...)` | `Text(S.of(context).userStatsActivity(s.heatmap), ...)` |
| 66 | `Text('每日明细', ...)` | `Text(S.of(context).userStatsDailyDetail, ...)` |
| 77 | `Text('累计总计', ...)` | `Text(S.of(context).userStatsCumulativeTotal, ...)` |
| 155 | `Text('修改', ...)` | `Text(S.of(context).userStatsEdit, ...)` |

- [ ] **Step 2: gallery_screen.dart（2 处）**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 196 | `SnackBar(content: Text('删除失败: $e'))` | `SnackBar(content: Text(S.of(context).galleryDeleteFailed(e)))` |
| 1182 | `Text('请稍候...')` | `Text(S.of(context).galleryPleaseWait)` |

> **注意**：gallery_screen 与 meme_detail 的 `删除失败: $e` 语义相同，复用同一 key `galleryDeleteFailed`。

- [ ] **Step 3: meme_detail_screen.dart（1 处）**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 97 | `SnackBar(content: Text('删除失败: $e'))` | `SnackBar(content: Text(S.of(context).galleryDeleteFailed(e)))` |

- [ ] **Step 4: s3_sync_screen.dart（1 处）**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 61 | `SnackBar(content: Text('同步失败: $error'))` | `SnackBar(content: Text(S.of(context).s3SyncFailed(error)))` |

- [ ] **Step 5: color_extraction_screen.dart（1 处）**

| 行 | 硬编码 | 替换为 |
|---|---|---|
| 15 | `appBar: AppBar(title: const Text('颜色提取算法配置'))` | `appBar: AppBar(title: Text(S.of(context).colorExtractionConfigTitle))` |

- [ ] **Step 6: 各文件补 `import '../../l10n/app_localizations.dart';`**（meme_detail/gallery 可能已有，核对；s3/color_extraction 核对是否有 S 使用）
- [ ] **Step 7: gen-l10n + 同步断言 + `flutter analyze`**
- [ ] **Step 8: Commit**

```bash
git add lib/features/settings/user_stats_screen.dart lib/features/gallery/ lib/features/settings/s3_sync_screen.dart lib/features/settings/color_extraction_screen.dart lib/l10n/
git commit -m "refactor(i18n): migrate remaining settings/gallery hardcoded Chinese"
```

---

## Chunk 7: 整体验证收尾

### Task G: 全量验证 + 汇总

- [ ] **Step 1: 全量 `flutter analyze`（0 error）**

Run: `flutter analyze | grep -c "error •"`
Expected: `0`

- [ ] **Step 2: arb 同步断言**

Run（同上 Task A Step 3 python）:
Expected: `sync OK:`，zh/en 非 `@` keys 完全相等。

- [ ] **Step 3: 全量测试**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: APK 构建**

Run: `flutter build apk --release | grep "✓ Built"`
Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 5: 复核 89 处已全部迁移**

Run（对照扫描脚本，期望 UI 硬编码中文归零）：
```bash
# 复用 brainstorming 阶段使用的扫描脚本，检查 89 处是否全部消除
```
Expected: 0 处残留 UI 硬编码中文（`features/` 与 `widgets/` 下，排除日志/注释）。

- [ ] **Step 6: 汇总 `git log master..HEAD`**，向用户交付。

---

## 验证总览

| 门槛 | 命令 | 期望 |
|---|---|---|
| gen-l10n | `flutter gen-l10n` | 无错误 |
| zh/en 同步 | python 断言 | keys 相等 |
| 静态分析 | `flutter analyze` | 0 error |
| 单元测试 | `flutter test` | All tests passed |
| 构建 | `flutter build apk --release` | ✓ Built |
| 残留扫描 | python 扫描脚本 | 0 处 UI 硬编码中文 |

## 风险与回退

- **复用误判**：凡语义可疑（如 291 `下载失败`、247 `分享`）按「新建精确 key」处理，Commit message 记录选择。
- **占位符类型**：整数用 `int`、字符串用 `String`，gen-l10n 会校验。
- **`const` 移除**：`const Text('...')` → `Text(S.of(...))` 需移除 `const`，analyze 会提示（info 级，但需避免 error）。
- 若某 key 名与现有冲突，gen-l10n 会报错，按报错改名。
