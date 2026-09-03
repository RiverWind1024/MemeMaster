# 图库滑动多选功能 —— 设计文档

日期：2026-09-03

## 背景与目标

手机自带图库 App 的多选交互：长按图片进入选择模式，手指在屏幕上滑动，经过的图片自动被选中/取消选中，无需逐个点击。

本次实现目标：**在现有选择模式基础上，增加滑动批量选择能力**，选中效果与现有右上角勾选图标保持一致。

## 现有交互

- `onLongPress` → `_enterSelectionMode(memeId)` → 进入选择模式 + 选中该 item
- `onTap` → `_toggleSelection(memeId)` → 切换单个 item 选中状态
- 选中效果：右上角圆形勾选图标（`Icons.check_circle` / `Icons.circle_outlined`）
- `GridView.builder`（`maxCrossAxisExtent: 150`, spacing: 4px）

## 目标交互

1. **长按**任意 item → 进入选择模式 + 选中该 item（已有）
2. **不抬手指，继续滑动** → 手指经过的 item 自动选中/取消选中
3. **抬起手指** → 滑动选择结束，选择模式保持
4. **GridView 滚动被抑制** → 滑动选择期间不触发列表滚动

## 设计方案

### 核心实现

用 `Stack` 包裹 `GridView`，在 Grid 上覆盖一层透明的 `Positioned.fill(Listener)` 捕获 `PointerMoveEvent`，用 `GestureDetector` 的 `onPanUpdate` 监听拖拽手势。

关键 API：`Listener.onPointerMove` 接收 `PointerMoveEvent`，其中 `position` 是**全局屏幕坐标**。需要将全局坐标转换为 Grid 局部坐标，结合 `scrollController.offset` 和 `maxCrossAxisExtent=150` 计算手指下的 item index。

### 手指坐标 → Grid item index 映射

```
columns = (gridWidth / 150).floor()
scrollOffset = scrollController.offset
localY = globalY - gridTop + scrollOffset
row = (localY / 150).floor()
col = (localX / 150).floor()
index = row * columns + col
```

### 滑动选择状态

```dart
bool _isDragSelecting = false;
Set<String> _visitedIds = {};  // 本次拖拽中已处理的 item id，防止重复 toggle
```

- `onPanStart`：`_isDragSelecting = true; _visitedIds.clear()`
- `onPanUpdate`：每帧将手指坐标转为 item index，若该 id 未在 `_visitedIds` 中则 `_toggleSelection(id)` 并加入 `_visitedIds`
- `onPanEnd`：` _isDragSelecting = false; _visitedIds.clear()`

### Grid 滚动抑制

拖拽选择期间阻止 GridView 滚动。最简方案：在 `_isDragSelecting == true` 时用 `NeverScrollableScrollPhysics` 替换 GridView 的 physics，之后恢复。

### 与现有 onTap 的冲突

Flutter 手势竞技场中 `onPan` 会覆盖 `onTap`。由于 `onTap` 内部已有 `_selectionMode` 判断（选择模式下走 `_toggleSelection`，否则跳转详情），滑动过程中手指抬起时 `onTap` 不会误触发。

长按后立即滑动的场景：`onLongPress` 先触发进入选择模式并选中当前 item，随后 `onPanUpdate` 开始追踪手指，经过的 item 自动 toggle。

### 改动文件

- `lib/features/gallery/gallery_screen.dart`（`_buildMemeGrid` 为主）
