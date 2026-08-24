import 'dart:io';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// 占位命令：骨架阶段尚未实现的子命令。
class UnimplementedCommand extends CliCommand {
  UnimplementedCommand({required super.name, required super.description});

  /// 尚未实现提示（供 cli_app 短路时输出，避免打开数据库）。
  String get unimplementedMessage => '子命令 "$name" 尚未实现';

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    stderr.writeln(unimplementedMessage);
    return 1;
  }
}
