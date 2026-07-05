import 'package:drift/drift.dart';

import '../../database/database.dart';

/// Meme 表基础 CRUD 操作
class MemeDao {
  final AppDatabase _db;
  MemeDao(this._db);

  /// 获取数据库实例
  AppDatabase get database => _db;

  /// 插入新 meme
  Future<void> insert(Meme meme) async {
    await _db.into(_db.memesTable).insertOnConflictUpdate(meme);
  }

  /// 批量插入
  Future<void> insertAll(List<Meme> memes) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.memesTable, memes);
    });
  }

  /// 根据 ID 查询
  Future<Meme?> getById(String id) async {
    return await (_db.select(_db.memesTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 获取所有 meme, 按导入时间降序
  Future<List<Meme>> getAll({int? limit, int? offset}) {
    final query = _db.select(_db.memesTable)
      ..orderBy([(t) => OrderingTerm.desc(t.importedAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset);
    }
    return query.get();
  }

  /// 获取分析状态为 done 的 meme
  Future<List<Meme>> getAnalyzed({int? limit, int? offset}) {
    final query = _db.select(_db.memesTable)
      ..where((t) => t.analysisStatus.equals('done'))
      ..orderBy([(t) => OrderingTerm.desc(t.importedAt)]);
    if (limit != null) {
      query.limit(limit, offset: offset);
    }
    return query.get();
  }

  /// 获取文件夹下的 meme
  Future<List<Meme>> getByFolderId(String folderId) {
    return (_db.select(_db.memesTable)
          ..where((t) => t.folderId.equals(folderId))
          ..orderBy([(t) => OrderingTerm.desc(t.importedAt)]))
        .get();
  }

  /// 按文件哈希去重
  Future<Meme?> getByFileHash(String hash) {
    return (_db.select(_db.memesTable)
          ..where((t) => t.fileHash.equals(hash)))
        .getSingleOrNull();
  }

  /// 通过标签内容模糊搜索 meme（JOIN tags 表）
  Future<List<Meme>> searchByTagContent(String keyword) async {
    final pattern = '%$keyword%';
    final rows = await (_db.customSelect(
      'SELECT DISTINCT m.id, m.filename, m.file_path, '
      'm.file_size, m.mime_type, m.width, m.height, '
      'm.folder_id, m.analysis_status, m.file_hash, '
      'm.description, m.created_at, m.updated_at, m.imported_at, '
      'm.copy_count, m.source '
      'FROM memes_table AS m '
      'INNER JOIN tags_table AS t ON t.meme_id = m.id '
      'WHERE t.content LIKE ? '
      'ORDER BY m.imported_at DESC',
      variables: [Variable.withString(pattern)],
    )).get();
    final result = <Meme>[];
    for (final row in rows) {
      final d = row.data;
      result.add(Meme(
        id: d['id'] as String,
        filename: d['filename'] as String,
        filePath: d['file_path'] as String,
        fileSize: d['file_size'] as int,
        mimeType: d['mime_type'] as String,
        width: d['width'] as int,
        height: d['height'] as int,
        folderId: d['folder_id'] as String?,
        analysisStatus: d['analysis_status'] as String,
        colorAnalysisStatus: d['color_analysis_status'] as String? ?? 'pending',
        ocrAnalysisStatus: d['ocr_analysis_status'] as String? ?? 'pending',
        aiAnalysisStatus: d['ai_analysis_status'] as String? ?? 'pending',
        fileHash: d['file_hash'] as String,
        description: d['description'] as String?,
        createdAt: d['created_at'] as int,
        updatedAt: d['updated_at'] as int,
        importedAt: d['imported_at'] as int,
        copyCount: d['copy_count'] as int? ?? 0,
        source: d['source'] as String?,
      ));
    }
    return result;
  }

  /// 模糊搜索文件名
  Future<List<Meme>> searchByFilename(String keyword) {
    return (_db.select(_db.memesTable)
          ..where(
            (t) => t.filename.like('%$keyword%'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.importedAt)]))
        .get();
  }

  /// 关键词搜索（含文件名和描述）
  Future<List<Meme>> searchByKeyword(String keyword) {
    final pattern = '%$keyword%';
    return (_db.select(_db.memesTable)
          ..where((t) =>
              t.filename.like(pattern) | t.description.like(pattern))
          ..orderBy([(t) => OrderingTerm.desc(t.importedAt)]))
        .get();
  }

  /// 更新分析状态
  Future<int> updateAnalysisStatus(String id, String status) {
    return (_db.update(_db.memesTable)
          ..where((t) => t.id.equals(id)))
        .write(MemesTableCompanion(
          analysisStatus: Value(status),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 更新颜色提取分析状态
  Future<int> updateColorAnalysisStatus(String id, String status) {
    return (_db.update(_db.memesTable)
          ..where((t) => t.id.equals(id)))
        .write(MemesTableCompanion(
          colorAnalysisStatus: Value(status),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 更新 OCR 分析状态
  Future<int> updateOcrAnalysisStatus(String id, String status) {
    return (_db.update(_db.memesTable)
          ..where((t) => t.id.equals(id)))
        .write(MemesTableCompanion(
          ocrAnalysisStatus: Value(status),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 更新 AI 分析状态
  Future<int> updateAiAnalysisStatus(String id, String status) {
    return (_db.update(_db.memesTable)
          ..where((t) => t.id.equals(id)))
        .write(MemesTableCompanion(
          aiAnalysisStatus: Value(status),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 更新 meme 文件夹
  Future<int> updateFolder(String id, String? folderId) {
    return (_db.update(_db.memesTable)
          ..where((t) => t.id.equals(id)))
        .write(MemesTableCompanion(folderId: Value(folderId), updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// 更新描述（由 LLM 生成）
  Future<int> updateDescription(String id, String description) {
    return (_db.update(_db.memesTable)
          ..where((t) => t.id.equals(id)))
        .write(MemesTableCompanion(
          description: Value(description),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 删除
  Future<int> delete(String id) async {
    return await (_db.delete(_db.memesTable)..where((t) => t.id.equals(id))).go();
  }

  /// 统计总数
  Future<int> countAll() async {
    final result =
        await _db.customSelect('SELECT COUNT(*) FROM memes_table').getSingle();
    return result.data.values.first as int;
  }

  /// 按指定字段排序获取所有 meme
  Future<List<Meme>> getAllSorted({
    required String sortField,
    bool ascending = false,
    int? limit,
    int? offset,
  }) async {
    final allowedFields = {'imported_at', 'file_size', 'created_at', 'copy_count'};
    final field = allowedFields.contains(sortField) ? sortField : 'imported_at';
    final direction = ascending ? 'ASC' : 'DESC';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';
    final rows = await _db.customSelect(
      'SELECT * FROM memes_table ORDER BY $field $direction $limitClause $offsetClause',
    ).get();
    return rows.map((row) {
      final d = row.data;
      return Meme(
        id: d['id'] as String,
        filename: d['filename'] as String,
        filePath: d['file_path'] as String,
        fileSize: d['file_size'] as int,
        mimeType: d['mime_type'] as String,
        width: d['width'] as int,
        height: d['height'] as int,
        folderId: d['folder_id'] as String?,
        analysisStatus: d['analysis_status'] as String,
        colorAnalysisStatus: d['color_analysis_status'] as String? ?? 'pending',
        ocrAnalysisStatus: d['ocr_analysis_status'] as String? ?? 'pending',
        aiAnalysisStatus: d['ai_analysis_status'] as String? ?? 'pending',
        fileHash: d['file_hash'] as String,
        description: d['description'] as String?,
        createdAt: d['created_at'] as int,
        updatedAt: d['updated_at'] as int,
        importedAt: d['imported_at'] as int,
        copyCount: d['copy_count'] as int? ?? 0,
        source: d['source'] as String?,
      );
    }).toList();
  }

  /// 更新复制次数（原子递增）
  Future<int> incrementCopyCount(String id) async {
    return await _db.customUpdate(
      'UPDATE memes_table SET copy_count = copy_count + 1, updated_at = ? WHERE id = ?',
      variables: [
        Variable(DateTime.now().millisecondsSinceEpoch),
        Variable(id),
      ],
    );
  }

  /// 直接设置复制次数
  Future<int> setCopyCount(String id, int count) async {
    return await (_db.update(_db.memesTable)
          ..where((t) => t.id.equals(id)))
        .write(MemesTableCompanion(
          copyCount: Value(count),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 更新图片来源
  Future<int> updateSource(String id, String source) async {
    return await (_db.update(_db.memesTable)
          ..where((t) => t.id.equals(id)))
        .write(MemesTableCompanion(
          source: Value(source),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 统计分析状态数量
  Future<int> countByStatus(String status) async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) FROM memes_table WHERE analysis_status = ?',
      variables: [Variable.withString(status)],
    ).getSingle();
    return result.data.values.first as int;
  }

  /// 检查是否存在指定时间戳之后更新的 meme
  Future<bool> hasChangesSince(int timestamp) async {
    final count = await _db.customSelect(
      'SELECT COUNT(*) as c FROM memes_table WHERE updated_at > ?',
      variables: [Variable.withInt(timestamp)],
    ).getSingle();
    return (count.data['c'] as int) > 0;
  }

  /// 获取指定时间戳之后更新的 meme
  Future<List<Meme>> getUpdatedSince(int timestamp) async {
    return (_db.select(_db.memesTable)
          ..where((t) => t.updatedAt.isBiggerThanValue(timestamp))
          ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]))
        .get();
  }
}
