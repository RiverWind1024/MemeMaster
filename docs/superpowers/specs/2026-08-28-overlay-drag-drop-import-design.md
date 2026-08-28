# 悬浮窗拖放导入设计文档

## 概述

实现一个常驻的Android系统级悬浮窗，用户可以从微信等应用直接拖动图片到悬浮窗，自动导入到MemeMaster。

## 目标

- 用户在微信中长按图片 → 扣图 → 拖动到MemeMaster悬浮窗 → 自动导入
- 无需经过剪贴板，直接通过Android DragEvent API实现跨应用拖放
- 悬浮窗常驻显示在屏幕边缘，不影响用户正常操作

## 技术方案

### 架构

```
┌─────────────────────────────────────────┐
│  Android原生层                           │
│  ┌─────────────────────────────────────┐ │
│  │  OverlayService (前台服务)           │ │
│  │  ┌─────────────────────────────┐   │ │
│  │  │  WindowManager悬浮窗        │   │ │
│  │  │  ┌───────────────────────┐  │   │ │
│  │  │  │  OverlayView          │  │   │ │
│  │  │  │  - OnDragListener     │  │   │ │
│  │  │  │  - 接收DragEvent      │  │   │ │
│  │  │  │  - 获取ClipData URI   │  │   │ │
│  │  │  │  - 请求权限           │  │   │ │
│  │  │  └───────────┬───────────┘  │   │ │
│  │  └──────────────┼──────────────┘   │ │
│  └─────────────────┼──────────────────┘ │
└────────────────────┼────────────────────┘
                     │ MethodChannel
┌────────────────────▼────────────────────┐
│  Flutter层                               │
│  - 接收URI                              │
│  - 复制到缓存                           │
│  - 导入MemeMaster                       │
└─────────────────────────────────────────┘
```

### 用户流程

1. 在MemeMaster中开启悬浮窗 → 屏幕右侧边缘显示小图标
2. 打开微信，长按图片 → 扣图
3. 拖动图片到MemeMaster悬浮窗
4. 悬浮窗高亮显示"松开导入"
5. 松开 → 自动导入到MemeMaster

### 权限需求

| 权限 | 用途 |
|------|------|
| `SYSTEM_ALERT_WINDOW` | 显示系统级悬浮窗 |
| `FOREGROUND_SERVICE` | 保持服务运行 |
| `POST_NOTIFICATIONS` | 显示前台服务通知（Android 13+） |

### 关键实现

#### 1. OverlayService（前台服务）

- 使用`WindowManager`创建`TYPE_APPLICATION_OVERLAY`悬浮窗
- 悬浮窗尺寸：60x120dp，位于屏幕右侧边缘
- 支持拖动调整位置
- 前台服务通知常驻

#### 2. OverlayView（悬浮窗视图）

- 设置`OnDragListener`监听拖放事件
- 处理`ACTION_DRAG_STARTED`：高亮显示"松开导入"
- 处理`ACTION_DROP`：获取`ClipData`中的图片URI
- 处理`ACTION_DRAG_ENDED`：恢复默认状态

#### 3. 数据传递

- 通过`MethodChannel`将URI传递给Flutter层
- Flutter层调用`SharedMediaHandler().copyContentUri()`复制到缓存
- 调用`ImportService.importImages()`导入

### 代码结构

```
android/app/src/main/kotlin/com/mememaster/app/
├── overlay/
│   ├── OverlayService.kt        # 前台服务
│   ├── OverlayView.kt           # 悬浮窗视图（含OnDragListener）
│   └── OverlayPermissionHelper.kt  # 权限管理
└── MainActivity.kt              # 添加OverlayService启动逻辑
```

### UI设计

悬浮窗样式：
- 尺寸：60x120dp
- 位置：屏幕右侧边缘，垂直居中
- 默认状态：半透明MemeMaster图标
- 拖入状态：高亮显示，显示"松开导入"文字
- 支持上下拖动调整位置

### 错误处理

- 权限未授予：引导用户到设置页面开启
- 服务启动失败：显示错误提示
- 拖放失败：显示失败提示，保留原图在剪贴板作为备选

### 限制

- 仅支持Android（iOS不支持系统级悬浮窗）
- 需要用户手动授权悬浮窗权限
- Android 8.0+需要前台服务通知
- 部分厂商可能有额外限制

## 测试方案

1. 基础功能测试：悬浮窗显示/隐藏/拖动
2. 拖放测试：从微信拖动图片到悬浮窗
3. 权限测试：权限授予/拒绝/撤销
4. 兼容性测试：不同Android版本和厂商设备
5. 性能测试：服务运行时的内存和电量影响
