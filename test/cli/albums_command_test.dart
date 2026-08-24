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

/// 按名称查找相册 id。
Future<String?> _findAlbumId(AppDatabase db, String name) async {
  for (final a in await db.albumDao.getAll()) {
    if (a.name == name) return a.id;
  }
  return null;
}

void main() {
  late Directory tempDir;
  late String dbPath;
  late String storagePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cli_albums_test_');
    dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
    storagePath = p.join(tempDir.path, 'memes');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('albums create', () {
    test('create 后 list 包含新相册', () async {
      final exitCode = await CliApp().run([
        'albums',
        'create',
        '测试相册',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final db = AppDatabase.open(dbPath);
      final albums = await db.albumDao.getAll();
      expect(albums.any((a) => a.name == '测试相册'), isTrue);
      await db.close();
    });

    test('缺少名称返回非 0', () async {
      final exitCode = await CliApp().run([
        'albums',
        'create',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });

  group('albums rename', () {
    test('rename 后相册名称更新', () async {
      await CliApp().run([
        'albums',
        'create',
        '旧名',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      final db = AppDatabase.open(dbPath);
      final id = await _findAlbumId(db, '旧名');
      expect(id, isNotNull);
      await db.close();

      final exitCode = await CliApp().run([
        'albums',
        'rename',
        id!,
        '新名',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final db2 = AppDatabase.open(dbPath);
      final renamed = await db2.albumDao.getById(id);
      expect(renamed?.name, '新名');
      await db2.close();
    });

    test('rename 不存在的相册返回非 0', () async {
      final exitCode = await CliApp().run([
        'albums',
        'rename',
        'no-such-album',
        '新名',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });

  group('albums delete', () {
    test('delete 后相册被删除', () async {
      await CliApp().run([
        'albums',
        'create',
        '要删',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      final db = AppDatabase.open(dbPath);
      final id = await _findAlbumId(db, '要删');
      await db.close();

      final exitCode = await CliApp().run([
        'albums',
        'delete',
        id!,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final db2 = AppDatabase.open(dbPath);
      expect(await db2.albumDao.getById(id), isNull);
      await db2.close();
    });

    test('delete 不存在的相册返回非 0', () async {
      final exitCode = await CliApp().run([
        'albums',
        'delete',
        'no-such-album',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });

  group('albums add / rm', () {
    test('add 后 getMemeIdsByAlbum 包含该 meme', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.close();
      await CliApp().run([
        'albums',
        'create',
        '收藏',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);

      final db2 = AppDatabase.open(dbPath);
      final albumId = await _findAlbumId(db2, '收藏');
      await db2.close();

      final exitCode = await CliApp().run([
        'albums',
        'add',
        'cat-0000000001',
        albumId!,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final db3 = AppDatabase.open(dbPath);
      final ids = await db3.albumDao.getMemeIdsByAlbum(albumId);
      expect(ids, contains('cat-0000000001'));
      await db3.close();
    });

    test('rm 后关联被移除', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.close();
      await CliApp().run([
        'albums',
        'create',
        '收藏',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);

      final db2 = AppDatabase.open(dbPath);
      final albumId = await _findAlbumId(db2, '收藏');
      await db2.close();

      await CliApp().run([
        'albums',
        'add',
        'cat-0000000001',
        albumId!,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);

      final exitCode = await CliApp().run([
        'albums',
        'rm',
        'cat-0000000001',
        albumId,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final db3 = AppDatabase.open(dbPath);
      final ids = await db3.albumDao.getMemeIdsByAlbum(albumId);
      expect(ids, isEmpty);
      await db3.close();
    });

    test('add 不存在的 meme 返回非 0', () async {
      await CliApp().run([
        'albums',
        'create',
        '收藏',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      final db = AppDatabase.open(dbPath);
      final albumId = await _findAlbumId(db, '收藏');
      await db.close();

      final exitCode = await CliApp().run([
        'albums',
        'add',
        'no-such-meme',
        albumId!,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });

    test('add 不存在的相册返回非 0', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMeme(db, id: 'cat-0000000001', filename: 'cat.png');
      await db.close();

      final exitCode = await CliApp().run([
        'albums',
        'add',
        'cat-0000000001',
        'no-such-album',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });

  group('albums list', () {
    test('list 输出相册名', () async {
      await CliApp().run([
        'albums',
        'create',
        '收藏',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run([
            'albums',
            'list',
            '--db',
            dbPath,
            '--storage',
            storagePath,
          ]);
        },
        prints(contains('收藏')),
      );
      expect(exitCode, 0);
    });

    test('list 包含默认"所有图片"相册', () async {
      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run([
            'albums',
            'list',
            '--db',
            dbPath,
            '--storage',
            storagePath,
          ]);
        },
        prints(contains('所有图片')),
      );
      expect(exitCode, 0);
    });

    test('--json 输出相册数组', () async {
      await CliApp().run([
        'albums',
        'create',
        '收藏',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);

      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run([
            'albums',
            'list',
            '--json',
            '--db',
            dbPath,
            '--storage',
            storagePath,
          ]);
        },
        prints(contains('"name":"收藏"')),
      );
      expect(exitCode, 0);
    });
  });

  group('albums 子命令校验', () {
    test('未知子命令返回非 0', () async {
      final exitCode = await CliApp().run([
        'albums',
        'frobnicate',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });
}
