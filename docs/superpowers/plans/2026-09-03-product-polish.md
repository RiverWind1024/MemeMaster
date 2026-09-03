# Product Polish Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 7 项产品打磨细节（悬浮窗开关迁移联动、退出停止悬浮窗、重索引/GPU 诊断确认、搜索布局、去 S3 定时同步、i18n 同步）。

**Architecture:** 全为 Dart/Flutter UI 层改动 + 1 处 Kotlin 生命周期改动。悬浮窗开关从图库页迁移到设置页并建立联动；退出通过 `MainActivity.onDestroy` 停止前台服务。i18n 用 Flutter gen-l10n（`.arb` → 生成 `app_localizations*.dart`）。

**Tech Stack:** Flutter, Riverpod, go_router, Kotlin (OverlayService), Flutter gen-l10n (intl).

参考 spec：`docs/superpowers/specs/2026-09-03-product-polish-design.md`
工作分支：`polish/product-details`

---

### Task 1: i18n 基础设施检查（先做，供后续任务复用）

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Generate: `lib/l10n/app_localizations*.dart`

- [ ] **Step 1: 确认当前 l10n 生成命令**

检查 `pubspec.yaml` 的 `l10n.yaml` 配置是否存在。若无 `l10n.yaml`，确认默认生成配置（`generate: true` + `lib/l10n/` 下的 `app_*.arb`）。

验证：`cat l10n.yaml 2>/dev/null || ls lib/l10n/*.arb`

- [ ] **Step 2: 跑一次 gen-l10n 验证基线**

Run: `flutter gen-l10n`
Expected: 成功，无报错。用 `git status` 确认生成文件若有变化则提交基线。

- [ ] **Step 3: Commit**

```bash
git add -A lib/l10n/
git commit -m "chore(l10n): baseline i18n regeneration" -q
```

---

### Task 2: 悬浮窗开关 —— 移除图库页按钮，设置页新增「开启」开关与联动

**Files:**
- Modify: `lib/features/gallery/gallery_screen.dart:19,405`（移除 OverlayToggleButton 与 import）
- Modify: `lib/features/settings/settings_screen.dart`（悬浮窗分组，改两个开关）
- Modify: `lib/l10n/app_zh.arb`, `lib/l10n/app_en.arb`（新增文案）

- [ ] **Step 1: 新增 i18n 文案（zh + en）**

在 `app_zh.arb` 新增：
```json
"overlayDragDropTitle": "开启拖拽导入图片悬浮窗",
"overlayDragDropDescription": "在屏幕上显示悬浮窗，可将其他应用的图片拖入导入",
"overlayAutoStartTitle": "自动开启悬浮窗",
"overlayAutoStartDescription": "打开应用后自动启动悬浮窗，无需手动开启"
```
在 `app_en.arb` 对应新增英文。
Run: `flutter gen-l10n`
Expected: 成功，`app_localizations*.dart` 更新。

- [ ] **Step 2: 移除图库页右上角悬浮窗按钮**

删除 `gallery_screen.dart:405` 的 `const OverlayToggleButton(),`，删除 `gallery_screen.dart:19` 的 `import '../overlay/overlay_toggle_button.dart';`。

- [ ] **Step 3: 设置页悬浮窗分组改为两个开关 + 联动**

在 `settings_screen.dart` 的「悬浮窗」Card 中，把当前单个 `自动开启悬浮窗` 开关替换为两块：

开关 A（开启拖拽导入）绑定 `overlayProvider`：
```dart
final overlayState = ref.watch(overlayProvider);
SwitchListTile(
  title: Text(S.of(context).overlayDragDropTitle),
  subtitle: Text(S.of(context).overlayDragDropDescription),
  value: overlayState.isActive,
  secondary: const Icon(Icons.picture_in_picture_alt),
  onChanged: (value) async {
    await ref.read(overlayProvider.notifier).toggle();
  },
),
```
开关 B（自动开启）绑定 `autoOverlayEnabledProvider`，联动 B→A：
```dart
SwitchListTile(
  title: Text(S.of(context).overlayAutoStartTitle),
  subtitle: Text(S.of(context).overlayAutoStartDescription),
  value: ref.watch(autoOverlayEnabledProvider),
  secondary: const Icon(Icons.auto_mode),
  onChanged: (value) async {
    ref.read(autoOverlayEnabledProvider.notifier).setEnabled(value);
    if (value) {
      // 开自动 -> 若未运行则一并打开
      final c = ref.read(overlayProvider.notifier);
      if (!c.state.isActive) await c.toggle();
    }
  },
),
```

