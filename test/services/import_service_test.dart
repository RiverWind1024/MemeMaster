import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:mememaster/services/file_storage_service.dart';
import 'package:mememaster/services/import_service.dart';

class MockMemeRepository extends Mock implements MemeRepository {}
class MockFileStorageService extends Mock implements FileStorageService {}

class FakeMeme extends Fake implements Meme {}

void main() {
  late MockMemeRepository mockMemeRepo;
  late MockFileStorageService mockStorage;
  late ImportService importService;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(FakeMeme());
  });

  setUp(() async {
    mockMemeRepo = MockMemeRepository();
    mockStorage = MockFileStorageService();
    // Dart: required this._memeRepo 在调用时参数名不带下划线
    importService = ImportService(
      memeRepo: mockMemeRepo,
      storage: mockStorage,
    );
    tempDir = await Directory.systemTemp.createTemp('import_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ImportResult', () {
    test('创建默认结果', () {
      const result = ImportResult(success: 5, skipped: 2);
      expect(result.success, 5);
      expect(result.skipped, 2);
      expect(result.errors, isEmpty);
      expect(result.skippedFiles, isEmpty);
    });

    test('创建包含错误的结果', () {
      const result = ImportResult(
        success: 3,
        skipped: 1,
        errors: ['file1.jpg: Invalid format'],
        skippedFiles: ['file2.jpg'],
      );
      expect(result.success, 3);
      expect(result.skipped, 1);
      expect(result.errors, ['file1.jpg: Invalid format']);
      expect(result.skippedFiles, ['file2.jpg']);
    });
  });

  group('ImportService.importImage', () {
    test('文件不存在返回 null', () async {
      final result = await importService.importImage('/nonexistent/path/image.png');
      expect(result, isNull);
    });
  });
}
