import 'package:drift/drift.dart';

import '../../database/database.dart';

class AnalysisQueueDao {
  final AppDatabase _db;
  AnalysisQueueDao(this._db);

  Future<void> insert(AnalysisQueueItem item) async {
    await _db.into(_db.analysisQueueTable).insertOnConflictUpdate(item);
  }

  Future<void> insertAll(List<AnalysisQueueItem> items) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.analysisQueueTable, items);
    });
  }

  Future<AnalysisQueueItem?> getById(String id) {
    return (_db.select(_db.analysisQueueTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 获取下一个待处理的任务（按优先级降序 + 创建时间升序）
  Future<AnalysisQueueItem?> getNextPending() {
    return (_db.select(_db.analysisQueueTable)
          ..where((t) => t.status.equals('queued'))
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.asc(t.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 获取当前正在运行的任务（用于并发控制）
  Future<List<AnalysisQueueItem>> getRunning() {
    return (_db.select(_db.analysisQueueTable)
          ..where((t) => t.status.equals('running')))
        .get();
  }

  /// 更新任务状态为 running
  Future<void> markRunning(String id) async {
    await (_db.update(_db.analysisQueueTable)
          ..where((t) => t.id.equals(id)))
        .write(AnalysisQueueTableCompanion(
          status: const Value('running'),
          startedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 更新任务状态为 done
  Future<void> markDone(String id) async {
    await (_db.update(_db.analysisQueueTable)
          ..where((t) => t.id.equals(id)))
        .write(AnalysisQueueTableCompanion(
          status: const Value('done'),
          doneAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 更新任务状态为 failed
  Future<void> markFailed(String id, String errorMsg) async {
    await (_db.update(_db.analysisQueueTable)
          ..where((t) => t.id.equals(id)))
        .write(AnalysisQueueTableCompanion(
          status: const Value('failed'),
          errorMsg: Value(errorMsg),
          doneAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 重置失败任务为 queued（重试）
  Future<void> resetFailed(String id) async {
    await (_db.update(_db.analysisQueueTable)
          ..where((t) => t.id.equals(id)))
        .write(const AnalysisQueueTableCompanion(
          status: Value('queued'),
          errorMsg: Value(null),
          startedAt: Value(null),
          doneAt: Value(null),
        ));
  }

  /// 重置所有 running 状态的任务为 queued（应用启动时清理闪退遗留的卡住任务）
  Future<void> resetAllRunningToQueued() async {
    await (_db.update(_db.analysisQueueTable)
          ..where((t) => t.status.equals('running')))
        .write(const AnalysisQueueTableCompanion(
          status: Value('queued'),
          startedAt: Value(null),
          doneAt: Value(null),
        ));
  }

  /// 获取所有 running 状态任务的关联 meme ID
  Future<List<String>> getRunningMemeIds() async {
    final rows = await (_db.select(_db.analysisQueueTable)
          ..where((t) => t.status.equals('running')))
        .get();
    return rows.map((r) => r.memeId).toList();
  }

  /// 统计排队的任务数
  Future<int> countQueued() async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) FROM analysis_queue_table WHERE status = ?',
      variables: [Variable.withString('queued')],
    ).getSingle();
    return result.data.values.first as int;
  }

  /// 删除与指定 meme 关联的所有队列项
  Future<int> deleteByMemeId(String memeId) {
    return (_db.delete(_db.analysisQueueTable)
          ..where((t) => t.memeId.equals(memeId)))
        .go();
  }

  /// 清理已完成的任务
  Future<int> deleteDone() {
    return (_db.delete(_db.analysisQueueTable)
          ..where((t) => t.status.equals('done')))
        .go();
  }

  /// 清空所有记录（旧统一队列迁移后不再使用）
  Future<void> deleteAll() async {
    await _db.delete(_db.analysisQueueTable).go();
  }
}