- [ ] **Step 4: 验证编译**

Run: `flutter analyze`
Expected: 无 error。`app.dart` 里 `_autoStartOverlayIfEnabled` 的自动开启逻辑不变（它读 `autoOverlayEnabledProvider`）。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(settings): move overlay toggle to settings with auto-start linkage" -q
```

---

### Task 3: 退出应用时停止悬浮窗

**Files:**
- Modify: `android/app/src/main/kotlin/com/mememaster/app/MainActivity.kt`（onDestroy）

- [ ] **Step 1: MainActivity 重写 onDestroy 停止悬浮窗**

在 `MainActivity.kt` 增加：
```kotlin
override fun onDestroy() {
    super.onDestroy()
    // 应用/Activity 真正销毁（划掉、强杀）时停止悬浮窗前台服务
    try {
        OverlayService.stop(this)
    } catch (e: Exception) {
        android.util.Log.w(tag, "stop overlay on destroy failed", e)
    }
}
```
注意：`OverlayService.stop` 通过 `startService(ACTION_STOP)` 触发服务 `onStartCommand` 停止。确保不被后台启动限制拦截（前台服务已运行，允许发送停止 intent）。`tag` 是实例级 `private val`（MainActivity.kt:282），`onDestroy` 可直接访问。

- [ ] **Step 2: 验证编译**

Run: `flutter build apk --release`
Expected: `✓ Built .../app-release.apk`
（若 `tag` 私有属性访问受限，改用 `android.util.Log.w("MainActivity", ...)`）。

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/mememaster/app/MainActivity.kt
git commit -m "fix(overlay): stop overlay service when app exits" -q
```

---

### Task 4: 重新索引加确认

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`（`_startReindex`）
- Modify: `lib/l10n/app_zh.arb`, `lib/l10n/app_en.arb`

- [ ] **Step 1: 新增 i18n 文案**

zh：`"reindexConfirmTitle": "重新索引所有表情？"`、`"reindexConfirmBody": "将重新扫描并分析所有图片，可能需要较长时间。"`、`"confirm": "确认"`
en 对应对应英文。
Run: `flutter gen-l10n`

- [ ] **Step 2: `_startReindex` 改为先确认**

```dart
void _startReindex(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.of(ctx).reindexConfirmTitle),
      content: Text(S.of(ctx).reindexConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(S.of(ctx).cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            _runReindex(context, ref);
          },
          child: Text(S.of(ctx).confirm),
        ),
      ],
    ),
  );
}

void _runReindex(BuildContext context, WidgetRef ref) {
  final notifier = ref.read(reindexStateProvider.notifier);
  notifier.startReindex();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(S.of(context).reindexStarted),
      duration: const Duration(seconds: 2),
    ),
  );
}
```

- [ ] **Step 3: 验证编译**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(settings): confirm dialog before reindex" -q
```

---

### Task 5: 搜索页 L2 徽标与结果计数同一行

**Files:**
- Modify: `lib/features/search/search_screen.dart`（build 与 _buildResults）

- [ ] **Step 1: 合并两处为一行**

在 `build()` 里删除单独成行的 `_SearchLevelBadge`（lines 262-263 附近），改为在 `_buildResults` 的结果 Row（原 line 300）中合并：

```dart
return Column(children: [
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Text(s.foundResults(_results!.length),
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
        const Spacer(),
        if (_level != SearchLevel.browse) _SearchLevelBadge(level: _level),
      ],
    ),
  ),
  const SizedBox(height: 4),
  Expanded(child: GridView.builder(/* 原样 */)),
]);
```
同时在 `build()` 中删除原来的 `if (_level != SearchLevel.browse) Padding(...badge...)` 块，保持 body 直接 `Expanded(child: _buildResults(...))`。

- [ ] **Step 2: 验证编译**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 3: Commit**

```bash
git add lib/features/search/search_screen.dart
git commit -m "fix(search): merge L2 badge and result count into one row" -q
```

---

### Task 6: S3 去掉定时自动同步

**Files:**
- Modify: `lib/features/settings/s3_sync_screen.dart`（删除定时自动同步卡片）
- Modify（视情况清理）: `lib/features/gallery/gallery_provider.dart`, `lib/services/s3_sync_service.dart`

