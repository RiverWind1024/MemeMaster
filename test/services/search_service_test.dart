import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:mememaster/core/repositories/color_repository.dart';
import 'package:mememaster/core/utils/color_utils.dart';
import 'package:mememaster/services/search_service.dart';

class MockMemeRepository extends Mock implements MemeRepository {}
class MockColorRepository extends Mock implements ColorRepository {}

class FakeMeme extends Fake implements Meme {}
class FakeColorEntry extends Fake implements ColorEntry {}

void main() {
  late MockMemeRepository mockMemeRepo;
  late MockColorRepository mockColorRepo;
  late SearchService searchService;

  setUpAll(() {
    registerFallbackValue(FakeMeme());
    registerFallbackValue(FakeColorEntry());
  });

  setUp(() {
    mockMemeRepo = MockMemeRepository();
    mockColorRepo = MockColorRepository();
    searchService = SearchService(
      memeRepo: mockMemeRepo,
      colorRepo: mockColorRepo,
    );
  });

  group('SearchResult', () {
    test('创建有效的搜索结果', () {
      const meme = _FakeMeme(id: 'test-id');
      const result = SearchResult(meme: meme, relevance: 0.85);
      expect(result.meme.id, 'test-id');
      expect(result.relevance, 0.85);
    });
  });

  group('SearchLevel', () {
    test('包含所有预期级别', () {
      expect(SearchLevel.values, contains(SearchLevel.full));
      expect(SearchLevel.values, contains(SearchLevel.colorAndKeyword));
      expect(SearchLevel.values, contains(SearchLevel.colorOnly));
      expect(SearchLevel.values, contains(SearchLevel.browse));
    });
  });

  group('SearchService.search', () {
    test('空查询返回浏览模式结果', () async {
      when(() => mockMemeRepo.getAll(limit: any(named: 'limit')))
          .thenAnswer((_) async => [_FakeMeme(id: 'meme-1')]);

      final results = await searchService.search();

      expect(results.isNotEmpty, isTrue);
      expect(results[0].relevance, 1.0);
      verify(() => mockMemeRepo.getAll(limit: any(named: 'limit'))).called(1);
    });
  });

  group('SearchService.detectLevel', () {
    test('无数据时返回 browse', () async {
      when(() => mockMemeRepo.count()).thenAnswer((_) async => 0);

      final level = await searchService.detectLevel();

      expect(level, SearchLevel.browse);
    });
  });
}

// Fake class for testing
class _FakeMeme implements Meme {
  const _FakeMeme({required this.id});

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => switch (invocation.memberName) {
        #id => id,
        #filename => 'test.png',
        #filePath => 'path/test.png',
        #fileHash => 'hash',
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
