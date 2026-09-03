# 存量硬编码 UI 中文全量迁移到 i18n —— 设计文档

日期：2026-09-03
分支建议：`polish/hardcoded-i18n`（从 `master` 创建）

## 背景与动机

产品打磨（`polish/product-details`）之后，项目 i18n 在**本次打磨范围内**已完善（新增文案双语同步、清理孤儿 key，当前 zh/en 各 379 key 完全对应）。但全项目仍有 **89 处用户可见的硬编码 UI 中文**未走 i18n，分布在 10 个文件。

这些文案是**用户直接可见的 UI 文案**（按钮、标题、tooltip、SnackBar、Dialog 内容），并非日志。`app.dart:358-364` 已正确配置 `localizationsDelegates`（`S.delegate` + `GlobalMaterialLocalizations` + `supportedLocales`），**英文 locale 真正生效**，因此迁移后切换英文才会真正有效——这是一次有实际价值的完善。

## 目标

- 消除 10 个文件、89 处用户可见硬编码 UI 中文，全部改走 `S.of(context)`。
- 迁移后 zh/en 保持完全同步，英文本地化补齐。
- 不改变任何现有 UI 文案内容（逐字保留中文为 zh 值）。

## 非目标

- 不迁移日志/内部消息（`debugPrint`、`LogService`、抛出的异常信息等）——非用户可见，且 CLI 侧也使用中文日志。
- 不调整 UI 布局、文案措辞、交互逻辑。
- 不为不可达代码造 key（删除死文件，见下）。

## 策略

1. **逐字保留中文为 zh 值**，新增对应 en 翻译 → UI 视觉零变化，改动风险最小。
2. **复用优先**：硬编码词若能对应现有 key，直接复用，不新建重复 key。已确认现有 arb 含有大量可复用通用 key，例：
   - `'确定'` → `ok`（已有）
   - `'取消'` → `cancel`（已有）
   - `'下载'`（按钮）→ `download`（已有）
   - `'搜索'`（按钮）→ `search`（已有）
   - `'加载更多'` → `loadMore`（按需确认）
   - `'已下载'` → `downloaded`（已有）
   - `'运行日志'` → `runLogs`（已有）
   - `'用户统计'` → `userStatsTitle`（已有）
   - `'保存'` → `save`（已有）
   - `'分享'` → `shareMeme`（已有）
   - `'错误: $e'` → `errorWithError` / 现有 `error` 语义确认
   - `'共 $count 条'` → `logCount`（已有，含 `{count}` 占位符）
3. **新建 key 原则**：仅对无现有 key 的文案新建，按功能前缀命名（小驼峰），前缀与现有分组风格一致：
   - `modelManager*`（模型管理 31 处）
   - `aiConfig*`（AI 分析配置 22 处）
   - `settings*`（调试菜单/OCR/导出等 19 处）
   - `llm*`（LLM 设置 7 处）
   - `userStats*`（用户统计 4 处）
   - `gallery*` / `memeDetail*`（图库 3 处）
   - `s3*`（同步 1 处）
   - `colorExtraction*`（颜色提取 1 处）
   - 已有分词如 `gpuDiagnose*`、`ocr*`、`export*` 沿用。

## 占位符 / 插值处理（14 处带变量）

- 统一用 ARB `{name}` 占位符语法，`S` 方法签名变为带参方法。
- 需特别注意的样例：
  - `'共 $count 条'` → 复用 `logCount`（现有 `{count}` 占位符）。
  - `'${model.name} ${isMmproj ? "mmproj" : "gguf"} 下载完成'`（model_manager:472）→ 三元表达式无法直接占位，按调用处拆分为两个分支各自使用合适 key（如"gguf 下载完成" / "mmproj 下载完成"），或传入已组合好的类型字符串作占位符。具体在计划阶段按调用处上下文定夺。
  - `'已暂停 ${(progress * 100).toStringAsFixed(2)}%'`（:666）与 `'${(state.progress*100).toStringAsFixed(1)}% ${isPaused ? "(已暂停)" : ""}'`（:739）→ 占位符传**已格式化**的字符串（`'{pct}%'` 形式），避免把格式化逻辑塞进 arb。
  - `'删除失败: $e'`、`'同步失败: $error'`、`'搜索失败: $e'`、`'模型加载失败: $e'`、`'下载失败: $e'`、`'错误: $e'`、`'诊断失败: $e'` → 各建一个带 `{error}` 占位符的 key（en 为 "… failed: {error}" 语义）。注意 `删除失败: $e` 在 gallery_screen 与 meme_detail_screen 各出现一次，复用**同一 key**。
  - `'Meme 活跃度 · ${s.heatmap}'` → 带 `{heatmap}` 占位符。

## 死代码清理

- 删除 `features/overlay/overlay_toggle_button.dart`（无任何引用，Task 2 移除图库页按钮后遗留），其中含 1 处硬编码中文 tooltip。删除为不可达代码造 key 的做法。

## 文件批次（每批独立 commit）

每一批：`flutter gen-l10n` → zh/en 同步断言 → `flutter analyze`（目标 0 error）→ commit。

1. `features/settings/model_manager_screen.dart`（31 处，最大批）
2. `features/settings/ai_analysis_config_screen.dart`（22 处）
3. `features/settings/settings_screen.dart`（19 处）+ 删除 `overlay_toggle_button.dart`
4. `features/settings/llm_settings_screen.dart`（7 处）
5. 其余小文件：`user_stats_screen.dart`(4)、`gallery_screen.dart`(2)、`meme_detail_screen.dart`(1)、`s3_sync_screen.dart`(1)、`color_extraction_screen.dart`(1)

commit message 风格沿用：`refactor(i18n): migrate hardcoded Chinese to l10n in <file>`。

## 验证

- 每批：`flutter gen-l10n` + zh/en arb 同步断言（非 `@` keys 集合相等）+ `flutter analyze` 无 error。
- 收尾：全量 `flutter analyze`（0 error）→ arb 同步断言 → `flutter build apk --release` 成功。
- 附注：项目存在 ~300 个存量 `info`/`warn`（test、脚本、样式 lint 如 `prefer_const_constructors`），非本次引入，不处理。

## 风险与注意

- **复用 key 的语义核对**：复用前必须核对现有 key 的 en/zh 语义，避免"看似相同实则有歧义"（如某处"下载"是动词按钮、某处"已下载"是状态标签）。歧义处一律新建语义精确的 key，不强行复用。
- **三元/格式化插值**：此类占位符在计划阶段逐一读调用处上下文后定夺，避免把逻辑塞进 arb。
- **`const Text('...')`**：改为 `S.of(context)` 后 `const` 通常需移除，注意保持语义一致。
