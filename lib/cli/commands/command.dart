import 'package:args/args.dart';

import '../cli_context.dart';

/// 命令抽象基类：子命令都必须实现 [run]。
abstract class CliCommand {
  final String name;
  final String description;

  CliCommand({required this.name, required this.description});

  /// 是否需要从 CLI 配置文件加载 LLM/S3 配置（默认为不加载）。
  bool get needsCliConfig => false;

  /// 执行命令，返回进程退出码（0 表示成功）。
  Future<int> run(CliContext context, ArgResults args);
}
