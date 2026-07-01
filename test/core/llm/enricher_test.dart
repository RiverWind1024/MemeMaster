import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meme_helper/core/llm/enricher.dart';
import 'package:meme_helper/core/llm/llm_service.dart';
import 'package:meme_helper/core/repositories/meme_repository.dart';

class MockLlmService extends Mock implements LlmService {}
class MockMemeRepository extends Mock implements MemeRepository {}

void main() {
  late MockLlmService mockLlm;
  late MockMemeRepository mockRepo;
  late LlmEnricher enricher;

  setUp(() {
    mockLlm = MockLlmService();
    mockRepo = MockMemeRepository();
    enricher = LlmEnricher(llm: mockLlm, repo: mockRepo);
  });

  group('LlmEnricher.enrich', () {
    test('skips when LLM is unavailable', () async {
      when(() => mockLlm.isAvailable).thenReturn(false);

      await enricher.enrich('meme-1', 'some text');

      verifyNever(() => mockLlm.complete(any(), options: any(named: 'options')));
    });

    test('saves tags and description when LLM returns content', () async {
      when(() => mockLlm.isAvailable).thenReturn(true);
      // 1st call = _suggestTags, 2nd call = _describe
      when(() => mockLlm.complete(any(), options: any(named: 'options')))
          .thenAnswer((_) async => '狗,猫,可爱');
      when(() => mockRepo.saveTags(any())).thenAnswer((_) async {});
      when(() => mockRepo.updateDescription(any(), any()))
          .thenAnswer((_) async {});

      await enricher.enrich('meme-1', '小狗小猫真可爱');

      verify(() => mockRepo.saveTags(any())).called(1);
      verify(() => mockRepo.updateDescription('meme-1', any())).called(1);
    });

    test('does not save when LLM returns empty string', () async {
      when(() => mockLlm.isAvailable).thenReturn(true);
      // Both _suggestTags and _describe return empty
      when(() => mockLlm.complete(any(), options: any(named: 'options')))
          .thenAnswer((_) async => '');

      await enricher.enrich('meme-1', 'text');

      verifyNever(() => mockRepo.saveTags(any()));
      verifyNever(() => mockRepo.updateDescription(any(), any()));
    });

    test('handles LLM exception gracefully without saving', () async {
      when(() => mockLlm.isAvailable).thenReturn(true);
      when(() => mockLlm.complete(any(), options: any(named: 'options')))
          .thenThrow(Exception('API error'));

      await enricher.enrich('meme-1', 'text');

      verifyNever(() => mockRepo.saveTags(any()));
      verifyNever(() => mockRepo.updateDescription(any(), any()));
    });
  });
}
