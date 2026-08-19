# TREK 风格 UI 视觉改造设计

日期：2026-08-19

## 背景

当前应用主题为默认 Material 3 `ColorScheme.fromSeed(deepPurple)`，视觉风格与 TREK（liketrek/TREK）差距较大。
本次改造借鉴 TREK 的 UI 设计语言：设计令牌化的色彩系统、玻璃态（Glassmorphism）、渐进式圆角、
柔和阴影、统一动画曲线与文本层级，应用到一个表情包管理工具中。

范围约定（已与需求方确认）：

- **仅视觉风格**：不引入用户可配置性（强调色/文字缩放/密度等设计令牌驱动系统不做）
- **强调色**：Indigo（浅 `#4f46e5` / 深 `#6366f1`）
- **玻璃态范围**：导航栏 + 弹窗 + 底部面板（内容卡片保持实心，突出图片本身）
- **实现方案**：集中式 ThemeData + 共享玻璃组件，**不新增依赖**

## 文件架构

```
lib/core/theme/
├── app_theme.dart          # buildLightTheme() / buildDarkTheme() 集中定义
├── app_animations.dart     # 缓动曲线 & 时长常量（TREK ease + 220ms）
└── glass_container.dart    # GlassContainer 毛玻璃组件
```

`app.dart` 改用 `buildLightTheme()/buildDarkTheme()`，其余页面组件自动继承主题。

## 色彩系统

| 角色 | 浅色 | 深色 |
|---|---|---|
| 主背景 surface | `#ffffff` | `#121215` |
| 次级背景 surfaceContainerLow | `#f8fafc` | `#1a1a1e` |
| 三级背景 surfaceContainerHighest | `#f1f5f9` | 深灰递进 |
| 主文字 onSurface | `#111827` | `#f4f4f5` |
| 次级文字 | `#374151` | `#d4d4d8` |
| 柔和文字 | `#6b7280` | `#a1a1aa` |
| **强调色 primary** | `#4f46e5` (indigo) | `#6366f1` |
| 成功 | `#16a34a` | `#22c55e` |
| 危险 | `#dc2626` | `#ef4444` |

实现方式：`ColorScheme.fromSeed(seedColor: indigo)` 生成基础色板后，用 `copyWith`
精确覆盖 surface/onSurface/文字层级色，确保 TREK 质感而非默认 M3 灰紫色调。

## 玻璃态（GlassContainer）

TREK 风格参数：

- `BackdropFilter`：`blur(22px) + saturate(1.7)`
- 半透明背景：浅色 `rgba(255,255,255,.7)` / 深色 `rgba(255,255,255,.06)`（深浅各一）
- 圆角默认 14，可配置
- 顶部高光描边：`inset 0 1px 0 rgba(255,255,255,.1)`
- 阴影：`0 8px 32px rgba(0,0,0,.18)`

### 应用位置

| 位置 | 实现方式 |
|---|---|
| 底部 NavigationBar（main_screen） | `extendBody: true` + `GlassContainer` 包裹 |
| gallery / search 的 AppBar | `extendBodyBehindAppBar` + 玻璃包裹（含 gallery 的 TabBar+排序栏） |
| AlertDialog | DialogTheme 半透明背景 + 内容内层 `GlassContainer` |
| showModalBottomSheet | BottomSheetTheme 圆角 28 + 半透明 + 玻璃 |
| SnackBar | 半透明玻璃浮条 |

## 圆角系统

| 场景 | 圆角 |
|---|---|
| 小控件/标签（Chip/小型按钮） | 10 |
| 输入框/小卡片 | 14 |
| 常规卡片（Card） | 18 |
| 弹窗（Dialog） | 22 |
| 底部面板（BottomSheet） | 28 |

通过 CardTheme / DialogTheme / BottomSheetTheme / InputDecorationTheme 等组件主题统一。

## 阴影系统

- 卡片：`0 8px 24px rgba(0,0,0,.14)`
- 弹窗/浮层：`0 8px 32px rgba(0,0,0,.18)`

## 动画

`app_animations.dart` 导出常量：

```dart
// 等价 cubic-bezier(.2,.7,.2,1)
const kTrekEase = ...;
const kTrekDuration = Duration(milliseconds: 220);
```

应用于新增过渡动画与交互反馈；现有 Radial 菜单等已有效果的保留不动。

## 文本层级

| TREK | Flutter TextTheme | 颜色 |
|---|---|---|
| title (24px) | titleLarge | 主文字色，加粗 |
| subtitle (18px) | titleMedium | 次级文字色 |
| body (14px) | bodyMedium | 主文字色 |
| caption (12px) | bodySmall | 柔和文字色 |

通过 TextTheme 统一设置，全局生效。

## 页面改造清单

1. `app.dart` — 接入新主题
2. `main_screen.dart` — NavigationBar 玻璃包裹 + `extendBody`
3. `gallery_screen.dart` — AppBar 玻璃化（含 TabBar/排序栏）
4. `search_screen.dart` — AppBar 玻璃化
5. `meme_detail_screen.dart` — 详情页弹窗（若需覆盖）
6. `settings_screen.dart` — 主题自动继承，检查卡片圆角

其余页面（scan/import/log/s3 等）只通过 ThemeData 继承，不逐页修改。

## 验证方式

- 现有集成测试/单元测试继续跑通（`flutter test` + `integration_test`）
- 手动运行 `flutter run -d linux` 检查深浅模式切换、各平台无回归
- 不新增测试文件（UI 视觉改动以人工验收为主）