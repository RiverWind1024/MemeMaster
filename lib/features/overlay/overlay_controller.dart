import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mememaster/features/gallery/gallery_provider.dart';
import 'package:mememaster/services/log_service.dart';
import 'package:mememaster/services/shared_media_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final SharedPreferences _prefs;
  static const _key = 'overlay_enabled';

  OverlayController(this._prefs) : super(const OverlayState()) {
    _checkPermission();
  }

  final _handler = SharedMediaHandler();

  /// 检查悬浮窗权限
  Future<void> _checkPermission() async {
    LogService.instance.info('Overlay', 'checking permission...');
    final hasPermission = await _handler.canDrawOverlays();
    final isActive = _prefs.getBool(_key) ?? false;
    LogService.instance.info('Overlay', 'canDrawOverlays = $hasPermission, persisted isActive = $isActive');
    state = state.copyWith(hasPermission: hasPermission, isActive: isActive);
  }

  /// 切换悬浮窗开关
  Future<void> toggle() async {
    LogService.instance.info(
        'Overlay',
        'toggle() called, isActive=${state.isActive}, hasPermission=${state.hasPermission}, isLoading=${state.isLoading}');
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);
    try {
      if (state.isActive) {
        LogService.instance.info('Overlay', '-> stopping overlay');
        await _handler.stopOverlay();
        await _prefs.setBool(_key, false);
        state = state.copyWith(isActive: false, isLoading: false);
      } else {
        if (!state.hasPermission) {
          LogService.instance.info('Overlay', '-> requesting permission');
          await _handler.requestOverlayPermission();
          await _checkPermission();
          if (!state.hasPermission) {
            LogService.instance.info('Overlay', '-> permission denied');
            state = state.copyWith(isLoading: false);
            return;
          }
        }
        LogService.instance.info('Overlay', '-> starting overlay');
        final started = await _handler.startOverlay();
        LogService.instance.info('Overlay', '-> startOverlay returned: $started');
        if (started) await _prefs.setBool(_key, true);
        state = state.copyWith(isActive: started, isLoading: false);
      }
    } catch (e, s) {
      LogService.instance.error('Overlay', 'toggle error: $e\n$s');
      state = state.copyWith(isLoading: false);
    }
  }
}

final overlayProvider =
    StateNotifierProvider<OverlayController, OverlayState>((ref) {
  return OverlayController(ref.read(sharedPreferencesProvider));
});
