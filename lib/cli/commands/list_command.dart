import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// list 命令：列出所有 meme（骨架最小实现，Task 4 完善为表格输出）。
class ListCommand extends CliCommand {
  ListCommand()
      : super(name: 'list', description: '列出所有 meme（id + 文件名）');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final memes = await context.memeRepo.getAll();
    print('共 ${memes.length} 条');
    for (final meme in memes) {
      print('${meme.id}  ${meme.filename}');
    }
    return 0;
  }
}