- [ ] **Step 1: 删除定时自动同步 UI**

删除 `s3_sync_screen.dart` 中「定时自动同步」整块（`scheduledSync` 标题 + `autoSync` 开关 + 间隔下拉，原 lines 434-507 及 `_intervalLabel` 若仅此处用）。同时删除顶部不再使用的 import（如有 `autoSyncEnabledProvider`/`autoSyncIntervalProvider` 相关）。

- [ ] **Step 2: 清理无用 provider / 服务引用**

已确认（grep）`autoSyncEnabledProvider`、`autoSyncIntervalProvider`、`s3_sync_service.dart` 的 `startPeriodicSync`/`stopPeriodicSync`（lines 734/750）**只被** `s3_sync_screen.dart` 引用，无后台调度机制引用。因此全部删除：
- `lib/features/gallery/gallery_provider.dart:1137-1175` 删除 `autoSyncEnabledProvider`、`autoSyncIntervalProvider` 及其 notifier。
- `lib/services/s3_sync_service.dart` 删除 `startPeriodicSync`、`stopPeriodicSync`（及 `onStop`/dispose 里对 `stopPeriodicSync` 的调用，line 758）。

Run: `flutter analyze`
Expected: 无未使用/未定义引用错误。若有残留引用，逐一清理。

- [ ] **Step 3: 验证编译**

Run: `flutter build apk --release`
Expected: 成功。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(s3): remove scheduled auto-sync, keep manual sync buttons" -q
```

---

### Task 7: 调试菜单 GPU 诊断加确认

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`（`_showDebugMenu` 中的 GPU 诊断 onTap）
- Modify: `lib/l10n/app_zh.arb`, `lib/l10n/app_en.arb`

- [ ] **Step 1: 新增 i18n 文案**

zh：`"gpuDiagnoseConfirmTitle": "执行 GPU 加速诊断？"`、`"gpuDiagnoseConfirmBody": "将检测 OpenCL 与 Vulkan 支持，结果写入运行日志。"`
en 对应英文。
Run: `flutter gen-l10n`

- [ ] **Step 2: 「GPU 加速诊断」onTap 加确认**

改为：
```dart
onTap: () => showDialog<void>(
  context: ctx,
  builder: (dialogCtx) => AlertDialog(
    title: Text(S.of(dialogCtx).gpuDiagnoseConfirmTitle),
    content: Text(S.of(dialogCtx).gpuDiagnoseConfirmBody),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogCtx),
        child: Text(S.of(dialogCtx).cancel),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(dialogCtx);
          _runOpenCLDiagnostic(ctx, ref);
        },
        child: Text(S.of(dialogCtx).confirm),
      ),
    ],
  ),
),
```

- [ ] **Step 3: 验证编译**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(settings): confirm dialog before GPU diagnostic" -q
```

---

### Task 8: 整体验证与收尾

**Files:**
- 无新文件

- [ ] **Step 1: 全量分析**

Run: `flutter analyze`
Expected: 无 error / warning（仅允许现有存量）。

- [ ] **Step 2: 全量回归检查 i18n 同步**

Run: `python3 -c "
import json
zh=json.load(open('lib/l10n/app_zh.arb'))
en=json.load(open('lib/l10n/app_en.arb'))
zk={k for k in zh if not k.startswith('@')}
ek={k for k in en if not k.startswith('@')}
assert zk==ek, (zk-ek, ek-zk)
print('i18n in sync:', len(zk))
"`
Expected: i18n in sync，无断言错误。

- [ ] **Step 3: 构建 Android APK**

Run: `flutter build apk --release`
Expected: `✓ Built .../app-release.apk`

- [ ] **Step 4: 汇总提交（如有未提交改动）**

```bash
git status
git log --oneline master..HEAD
```
确认本分支所有改动已提交，无工作区残留。

---

## 真机验证清单（交付前）

- [ ] 悬浮窗开关在设置页：手动开关 A 生效；开自动 B 时 A 自动打开；关 A 不影响 B。
- [ ] 退出应用（划掉）后悬浮窗消失；按 Home 后台时悬浮窗仍在。
- [ ] 重新索引弹确认，取消则不触发。
- [ ] 搜索页 L2 徽标与「找到 n 个结果」同一行。
- [ ] S3 页面无「定时自动同步」，仅手动同步按钮。
- [ ] GPU 诊断弹确认。
- [ ] 中英文案均正确。
