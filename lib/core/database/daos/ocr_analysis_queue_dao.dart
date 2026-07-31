import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/parallel_analysis_queue_tables.dart';

/// OCR分析队列 DAO
class OcrAnalysisQueueDao {
  final AppDatabase _db;

  OcrAnalysisQueueDao(this._db);

  Future<void> insert(OcrAnalysisQueueItem item) async {
    await _db.into(_db.ocrAnalysisQueueTable).insertOnConflictUpdate(item);
  }

  Future<void> insertAll(List<OcrAnalysisQueueItem> items) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.ocrAnalysisQueueTable, items);
    });
  }

  Future<OcrAnalysisQueueItem?> getNextPending() {
    return (_db.select(_db.ocrAnalysisQueueTable)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.desc(t.priority), (t) => OrderingTerm.asc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<OcrAnalysisQueueItem>> getRunning() {
    return (_db.select(_db.ocrAnalysisQueueTable)
          ..where((t) => t.status.equals('running')))
        .get();
  }

  Future<void> markRunning(String id) async {
    await (_db.update(_db.ocrAnalysisQueueTable)
          ..where((t) => t.id.equals(id)))
        .write(OcrAnalysisQueueTableCompanion(
          status: const Value('running'),
          startedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  Future<void> markDone(String id) async {
    await (_db.update(_db.ocrAnalysisQueueTable)
          ..where((t) => t.id.equals(id)))
        .write(OcrAnalysisQueueTableCompanion(
          status: const Value('done'),
          doneAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  Future<void> markFailed(String id, String error) async {
    await (_db.update(_db.ocrAnalysisQueueTable)
          ..where((t) => t.id.equals(id)))
        .write(OcrAnalysisQueueTableCompanion(
          status: const Value('failed'),
          errorMsg: Value(error),
          doneAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  Future<void> resetAllRunningToPending() async {
    await (_db.update(_db.ocrAnalysisQueueTable)
          ..where((t) => t.status.equals('running')))
        .write(const OcrAnalysisQueueTableCompanion(
          status: Value('pending'),
        ));
  }

  Future<List<String>> getRunningMemeIds() async {
    final rows = await (_db.select(_db.ocrAnalysisQueueTable)
          ..where((t) => t.status.equals('running')))
        .get();
    return rows.map((r) => r.memeId).toList();
  }

  Future<List<String>> getPendingMemeIds() async {
    final rows = await (_db.select(_db.ocrAnalysisQueueTable)
          ..where((t) => t.status.equals('pending')))
        .get();
    return rows.map((r) => r.memeId).toList();
  }

  Future<int> getPendingCount() async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) as count FROM ocr_analysis_queue_table WHERE status = ?',
      variables: [Variable<String>('pending')],
    ).getSingle();
    return result.read<int>('count');
  }

  Future<int> getRunningCount() async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) as count FROM ocr_analysis_queue_table WHERE status = ?',
      variables: [Variable<String>('running')],
    ).getSingle();
    return result.read<int>('count');
  }

  Future<void> deleteByMemeId(String memeId) async {
    await (_db.delete(_db.ocrAnalysisQueueTable)
          ..where((t) => t.memeId.equals(memeId)))
        .go();
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.ocrAnalysisQueueTable).go();
  }
}
