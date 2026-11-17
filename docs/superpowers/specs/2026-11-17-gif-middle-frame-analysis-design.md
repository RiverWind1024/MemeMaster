# GIF 分析取中间帧 设计

日期：2026-11-17

## 背景

颜色提取、OCR、视觉 AI 分析此前都按「第 0 帧」处理 GIF，导致：

- 动图首帧常是黑屏、纯色或片头，取色结果与内容不符
- 首帧无文字时 OCR 无结果，即使中间帧有文字
- AI 标签只基于首帧，和用户实际看到的画面不一致

`image: 4.9.1` 的 GIF 解码器在 `decode()` 时会把所有帧解码并合成，返回的 `Image`
带有完整 `frames` 列表（`gif_decoder.dart`）。因此取中间帧不需要额外解码成本。

## 方案

新增 `lib/core/image/analysis_frame.dart`：

- `selectAnalysisFrame(img.Image)`：多帧时返回 `frames[numFrames ~/ 2]`，静态图原样返回。
- `withAnalysisFrameFile(path, action)`：动图 GIF 的中间帧编码为临时 PNG 后交给
  `action`，结束后删除；非 GIF 或单帧 GIF 直接透传原路径。

接入点：

1. `lib/core/image/color_extractor.dart` — 解码后取中间帧再交给 K-means。
2. `lib/services/parallel_analysis_scheduler.dart` — OCR 调用包一层
   `withAnalysisFrameFile`（OCR 各平台实现只接受文件路径）。
3. `lib/core/llm/vision_enricher.dart` — 读取字节后，动图 GIF 替换为中间帧 PNG 字节，
   再走原有压缩/缩放逻辑（压缩关闭时也替换）。

不改：

- 存储文件与展示：原 GIF 保留，`Image.file` 继续播放动画。
- `meme_detector`：GIF 本就自动放行，不参与 OCR。
- 旧 `analysis_queue_scheduler.dart`：全项目无实例化。

## 代价与约束

- 固定取 `numFrames ~/ 2`，若中间帧是空白/过渡帧，分析结果会偏差；日志记录
  `GIF 取帧 n/N` 便于排查。
- `decodeImage` 对多帧 GIF 是全帧解码，属既有成本。
- 不要用 `decodeImage(bytes, frame: n)` 取单帧：它不做前序帧合成，结果可能缺内容。

## 测试

`test/core/image/analysis_frame_test.dart`：

- 静态图返回自身
- 3 帧 GIF 返回中间帧
- 非 GIF 不产生临时文件
- GIF 临时文件在回调结束后删除
