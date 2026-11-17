# GIF 分析取首帧 + 中间帧 设计

日期：2026-11-17

## 背景

颜色提取、OCR、视觉 AI 分析此前都按「第 0 帧」处理 GIF，导致：

- 动图首帧常是黑屏、纯色或片头，取色结果与内容不符
- 首帧无文字时 OCR 无结果，即使中间帧有文字
- AI 标签只基于首帧，和用户实际看到的画面不一致

`image: 4.8/4.9` 的 GIF 解码器在 `decode()` 时会把所有帧解码并合成，返回的 `Image`
带有完整 `frames` 列表，因此多取一帧没有额外解码成本。

## 方案

新增 `lib/core/image/analysis_frame.dart`：

- `selectAnalysisFrames(img.Image)`：多帧时返回 `[frames.first, frames[numFrames ~/ 2]]`，
  静态图只返回自身。
- `combineAnalysisFrames(List<img.Image>)`：垂直拼接成一张图，供只接受单图的分析使用。
- `withAnalysisFramesFiles(path, action)`：动图 GIF 的首帧和中间帧编码为两个临时 PNG 后
  交给 `action`，结束后删除；非 GIF 或单帧 GIF 直接透传原路径。

接入点：

1. `lib/core/image/color_extractor.dart` — 首帧 + 中间帧垂直拼接后一起跑一次 K-means，
   颜色比例是两帧的综合结果。
2. `lib/services/parallel_analysis_scheduler.dart` — 两帧分别 OCR，再用
   `OcrResult.merged()` 合并：文本按行去重（保留首次出现顺序），blocks 与 diagnostics 拼接。
3. `lib/core/llm/vision_enricher.dart` — 首帧 + 中间帧垂直拼成一张 PNG 后走原有压缩逻辑，
   模型一次请求看到两个画面（压缩关闭时也拼接）。

不改：

- 存储文件与展示：原 GIF 保留，`Image.file` 继续播放动画。
- `meme_detector`：GIF 本就自动放行，不参与 OCR。
- 旧 `analysis_queue_scheduler.dart`：全项目无实例化。

## 代价与约束

- 颜色提取是两帧像素一起聚类，不是分别提取后合并，因此比例可直接比较。
- OCR 每张动图会调用两次识别引擎，成本约为静态图的两倍。
- 视觉 AI 的输入变成两帧拼接图，压缩后每帧分辨率减半。
- `decodeImage` 对多帧 GIF 是全帧解码，属既有成本。
- 不要用 `decodeImage(bytes, frame: n)` 取单帧：它不做前序帧合成，结果可能缺内容。

## 测试

- `test/core/image/analysis_frame_test.dart`：静态图、3 帧取首帧+中间帧、两帧拼接尺寸与像素、
  非 GIF 透传、临时文件清理。
- `test/core/ocr/ocr_result_merge_test.dart`：空列表、单帧、文本去重与 blocks/diagnostics 拼接。
