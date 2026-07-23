import 'package:uuid/uuid.dart';

import '../database/daos/meme_dao.dart';
import '../database/daos/tag_dao.dart';
import '../database/daos/color_dao.dart';
import '../database/daos/analysis_queue_dao.dart';
import '../database/daos/color_analysis_queue_dao.dart';
import '../database/daos/ocr_analysis_queue_dao.dart';
import '../database/daos/ai_analysis_queue_dao.dart';
import '../database/daos/album_dao.dart';
import '../database/database.dart';
import '../../services/file_storage_service.dart';

/// Meme 聚合仓库，组合 DAO 操作并提供业务逻辑
class MemeRepository {
  final MemeDao _memeDao;
  final TagDao _tagDao;
  final ColorDao _colorDao;
  final AnalysisQueueDao _queueDao;
  final ColorAnalysisQueueDao _colorQueueDao;
  final OcrAnalysisQueueDao _ocrQueueDao;
  final AiAnalysisQueueDao _aiQueueDao;
  final AlbumDao _albumDao;
  final Uuid _uuid = const Uuid();

  MemeRepository({
    required this._memeDao,
    required this._tagDao,
    required this._colorDao,
    required this._queueDao,
    ColorAnalysisQueueDao? colorQueueDao,
    OcrAnalysisQueueDao? ocrQueueDao,
    AiAnalysisQueueDao? aiQueueDao,
    AlbumDao? albumDao,
  })  : _colorQueueDao = colorQueueDao ?? ColorAnalysisQueueDao(_memeDao.database),
        _ocrQueueDao = ocrQueueDao ?? OcrAnalysisQueueDao(_memeDao.database),
        _aiQueueDao = aiQueueDao ?? AiAnalysisQueueDao(_memeDao.database),
        _albumDao = albumDao ?? AlbumDao(_memeDao.database);

  Future<Meme?> getById(String id) => _memeDao.getById(id);

  Future<List<Meme>> getAll({int? limit, int? offset}) =>
      _memeDao.getAll(limit: limit, offset: offset);

  Future<List<Meme>> getAnalyzed({int? limit, int? offset}) =>
      _memeDao.getAnalyzed(limit: limit, offset: offset);

  Future<Meme?> getByFileHash(String hash) => _memeDao.getByFileHash(hash);

  Future<List<Meme>> searchByFilename(String keyword) =>
      _memeDao.searchByFilename(keyword);

  Future<List<Meme>> searchByKeyword(String keyword) =>
      _memeDao.searchByKeyword(keyword);

  Future<List<Meme>> searchByTagContent(String keyword) =>
      _memeDao.searchByTagContent(keyword);

