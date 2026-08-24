import 'package:args/args.dart';

import '../cli_context.dart';

/// 命令抽象基类：子命令都必须实现 [run]。
abstract class CliCommand {
  final String name;
  final String description;

  CliCommand({required this.name, required this.description});

  /// 执行命令，返回进程退出码（0 表示成功）。
  Future<int> run(CliContext context, ArgResults args);
}
