# MemeHelper 用户交互设计

> 所属项目: MemeHelper
> 文档编号: 11-user-interaction.md
> 涵盖: 手势、动画、触感反馈、微交互

---

## 1. 交互设计原则

| 原则 | 说明 |
|------|------|
| **即时反馈** | 任何用户操作必须在 100ms 内给出视觉/触觉响应 |
| **渐进披露** | 复杂功能逐步展示，不一次性堆叠 |
| **容错** | 删除/覆盖等破坏性操作提供撤销或二次确认 |
| **状态可见** | 后台任务（分析、同步）进度随时可见 |
| **一致性** | 类似操作使用相同的手势和反馈模式 |

---

## 2. 手势映射表

| 手势 | 触发区域 | 效果 | 触感反馈 |
|------|---------|------|---------|
| 点击 (Tap) | 缩略图 | 打开详情页 | 轻触 (HapticFeedback.lightImpact) |
| 点击 | 搜索框 | 聚焦→展开搜索页 | 无 |
| 点击 | FAB (+) | 打开导入弹窗 | 轻触 |
| 长按 (Long Press) | 缩略图 | 进入多选模式 | 强反馈 (HapticFeedback.heavyImpact) |
| 长按 + 拖动 | 多选后的缩略图 | 批量移动 | 中反馈 |
| 滑动 (Swipe) | 详情页图片 | 切换到上一张/下一张 | 无 |
| 下拉 (Pull Down) | Gallery 页面 | 刷新 / 重新检查分析 | 无 |
| 上滑 (Scroll) | Gallery | 加载更多 | 无 |
| 双指捏合 (Pinch) | 详情页图片 | 缩放 | 无 |
| 点击 | AppBar 标题 | 滚动到列表顶部 | 轻触 |
| 右滑返回 | 详情页 | 返回 Gallery | 无 |
| 长按 | 标签 Chip | 弹出"删除标签"选项 | 中反馈 |
| 拖动 (Drag) | 文件夹列表 | 长按拖拽排序 | 中反馈 |

### 2.1 手势冲突处理

```
场景: Gallery 中同时支持水平滚动(文件夹)和垂直滚动(列表)
方案: 垂直滚动为主（列表），水平为次（颜色芯片行），不冲突
      详情页的左右滑动切换和垂直滚动通过方向惯性区分
```

---

## 3. 动画规格

### 3.1 动画曲线

| 场景 | 曲线 | 时长 | 说明 |
|------|------|------|------|
| 页面转场 | `Curves.easeInOutCubic` | 300ms | 标准 Material 转场 |
| 弹窗/底部 Sheet | `Curves.easeOutBack` | 350ms | 弹簧效果弹出 |
| FAB 展开/收起 | `Curves.easeInOut` | 200ms | 快速响应 |
| 搜索栏展开 | `Curves.easeOutCubic` | 250ms | 平滑展开 |
| 颜色 Chip 添加/移除 | `Curves.elasticOut` | 300ms | 弹性效果 |
| 缩略图加载 | `Curves.easeOut` | 150ms | 淡入 |
| 角标状态切换 | `Curves.easeInOut` | 200ms | 灰→蓝→绿渐变 |
| 多选选中动画 | `Curves.easeOutBack` | 250ms | 选中标记弹性出现 |
| 错误提示消失 | `Curves.easeIn` | 300ms | 淡出 |
| 进度条动画 | `Curves.linear` | 按实际 | 连续平缓 |
| SnackBar 出现/消失 | `Curves.easeInOut` | 400ms | 底部弹出/收回 |

### 3.2 关键动画实现

```dart
// 1. 缩略图淡入动画
AnimatedOpacity(
  opacity: _isLoaded ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 150),
  curve: Curves.easeOut,
  child: Image.memory(thumbnailBytes),
)

// 2. 多选选中标记弹性出现
AnimatedScale(
  scale: isSelected ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOutBack,
  child: CheckMark(),
)

// 3. 搜索栏展开
AnimatedContainer(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOutCubic,
  width: isExpanded ? fullWidth : searchIconSize,
  child: SearchBar(),
)

// 4. 页面转场
CustomTransitionPage(
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      )),
      child: child,
    );
  },
)
```

---

## 4. 触感反馈 (Haptic Feedback)

| 操作 | 反馈类型 | API |
|------|---------|-----|
| 点击按钮 | 轻触 | `HapticFeedback.lightImpact()` |
| 长按进入多选 | 强 | `HapticFeedback.heavyImpact()` |
| 切换开关 | 轻触 | `HapticFeedback.selectionClick()` |
| 拖拽排序 | 中 | `HapticFeedback.mediumImpact()` |
| 错误操作 | 警告 | `HapticFeedback.vibrate()` (自定义振动) |
| 导入完成 | 成功 | 自定义振动 (100ms) |
| 分析完成 | 通知 | `HapticFeedback.selectionClick()` |

