import 'package:drift/drift.dart';

@DataClassName('Meme')
class MemesTable extends Table {
  TextColumn get id => text()();
  TextColumn get filename => text()();
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer()();
  TextColumn get mimeType => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  TextColumn? get folderId => text().nullable()();
  TextColumn get analysisStatus => text().withDefault(const Constant('pending'))();
  TextColumn get fileHash => text()();
  TextColumn? get description => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get importedAt => integer()();

  /// 复制次数（用于排序和统计）
  IntColumn get copyCount => integer().withDefault(const Constant(0))();

  /// 图片来源：clipboard, wechat, album, bilibili, system_share, manual_import, drag_drop 等
  TextColumn? get source => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
