import 'package:flutter/animation.dart';

// 注：本文件常量为主题基础设施的一部分，供后续新增动画/过渡时统一引用（预留）。
// 当前版本尚未消费，避免各处硬编码散落的 duration/curve。

/// TREK 主缓动曲线，等价 cubic-bezier(.2, .7, .2, 1)
const kTrekEase = Cubic(0.2, 0.7, 0.2, 1.0);

/// TREK 快速弹出曲线，等价 cubic-bezier(.23, 1, .32, 1)
const kTrekEaseQuint = Cubic(0.23, 1.0, 0.32, 1.0);

/// 标准交互时长
const kTrekDuration = Duration(milliseconds: 220);