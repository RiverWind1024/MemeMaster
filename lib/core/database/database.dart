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
import 'daos/color_analysis_queue_dao.dart';
import 'daos/ocr_analysis_queue_dao.dart';
import 'daos/ai_analysis_queue_dao.dart';
import 'daos/sync_state_dao.dart';
import 'daos/user_stats_dao.dart';
import 'tables/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    MemesTable,
    TagsTable,
    ColorsTable,
    EmbeddingsTable,
    AnalysisQueueTable,
    ColorAnalysisQueueTable,
    OcrAnalysisQueueTable,
    AiAnalysisQueueTable,
    SyncStateTable,
    AlbumsTable,
    MemeAlbumsTable,
    UserStatsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

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
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(memesTable, memesTable.copyCount);
          await m.addColumn(memesTable, memesTable.source);
          await m.create(userStatsTable);
        }
        if (from < 3) {
          await m.addColumn(userStatsTable, userStatsTable.promptTokens);
          await m.addColumn(userStatsTable, userStatsTable.completionTokens);
        }
        if (from < 4) {
          // 添加并行分析相关列
          await m.addColumn(memesTable, memesTable.colorAnalysisStatus);
          await m.addColumn(memesTable, memesTable.ocrAnalysisStatus);
          await m.addColumn(memesTable, memesTable.aiAnalysisStatus);
          // 创建新的队列表
          await m.create(colorAnalysisQueueTable);
          await m.create(ocrAnalysisQueueTable);
          await m.create(aiAnalysisQueueTable);
        }
        if (from < 5) {
          // 添加软删除时间戳（用于 S3 增量同步）
          await m.addColumn(memesTable, memesTable.deletedAt);
        }
      },
    );
  }

  late final MemeDao memeDao = MemeDao(this);
  late final TagDao tagDao = TagDao(this);
  late final ColorDao colorDao = ColorDao(this);
  late final AlbumDao albumDao = AlbumDao(this);
  late final AnalysisQueueDao analysisQueueDao = AnalysisQueueDao(this);
  late final ColorAnalysisQueueDao colorAnalysisQueueDao = ColorAnalysisQueueDao(this);
  late final OcrAnalysisQueueDao ocrAnalysisQueueDao = OcrAnalysisQueueDao(this);
  late final AiAnalysisQueueDao aiAnalysisQueueDao = AiAnalysisQueueDao(this);
  late final SyncStateDao syncStateDao = SyncStateDao(this);
  late final UserStatsDao userStatsDao = UserStatsDao(this);
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
