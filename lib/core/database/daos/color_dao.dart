import '../../database/database.dart';

class ColorDao {
  final AppDatabase _db;
  ColorDao(this._db);

  Future<void> insert(ColorEntry color) async {
    await _db.into(_db.colorsTable).insertOnConflictUpdate(color);
  }

  Future<void> insertAll(List<ColorEntry> colors) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.colorsTable, colors);
    });
  }

  Future<List<ColorEntry>> getByMemeId(String memeId) {
    return (_db.select(_db.colorsTable)
          ..where((t) => t.memeId.equals(memeId)))
        .get();
  }

  /// 获取所有颜色（用于全局颜色搜索）
  Future<List<ColorEntry>> getAll() {
    return _db.select(_db.colorsTable).get();
  }

  Future<int> deleteByMemeId(String memeId) {
    return (_db.delete(_db.colorsTable)
          ..where((t) => t.memeId.equals(memeId)))
        .go();
  }
}
