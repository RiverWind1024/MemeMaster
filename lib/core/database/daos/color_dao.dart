import 'package:drift/drift.dart';

import '../../database/database.dart';

class ColorDao {
  final AppDatabase _db;
  ColorDao(this._db);

  /// bump 父 meme 的 updatedAt（子数据变更时）
  Future<void> _touch(String memeId) async {
    await (_db.update(_db.memesTable)..where((t) => t.id.equals(memeId)))
        .write(MemesTableCompanion(
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  Future<void> insert(ColorEntry color) async {
    await _db.into(_db.colorsTable).insertOnConflictUpdate(color);
    await _touch(color.memeId);
  }

  Future<void> insertAll(List<ColorEntry> colors) async {
    if (colors.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.colorsTable, colors);
    });
    // 同一个 meme 可能带多条颜色，逐条 _touch 只会把同一个 updatedAt 重复写一遍。
    final memeIds = colors.map((c) => c.memeId).toSet();
    for (final memeId in memeIds) {
      await _touch(memeId);
    }
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

  Future<int> deleteByMemeId(String memeId) async {
    final n = await (_db.delete(_db.colorsTable)
          ..where((t) => t.memeId.equals(memeId)))
        .go();
    await _touch(memeId);
    return n;
  }
}
