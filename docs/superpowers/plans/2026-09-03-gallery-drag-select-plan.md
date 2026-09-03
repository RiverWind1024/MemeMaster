# 图库滑动多选功能 —— 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现手机自带图库风格的滑动批量选择：长按进入选择模式后，手指滑动经过的 item 自动选中/取消选中。

**分支：** `polish/product-details`（当前分支）

---

## Chunk 1: 状态变量 + 辅助方法

### Task 1: 添加状态变量

**Files:**
- Modify: `lib/features/gallery/gallery_screen.dart`

- [ ] **Step 1: 在 `_GalleryScreenState` 中添加状态变量**

在现有 `_selectionMode`、`_selectedIds` 等变量附近添加：

```dart
bool _isDragSelecting = false;          // 是否在拖拽选择中
final Set<String> _visitedIds = {};       // 本次拖拽中已处理的 item id
```

- [ ] **Step 2: Commit**

---

## Chunk 2: 滑动选择核心逻辑

### Task 2: 实现滑动选择处理方法

**Files:**
- Modify: `lib/features/gallery/gallery_screen.dart`

- [ ] **Step 1: 在 `_GalleryScreenState` 类中添加 `_handleDragSelect` 方法**

```dart
void _handleDragSelect(Offset globalPosition) {
  if (!_isDragSelecting) return;
  final gridBox = _gridGlobalKey.currentContext?.findRenderObject() as RenderBox?;
  if (gridBox == null) return;
  final localPos = gridBox.globalToLocal(globalPosition);
  final adjustedY = localPos.dy + _scrollOffset - 4;
  final adjustedX = localPos.dx - 4;
  if (adjustedX < 0 || adjustedY < 0) return;
  final col = (adjustedX / 154).floor();
  final row = (adjustedY / 154).floor();
  if (row < 0 || col < 0) return;
  final columns = _gridColumnCount;
  if (columns <= 0) return;
  final index = row * columns + col;
  final memes = ref.read(memeListProvider).valueOrNull;
  if (memes == null || index < 0 || index >= memes.length) return;
  final id = memes[index].id;
  if (!_visitedIds.contains(id)) {
    _visitedIds.add(id);
    _toggleSelection(id);
  }
}
```

- [ ] **Step 2: Commit**

---

## Chunk 3: GridView 包裹与手势拦截

### Task 3: 修改 `_buildMemeGrid`

**Files:**
- Modify: `lib/features/gallery/gallery_screen.dart`

- [ ] **Step 1: 添加 GridView 的 GlobalKey 和滚动偏移量追踪**

在类顶部添加：

```dart
final GlobalKey _gridGlobalKey = GlobalKey();
double _scrollOffset = 0;
int _gridColumnCount = 0;
```

- [ ] **Step 2: 修改 `_buildMemeGrid` 返回 `LayoutBuilder` 包裹的 `Stack` 结构**

将原来的 `GridView.builder` 用 `NotificationListener` + `LayoutBuilder` + `Stack` 包裹，透明手势拦截层在最上方（`Positioned.fill`），接收 `PointerMoveEvent` 触发 `_handleDragSelect`。

关键结构：
```
NotificationListener<ScrollNotification> (阻止拖拽期间滚动)
  LayoutBuilder
    Stack
      RefreshIndicator
        GridView.builder (key: _gridGlobalKey)
      Positioned.fill + Listener + GestureDetector (透明手势拦截层)
        onPointerMove → _handleDragSelect
        onPanStart → _isDragSelecting=true; _visitedIds.clear()
        onPanEnd/Cancel → _isDragSelecting=false; _visitedIds.clear()
```

Grid 列数计算：`columns = (constraints.maxWidth / 154).floor().clamp(1, 10)`
Item 尺寸：150px + 4px spacing = 154px

- [ ] **Step 3: `flutter analyze`**（目标文件，0 error）
- [ ] **Step 4: Commit**

---

## Chunk 4: 收尾验证

### Task 4: 全量验证

- [ ] `flutter analyze`（全项目，0 error）
- [ ] `flutter test`（233 tests passed）
- [ ] `flutter build apk --release`
- [ ] 提交

---

## 验证总览

| 门槛 | 命令 | 期望 |
|---|---|---|
| 静态分析 | `flutter analyze` | 0 error |
| 单元测试 | `flutter test` | All passed |
| 构建 | `flutter build apk --release` | Built |
