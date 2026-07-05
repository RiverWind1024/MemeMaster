import 'package:drift/drift.dart';

import 'memes_table.dart';

/// 颜色提取分析队列表
@DataClassName('ColorAnalysisQueueItem')
class ColorAnalysisQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text().references(MemesTable, #id)();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn? get errorMsg => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn? get startedAt => integer().nullable()();
  IntColumn? get doneAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// OCR分析队列表
@DataClassName('OcrAnalysisQueueItem')
class OcrAnalysisQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text().references(MemesTable, #id)();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn? get errorMsg => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn? get startedAt => integer().nullable()();
  IntColumn? get doneAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// AI分析队列表
@DataClassName('AiAnalysisQueueItem')
class AiAnalysisQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text().references(MemesTable, #id)();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn? get errorMsg => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn? get startedAt => integer().nullable()();
  IntColumn? get doneAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
