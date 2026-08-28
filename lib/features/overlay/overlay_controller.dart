import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mememaster/services/shared_media_handler.dart';

/// 悬浮窗状态
class OverlayState {
  final bool isActive;
  final bool hasPermission;
  final bool isLoading;

  const OverlayState({
    this.isActive = false,
    this.hasPermission = false,
    this.isLoading = false,
  });

  OverlayState copyWith({
    bool? isActive,
    bool? hasPermission,
    bool? isLoading,
  }) {
    return OverlayState(
      isActive: isActive ?? this.isActive,
      hasPermission: hasPermission ?? this.hasPermission,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 悬浮窗控制器
class OverlayController extends StateNotifier<OverlayState> {
  OverlayController() : super(const OverlayState()) {
    _checkPermission();
  }

  final _handler = SharedMediaHandler();

  /// 检查悬浮窗权限
  Future<void> _checkPermission() async {
    final hasPermission = await _handler.canDrawOverlays();
    state = state.copyWith(hasPermission: hasPermission);
  }

  /// 切换悬浮窗开关
  Future<void> toggle() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);
    try {
      if (state.isActive) {
        await _handler.stopOverlay();
        state = state.copyWith(isActive: false, isLoading: false);
      } else {
        if (!state.hasPermission) {
          await _handler.requestOverlayPermission();
          await _checkPermission();
          if (!state.hasPermission) {
            state = state.copyWith(isLoading: false);
            return;
          }
        }
        final started = await _handler.startOverlay();
        state = state.copyWith(isActive: started, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final overlayProvider =
    StateNotifierProvider<OverlayController, OverlayState>((ref) {
  return OverlayController();
});
