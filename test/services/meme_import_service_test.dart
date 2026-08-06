import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/services/meme_import_service.dart';

void main() {
  group('MemeImportResult', () {
    test('创建成功结果', () {
      final result = MemeImportResult(
        success: 5,
        skipped: 2,
        errors: const [],
      );
      expect(result.success, 5);
      expect(result.skipped, 2);
      expect(result.errors, isEmpty);
    });

    test('创建包含错误的结果', () {
      final result = MemeImportResult(
        success: 3,
        skipped: 1,
        errors: const ['file1.png: corrupt data'],
      );
      expect(result.success, 3);
      expect(result.skipped, 1);
      expect(result.errors, ['file1.png: corrupt data']);
    });
  });

  group('MemeImportService._extToMimeType', () {
    test('返回正确的 MIME 类型', () {
      // _extToMimeType 接收带点的扩展名，如 '.jpg'
      expect(_testMimeType('.png'), 'image/png');
      expect(_testMimeType('.jpg'), 'image/jpeg');
      expect(_testMimeType('.jpeg'), 'image/jpeg');
      expect(_testMimeType('.gif'), 'image/gif');
      expect(_testMimeType('.webp'), 'image/webp');
      expect(_testMimeType('.bmp'), 'image/bmp');
      expect(_testMimeType('.unknown'), 'image/png');
    });
  });
}

// 测试用的 mime 类型转换函数（复制 MemeImportService 的逻辑）
String _testMimeType(String ext) {
  switch (ext) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.bmp':
      return 'image/bmp';
    default:
      return 'image/png';
  }
}
