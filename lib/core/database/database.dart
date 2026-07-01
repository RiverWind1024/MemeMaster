import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:uuid/uuid.dart';

import 'daos/meme_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/color_dao.dart';
import 'daos/album_dao.dart';
import 'daos/analysis_queue_dao.dart';
import 'daos/sync_state_dao.dart';
import 'tables/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    MemesTable,
    TagsTable,
    ColorsTable,
    EmbeddingsTable,
    AnalysisQueueTable,
    SyncStateTable,
    AlbumsTable,
    MemeAlbumsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // 插入默认"所有图片"相册
        final id = const Uuid().v4();
        await customInsert(
          'INSERT OR IGNORE INTO albums_table '
          '(id, name, icon, sort_order, is_default, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(id),
            Variable.withString('所有图片'),
            Variable.withString('photo_library'),
            Variable.withInt(0),
            Variable.withInt(1),
            Variable.withInt(DateTime.now().millisecondsSinceEpoch),
          ],
        );
      },
    );
  }

  late final MemeDao memeDao = MemeDao(this);
  late final TagDao tagDao = TagDao(this);
  late final ColorDao colorDao = ColorDao(this);
  late final AlbumDao albumDao = AlbumDao(this);
  late final AnalysisQueueDao analysisQueueDao = AnalysisQueueDao(this);
  late final SyncStateDao syncStateDao = SyncStateDao(this);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationDocumentsDirectory();
    await dbDir.create(recursive: true);

    final dbPath = '${dbDir.path}/meme_helper.db';

    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

    final db = sqlite3.sqlite3.open(
      dbPath,
      uri: false,
    );

    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA foreign_keys=ON');

    return NativeDatabase.opened(db);
  });
}
