import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// help 命令：打印用法。
class HelpCommand extends CliCommand {
  final String Function() _usage;

  HelpCommand(this._usage)
      : super(name: 'help', description: '显示帮助信息');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    print(_usage());
    return 0;
  }
}
