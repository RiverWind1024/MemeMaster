import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';

void main() {
  late AppDatabase db;
  late Directory dir2;

  setUp(() async {
    dir2 = await Directory.systemTemp.createTemp('repo_reindex_');
    db = AppDatabase.open('${dir2.path}/t.db');
  });

  tearDown(() async {
    await db.close();
    await dir2.delete(recursive: true);
  });

  Future<Meme> seedMeme({
    String colorStatus = 'done',
    String ocrStatus = 'done',
    String aiStatus = 'done',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'm_${now}_${colorStatus}_${ocrStatus}_${aiStatus}';
    final meme = Meme(
      id: id,
      filename: '$id.jpg',
      filePath: '$id.jpg',
      fileSize: 1,
      mimeType: 'image/jpeg',
      width: 1,
      height: 1,
      analysisStatus: 'done',
      colorAnalysisStatus: colorStatus,
      ocrAnalysisStatus: ocrStatus,
      aiAnalysisStatus: aiStatus,
      fileHash: 'h_$id',
      copyCount: 0,
      createdAt: now,
      updatedAt: now,
      importedAt: now,
    );
    await db.memeDao.insert(meme);
    return meme;
  }

  Future<int> queueLength(String tableSuffix, String memeId) async {
    final r = await db.customSelect(
      'SELECT COUNT(*) AS n FROM ${tableSuffix}_analysis_queue_table WHERE meme_id = ?',
      variables: [Variable<String>(memeId)],
    ).getSingle();
    return r.read<int>('n');
  }

  test('reindexMeme 强制重跑颜色和 OCR，AI 只在未完成时入队', () async {
    final repo = MemeRepository(
      memeDao: db.memeDao,
      tagDao: db.tagDao,
      colorDao: db.colorDao,
      queueDao: db.analysisQueueDao,
    );
    // 三维度均已完成。reindex 后：color/ocr 应强制入队，ai 不入队。
    final m = await seedMeme();

    final enqueued = await repo.reindexMeme(m.id);
    expect(enqueued, 2);

    expect(await queueLength('color', m.id), 1);
    expect(await queueLength('ocr', m.id), 1);
    expect(await queueLength('ai', m.id), 0);

    final after = await db.memeDao.getById(m.id);
    expect(after!.colorAnalysisStatus, 'pending');
    expect(after.ocrAnalysisStatus, 'pending');
    expect(after.aiAnalysisStatus, 'done');
    expect(after.analysisStatus, 'pending');
  });

  test('reindexMeme 强制重跑时会清掉该 meme 旧的 color/ocr 任务', () async {
    final repo = MemeRepository(
      memeDao: db.memeDao,
      tagDao: db.tagDao,
      colorDao: db.colorDao,
      queueDao: db.analysisQueueDao,
    );
    final m = await seedMeme(colorStatus: 'pending', ocrStatus: 'pending');
    // 第一次：补漏模式应入队 color 和 ocr。
    var enq = await repo.reindexMeme(m.id);
    expect(enq, 2);
    expect(await queueLength('color', m.id), 1);
    expect(await queueLength('ocr', m.id), 1);

    // 模拟 color 已 done，ocr 已 done；状态字段已为 done。
    await db.memeDao.updateColorAnalysisStatus(m.id, 'done');
    await db.memeDao.updateOcrAnalysisStatus(m.id, 'done');
    await db.memeDao.updateAnalysisStatus(m.id, 'done');

    // 第二次：颜色 OCR 仍各 1 条（因为旧任务被 deleteByMemeId 清掉），
    // 而不是 2 条。
    enq = await repo.reindexMeme(m.id);
    expect(enq, 2);
    expect(await queueLength('color', m.id), 1);
    expect(await queueLength('ocr', m.id), 1);
  });

  test('reindexMeme 当 AI 也未完成时三维度都入队', () async {
    final repo = MemeRepository(
      memeDao: db.memeDao,
      tagDao: db.tagDao,
      colorDao: db.colorDao,
      queueDao: db.analysisQueueDao,
    );
    final m = await seedMeme(
      colorStatus: 'pending',
      ocrStatus: 'pending',
      aiStatus: 'pending',
    );

    final enq = await repo.reindexMeme(m.id);
    expect(enq, 3);
    expect(await queueLength('color', m.id), 1);
    expect(await queueLength('ocr', m.id), 1);
    expect(await queueLength('ai', m.id), 1);
  });

  test('reindexAll 强制 color/ocr，仅补漏 ai', () async {
    final repo = MemeRepository(
      memeDao: db.memeDao,
      tagDao: db.tagDao,
      colorDao: db.colorDao,
      queueDao: db.analysisQueueDao,
    );
    final m1 = await seedMeme(); // 全 done
    final m2 = await seedMeme(aiStatus: 'pending'); // ai 未完成

    final result = await repo.reindexAll();
    // m1：入队 2（color+ocr，不动 ai）；m2：入队 3（color+ocr+ai）。
    expect(result['total'], 2);
    expect(result['enqueued'], 5);
  });
}