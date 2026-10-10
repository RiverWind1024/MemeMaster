import 'package:drift/drift.dart';

import '../../database/database.dart';

class TagDao {
  final AppDatabase _db;
  TagDao(this._db);

  /// bump 父 meme 的 updatedAt（子数据变更时）
  Future<void> _touch(String memeId) async {
    await (_db.update(_db.memesTable)..where((t) => t.id.equals(memeId)))
        .write(MemesTableCompanion(
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  Future<void> insert(TagEntry tag) async {
    await _db.into(_db.tagsTable).insertOnConflictUpdate(tag);
    await _touch(tag.memeId);
  }

  Future<void> insertAll(List<TagEntry> tags) async {
    if (tags.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.tagsTable, tags);
    });
    for (final t in tags) {
      await _touch(t.memeId);
    }
  }

  Future<List<TagEntry>> getByMemeId(String memeId) {
    return (_db.select(_db.tagsTable)
          ..where((t) => t.memeId.equals(memeId)))
        .get();
  }

  Future<List<TagEntry>> getBySource(String source) {
    return (_db.select(_db.tagsTable)
          ..where((t) => t.source.equals(source)))
        .get();
  }

  Future<List<TagEntry>> searchByContent(String keyword) {
    return (_db.select(_db.tagsTable)
          ..where((t) => t.content.like('%$keyword%')))
        .get();
  }

  Future<int> countBySource(String source) async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) FROM tags_table WHERE source = ?',
      variables: [Variable.withString(source)],
    ).getSingle();
    return result.data.values.first as int;
  }

  Future<int> deleteByMemeId(String memeId) async {
    final n = await (_db.delete(_db.tagsTable)
          ..where((t) => t.memeId.equals(memeId)))
        .go();
    await _touch(memeId);
    return n;
  }

  /// 删除指定 meme 下特定 source 列表的标签
  Future<int> deleteBySourcesForMeme(String memeId, List<String> sources) async {
    if (sources.isEmpty) return 0;
    final n = await (_db.delete(_db.tagsTable)
          ..where((t) =>
              t.memeId.equals(memeId) & t.source.isIn(sources)))
        .go();
    await _touch(memeId);
    return n;
  }

  Future<int> delete(String id) async {
    final row = await (_db.select(_db.tagsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final n =
        await (_db.delete(_db.tagsTable)..where((t) => t.id.equals(id))).go();
    if (row != null) {
      await _touch(row.memeId);
    }
    return n;
  }
}
