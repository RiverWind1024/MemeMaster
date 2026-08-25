import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/cli/cli_app.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:path/path.dart' as p;

/// 直接插入一条 meme（不依赖导入图片文件），用于 stats/reindex 测试。
Future<Meme> _createMeme(AppDatabase db, {String filename = 'x.png'}) {
  final repo = MemeRepository(
    memeDao: db.memeDao,
    tagDao: db.tagDao,
    colorDao: db.colorDao,
    queueDao: db.analysisQueueDao,
  );
  return repo.create(
    filename: filename,
    filePath: '2026/01/$filename',
    fileSize: 100,
    mimeType: 'image/png',
    width: 2,
    height: 2,
    fileHash: 'hash-$filename',
  );
}

void main() {
  late Directory tempDir;
  late String dbPath;
  late String storagePath;
  late String configPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cli_stats_reindex_');
    dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
    storagePath = p.join(tempDir.path, 'memes');
    configPath = p.join(tempDir.path, 'cli_config.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('stats 命令', () {
    test('空库输出 0 统计并返回 0', () async {
      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp()
              .run(['stats', '--db', dbPath, '--storage', storagePath]);
        },
        prints(contains('meme 总数: 0')),
      );
      expect(exitCode, 0);
    });

    test('含 1 条 meme 时输出总数与状态计数', () async {
      final db = AppDatabase.open(dbPath);
      await _createMeme(db);
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp()
              .run(['stats', '--db', dbPath, '--storage', storagePath]);
        },
        prints(allOf(contains('meme 总数: 1'), contains('pending=1'))),
      );
      expect(exitCode, 0);
    });

    test('--json 输出 JSON 统计', () async {
      final db = AppDatabase.open(dbPath);
      final meme = await _createMeme(db);
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp()
              .run(['stats', '--json', '--db', dbPath, '--storage', storagePath]);
        },
        prints(contains('"totalMemes":1')),
      );
      expect(exitCode, 0);
      expect(meme, isNotNull);
    });
  });

  group('reindex 命令', () {
    test('--all 对 pending meme 入队 3 个维度', () async {
      final db = AppDatabase.open(dbPath);
      await _createMeme(db);
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp()
              .run(['reindex', '--all', '--db', dbPath, '--storage', storagePath]);
        },
        prints(allOf(contains('处理 1 条'), contains('入队 3'))),
      );
      expect(exitCode, 0);
    });

    test('单 id 重索引入队并返回 0', () async {
      final db = AppDatabase.open(dbPath);
      final meme = await _createMeme(db);
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run(
              ['reindex', meme.id, '--db', dbPath, '--storage', storagePath]);
        },
        prints(contains('入队 3')),
      );
      expect(exitCode, 0);
    });

    test('不存在的 id 返回非 0', () async {
      final exitCode = await CliApp().run(
          ['reindex', 'no-such-id', '--db', dbPath, '--storage', storagePath]);
      expect(exitCode, isNot(0));
    });

    test('无参数返回 1', () async {
      expect(
        await CliApp().run(['reindex', '--db', dbPath, '--storage', storagePath]),
        1,
      );
    });
  });

  group('s3 命令', () {
    test('未配置时报错并返回 1', () async {
      final exitCode = await CliApp(configPath: configPath).run(
        ['s3', 'test', '--db', dbPath, '--storage', storagePath],
      );
      expect(exitCode, 1);
    });

    test('无子命令返回 1', () async {
      final exitCode = await CliApp(configPath: configPath).run(
        ['s3', '--db', dbPath, '--storage', storagePath],
      );
      expect(exitCode, 1);
    });
  });
}