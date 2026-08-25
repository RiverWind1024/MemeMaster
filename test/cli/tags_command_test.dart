import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/cli/cli_app.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:path/path.dart' as p;

/// 向临时库直接插入一条 meme（绕开图片导入，快且稳定）。
Future<void> _insertMeme(
  AppDatabase db, {
  required String id,
  required String filename,
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
          createdAt: 1000,
          updatedAt: 1000,
          importedAt: 1000,
        ),
      );
}

void main() {
  late Directory tempDir;
  late String dbPath;
  late String storagePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cli_tags_test_');
    dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
    storagePath = p.join(tempDir.path, 'memes');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('tags add', () {
    test('add 后数据库出现该标签（默认来源 custom）', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run([
            'tags',
            'add',
            'cat-0000000001',
            '猫',
            '--db',
            dbPath,
            '--storage',
            storagePath,
          ]);
        },
        prints(contains('猫')),
      );
      expect(exitCode, 0);

      final db2 = AppDatabase.open(dbPath);
      final tags = await db2.tagDao.getByMemeId('cat-0000000001');
      expect(tags, hasLength(1));
      expect(tags.single.content, '猫');
      expect(tags.single.source, 'custom');
      await db2.close();
    });

    test('--source 指定标签来源', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.close();

      final exitCode = await CliApp().run([
        'tags',
        'add',
        'cat-0000000001',
        '表情',
        '--source',
        'wechat',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final db2 = AppDatabase.open(dbPath);
      final tags = await db2.tagDao.getByMemeId('cat-0000000001');
      expect(tags.single.source, 'wechat');
      await db2.close();
    });

    test('重复添加同一标签不产生重复记录', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.close();

      for (var i = 0; i < 2; i++) {
        final exitCode = await CliApp().run([
          'tags',
          'add',
          'cat-0000000001',
          '猫',
          '--db',
          dbPath,
          '--storage',
          storagePath,
        ]);
        expect(exitCode, 0);
      }

      final db2 = AppDatabase.open(dbPath);
      final tags = await db2.tagDao.getByMemeId('cat-0000000001');
      expect(tags, hasLength(1));
      await db2.close();
    });

    test('meme 不存在返回非 0', () async {
      final exitCode = await CliApp().run([
        'tags',
        'add',
        'no-such-id',
        '猫',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });

    test('缺少参数返回非 0', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.close();

      final exitCode = await CliApp().run([
        'tags',
        'add',
        'cat-0000000001',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });

  group('tags rm', () {
    test('rm 后数据库中标签被删除', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.tagDao.insert(const TagEntry(
        id: 'tag-1',
        memeId: 'cat-0000000001',
        source: 'custom',
        content: '猫',
        confidence: 1.0,
      ));
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run([
            'tags',
            'rm',
            'cat-0000000001',
            '猫',
            '--db',
            dbPath,
            '--storage',
            storagePath,
          ]);
        },
        prints(contains('猫')),
      );
      expect(exitCode, 0);

      final db2 = AppDatabase.open(dbPath);
      final tags = await db2.tagDao.getByMemeId('cat-0000000001');
      expect(tags, isEmpty);
      await db2.close();
    });

    test('rm 默认仅删除 custom 来源，保留同名自动标签', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.tagDao.insert(const TagEntry(
        id: 'tag-1',
        memeId: 'cat-0000000001',
        source: 'custom',
        content: '狗',
        confidence: 1.0,
      ));
      await db.tagDao.insert(const TagEntry(
        id: 'tag-2',
        memeId: 'cat-0000000001',
        source: 'llm',
        content: '狗',
        confidence: 0.9,
      ));
      await db.close();

      final exitCode = await CliApp().run([
        'tags',
        'rm',
        'cat-0000000001',
        '狗',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final db2 = AppDatabase.open(dbPath);
      final tags = await db2.tagDao.getByMemeId('cat-0000000001');
      expect(tags, hasLength(1));
      expect(tags.single.source, 'llm');
      expect(tags.single.content, '狗');
      await db2.close();
    });

    test('rm --source 删除指定来源标签', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.tagDao.insert(const TagEntry(
        id: 'tag-1',
        memeId: 'cat-0000000001',
        source: 'custom',
        content: '狗',
        confidence: 1.0,
      ));
      await db.tagDao.insert(const TagEntry(
        id: 'tag-2',
        memeId: 'cat-0000000001',
        source: 'llm',
        content: '狗',
        confidence: 0.9,
      ));
      await db.close();

      final exitCode = await CliApp().run([
        'tags',
        'rm',
        'cat-0000000001',
        '狗',
        '--source',
        'llm',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final db2 = AppDatabase.open(dbPath);
      final tags = await db2.tagDao.getByMemeId('cat-0000000001');
      expect(tags, hasLength(1));
      expect(tags.single.source, 'custom');
      await db2.close();
    });

    test('rm 不存在的标签幂等返回 0', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.close();

      final exitCode = await CliApp().run([
        'tags',
        'rm',
        'cat-0000000001',
        '不存在的标签',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);
    });

    test('meme 不存在返回非 0', () async {
      final exitCode = await CliApp().run([
        'tags',
        'rm',
        'no-such-id',
        '猫',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });

  group('tags list', () {
    test('list 输出全部标签', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.tagDao.insert(const TagEntry(
        id: 'tag-1',
        memeId: 'cat-0000000001',
        source: 'custom',
        content: '猫',
        confidence: 1.0,
      ));
      await db.tagDao.insert(const TagEntry(
        id: 'tag-2',
        memeId: 'cat-0000000001',
        source: 'llm',
        content: '动物',
        confidence: 0.9,
      ));
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run([
            'tags',
            'list',
            'cat-0000000001',
            '--db',
            dbPath,
            '--storage',
            storagePath,
          ]);
        },
        prints(allOf(contains('猫'), contains('动物'))),
      );
      expect(exitCode, 0);
    });

    test('--json 输出标签数组', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.tagDao.insert(const TagEntry(
        id: 'tag-1',
        memeId: 'cat-0000000001',
        source: 'custom',
        content: '猫',
        confidence: 1.0,
      ));
      await db.close();

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run([
            'tags',
            'list',
            'cat-0000000001',
            '--json',
            '--db',
            dbPath,
            '--storage',
            storagePath,
          ]);
        },
        prints(contains('"content":"猫"')),
      );
      expect(exitCode, 0);
    });

    test('meme 不存在返回非 0', () async {
      final exitCode = await CliApp().run([
        'tags',
        'list',
        'no-such-id',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });

  group('tags 子命令校验', () {
    test('未知子命令返回非 0', () async {
      final exitCode = await CliApp().run([
        'tags',
        'frobnicate',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });

    test('缺少子命令返回非 0', () async {
      final exitCode = await CliApp().run([
        'tags',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });
}
