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

  @override
  Set<Column> get primaryKey => {id};
}
