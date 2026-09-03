# 产品打磨设计 (2026-09-03)

工作分支：`polish/product-details`（基于 `master`，已推送）。

目标：按用户反馈打磨 7 项细节，提升产品完成度。

## 1. 悬浮窗开关移到设置页

现状：
- 图库页右上角有 `OverlayToggleButton`（gallery_screen.dart:405），直接控制 `overlayProvider`（悬浮窗运行状态）。
- 设置页「悬浮窗」分组只有单个「自动开启悬浮窗」开关 `autoOverlayEnabledProvider`。

改动：
- **移除** 图库页右上角 `OverlayToggleButton` 及对应 import。
- 设置页「悬浮窗」分组改为两个开关：
  - **开关 A「开启拖拽导入图片悬浮窗」**：绑定 `overlayProvider`（当前是否运行）。打开：无权限先 `requestOverlayPermission` 再 `startOverlay`；关闭：`stopOverlay`。复用 `OverlayController.toggle()` 及 `hasPermission` 处理。
  - **开关 B「自动开启悬浮窗」**：绑定 `autoOverlayEnabledProvider`。联动：开启 B 时若 A 未开则同时打开 A（B 蕴含 A）；关闭 A 不改动 B 状态。

涉及文件：`gallery_screen.dart`、`settings_screen.dart`、`gallery_provider.dart`（如需要）、i18n。

## 2. 退出应用时停止悬浮窗

现状：悬浮窗是**前台服务**（`OverlayService`，`startForeground`），系统级常驻，退出应用后仍显示。用户需强杀才关。

改动：
- 在 `MainActivity.onDestroy()`（Activity 真正销毁 = 从最近任务划掉 / 进程结束）调用 `OverlayService.stop(this)`。
- 行为：按 Home 键后台**不**停（跨应用拖图仍可用）；真正退出应用时悬浮窗随之停止。
- 重新打开应用 + 开了「自动开启」→ 由现有 `_autoStartOverlayIfEnabled()` 重新拉起。

涉及文件：`MainActivity.kt`。

## 3. 重新索引加确认

现状：`_startReindex` 点击即触发 `startReindex()`。

改动：点击「重新索引所有表情」先弹 `AlertDialog` 确认（提示会重新扫描所有图片、耗时），点「确认」才执行；「取消」不动。

涉及文件：`settings_screen.dart`、i18n。

## 4. 搜索页 L2 徽标与结果计数同一行

现状：
- `_SearchLevelBadge` 独占一行（右对齐，search_screen.dart:262-263）。
- 「找到 n 个结果」独占一行（左对齐，search_screen.dart:300）。

改动：把 L2 徽标与「找到 n 个结果」放进**同一个 Row**（`mainAxisAlignment: spaceBetween`，结果靠左、徽标靠右），合并原两处，省一行空白。

涉及文件：`search_screen.dart`。

## 5. S3 去掉定时自动同步

现状：`s3_sync_screen.dart` 有「定时自动同步」卡片（lines 434-507），含 `autoSync` 开关 + 间隔下拉。

改动：
- 移除「定时自动同步」整卡（`scheduledSync` 标题 + `autoSync` 开关 + 间隔下拉）。
- 保留手动同步按钮（全量上传/全量下载/增量同步）。
- 清理 `s3_sync_screen.dart` 对 `autoSyncEnabledProvider` / `autoSyncIntervalProvider` 的引用；若 `startPeriodicSync`/`stopPeriodicSync` 仅被此界面调用，一并清理服务端；否则保留但不暴露 UI。

涉及文件：`s3_sync_screen.dart`、`gallery_provider.dart`、`s3_sync_service.dart`（视清理范围）、i18n。

## 6. 调试菜单 GPU 诊断加确认

现状：`_runOpenCLDiagnostic` 点击即执行。

改动：点击「GPU 加速诊断」先弹确认对话框（"将执行 OpenCL + Vulkan 诊断…"），确认才执行。

涉及文件：`settings_screen.dart`、i18n。

## 7. i18n 检查与同步

已确认 `app_zh.arb` 与 `app_en.arb` 完全同步（各 384 key，无缺失）。

新增的所有字符串均加入两个 `.arb`，运行 `flutter gen-l10n` 重新生成 `app_localizations*.dart`，保持中英同步。

涉及文件：`app_zh.arb`、`app_en.arb`、生成文件。

## 验证

- `flutter analyze` 通过。
- `flutter build apk --release` 成功（改动含原生 MainActivity.kt）。
- 真机验证：悬浮窗开关联动、退出应用停止悬浮窗、重新索引/GPU 诊断确认弹窗、S3 无自动同步、搜索页布局、中英文案。
