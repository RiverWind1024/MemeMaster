import 'package:drift/drift.dart';

import 'memes_table.dart';

@DataClassName('AnalysisQueueItem')
class AnalysisQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text().references(MemesTable, #id)();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn? get errorMsg => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn? get startedAt => integer().nullable()();
  IntColumn? get doneAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
