import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/cli/cli_app.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cli_app_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('--help 打印非空帮助并返回 0', () async {
    var exitCode = -1;
    await expectLater(
      () async {
        exitCode = await CliApp().run(['--help']);
      },
      prints(isNotEmpty),
    );
    expect(exitCode, 0);
  });

  test('未知子命令返回非 0', () async {
    final exitCode = await CliApp().run(['no-such-command']);
    expect(exitCode, isNot(0));
  });

  test('list 使用临时 db/storage 返回 0 且输出非空', () async {
    // 嵌套路径：验证 --db 会自动创建父目录，绝不触碰真实 ~/Documents 库
    final dbPath = p.join(tempDir.path, 'nested', 'data', 'meme_helper.db');
    final storagePath = p.join(tempDir.path, 'memes');

    var exitCode = -1;
    await expectLater(
      () async {
        exitCode = await CliApp().run(
          ['list', '--db', dbPath, '--storage', storagePath],
        );
      },
      prints(isNotEmpty),
    );
    expect(exitCode, 0);
  });
}
