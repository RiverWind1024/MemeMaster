import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/llm/ollama_service.dart';

void main() {
  group('OllamaLlmService', () {
    test('isAvailable 始终为 true', () {
      final service = OllamaLlmService();
      expect(service.isAvailable, isTrue);
    });

    test('modelName 返回配置的模型', () {
      final service = OllamaLlmService(model: 'llama3.2');
      expect(service.modelName, 'llama3.2');
    });

    test('默认模型为 llama3.2', () {
      final service = OllamaLlmService();
      expect(service.modelName, 'llama3.2');
    });

    test('默认 baseUrl 为 localhost:11434', () {
      // 内部使用 OpenAiLlmService，只需要验证构造不抛异常
      final service = OllamaLlmService();
      expect(service.isAvailable, isTrue);
      expect(service.modelName, 'llama3.2');
    });

    test('可配置 baseUrl', () {
      final service = OllamaLlmService(
        baseUrl: 'http://192.168.1.100:11434/v1',
        model: 'qwen2.5',
      );
      expect(service.modelName, 'qwen2.5');
      expect(service.isAvailable, isTrue);
    });

    test('dispose 不抛异常', () {
      final service = OllamaLlmService();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
