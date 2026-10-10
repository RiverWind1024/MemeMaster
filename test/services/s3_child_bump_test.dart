import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/database/database.dart';

/// Task 4: 子数据（标签/颜色/相册归属）变更应 bump 父实体的 updatedAt，
/// 以便 S3 LWW 同步能够将这些变更传播出去。
void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bump_');
    db = AppDatabase.open('${dir.path}/t.db');
    const now = 1000;
    await db.memeDao.insert(const Meme(
      id: 'm1',
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
    ));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<int> memeUpdatedAt(String id) async =>
      (await db.memeDao.getByIdIncludingDeleted(id))!.updatedAt;

  /// 重置父 meme updatedAt 到基线，确保后续断言验证的是操作本身触发的 bump
  Future<void> resetMeme(String id) => db.memeDao.touchUpdatedAt(id, 1000);

  /// 重置相册 updatedAt 到基线
  Future<void> resetAlbum(String id) async {
    await (db.update(db.albumsTable)..where((t) => t.id.equals(id)))
        .write(const AlbumsTableCompanion(updatedAt: Value(1000)));
  }

  group('TagDao 会 bump 父 meme updatedAt', () {
    test('insert', () async {
      await db.tagDao.insert(const TagEntry(
        id: 't1',
        memeId: 'm1',
        source: 'manual',
        content: 'x',
        confidence: 1.0,
      ));
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });

    test('insertAll', () async {
      await db.tagDao.insertAll(const [
        TagEntry(
          id: 't1',
          memeId: 'm1',
          source: 'manual',
          content: 'a',
          confidence: 1.0,
        ),
        TagEntry(
          id: 't2',
          memeId: 'm1',
          source: 'ocr',
          content: 'b',
          confidence: 0.9,
        ),
      ]);
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });

    test('deleteByMemeId', () async {
      await db.tagDao.deleteByMemeId('m1');
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });

    test('deleteBySourcesForMeme', () async {
      await db.tagDao.insert(const TagEntry(
        id: 't1',
        memeId: 'm1',
        source: 'ocr',
        content: 'b',
        confidence: 0.9,
      ));
      await resetMeme('m1');
      await db.tagDao.deleteBySourcesForMeme('m1', ['ocr']);
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });

    test('delete(id)', () async {
      await db.tagDao.insert(const TagEntry(
        id: 't1',
        memeId: 'm1',
        source: 'manual',
        content: 'x',
        confidence: 1.0,
      ));
      await resetMeme('m1');
      await db.tagDao.delete('t1');
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });
  });

  group('ColorDao 会 bump 父 meme updatedAt', () {
    test('insert', () async {
      await db.colorDao.insert(const ColorEntry(
        id: 'c1',
        memeId: 'm1',
        hexColor: '#ffffff',
        labL: 100,
        labA: 0,
        labB: 0,
        ratio: 1.0,
      ));
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });

    test('insertAll', () async {
      await db.colorDao.insertAll(const [
        ColorEntry(
          id: 'c1',
          memeId: 'm1',
          hexColor: '#ffffff',
          labL: 100,
          labA: 0,
          labB: 0,
          ratio: 0.5,
        ),
        ColorEntry(
          id: 'c2',
          memeId: 'm1',
          hexColor: '#000000',
          labL: 0,
          labA: 0,
          labB: 0,
          ratio: 0.5,
        ),
      ]);
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });

    test('deleteByMemeId', () async {
      await db.colorDao.deleteByMemeId('m1');
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });
  });

  group('AlbumDao 会 bump 父实体 updatedAt', () {
    test('addMemeToAlbum bump meme 与相册', () async {
      final album = (await db.albumDao.getDefaultAlbum())!;
      await resetAlbum(album.id);
      await db.albumDao.addMemeToAlbum('m1', album.id);
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
      expect((await db.albumDao.getById(album.id))!.updatedAt, greaterThan(1000));
    });

    test('removeMemeFromAlbum bump meme 与相册', () async {
      final album = (await db.albumDao.getDefaultAlbum())!;
      await db.albumDao.addMemeToAlbum('m1', album.id);
      await resetMeme('m1');
      await resetAlbum(album.id);
      await db.albumDao.removeMemeFromAlbum('m1', album.id);
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
      expect((await db.albumDao.getById(album.id))!.updatedAt, greaterThan(1000));
    });

    test('removeMemeFromAllAlbums bump meme', () async {
      final album = (await db.albumDao.getDefaultAlbum())!;
      await db.albumDao.addMemeToAlbum('m1', album.id);
      await resetMeme('m1');
      await db.albumDao.removeMemeFromAllAlbums('m1');
      expect(await memeUpdatedAt('m1'), greaterThan(1000));
    });

    test('updateName bump 相册', () async {
      final album = (await db.albumDao.getDefaultAlbum())!;
      await db.albumDao.updateName(album.id, '新名字');
      expect((await db.albumDao.getById(album.id))!.updatedAt, greaterThan(1000));
    });

    test('updateSortOrder bump 相册', () async {
      final album = (await db.albumDao.getDefaultAlbum())!;
      await db.albumDao.updateSortOrder(album.id, 5);
      expect((await db.albumDao.getById(album.id))!.updatedAt, greaterThan(1000));
    });
  });
}
