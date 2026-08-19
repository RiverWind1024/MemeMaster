import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/features/gallery/gallery_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('系统级 OCR 平台（Android/iOS）读取已保存的开关状态', () async {
    // 预置已保存状态：ocr_enabled = true
    SharedPreferences.setMockInitialValues({'ocr_enabled': true});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // 模拟 Android：platformCheck 返回 true（系统级 OCR）
        ocrEnabledProvider.overrideWith(
          () => OcrEnabledNotifier(platformCheck: () => true),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(ocrEnabledProvider), true);
  });

  test('非系统级平台且 OCR 不可用时强制关闭', () async {
    SharedPreferences.setMockInitialValues({'ocr_enabled': true});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ocrEnabledProvider.overrideWith(
          () => OcrEnabledNotifier(
            platformCheck: () => false,
            ocrAvailableCheck: () => false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(ocrEnabledProvider), false);
  });
}