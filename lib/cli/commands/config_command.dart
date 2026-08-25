import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../../core/llm/config.dart';
import '../cli_config_store.dart';
import '../cli_context.dart';
import 'command.dart';

/// config 命令：查看 / 修改 LLM 与 S3 配置（持久化到 cli_config.json）。
///
/// 用法:
///   mememaster config show
///   mememaster config llm --provider `<openai|ollama>` [--base-url] [--model] [--api-key]
///   mememaster config s3 --endpoint --bucket --access-key --secret-key [--region] [--use-ssl] [--path-style]
///
/// 该命令不依赖数据库，cli_app 在打开数据库前调用 [execute]。
class ConfigCommand extends CliCommand {
  final CliConfigStore store;

  ConfigCommand(this.store)
      : super(name: 'config', description: '查看/修改配置');

  @override
  Future<int> run(CliContext context, ArgResults args) =>
      execute(args, jsonOutput: context.jsonOutput);

  /// config 命令入口（cli_app 在打开数据库前调用）。
  Future<int> execute(ArgResults args, {bool jsonOutput = false}) async {
    if (args.rest.isEmpty) {
      stderr.writeln('用法: mememaster config <show|llm|s3> ...');
      return 1;
    }
    switch (args.rest.first) {
      case 'show':
        return _show(jsonOutput);
      case 'llm':
        return _setLlm(args);
      case 's3':
        return _setS3(args);
      default:
        stderr.writeln('未知 config 子命令: ${args.rest.first}');
        return 1;
    }
  }

  Future<int> _show(bool jsonOutput) async {
    final config = await store.load();
    if (jsonOutput) {
      print(jsonEncode({'llm': config.llm.toJson(), 's3': config.s3.toJson()}));
      return 0;
    }

    final llm = config.llm;
    final s3 = config.s3;
    print('LLM 配置:');
    print('  模式: ${llm.mode.name}');
    print('  供应商: ${llm.provider.name}');
    print('  baseUrl: ${llm.baseUrl}');
    print('  模型: ${llm.model}');
    print('  API Key: ${_mask(llm.apiKey)}');
    print('S3 配置:');
    print('  endpoint: ${s3.endpoint}');
    print('  bucket: ${s3.bucket}');
    print('  region: ${s3.region}');
    print('  accessKey: ${s3.accessKey}');
    print('  secretKey: ${_mask(s3.secretKey)}');
    print('  useSSL: ${s3.useSsl}');
    print('  pathStyle: ${s3.pathStyle}');
    print('  已配置: ${s3.isValid ? '是' : '否'}');
    return 0;
  }

  Future<int> _setLlm(ArgResults args) async {
    final providerArg = args['provider'] as String?;
    if (providerArg == null) {
      stderr.writeln(
          '用法: mememaster config llm --provider <openai|ollama> '
          '[--base-url <url>] [--model <name>] [--api-key <key>]');
      return 1;
    }

    final provider = LlmProviderType.values.byName(providerArg);
    final config = await store.load();

    final updated = config.llm.copyWith(
      mode: provider == LlmProviderType.openai ? LlmMode.remote : LlmMode.local,
      provider: provider,
      baseUrl: args['base-url'] as String?,
      model: args['model'] as String?,
      apiKey: args['api-key'] as String?,
    );
    await store.save(CliConfig(llm: updated, s3: config.s3));
    print('已保存 LLM 配置（provider ${provider.name}）');
    return 0;
  }

  Future<int> _setS3(ArgResults args) async {
    final endpoint = args['endpoint'] as String?;
    final bucket = args['bucket'] as String?;
    final accessKey = args['access-key'] as String?;
    final secretKey = args['secret-key'] as String?;
    if (endpoint == null || bucket == null || accessKey == null || secretKey == null) {
      stderr.writeln(
          '用法: mememaster config s3 --endpoint <url> --bucket <bucket> '
          '--access-key <key> --secret-key <key> '
          '[--region <region>] [--use-ssl|--no-use-ssl] [--path-style|--no-path-style]');
      return 1;
    }

    final config = await store.load();
    final current = config.s3;
    final updated = current.copyWith(
      endpoint: endpoint,
      bucket: bucket,
      accessKey: accessKey,
      secretKey: secretKey,
      region: args['region'] as String?,
      useSsl: args.wasParsed('use-ssl') ? args['use-ssl'] as bool : null,
      pathStyle:
          args.wasParsed('path-style') ? args['path-style'] as bool : null,
    );
    await store.save(CliConfig(llm: config.llm, s3: updated));
    print('已保存 S3 配置（bucket $bucket）');
    return 0;
  }

  static String _mask(String? value) =>
      (value == null || value.isEmpty) ? '(未设置)' : '(已设置)';
}