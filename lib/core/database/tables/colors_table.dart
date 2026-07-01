import 'package:drift/drift.dart';

import 'memes_table.dart';

@DataClassName('ColorEntry')
class ColorsTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text().references(MemesTable, #id)();
  TextColumn get hexColor => text()();
  RealColumn get labL => real()();
  RealColumn get labA => real()();
  RealColumn get labB => real()();
  RealColumn get ratio => real()();

  @override
  Set<Column> get primaryKey => {id};
}
