import 'package:drift/drift.dart';

import 'memes_table.dart';

@DataClassName('TagEntry')
class TagsTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text().references(MemesTable, #id)();
  TextColumn get source => text()();
  TextColumn get content => text()();
  RealColumn get confidence => real().withDefault(const Constant(1.0))();

  @override
  Set<Column> get primaryKey => {id};
}
