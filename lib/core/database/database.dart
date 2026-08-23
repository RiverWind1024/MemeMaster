import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
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
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _throwMissingExecutor());

  /// 打开指定路径的数据库（CLI/GUI 共用，不依赖 Flutter 插件）。
  ///
  /// 自动创建父目录（CLI 可能通过 --db 指定新路径）。
  static AppDatabase open(String dbPath) {
    File(dbPath).parent.createSync(recursive: true);
    return AppDatabase(NativeDatabase.opened(
      sqlite3.sqlite3.open(dbPath, uri: false)
        ..execute('PRAGMA journal_mode=WAL')
        ..execute('PRAGMA foreign_keys=ON'),
    ));
  }

  @override
  int get schemaVersion => 6;

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
        if (from < 6) {
          // 添加用户自定义名称
          await m.addColumn(memesTable, memesTable.customName);
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

/// 无 executor 时的守卫：不允许无路径/无注入的裸构造
Never _throwMissingExecutor() =>
    throw StateError('必须通过 AppDatabase.open(dbPath) 或传入 QueryExecutor 构造');
