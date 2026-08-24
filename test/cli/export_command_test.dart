import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/cli/cli_app.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:path/path.dart' as p;

/// 向临时库直插一条 meme，并在 storage 下创建对应物理文件。
Future<void> _insertMemeWithFile(
  AppDatabase db,
  String storagePath, {
  required String id,
  required String filename,
}) async {
  final relPath = '2026/08/$filename';
  final file = File(p.join(storagePath, relPath));
  await file.parent.create(recursive: true);
  await file.writeAsBytes([1, 2, 3, 4, 5]);

  await db.into(db.memesTable).insert(
        MemesTableCompanion.insert(
          id: id,
          filename: filename,
          filePath: relPath,
          fileSize: 5,
          mimeType: 'image/png',
          width: 10,
          height: 10,
          fileHash: 'hash-$id',
          createdAt: 1000,
          updatedAt: 1000,
          importedAt: 1000,
        ),
      );
}

/// 从 zip 文件解析出文件名列表。
List<String> _zipFileNames(String path) {
  final bytes = File(path).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  return archive.files.map((f) => f.name).toList();
}

void main() {
  late Directory tempDir;
  late String dbPath;
  late String storagePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cli_export_test_');
    dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
    storagePath = p.join(tempDir.path, 'memes');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('export --ids', () {
    test('导出指定 meme 到 zip，文件存在且非空', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMemeWithFile(
        db,
        storagePath,
        id: 'cat-0000000001',
        filename: 'cat.png',
      );
      await db.close();

      final out = p.join(tempDir.path, 'out.zip');
      var exitCode = -1;
      await expectLater(
        () async {
          exitCode = await CliApp().run([
            'export',
            '--ids',
            'cat-0000000001',
            '--output',
            out,
            '--db',
            dbPath,
            '--storage',
            storagePath,
          ]);
        },
        prints(contains('导出成功')),
      );
      expect(exitCode, 0);

      final f = File(out);
      expect(await f.exists(), isTrue);
      expect(await f.length(), greaterThan(0));

      final names = _zipFileNames(out);
      expect(names, contains('manifest.json'));
      expect(names, contains('memes/hash-cat-0000000001.png'));
      expect(names, contains('memes/hash-cat-0000000001.json'));
    });

    test('--ids 指定不存在的 meme 返回非 0', () async {
      final out = p.join(tempDir.path, 'out.zip');
      final exitCode = await CliApp().run([
        'export',
        '--ids',
        'no-such-id',
        '--output',
        out,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
      expect(await File(out).exists(), isFalse);
    });
  });

  group('export --all', () {
    test('导出全部 meme', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMemeWithFile(
        db,
        storagePath,
        id: 'cat-0000000001',
        filename: 'cat.png',
      );
      await _insertMemeWithFile(
        db,
        storagePath,
        id: 'dog-0000000002',
        filename: 'dog.png',
      );
      await db.close();

      final out = p.join(tempDir.path, 'out.zip');
      final exitCode = await CliApp().run([
        'export',
        '--all',
        '--output',
        out,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, 0);

      final f = File(out);
      expect(await f.exists(), isTrue);
      expect(await f.length(), greaterThan(0));

      final names = _zipFileNames(out);
      expect(names, contains('memes/hash-cat-0000000001.png'));
      expect(names, contains('memes/hash-dog-0000000002.png'));
    });

    test('数据库为空时返回非 0', () async {
      final out = p.join(tempDir.path, 'out.zip');
      final exitCode = await CliApp().run([
        'export',
        '--all',
        '--output',
        out,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });

  group('export 参数校验', () {
    test('--ids 与 --all 都未提供返回非 0', () async {
      final out = p.join(tempDir.path, 'out.zip');
      final exitCode = await CliApp().run([
        'export',
        '--output',
        out,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });

    test('--ids 与 --all 同时提供返回非 0', () async {
      final out = p.join(tempDir.path, 'out.zip');
      final exitCode = await CliApp().run([
        'export',
        '--ids',
        'a,b',
        '--all',
        '--output',
        out,
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });

    test('缺少 --output 返回非 0', () async {
      final exitCode = await CliApp().run([
        'export',
        '--ids',
        'a',
        '--db',
        dbPath,
        '--storage',
        storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });
}
