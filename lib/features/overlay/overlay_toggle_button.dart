import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mememaster/features/overlay/overlay_controller.dart';

/// 悬浮窗开关按钮
class OverlayToggleButton extends ConsumerWidget {
  const OverlayToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayState = ref.watch(overlayProvider);

    return IconButton(
      icon: overlayState.isActive
          ? const Icon(Icons.picture_in_picture)
          : const Icon(Icons.picture_in_picture_alt),
      tooltip: overlayState.isActive ? '关闭悬浮窗' : '开启悬浮窗',
      onPressed: overlayState.isLoading
          ? null
          : () {
              debugPrint('[Overlay] toggle button pressed');
              ref.read(overlayProvider.notifier).toggle();
            },
    );
  }
}