  /// 创建新 meme（自动生成 ID 和时间戳）
  Future<Meme> create({
    required String filename,
    required String filePath,
    required int fileSize,
    required String mimeType,
    required int width,
    required int height,
    required String fileHash,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final meme = Meme(
      id: _uuid.v4(),
      filename: filename,
      filePath: filePath,
      fileSize: fileSize,
      mimeType: mimeType,
      width: width,
      height: height,
      analysisStatus: 'pending',
      colorAnalysisStatus: 'pending',
      ocrAnalysisStatus: 'pending',
      aiAnalysisStatus: 'pending',
      fileHash: fileHash,
      copyCount: 0,
      createdAt: now,
      updatedAt: now,
      importedAt: now,
    );
    await _memeDao.insert(meme);
    return meme;
  }

  /// 删除 meme 及其关联数据（颜色/标签/队列/文件）
  ///
  /// 使用软删除（设置 deletedAt）以支持 S3 增量同步传播删除到其他设备。
  /// [deleteFile] 是否同时删除物理文件（默认 true）
  Future<void> delete(String id, {bool deleteFile = true}) async {
    final meme = await _memeDao.getById(id);

    await _queueDao.deleteByMemeId(id);
    await _colorDao.deleteByMemeId(id);
    await _tagDao.deleteByMemeId(id);
    // 清理并行分析队列，避免外键约束异常
    await _colorQueueDao.deleteByMemeId(id);
    await _ocrQueueDao.deleteByMemeId(id);
    await _aiQueueDao.deleteByMemeId(id);
    // 清理相册关联，避免外键约束异常
    await _albumDao.removeMemeFromAllAlbums(id);
    // 软删除（墓碑），同步时会传播到 S3
    await _memeDao.softDelete(id);

    if (deleteFile && meme != null && meme.filePath.isNotEmpty) {
      try {
        final storage = FileStorageService();
        await storage.deleteImage(meme.filePath);
      } catch (_) {
        // 文件已不存在或无法删除，不影响逻辑删除
      }
    }
  }

  /// 更新分析状态，若完成则清理队列
  Future<void> updateAnalysisStatus(String id, String status) async {
    await _memeDao.updateAnalysisStatus(id, status);
    if (status == 'done' || status == 'failed') {
      // 不在此处清理队列，留给队列管理器处理
    }
  }

  Future<void> updateDescription(String id, String description) =>
      _memeDao.updateDescription(id, description);

  Future<int> count() => _memeDao.countAll();
  Future<int> countByStatus(String status) => _memeDao.countByStatus(status);
  Future<bool> hasChangesSince(int timestamp) =>
      _memeDao.hasChangesSince(timestamp);
  Future<List<Meme>> getUpdatedSince(int timestamp) =>
      _memeDao.getUpdatedSince(timestamp);
  Future<int> softDeleteWithTimestamp(String id, int deletedAt) =>
      _memeDao.softDeleteWithTimestamp(id, deletedAt);

  // ---- 排序 ----

  Future<List<Meme>> getAllSorted({
    required String sortField,
    bool ascending = false,
    int? limit,
    int? offset,
  }) =>
      _memeDao.getAllSorted(
          sortField: sortField,
          ascending: ascending,
          limit: limit,
          offset: offset);

  // ---- 复制次数 ----

  Future<void> incrementCopyCount(String id) =>
      _memeDao.incrementCopyCount(id);

  Future<void> setCopyCount(String id, int count) =>
      _memeDao.setCopyCount(id, count);

  // ---- 图片来源 ----

  Future<void> updateSource(String id, String source) =>
      _memeDao.updateSource(id, source);

  /// 对指定 meme 重新索引缺失的分析维度
  ///
  /// 检查 colorAnalysisStatus / ocrAnalysisStatus / aiAnalysisStatus，
  /// 仅对不是 'done' 的维度入队分析。返回实际入队的数量。
  Future<int> reindexMeme(String memeId) async {
    final meme = await _memeDao.getById(memeId);
    if (meme == null) return 0;

    int enqueued = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final uuid = _uuid.v4();

    if (meme.colorAnalysisStatus != 'done') {
      await _colorQueueDao.insert(ColorAnalysisQueueItem(
        id: '${uuid}_color',
        memeId: memeId,
        status: 'pending',
        priority: 0,
        retryCount: 0,
        createdAt: now,
      ));
      enqueued++;
    }

    if (meme.ocrAnalysisStatus != 'done') {
      await _ocrQueueDao.insert(OcrAnalysisQueueItem(
        id: '${uuid}_ocr',
        memeId: memeId,
        status: 'pending',
        priority: 0,
        retryCount: 0,
        createdAt: now,
      ));
      enqueued++;
    }

    if (meme.aiAnalysisStatus != 'done') {
      await _aiQueueDao.insert(AiAnalysisQueueItem(
        id: '${uuid}_ai',
        memeId: memeId,
        status: 'pending',
        priority: 0,
        retryCount: 0,
        createdAt: now,
      ));
      enqueued++;
    }

    if (enqueued > 0) {
      await _memeDao.updateAnalysisStatus(memeId, 'pending');
    }

    return enqueued;
  }

  /// 批量重新索引所有 meme
  ///
  /// 遍历所有 meme，对每个 meme 缺失的分析维度入队。
  /// [onProgress] 回调参数为 (已处理数, 已入队数)。
  Future<Map<String, int>> reindexAll({
    void Function(int processed, int enqueued)? onProgress,
  }) async {
    int total = 0, enqueued = 0, failed = 0;

    const batchSize = 50;
    int offset = 0;
    List<Meme> batch;

    do {
      batch = await _memeDao.getAll(limit: batchSize, offset: offset);
      for (final meme in batch) {
        try {
          final n = await reindexMeme(meme.id);
          enqueued += n;
          total++;
          onProgress?.call(total, enqueued);
        } catch (e) {
          failed++;
        }
      }
      offset += batchSize;
    } while (batch.length == batchSize);

    return {'total': total, 'enqueued': enqueued, 'failed': failed};
  }

  // ---- 并行分析队列状态 ----

  Future<void> updateColorAnalysisStatus(String id, String status) async {
    await _memeDao.updateColorAnalysisStatus(id, status);
  }

  Future<void> updateOcrAnalysisStatus(String id, String status) async {
    await _memeDao.updateOcrAnalysisStatus(id, status);
  }

  Future<void> updateAiAnalysisStatus(String id, String status) async {
    await _memeDao.updateAiAnalysisStatus(id, status);
  }

  /// 检查图片是否所有分析都已完成
  Future<bool> isAnalysisComplete(String id) async {
    final meme = await _memeDao.getById(id);
    if (meme == null) return false;
    return meme.colorAnalysisStatus == 'done' &&
        meme.ocrAnalysisStatus == 'done' &&
        meme.aiAnalysisStatus == 'done';
  }

  // ---- 关联数据 ----

  Future<List<TagEntry>> getTags(String memeId) => _tagDao.getByMemeId(memeId);
  Future<void> saveTags(List<TagEntry> tags) => _tagDao.insertAll(tags);
  Future<void> deleteTags(String memeId) => _tagDao.deleteByMemeId(memeId);
  /// 仅删除自动生成的标签（ocr/llm），保留用户自定义的
  /// [sources] 指定要删除的来源列表，默认删除 ocr 和 llm
  Future<void> deleteAutoTags(String memeId, {List<String>? sources}) =>
      _tagDao.deleteBySourcesForMeme(memeId, sources ?? ['ocr', 'llm']);
  Future<int> countTagsBySource(String source) => _tagDao.countBySource(source);

  Future<List<ColorEntry>> getColors(String memeId) =>
      _colorDao.getByMemeId(memeId);
  Future<void> saveColors(List<ColorEntry> colors) => _colorDao.insertAll(colors);
  Future<void> deleteColors(String memeId) => _colorDao.deleteByMemeId(memeId);

  // ---- 分析队列 ----

  Future<void> enqueueAnalysis(String memeId, {int priority = 0}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uuid = _uuid.v4();

    // 添加到颜色提取队列
    await _colorQueueDao.insert(ColorAnalysisQueueItem(
      id: '${uuid}_color',
      memeId: memeId,
      status: 'pending',
      priority: priority,
      retryCount: 0,
      createdAt: now,
    ));

    // 添加到 OCR 队列
    await _ocrQueueDao.insert(OcrAnalysisQueueItem(
      id: '${uuid}_ocr',
      memeId: memeId,
      status: 'pending',
      priority: priority,
      retryCount: 0,
      createdAt: now,
    ));

    // 添加到 AI 分析队列
    await _aiQueueDao.insert(AiAnalysisQueueItem(
      id: '${uuid}_ai',
      memeId: memeId,
      status: 'pending',
      priority: priority,
      retryCount: 0,
      createdAt: now,
    ));
  }

  Future<AnalysisQueueItem?> getNextPending() => _queueDao.getNextPending();
  Future<List<AnalysisQueueItem>> getRunning() => _queueDao.getRunning();
  Future<void> markQueueRunning(String id) => _queueDao.markRunning(id);
  Future<void> markQueueDone(String id) => _queueDao.markDone(id);
  Future<void> markQueueFailed(String id, String error) =>
      _queueDao.markFailed(id, error);
  Future<int> countQueued() => _queueDao.countQueued();
}
