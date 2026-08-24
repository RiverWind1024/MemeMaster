import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/cli/cli_app.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/utils/color_utils.dart';
import 'package:path/path.dart' as p;

/// 向临时库直接插入一条 meme（方式二：绕开图片导入，快且稳定）。
Future<void> _insertMeme(
  AppDatabase db, {
  required String id,
  required String filename,
  required int importedAt,
}) async {
  await db.into(db.memesTable).insert(
        MemesTableCompanion.insert(
          id: id,
          filename: filename,
          filePath: '2026/08/$filename',
          fileSize: 100,
          mimeType: 'image/png',
          width: 100,
          height: 100,
          fileHash: 'hash-$id',
          createdAt: importedAt,
          updatedAt: importedAt,
          importedAt: importedAt,
        ),
      );
}

Future<void> _insertTag(
  AppDatabase db, {
  required String id,
  required String memeId,
  required String content,
}) async {
  await db.into(db.tagsTable).insert(
        TagsTableCompanion.insert(
          id: id,
          memeId: memeId,
          source: 'llm',
          content: content,
        ),
      );
}

Future<void> _insertColor(
  AppDatabase db, {
  required String id,
  required String memeId,
  required ColorRgb color,
}) async {
  final lab = rgbToLab(color);
  await db.into(db.colorsTable).insert(
        ColorsTableCompanion.insert(
          id: id,
          memeId: memeId,
          hexColor: color.hex,
          labL: lab.l,
          labA: lab.a,
          labB: lab.b,
          ratio: 1.0,
        ),
      );
}

/// 从当前目录向上定位项目根（含 pubspec.yaml）。
String _projectRoot() {
  var dir = Directory.current;
  while (!File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return dir.path;
}

void main() {
  late Directory tempDir;
  late String dbPath;
  late String storagePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cli_search_test_');
    dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
    storagePath = p.join(tempDir.path, 'memes');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('search 关键词', () {
    test('按标签内容命中 meme 并输出列表', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png', importedAt: 2000);
      await _insertMeme(db, id: 'dog-0000000002', filename: 'dog.png', importedAt: 1000);
      await _insertTag(db, id: 'tag-1', memeId: 'cat-0000000001', content: '猫');
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run(
            ['search', '猫', '--db', dbPath, '--storage', storagePath],
          );
        },
        prints(contains('cat.png')),
      );
      expect(exitCode, 0);
    });

    test('按文件名关键词命中 meme', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'my-cat.png', importedAt: 1000);
      await _insertMeme(db, id: 'dog-0000000002', filename: 'dog.png', importedAt: 500);
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run(
            ['search', 'cat', '--db', dbPath, '--storage', storagePath],
          );
        },
        prints(contains('my-cat.png')),
      );
      expect(exitCode, 0);
    });

    test('--json 输出命中项数组', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png', importedAt: 1000);
      await _insertTag(db, id: 'tag-1', memeId: 'cat-0000000001', content: '猫');
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run(
            ['search', '猫', '--json', '--db', dbPath, '--storage', storagePath],
          );
        },
        prints(contains('cat-0000000001')),
      );
      expect(exitCode, 0);
    });

    test('无结果时输出 无结果 并返回 0', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png', importedAt: 1000);
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run(
            ['search', '不存在的词', '--db', dbPath, '--storage', storagePath],
          );
        },
        prints(contains('无结果')),
      );
      expect(exitCode, 0);
    });

    test('--limit 非法值返回非 0', () async {
      final exitCode = await CliApp().run(
        ['search', '猫', '--limit', '0', '--db', dbPath, '--storage', storagePath],
      );
      expect(exitCode, isNot(0));
    });
  });

  group('search 颜色', () {
    test('--color 按颜色命中 meme', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'red-0000000001', filename: 'red.png', importedAt: 3000);
      await _insertMeme(db, id: 'blue-0000000002', filename: 'blue.png', importedAt: 2000);
      await _insertColor(
        db,
        id: 'color-red',
        memeId: 'red-0000000001',
        color: const ColorRgb(255, 0, 0),
      );
      await _insertColor(
        db,
        id: 'color-blue',
        memeId: 'blue-0000000002',
        color: const ColorRgb(0, 0, 255),
      );
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run(
            [
              'search',
              '--color',
              '#ff0000',
              '--limit',
              '1',
              '--db',
              dbPath,
              '--storage',
              storagePath,
            ],
          );
        },
        prints(allOf(contains('red.png'), isNot(contains('blue.png')))),
      );
      expect(exitCode, 0);
    });

    test('--color 非法格式返回非 0', () async {
      final exitCode = await CliApp().run(
        [
          'search',
          '--color',
          '#ff000',
          '--db',
          dbPath,
          '--storage',
          storagePath,
        ],
      );
      expect(exitCode, isNot(0));
    });
  });

  group('search 组合', () {
    test('关键词 + 颜色组合搜索命中交集 meme', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(
        db,
        id: 'catred-00000001',
        filename: 'catred.png',
        importedAt: 5000,
      );
      await _insertTag(db, id: 'tag-1', memeId: 'catred-00000001', content: '猫');
      await _insertColor(
        db,
        id: 'color-1',
        memeId: 'catred-00000001',
        color: const ColorRgb(255, 0, 0),
      );
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run(
            [
              'search',
              '猫',
              '--color',
              '#ff0000',
              '--db',
              dbPath,
              '--storage',
              storagePath,
            ],
          );
        },
        prints(contains('catred.png')),
      );
      expect(exitCode, 0);
    });
  });

  group('search 参数校验', () {
    test('无关键词且无 --color 时返回非 0', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png', importedAt: 1000);
      await db.close();

      final exitCode = await CliApp().run(
        ['search', '--db', dbPath, '--storage', storagePath],
      );
      expect(exitCode, isNot(0));
    });

    test('无关键词且无 --color 时 stderr 打印用法', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png', importedAt: 1000);
      await db.close();

      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/mememaster.dart',
          'search',
          '--db',
          dbPath,
          '--storage',
          storagePath,
        ],
        workingDirectory: _projectRoot(),
      );
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('用法'));
    });
  });
}
