import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/cli/cli_app.dart';
import 'package:mememaster/cli/cli_config_store.dart';
import 'package:mememaster/core/llm/config.dart';
import 'package:mememaster/services/s3_config.dart';
import 'package:path/path.dart' as p;

void main() {
  group('CliConfigStore', () {
    late Directory tempDir;
    late String configPath;
    late CliConfigStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_config_store_');
      configPath = p.join(tempDir.path, 'cli_config.json');
      store = CliConfigStore(configPath: configPath);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('文件不存在时 load 返回默认值', () async {
      final config = await store.load();
      expect(config.llm.provider, LlmProviderType.ollama);
      expect(config.llm.model, 'llama3.2');
      expect(config.s3.isValid, isFalse);
    });

    test('save 后 load 往返一致（LLM + S3）', () async {
      const llm = LlmConfig(
        mode: LlmMode.remote,
        provider: LlmProviderType.openai,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        model: 'gpt-4o',
      );
      const s3 = S3Config(
        endpoint: 'https://s3.example.com',
        bucket: 'memes',
        region: 'us-west-1',
        accessKey: 'ak',
        secretKey: 'sk',
        useSsl: false,
        pathStyle: false,
      );
      await store.save(const CliConfig(llm: llm, s3: s3));

      final loaded = await store.load();
      expect(loaded.llm.provider, LlmProviderType.openai);
      expect(loaded.llm.apiKey, 'sk-test');
      expect(loaded.llm.model, 'gpt-4o');
      expect(loaded.s3.endpoint, 'https://s3.example.com');
      expect(loaded.s3.secretKey, 'sk');
      expect(loaded.s3.useSsl, isFalse);
      expect(loaded.s3.isValid, isTrue);
    });

    test('损坏的 JSON 回退默认值且不抛出', () async {
      await File(configPath).writeAsString('{not-json');
      final config = await store.load();
      expect(config.llm.provider, LlmProviderType.ollama);
    });
  });

  group('config 命令', () {
    late Directory tempDir;
    late CliApp app;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_config_cmd_');
      app = CliApp(configPath: p.join(tempDir.path, 'cli_config.json'));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('config show 无配置时显示默认值并返回 0', () async {
      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await app.run(['config', 'show']);
        },
        prints(contains('ollama')),
      );
      expect(exitCode, 0);
    });

    test('config llm 设置后持久化并可 show 读取', () async {
      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await app.run(
            ['config', 'llm', '--provider', 'ollama', '--model', 'llama3.2'],
          );
        },
        prints(contains('已保存 LLM')),
      );
      expect(exitCode, 0);

      await expectLater(
        () async {
          exitCode = await app.run(['config', 'show']);
        },
        prints(contains('llama3.2')),
      );
      expect(exitCode, 0);

      final config = await CliConfigStore(
              configPath: p.join(tempDir.path, 'cli_config.json'))
          .load();
      expect(config.llm.provider, LlmProviderType.ollama);
      expect(config.llm.model, 'llama3.2');
      expect(config.llm.mode, LlmMode.local);
    });

    test('config llm --provider openai 映射 mode=remote', () async {
      await app.run(['config', 'llm', '--provider', 'openai']);
      final config = await CliConfigStore(
              configPath: p.join(tempDir.path, 'cli_config.json'))
          .load();
      expect(config.llm.provider, LlmProviderType.openai);
      expect(config.llm.mode, LlmMode.remote);
    });

    test('config llm 缺 --provider 返回 1', () async {
      expect(await app.run(['config', 'llm']), 1);
    });

    test('config s3 设置后持久化', () async {
      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await app.run([
            'config',
            's3',
            '--endpoint',
            'http://localhost:9000',
            '--bucket',
            'memes',
            '--access-key',
            'minioadmin',
            '--secret-key',
            'minioadmin',
            '--use-ssl',
          ]);
        },
        prints(contains('已保存 S3')),
      );
      expect(exitCode, 0);

      final config = await CliConfigStore(
              configPath: p.join(tempDir.path, 'cli_config.json'))
          .load();
      expect(config.s3.bucket, 'memes');
      expect(config.s3.isValid, isTrue);
    });

    test('config s3 缺必填参数返回 1', () async {
      expect(
        await app.run(['config', 's3', '--endpoint', 'http://x']),
        1,
      );
    });

    test('未知 config 子命令返回 1', () async {
      expect(await app.run(['config', 'bogus']), 1);
    });
  });
}