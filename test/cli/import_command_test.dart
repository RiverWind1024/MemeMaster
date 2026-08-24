import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mememaster/cli/cli_app.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:path/path.dart' as p;

/// 程序化生成一张 2x2 PNG（不同 seed 产生不同内容 → 不同 hash）
Future<String> _writePng(String path, {required int seed}) async {
  final image = img.Image(width: 2, height: 2);
  img.fill(
    image,
    color: img.ColorRgb8(seed % 256, (seed * 7) % 256, (seed * 13) % 256),
  );
  await File(path).writeAsBytes(img.encodePng(image));
  return path;
}

void main() {
  late Directory tempDir;
  late String dbPath;
  late String storagePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cli_import_test_');
    dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
    storagePath = p.join(tempDir.path, 'memes');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('import 单张图片：入库、复制到 storage、返回 0', () async {
    final imgPath = await _writePng(p.join(tempDir.path, 'src.png'), seed: 1);

    final exitCode = await CliApp().run(
      ['import', imgPath, '--db', dbPath, '--storage', storagePath],
    );
    expect(exitCode, 0);

    final db = AppDatabase.open(dbPath);
    final memes = await db.memeDao.getAll();
    expect(memes, hasLength(1));
    expect(memes.first.filename, 'src.png');
    expect(memes.first.width, 2);
    expect(memes.first.height, 2);
    expect(
      await File(p.join(storagePath, memes.first.filePath)).exists(),
      isTrue,
    );
    await db.close();
  });

  test('import 重复图片：跳过且不重复入库', () async {
    final imgPath = await _writePng(p.join(tempDir.path, 'src.png'), seed: 2);
    expect(
      await CliApp()
          .run(['import', imgPath, '--db', dbPath, '--storage', storagePath]),
      0,
    );

    var exitCode = -1;
    await expectLater(
      () async {
        exitCode = await CliApp().run(
          ['import', imgPath, '--db', dbPath, '--storage', storagePath],
        );
      },
      prints(contains('跳过')),
    );
    expect(exitCode, 0);

    final db = AppDatabase.open(dbPath);
    expect(await db.memeDao.getAll(), hasLength(1));
    await db.close();
  });

  test('import 不存在的路径返回非 0', () async {
    final exitCode = await CliApp().run([
      'import',
      p.join(tempDir.path, 'no-such.png'),
      '--db',
      dbPath,
      '--storage',
      storagePath,
    ]);
    expect(exitCode, isNot(0));
  });

  test('import 目录 --recursive 导入子目录所有图片', () async {
    final dir = Directory(p.join(tempDir.path, 'pics'));
    await dir.create(recursive: true);
    final sub = Directory(p.join(dir.path, 'sub'));
    await sub.create();
    await _writePng(p.join(dir.path, 'a.png'), seed: 1);
    await _writePng(p.join(dir.path, 'b.png'), seed: 2);
    await _writePng(p.join(sub.path, 'c.png'), seed: 3);

    var exitCode = -1;
    await expectLater(
      () async {
        exitCode = await CliApp().run([
          'import',
          dir.path,
          '--recursive',
          '--db',
          dbPath,
          '--storage',
          storagePath,
        ]);
      },
      prints(contains('成功 3')),
    );
    expect(exitCode, 0);

    final db = AppDatabase.open(dbPath);
    expect(await db.memeDao.getAll(), hasLength(3));
    await db.close();
  });

  test('list 输出导入的 meme；--json 输出 JSON；--limit 生效', () async {
    final imgPath =
        await _writePng(p.join(tempDir.path, 'listme.png'), seed: 4);
    await CliApp().run(
      ['import', imgPath, '--db', dbPath, '--storage', storagePath],
    );

    var exitCode = -1;
    await expectLater(
      () async {
        exitCode =
            await CliApp().run(['list', '--db', dbPath, '--storage', storagePath]);
      },
      prints(contains('listme.png')),
    );
    expect(exitCode, 0);

    await expectLater(
      () async {
        exitCode = await CliApp().run(
          ['list', '--json', '--db', dbPath, '--storage', storagePath],
        );
      },
      prints(contains('"filename"')),
    );
    expect(exitCode, 0);

    exitCode = await CliApp().run(
      ['list', '--limit', '1', '--db', dbPath, '--storage', storagePath],
    );
    expect(exitCode, 0);
  });

  test('get 通过完整 id 与短码获取详情；--json 输出对象', () async {
    final imgPath =
        await _writePng(p.join(tempDir.path, 'getme.png'), seed: 5);
    await CliApp().run(
      ['import', imgPath, '--db', dbPath, '--storage', storagePath],
    );

    final db = AppDatabase.open(dbPath);
    final id = (await db.memeDao.getAll()).single.id;
    await db.close();

    var exitCode = -1;
    await expectLater(
      () async {
        exitCode =
            await CliApp().run(['get', id, '--db', dbPath, '--storage', storagePath]);
      },
      prints(contains('getme.png')),
    );
    expect(exitCode, 0);

    await expectLater(
      () async {
        exitCode = await CliApp().run([
          'get',
          id.substring(0, 8),
          '--json',
          '--db',
          dbPath,
          '--storage',
          storagePath,
        ]);
      },
      prints(contains('"filename"')),
    );
    expect(exitCode, 0);
  });

  test('get 不存在的 id 返回非 0', () async {
    final exitCode = await CliApp().run(
      ['get', 'no-such-id', '--db', dbPath, '--storage', storagePath],
    );
    expect(exitCode, isNot(0));
  });
}
