import 'package:drift/drift.dart';

/// 相册 — meme 的多对多分组
@DataClassName('Album')
class AlbumsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn? get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get isDefault => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
