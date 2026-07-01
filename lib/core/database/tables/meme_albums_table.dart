import 'package:drift/drift.dart';

import 'memes_table.dart';
import 'albums_table.dart';

/// meme 与 相册 的多对多关联表
@DataClassName('MemeAlbum')
class MemeAlbumsTable extends Table {
  TextColumn get memeId => text().references(MemesTable, #id)();
  TextColumn get albumId => text().references(AlbumsTable, #id)();
  IntColumn get addedAt => integer()();

  @override
  Set<Column> get primaryKey => {memeId, albumId};
}