```dart
// haptic_service.dart
class HapticService {
  static void lightTap() => HapticFeedback.lightImpact();
  static void heavyTap() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void mediumImpact() => HapticFeedback.mediumImpact();

  static Future<void> success() async {
    // 自定义成功振动: 两次短振
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.vibrate();
  }

  static Future<void> error() async {
    // 错误振动: 三次短振
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }
}
```

---

## 5. 微交互细节

### 5.1 导入流程微交互

```
用户点击 FAB (+)
    │
    ├── FAB 旋转 45° 变为 ✕（200ms easeInOut）
    ├── 底部弹出 ImportSourceSheet（350ms easeOutBack）
    │
    ├── 用户选择"从相册选择"
    │   ├── Sheet 收回（200ms easeIn）
    │   ├── 系统文件选择器打开
    │   ├── 用户选定图片后返回
    │   │
    │   ├── SnackBar: "正在导入 3 张..."（400ms 滑入）
    │   ├── 底部出现 ImportProgressCard
    │   │   ├── 进度条平滑动画（每张完成跳一次）
    │   │   ├── 已完成数字跳动更新
    │   │   └── Card 从底部升起（250ms）
    │   │
    │   └── 导入完成
    │       ├── ImportProgressCard 变为
    │       │   "✓ 成功导入 3 张，跳过 0 张（重复）"
    │       ├── 角标：新增 meme 显示灰点（pending）
    │       ├── 成功触感反馈
    │       └── 3s 后 Card 自动淡出消失
    │
    └── 分析开始在后台进行
        └── 缩略图上的灰点逐张变为蓝色旋转 → 绿色
```

### 5.2 搜索流程微交互

```
用户点击搜索栏
    │
    ├── 搜索栏展开（250ms easeOutCubic）
    ├── 键盘弹出（系统行为）
    ├── Gallery 内容切换为搜索界面
    │
    ├── 用户输入 "悲伤"
    │   ├── 300ms debounce 后触发搜索
    │   ├── 结果网格淡入（每项间隔 50ms 依次出现，共 50×6=300ms）
    │   │
    │   └── 可同时点击颜色芯片
    │       ├── 芯片带弹性效果添加（300ms elasticOut）
    │       ├── 结果即时刷新
    │       └── 再次点击芯片取消（芯片飞出动画，200ms easeIn）
    │
    ├── 结果排序
    │   └── 匹配度从上到下递减
    │
    └── 点击搜索结果
        └── 页面向右推进进入详情（300ms slideIn）
```

### 5.3 多选交互细节

```
用户长按某张缩略图（>300ms）
    │
    ├── 缩略图微缩小（scale 0.95, 50ms）
    ├── 角标出现选中标记（250ms elasticOut）
    ├── 顶部 AppBar 变为多选操作栏
    │   ├── "已选 1 张"（文字动画）
    │   ├── 出现 [全选] [移动] [删除] [取消]
    │   └── AppBar 背景色略微变化
    │
    ├── 继续点击其他项
    │   └── 每项都有 250ms 弹性选中动画
    │
    ├── 点击 [删除]
    │   ├── 底部弹出确认 Sheet（350ms）
    │   └── 确认后:
    │       ├── 选中项淡出 + 缩放为 0（200ms easeIn）
    │       ├── 网格紧凑排列（animate 300ms）
    │       ├── SnackBar: "已删除 3 张" + [撤销]
    │       └── 点击撤销 → 恢复（反向动画 200ms）
    │
    └── 点击 [取消]
        └── 选中标记逆序消失（每项 100ms）
```

### 5.4 同步交互细节

```
用户进入设置 → S3 同步
    │
    ├── 未配置: 显示配置表单
    │   ├── 输入时实时验证 (Endpoint, Access Key)
    │   ├── [测试连接] 按钮
    │   │   ├── 点击 → 按钮变为加载旋转（CircularProgressIndicator）
    │   │   ├── 成功 → 绿色对勾 + "连接成功"（300ms）
    │   │   └── 失败 → 红色 ✕ + 错误信息（抖动动画 300ms）
    │   └── [保存] 成功 → SnackBar: "同步配置已保存"
    │
    ├── 已配置: 显示同步状态页
    │   ├── 卡片显示上次同步时间
    │   ├── [立即同步] 按钮
    │   │   ├── 点击 → 按钮旋转加载
    │   │   ├── 进度: "正在上传 3 张 / 下载 1 张"
    │   │   └── 完成 → 绿色对勾 + 触感反馈
    │   └── 自动同步开关
    │
    └── 同步出错
        └── 卡片变为红色边框 + 错误信息 + [重试] 按钮
```

---

## 6. 加载与过渡状态

### 6.1 Skeleton Loading

