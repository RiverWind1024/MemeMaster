import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/ocr/ocr_service.dart';

void main() {
  group('OcrResult.merged', () {
    test('空列表返回空结果', () {
      final merged = OcrResult.merged([]);
      expect(merged.text, isEmpty);
      expect(merged.blocks, isEmpty);
    });

    test('单帧原样返回', () {
      const single = OcrResult(
        text: 'hello',
        blocks: [OcrBlock(text: 'hello', boundingBox: Rect.zero)],
      );
      expect(identical(OcrResult.merged([single]), single), isTrue);
    });

    test('文本按行去重，blocks 与 diagnostics 拼接', () {
      const first = OcrResult(
        text: 'hello\nworld',
        blocks: [OcrBlock(text: 'hello', boundingBox: Rect.zero)],
        diagnostics: ['frame0'],
      );
      const middle = OcrResult(
        text: 'world\n中文',
        blocks: [OcrBlock(text: '中文', boundingBox: Rect.zero)],
        diagnostics: ['frame1'],
      );

      final merged = OcrResult.merged([first, middle]);

      expect(merged.text, 'hello\nworld\n中文');
      expect(merged.blocks, hasLength(2));
      expect(merged.diagnostics, ['frame0', 'frame1']);
    });
  });
}
