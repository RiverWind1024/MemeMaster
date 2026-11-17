import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/database/database.dart';

/// 构造测试用 meme；deletedAt 非空表示墓碑。
Meme _meme(String id, {int? deletedAt}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Meme(
    id: id,
    filename: 'a.jpg',
    filePath: 'x/a.jpg',
    fileSize: 1,
    mimeType: 'image/jpeg',
    width: 1,
    height: 1,
    analysisStatus: 'pending',
    colorAnalysisStatus: 'pending',
    ocrAnalysisStatus: 'pending',
    aiAnalysisStatus: 'pending',
    fileHash: 'h1',
    copyCount: 0,
    createdAt: now,
    updatedAt: now,
    importedAt: now,
    deletedAt: deletedAt,
  );
}

void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('schema7_');
    db = AppDatabase.open('${dir.path}/t.db');
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('albums_table 有 updated_at 列', () async {
    final r = await db.customSelect(
      "SELECT COUNT(*) c FROM pragma_table_info('albums_table') "
      "WHERE name='updated_at'",
    ).getSingle();
    expect(r.read<int>('c'), 1);
  });

  test('默认相册 updatedAt 默认为 0', () async {
    final album = await db.albumDao.getDefaultAlbum();
    expect(album, isNotNull);
    expect(album!.updatedAt, 0);
  });

  test('getAllIncludingDeleted 返回墓碑', () async {
    await db.memeDao.insert(_meme('m1', deletedAt: 1));
    expect((await db.memeDao.getAll()).isEmpty, isTrue);
    expect((await db.memeDao.getAllIncludingDeleted()).length, 1);
  });

  test('getByIdIncludingDeleted 可查到墓碑', () async {
    await db.memeDao.insert(_meme('m2', deletedAt: 1));
    expect(await db.memeDao.getById('m2'), isNull);
    expect(await db.memeDao.getByIdIncludingDeleted('m2'), isNotNull);
  });

  test('touchUpdatedAt 仅更新 updatedAt', () async {
    await db.memeDao.insert(_meme('m3'));
    await db.memeDao.touchUpdatedAt('m3', 42);
    final updated = await db.memeDao.getById('m3');
    expect(updated!.updatedAt, 42);
  });
}
