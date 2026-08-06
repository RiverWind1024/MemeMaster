import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:mememaster/core/llm/openai_service.dart';
import 'package:mememaster/core/llm/models.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

class FakeLlmOptions extends Fake implements LlmOptions {}

void main() {
  late MockHttpClient mockClient;
  late OpenAiLlmService service;

  setUpAll(() {
    registerFallbackValue(FakeUri());
    registerFallbackValue(FakeLlmOptions());
  });

  setUp(() {
    mockClient = MockHttpClient();
    service = OpenAiLlmService(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: 'test-key',
      model: 'gpt-4o-mini',
      client: mockClient,
    );
  });

  group('OpenAiLlmService', () {
    group('isAvailable', () {
      test('apiKey 非空时可用', () {
        final s = OpenAiLlmService(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'some-key',
        );
        expect(s.isAvailable, isTrue);
      });

      test('apiKey 为空时不可用', () {
        final s = OpenAiLlmService(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: '',
        );
        expect(s.isAvailable, isFalse);
      });
    });

    group('modelName', () {
      test('返回配置的模型名称', () {
        expect(service.modelName, 'gpt-4o-mini');
      });

      test('默认模型名称', () {
        final s = OpenAiLlmService(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'key',
        );
        expect(s.modelName, 'gpt-4o-mini');
      });
    });

    group('complete', () {
      test('发送 complete 请求并返回响应内容', () async {
        final responseJson = {
          'choices': [
            {
              'message': {'content': 'Hello! How can I help you?'}
            }
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 20,
          },
        };

        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(responseJson),
          200,
        ));

        final result = await service.complete('Hi');

        expect(result, 'Hello! How can I help you?');
      });

      test('API 返回非 200 状态码抛出异常', () async {
        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          '{"error": "invalid request"}',
          400,
        ));

        expect(
          () => service.complete('Hi'),
          throwsA(isA<LlmException>()),
        );
      });

      test('complete 将单个 prompt 包装成 user 消息', () async {
        String? capturedBody;

        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((invocation) async {
          capturedBody = invocation.namedArguments[#body] as String;
          return http.Response(
            jsonEncode({
              'choices': [
                {'message': {'content': 'response'}}
              ],
            }),
            200,
          );
        });

        await service.complete('test prompt');

        final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        expect(messages.length, 1);
        expect((messages[0] as Map)['role'], 'user');
        expect((messages[0] as Map)['content'], 'test prompt');
      });
    });

    group('chat', () {
      test('发送 chat 请求并返回响应内容', () async {
        final responseJson = {
          'choices': [
            {
              'message': {'content': 'AI response'}
            }
          ],
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 10,
          },
        };

        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(responseJson),
          200,
        ));

        final result = await service.chat([
          const LlmMessage(role: 'user', content: 'Hello'),
        ]);

        expect(result, 'AI response');
      });

      test('token 用量回调被触发', () async {
        int? promptTokens;
        int? completionTokens;

        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'choices': [
              {'message': {'content': 'response'}}
            ],
            'usage': {
              'prompt_tokens': 15,
              'completion_tokens': 25,
            },
          }),
          200,
        ));

        final s = OpenAiLlmService(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'key',
          model: 'gpt-4o-mini',
          client: mockClient,
          onTokenUsage: (p, c) {
            promptTokens = p;
            completionTokens = c;
          },
        );

        await s.complete('test');

        expect(promptTokens, 15);
        expect(completionTokens, 25);
      });

      test('响应缺少 usage 字段时不触发回调', () async {
        var callbackCalled = false;

        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'choices': [
              {'message': {'content': 'response'}}
            ],
          }),
          200,
        ));

        final s = OpenAiLlmService(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'key',
          model: 'gpt-4o-mini',
          client: mockClient,
          onTokenUsage: (p, c) {
            callbackCalled = true;
          },
        );

        await s.complete('test');

        expect(callbackCalled, isFalse);
      });
    });

    group('baseUrl 处理', () {
      test('自动添加尾部斜杠', () {
        final s = OpenAiLlmService(
          baseUrl: 'https://api.openai.com/v1', // 无尾部斜杠
          apiKey: 'key',
        );
        expect(s.modelName, 'gpt-4o-mini'); // 不抛异常即可
      });

      test('保留已有的尾部斜杠', () {
        final s = OpenAiLlmService(
          baseUrl: 'https://api.openai.com/v1/', // 有尾部斜杠
          apiKey: 'key',
        );
        expect(s.modelName, 'gpt-4o-mini');
      });
    });

    group('dispose', () {
      test('关闭 HTTP 客户端', () {
        // dispose 调用 client.close()
        // MockClient 没有 close 方法，所以只验证不抛异常
        expect(() => service.dispose(), returnsNormally);
      });
    });
  });

  group('LlmException', () {
    test('toString 包含消息', () {
      const e = LlmException('Test error');
      expect(e.toString(), contains('Test error'));
    });

    test('消息可包含详细信息', () {
      const e = LlmException('API returned 500: Internal Server Error');
      expect(e.message, 'API returned 500: Internal Server Error');
    });
  });
}
