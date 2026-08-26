import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/services/file_storage_service.dart';

void main() {
  group('FileStorageService 注入 basePath 后纯 Dart 测试', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_storage_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('deleteImage 不存在的文件不抛出异常', () async {
      final storage = FileStorageService(basePath: tempDir.path);
      await expectLater(
        storage.deleteImage('2026/06/nonexistent.png'),
        completes,
      );
    });

    test('storeImage 返回相对路径并写入文件，getImage 可读回', () async {
      final storage = FileStorageService(basePath: tempDir.path);
      final source = File('${tempDir.path}/src.png');
      await source.writeAsBytes([1, 2, 3]);

      final rel = await storage.storeImage(source.path, 'abc123');
      expect(rel, matches(RegExp(r'^\d{4}/\d{2}/abc123\.png$')));

      final dest = await storage.getImage(rel);
      expect(await dest.exists(), isTrue);
      expect(await dest.readAsBytes(), [1, 2, 3]);
    });

    test('未注入 basePath 时访问抛 StateError', () {
      final storage = FileStorageService();
      expect(storage.basePath, throwsStateError);
    });
  });
}
