import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/llm/models.dart';

void main() {
  group('LlmOptions', () {
    test('默认构造函数设置正确的默认值', () {
      const options = LlmOptions();
      expect(options.model, isNull);
      expect(options.temperature, 0.7);
      expect(options.maxTokens, 512);
    });

    test('构造函数接受自定义值', () {
      const options = LlmOptions(
        model: 'gpt-4',
        temperature: 0.5,
        maxTokens: 1024,
      );
      expect(options.model, 'gpt-4');
      expect(options.temperature, 0.5);
      expect(options.maxTokens, 1024);
    });

    test('toJson 包含所有字段', () {
      const options = LlmOptions(
        model: 'gpt-4',
        temperature: 0.5,
        maxTokens: 1024,
      );
      final json = options.toJson();
      expect(json['model'], 'gpt-4');
      expect(json['temperature'], 0.5);
      expect(json['max_tokens'], 1024);
    });

    test('toJson 省略 null model', () {
      const options = LlmOptions();
      final json = options.toJson();
      expect(json.containsKey('model'), isFalse);
    });

    test('toJson 包含 temperature 和 max_tokens', () {
      const options = LlmOptions();
      final json = options.toJson();
      expect(json['temperature'], 0.7);
      expect(json['max_tokens'], 512);
    });
  });

  group('LlmMessage', () {
    test('创建包含必需字段的消息', () {
      const message = LlmMessage(role: 'user', content: 'Hello');
      expect(message.role, 'user');
      expect(message.content, 'Hello');
      expect(message.imageBase64, isNull);
      expect(message.imageBytes, isNull);
    });

    test('创建带 base64 图片的消息', () {
      const message = LlmMessage(
        role: 'user',
        content: 'What is in this image?',
        imageBase64: 'base64encodedimage',
      );
      expect(message.imageBase64, 'base64encodedimage');
    });

    test('创建带图片字节的消息', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final message = LlmMessage(
        role: 'user',
        content: 'What is in this image?',
        imageBytes: bytes,
      );
      expect(message.imageBytes, bytes);
    });

    test('toJson 包含 role 和 content', () {
      const message = LlmMessage(role: 'assistant', content: 'Hello!');
      final json = message.toJson();
      expect(json['role'], 'assistant');
      expect(json['content'], 'Hello!');
    });

    test('toJson 不包含 image 字段（由子类添加）', () {
      const message = LlmMessage(
        role: 'user',
        content: 'Hello',
        imageBase64: 'somebase64',
      );
      final json = message.toJson();
      // toJson 是简化的，不包含图片
      expect(json['role'], 'user');
      expect(json['content'], 'Hello');
    });
  });

  group('LlmCompletionRequest', () {
    test('创建请求包含消息列表', () {
      const request = LlmCompletionRequest(
        messages: [
          LlmMessage(role: 'system', content: 'You are a helpful assistant'),
          LlmMessage(role: 'user', content: 'Hello'),
        ],
      );
      expect(request.messages.length, 2);
      expect(request.messages[0].role, 'system');
      expect(request.messages[1].role, 'user');
    });

    test('创建请求包含自定义选项', () {
      const request = LlmCompletionRequest(
        messages: [LlmMessage(role: 'user', content: 'Hi')],
        options: LlmOptions(model: 'gpt-4', temperature: 0.9),
      );
      expect(request.options.model, 'gpt-4');
      expect(request.options.temperature, 0.9);
    });

    test('使用默认选项', () {
      const request = LlmCompletionRequest(
        messages: [LlmMessage(role: 'user', content: 'Hi')],
      );
      expect(request.options.temperature, 0.7);
      expect(request.options.maxTokens, 512);
    });

    test('toJson 序列化消息和选项', () {
      const request = LlmCompletionRequest(
        messages: [LlmMessage(role: 'user', content: 'Hi')],
        options: LlmOptions(temperature: 0.5),
      );
      final json = request.toJson();
      expect(json['messages'], isA<List>());
      expect(json['temperature'], 0.5);
      expect(json['max_tokens'], 512);
    });
  });

  group('LlmCompletionResponse', () {
    test('fromOpenAiJson 解析有效响应', () {
      final json = {
        'choices': [
          {
            'message': {'content': 'Hello, how can I help you?'}
          }
        ],
        'model': 'gpt-4',
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 20,
        },
      };

      final response = LlmCompletionResponse.fromOpenAiJson(json);
      expect(response.content, 'Hello, how can I help you?');
      expect(response.model, 'gpt-4');
      expect(response.promptTokens, 10);
      expect(response.completionTokens, 20);
    });

    test('fromOpenAiJson 处理空 choices', () {
      final json = {
        'choices': [],
        'model': 'gpt-4',
      };

      final response = LlmCompletionResponse.fromOpenAiJson(json);
      expect(response.content, '');
    });

    test('fromOpenAiJson 处理 null content', () {
      final json = {
        'choices': [
          {'message': {'content': null}}
        ],
      };

      final response = LlmCompletionResponse.fromOpenAiJson(json);
      expect(response.content, '');
    });

    test('fromOpenAiJson 处理缺失的 usage', () {
      final json = {
        'choices': [
          {'message': {'content': 'Hello'}}
        ],
      };

      final response = LlmCompletionResponse.fromOpenAiJson(json);
      expect(response.content, 'Hello');
      expect(response.promptTokens, isNull);
      expect(response.completionTokens, isNull);
    });

    test('fromOpenAiJson 去除内容首尾空白', () {
      final json = {
        'choices': [
          {'message': {'content': '  Hello, world!  '}}
        ],
      };

      final response = LlmCompletionResponse.fromOpenAiJson(json);
      expect(response.content, 'Hello, world!');
    });

    test('创建完整响应', () {
      const response = LlmCompletionResponse(
        content: 'Test response',
        model: 'gpt-4',
        promptTokens: 5,
        completionTokens: 10,
      );
      expect(response.content, 'Test response');
      expect(response.model, 'gpt-4');
      expect(response.promptTokens, 5);
      expect(response.completionTokens, 10);
    });

    test('创建不带 token 信息的响应', () {
      const response = LlmCompletionResponse(content: 'Simple response');
      expect(response.content, 'Simple response');
      expect(response.model, isNull);
      expect(response.promptTokens, isNull);
      expect(response.completionTokens, isNull);
    });
  });
}
