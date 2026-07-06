# AI Chat 测试功能设计

## 概述

将现有的「测试推理」按钮改造为打开一个 AI Chat 对话框，用户可以自由输入问题测试 AI 对话。

## UI 设计

采用 **全屏对话框 (Full-screen Dialog)** 形式：

```
┌─────────────────────────────┐
│ ← 返回    AI Chat      模型名│  ← AppBar
├─────────────────────────────┤
│                             │
│  用户: 你好                 │
│                             │
│  AI: 你好！有什么可以帮助   │  ← 消息列表
│  你的吗？                   │
│                             │
├─────────────────────────────┤
│ [输入框...              ] [发送]│  ← InputBar
└─────────────────────────────┘
```

## 架构设计

### 组件

| 组件 | 说明 |
|------|------|
| `LlmChatScreen` | 全屏对话框，包含 AppBar、消息列表、输入框 |

### 复用现有服务

- `OpenAiLlmService.chat(messages)` - 远程 API（支持多轮对话）
- `LocalLlmService.complete(prompt)` - 本地模型（无 chat 接口，用 complete）

### 消息结构

```dart
class ChatMessage {
  final bool isUser;      // true=用户, false=AI
  final String content;    // 消息内容
  final DateTime? time;   // 时间戳
}
```

## 实现步骤

1. 创建 `LlmChatScreen` 全屏对话框
2. 修改 `LlmSettingsScreen` 测试按钮跳转逻辑
3. 添加国际化字符串

## 改动文件

| 文件 | 操作 |
|------|------|
| `lib/features/llm/llm_chat_screen.dart` | 新建 Chat 对话框 |
| `lib/features/settings/llm_settings_screen.dart` | 修改测试按钮 |
| `lib/l10n/app_en.arb`, `app_zh.arb` | 添加国际化 |

## 进度

- [x] 设计完成
- [ ] 实现 LlmChatScreen
- [ ] 修改 LlmSettingsScreen
- [ ] 添加国际化
- [ ] 测试