```
Gallery 首次加载时:
┌──────────────────────────────────┐
│                                  │
│  ┌────┐ ┌────┐ ┌────┐           │
│  │ ░░░░│ │ ░░░░│ │ ░░░░│          │  ← 灰色闪烁占位块
│  │ ░░░░│ │ ░░░░│ │ ░░░░│          │     (Shimmer 动画)
│  └────┘ └────┘ └────┘           │
│  ┌────┐ ┌────┐ ┌────┐           │
│  │ ░░░░│ │ ░░░░│ │ ░░░░│          │
│  └────┘ └────┘ └────┘           │
│                                  │
└──────────────────────────────────┘

实现: ShimmerEffect (两个渐变带状在灰色块上滑动)
```

### 6.2 进度指示器

```dart
// 分析进度 - 线性进度条（AppBar 下方）
LinearProgressIndicator(
  value: analyzedCount / totalCount,
  minHeight: 2,
)

// 导入进度 - 带百分比的进度卡
ImportProgressCard(
  current: 23,
  total: 45,
  skipped: 3,
  // 内嵌动画数字
)

// 无限进度 - 使用扇形旋转
CircularProgressIndicator(
  strokeWidth: 3,
)

// 搜索加载 - 结果项依次淡入
SearchResultItem(
  // stagger animation
)
```

### 6.3 过渡状态表

| 状态 | 交互 | UI 反馈 | 持续时间 |
|------|------|---------|---------|
| 按钮加载 | 点击后禁用 | 文字变为 CircularProgressIndicator | 直到完成 |
| 下拉刷新 | 拖拽 | 顶部刷新指示器 + "正在检查..." | ~1s |
| 页面切换 | Tab 点击 | 页面滑动 + AppBar 标题渐变 | 300ms |
| 搜索输入 | 打字 | 300ms 延迟后结果更新 | 300ms |
| 图片加载 | 滚动 | 淡入显示（150ms） | 150ms |
| 同步进行 | 手动触发 | 按钮旋转 + 状态文字 | 直到完成 |
| 模型下载 | 触发下载 | 进度条 + 百分比 + MB/s | 几分钟 |

---

## 7. 空状态交互

| 空状态 | 插图 | 文案 | 操作按钮 |
|--------|------|------|---------|
| 无 meme | 空相册插图 | "还没有表情包" | [📥 导入表情包] |
| 搜索无结果 | 搜索插图 | "没找到相关表情包" | [试试颜色搜索] |
| 文件夹为空 | 空文件夹插图 | "这个文件夹还空着" | [从其他文件夹移入] |
| 分析队列空 | 打勾插图 | "所有表情包已分析完成" | — |
| 同步未配置 | 云插图 | "未配置同步" | [配置 S3 同步] |

---

## 8. 错误交互

| 错误 | 呈现方式 | 操作 |
|------|---------|------|
| 导入失败（文件损坏） | SnackBar: "2 张图片导入失败" | [详情] |
| 分析失败 | 缩略图红点角标 | 点击红点→[重新分析] |
| 存储空间不足 | Dialog: "存储空间不足" | [去清理] + [取消] |
| 模型加载失败 | Dialog: "模型加载失败" | [重新下载] + [取消] |
| 同步网络错误 | 同步卡片红色 | [重试] |
| 数据库错误 | 全屏错误页面 | [重启 App] |
| 权限不足 | SnackBar: "需要文件访问权限" | [去设置] |

### 8.1 SnackBar 行为规范

```dart
// 成功: 绿色左侧条
SnackBar(
  content: Text('导入成功 (3 张)'),
  behavior: SnackBarBehavior.floating,
  duration: Duration(seconds: 4),
  action: SnackAction(
    label: '撤销',
    onPressed: () => undoImport(),
  ),
)

// 错误: 红色左侧条
SnackBar(
  content: Text('2 张导入失败'),
  backgroundColor: Colors.red.shade700,
  behavior: SnackBarBehavior.floating,
  action: SnackAction(
    label: '详情',
    onPressed: () => showErrorDetails(),
  ),
)

// 信息: 无颜色条
SnackBar(
  content: Text('后台分析中...'),
  behavior: SnackBarBehavior.floating,
  duration: Duration(seconds: 2),
)
```

---

## 9. 无障碍 (Accessibility)

| 元素 | 语义标签 | 手势替代 |
|------|---------|---------|
| 缩略图 | "meme: {tags}" | Tap 替代长按选中 |
| FAB | "导入表情包" | 屏幕阅读器焦点 |
| 颜色芯片 | "蓝色" | Tap 代替滑动 |
| 删除按钮 | "删除选中 {n} 张" | 确认对话框辅助 |
| 分析角标 | "分析完成" / "分析失败" | 文字描述 |

```dart
Semantics(
  label: 'meme: ${meme.tags?.firstOrNull?.content ?? "未标注"}',
  onLongPress: () => _enterSelectionMode(meme),
  child: MemeGridTile(meme: meme),
)
```
