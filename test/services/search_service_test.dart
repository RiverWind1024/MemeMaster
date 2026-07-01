import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meme_helper/core/database/database.dart';
import 'package:meme_helper/core/repositories/color_repository.dart';
import 'package:meme_helper/core/repositories/meme_repository.dart';
import 'package:meme_helper/core/utils/color_utils.dart';
import 'package:meme_helper/services/search_service.dart';

class MockMemeRepository extends Mock implements MemeRepository {}
class MockColorRepository extends Mock implements ColorRepository {}

void main() {
  late MockMemeRepository mockMemeRepo;
  late MockColorRepository mockColorRepo;
  late SearchService search;

  setUp(() {
    mockMemeRepo = MockMemeRepository();
    mockColorRepo = MockColorRepository();
    search = SearchService(memeRepo: mockMemeRepo, colorRepo: mockColorRepo);
  });

  group('SearchService', () {
    group('searchByColor', () {
      test('returns empty list when no colors match', () async {
        when(() => mockColorRepo.searchByColor(
              targetL: any(named: 'targetL'),
              targetA: any(named: 'targetA'),
              targetB: any(named: 'targetB'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => []);

        final results = await search.searchByColor(const ColorRgb(255, 0, 0));

        expect(results, isEmpty);
      });

      test('deduplicates by memeId keeping min deltaE', () async {
        when(() => mockColorRepo.searchByColor(
              targetL: any(named: 'targetL'),
              targetA: any(named: 'targetA'),
              targetB: any(named: 'targetB'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => [
              ColorEntry(
                id: 'c1',
                memeId: 'meme-1',
                hexColor: '#ff0000',
                labL: 50,
                labA: 60,
                labB: 30,
                ratio: 0.5,
              ),
              ColorEntry(
                id: 'c2',
                memeId: 'meme-1',
                hexColor: '#ff1111',
                labL: 48,
                labA: 58,
                labB: 28,
                ratio: 0.3,
              ),
            ]);

        when(() => mockMemeRepo.getById('meme-1')).thenAnswer(
          (_) async => Meme(
            id: 'meme-1',
            filename: 'test.png',
            filePath: 'test.png',
            fileSize: 1000,
            mimeType: 'image/png',
            width: 100,
            height: 100,
            fileHash: 'abc',
            analysisStatus: 'done',
            createdAt: 0,
            updatedAt: 0,
            importedAt: 0,
          ),
        );

        final results = await search.searchByColor(const ColorRgb(255, 0, 0));

        // Only one result despite 2 color entries
        expect(results.length, 1);
        expect(results.first.meme.id, 'meme-1');
      });

      test('results sorted by relevance descending', () async {
        // Return colors for 2 different memes with different distances
        when(() => mockColorRepo.searchByColor(
              targetL: any(named: 'targetL'),
              targetA: any(named: 'targetA'),
              targetB: any(named: 'targetB'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => [
              ColorEntry(
                id: 'c1', memeId: 'meme-1',
                hexColor: '#ff0000', labL: 50, labA: 60, labB: 30, ratio: 0.5,
              ),
              ColorEntry(
                id: 'c2', memeId: 'meme-2',
                hexColor: '#00ff00', labL: 20, labA: -40, labB: 30, ratio: 0.4,
              ),
            ]);

        when(() => mockMemeRepo.getById(any())).thenAnswer((inv) async {
          final id = inv.positionalArguments[0] as String;
          return Meme(
            id: id,
            filename: '$id.png',
            filePath: '$id.png',
            fileSize: 1000,
            mimeType: 'image/png',
            width: 100,
            height: 100,
            fileHash: id,
            analysisStatus: 'done',
            createdAt: 0,
            updatedAt: 0,
            importedAt: 0,
          );
        });

        final results = await search.searchByColor(const ColorRgb(255, 0, 0));

        expect(results.length, 2);
        // meme-1 (closer to target red) should be first
        expect(results.first.meme.id, 'meme-1');
        expect(results.first.relevance, greaterThan(results.last.relevance));
      });
    });

    group('detectLevel', () {
      test('returns browse when no memes exist', () async {
        when(() => mockMemeRepo.count()).thenAnswer((_) async => 0);

        final level = await search.detectLevel();
        expect(level, SearchLevel.browse);
      });

      test('returns browse when memes exist but no color data', () async {
        when(() => mockMemeRepo.count()).thenAnswer((_) async => 5);
        when(() => mockColorRepo.getAllMemeIds()).thenAnswer((_) async => []);

        final level = await search.detectLevel();
        expect(level, SearchLevel.browse);
      });

      test('returns colorOnly when memes and color data exist', () async {
        when(() => mockMemeRepo.count()).thenAnswer((_) async => 5);
        when(() => mockColorRepo.getAllMemeIds()).thenAnswer(
          (_) async => ['meme-1', 'meme-2'],
        );

        final level = await search.detectLevel();
        expect(level, SearchLevel.colorOnly);
      });
    });
  });
}
