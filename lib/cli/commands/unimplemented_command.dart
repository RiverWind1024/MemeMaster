import 'dart:io';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// 占位命令：骨架阶段尚未实现的子命令。
class UnimplementedCommand extends CliCommand {
  UnimplementedCommand({required super.name, required super.description});

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    stderr.writeln('子命令 "$name" 尚未实现');
    return 1;
  }
}
