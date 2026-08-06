import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:mememaster/services/file_storage_service.dart';
import 'package:mememaster/services/meme_export_service.dart';

class MockMemeRepository extends Mock implements MemeRepository {}
class MockFileStorageService extends Mock implements FileStorageService {}

class FakeMeme extends Fake implements Meme {}
class FakeTagEntry extends Fake implements TagEntry {}
class FakeColorEntry extends Fake implements ColorEntry {}

void main() {
  late MockMemeRepository mockMemeRepo;
  late MockFileStorageService mockStorage;
  late MemeExportService exportService;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(FakeMeme());
    registerFallbackValue(FakeTagEntry());
    registerFallbackValue(FakeColorEntry());
  });

  setUp(() async {
    mockMemeRepo = MockMemeRepository();
    mockStorage = MockFileStorageService();
    exportService = MemeExportService(
      memeRepo: mockMemeRepo,
      storage: mockStorage,
    );
    tempDir = await Directory.systemTemp.createTemp('export_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MemeExportItem', () {
    test('创建有效的导出项', () {
      final item = MemeExportItem(
        hash: 'abc123',
        filename: 'meme.png',
        imagePath: '2026/07/abc123.png',
        colors: const [],
        tags: const [],
      );
      expect(item.hash, 'abc123');
      expect(item.filename, 'meme.png');
      expect(item.imagePath, '2026/07/abc123.png');
      expect(item.colors, isEmpty);
      expect(item.tags, isEmpty);
    });

    test('创建带描述的导出项', () {
      final item = MemeExportItem(
        hash: 'abc123',
        filename: 'meme.png',
        imagePath: '2026/07/abc123.png',
        colors: const [],
        tags: const [],
        description: 'A funny meme',
      );
      expect(item.description, 'A funny meme');
    });

    test('toJson 包含所有字段', () {
      final item = MemeExportItem(
        hash: 'abc123',
        filename: 'meme.png',
        imagePath: '2026/07/abc123.png',
        colors: const [],
        tags: const [],
      );
      final json = item.toJson();
      expect(json['filename'], 'meme.png');
      expect(json['colors'], isEmpty);
      expect(json['tags'], isEmpty);
      expect(json['description'], isNull);
    });
  });

  group('MemeExportService.exportMemes', () {
    test('导出空列表返回空 zip', () async {
      when(() => mockMemeRepo.getById(any())).thenAnswer((_) async => null);

      final outputPath = '${tempDir.path}/empty_export.zip';
      final result = await exportService.exportMemes(
        memeIds: [],
        outputPath: outputPath,
      );

      expect(result, outputPath);
      expect(await File(outputPath).exists(), isTrue);
    });

    test('导出不存在的 meme 跳过', () async {
      when(() => mockMemeRepo.getById('nonexistent'))
          .thenAnswer((_) async => null);

      final outputPath = '${tempDir.path}/export.zip';
      await exportService.exportMemes(
        memeIds: ['nonexistent'],
        outputPath: outputPath,
      );

      expect(await File(outputPath).exists(), isTrue);
    });

    test('导出单个 meme 到 zip 文件', () async {
      final meme = _createMockMeme('meme-1');
      when(() => mockMemeRepo.getById('meme-1')).thenAnswer((_) async => meme);
      when(() => mockMemeRepo.getColors('meme-1')).thenAnswer((_) async => const []);
      when(() => mockMemeRepo.getTags('meme-1')).thenAnswer((_) async => const []);

      // Mock 图片文件
      final testImage = File('${tempDir.path}/test.png');
      await testImage.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
      when(() => mockStorage.getImage(any()))
          .thenAnswer((_) async => testImage);

      final outputPath = '${tempDir.path}/export.zip';
      final result = await exportService.exportMemes(
        memeIds: ['meme-1'],
        outputPath: outputPath,
      );

      expect(result, outputPath);
      expect(await File(outputPath).exists(), isTrue);
      final fileSize = await File(outputPath).length();
      expect(fileSize, greaterThan(0));
    });
  });

  group('MemeExportService.exportMemesAsBytes', () {
    test('生成 zip 字节数据', () async {
      final meme = _createMockMeme('meme-1');
      when(() => mockMemeRepo.getById('meme-1')).thenAnswer((_) async => meme);
      when(() => mockMemeRepo.getColors('meme-1')).thenAnswer((_) async => const []);
      when(() => mockMemeRepo.getTags('meme-1')).thenAnswer((_) async => const []);

      final testImage = File('${tempDir.path}/test.png');
      await testImage.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
      when(() => mockStorage.getImage(any()))
          .thenAnswer((_) async => testImage);

      final bytes = await exportService.exportMemesAsBytes(
        memeIds: ['meme-1'],
      );

      expect(bytes.isNotEmpty, isTrue);
      // ZIP 文件以 PK 开头
      expect(bytes[0], 0x50); // P
      expect(bytes[1], 0x4B); // K
    });

    test('空列表生成有效 zip', () async {
      final bytes = await exportService.exportMemesAsBytes(memeIds: []);

      expect(bytes.isNotEmpty, isTrue);
      // ZIP 文件以 PK 开头
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });
  });
}

Meme _createMockMeme(String id) {
  return _MockMeme(id: id);
}

class _MockMeme implements Meme {
  _MockMeme({required this.id});

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => switch (invocation.memberName) {
        #id => id,
        #filename => 'test.png',
        #filePath => 'path/test.png',
        #fileHash => 'hash_$id',
        #fileSize => 1024,
        #mimeType => 'image/png',
        #width => 100,
        #height => 100,
        #analysisStatus => 'done',
        #colorAnalysisStatus => 'done',
        #ocrAnalysisStatus => 'done',
        #aiAnalysisStatus => 'done',
        #copyCount => 0,
        #createdAt => 0,
        #updatedAt => 0,
        #importedAt => 0,
        #deletedAt => null,
        #description => null,
        #source => null,
        _ => super.noSuchMethod(invocation),
      };
}
