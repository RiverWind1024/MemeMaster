import 'package:drift/drift.dart';

@DataClassName('EmbeddingEntry')
class EmbeddingsTable extends Table {
  TextColumn get memeId => text()();
  Column<Uint8List> get vector => blob()();
  TextColumn get modelId => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {memeId};
}
