import 'package:flutter_test/flutter_test.dart';
import 'package:meme_helper/core/llm/models.dart';

void main() {
  group('LlmOptions', () {
    test('toJson with default values', () {
      final options = const LlmOptions();
      expect(options.toJson(), {
        'temperature': 0.7,
        'max_tokens': 512,
      });
    });

    test('toJson with model', () {
      final options = const LlmOptions(model: 'gpt-4');
      expect(options.toJson(), {
        'model': 'gpt-4',
        'temperature': 0.7,
        'max_tokens': 512,
      });
    });

    test('toJson with custom values', () {
      final options = const LlmOptions(
        temperature: 0.1,
        maxTokens: 128,
      );
      expect(options.toJson(), {
        'temperature': 0.1,
        'max_tokens': 128,
      });
    });
  });

  group('LlmMessage', () {
    test('toJson produces correct format', () {
      final message = LlmMessage(role: 'user', content: 'Hello');
      expect(message.toJson(), {
        'role': 'user',
        'content': 'Hello',
      });
    });

    test('toJson supports system role', () {
      final message = LlmMessage(role: 'system', content: 'Be helpful');
      expect(message.toJson(), {
        'role': 'system',
        'content': 'Be helpful',
      });
    });
  });

  group('LlmCompletionRequest', () {
    test('toJson produces correct format', () {
      final request = LlmCompletionRequest(
        messages: [
          LlmMessage(role: 'user', content: 'Hi'),
        ],
        options: const LlmOptions(model: 'test-model'),
      );
      final json = request.toJson();
      expect(json['model'], 'test-model');
      expect(json['messages'], [
        {'role': 'user', 'content': 'Hi'},
      ]);
    });
  });

  group('LlmCompletionResponse.fromOpenAiJson', () {
    test('parses valid response', () {
      final json = {
        'model': 'gpt-4o-mini',
        'choices': [
          {
            'message': {
              'content': 'Hello world',
            },
          },
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 5,
        },
      };

      final response = LlmCompletionResponse.fromOpenAiJson(json);
      expect(response.content, 'Hello world');
      expect(response.model, 'gpt-4o-mini');
      expect(response.promptTokens, 10);
      expect(response.completionTokens, 5);
    });

    test('handles empty choices', () {
      final json = {
        'choices': <dynamic>[],
      };

      final response = LlmCompletionResponse.fromOpenAiJson(json);
      expect(response.content, '');
    });

    test('trims whitespace from content', () {
      final json = {
        'choices': [
          {
            'message': {
              'content': '  Hello world  ',
            },
          },
        ],
      };

      final response = LlmCompletionResponse.fromOpenAiJson(json);
      expect(response.content, 'Hello world');
    });
  });
}
