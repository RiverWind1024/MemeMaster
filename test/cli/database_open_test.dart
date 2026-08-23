import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:path/path.dart' as p;

void main() {
  test('AppDatabase.open 数据持久化到指定路径（重开后仍在）', () async {
    final dir = await Directory.systemTemp.createTemp('cli_db_test_');
    // 嵌套路径：父目录不存在，验证 open 会自动创建
    final dbPath = p.join(dir.path, 'nested', 'data', 'meme_helper.db');

    var db = AppDatabase.open(dbPath);
    await db.into(db.memesTable).insert(
          MemesTableCompanion.insert(
            id: 'test-id',
            filename: 'a.png',
            filePath: '2026/08/a.png',
            fileSize: 1,
            mimeType: 'image/png',
            width: 10,
            height: 10,
            fileHash: 'hash',
            createdAt: 0,
            updatedAt: 0,
            importedAt: 0,
          ),
        );
    await db.close();

    // 重开同一路径，数据应仍在（证明落盘在 dbPath 指定的文件上）
    db = AppDatabase.open(dbPath);
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM memes_table')
        .getSingle();
    expect(row.read<int>('c'), 1);

    await db.close();
    await dir.delete(recursive: true);
  });
}
