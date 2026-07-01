import 'package:drift/drift.dart';

@DataClassName('SyncStateEntry')
class SyncStateTable extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
