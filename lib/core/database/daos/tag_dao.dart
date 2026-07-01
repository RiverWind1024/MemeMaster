import 'package:drift/drift.dart';

import '../../database/database.dart';

class TagDao {
  final AppDatabase _db;
  TagDao(this._db);

  Future<void> insert(TagEntry tag) async {
    await _db.into(_db.tagsTable).insertOnConflictUpdate(tag);
  }

  Future<void> insertAll(List<TagEntry> tags) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.tagsTable, tags);
    });
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

  Future<int> deleteByMemeId(String memeId) {
    return (_db.delete(_db.tagsTable)
          ..where((t) => t.memeId.equals(memeId)))
        .go();
  }

  /// 删除指定 meme 下特定 source 列表的标签
  Future<int> deleteBySourcesForMeme(String memeId, List<String> sources) {
    if (sources.isEmpty) return Future.value(0);
    return (_db.delete(_db.tagsTable)
          ..where((t) =>
              t.memeId.equals(memeId) & t.source.isIn(sources)))
        .go();
  }

  Future<int> delete(String id) {
    return (_db.delete(_db.tagsTable)..where((t) => t.id.equals(id))).go();
  }
}
