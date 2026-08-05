import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mememaster/services/log_service.dart';
import 'package:mememaster/services/parallel_analysis_scheduler.dart';
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('导入后自动入队三类分析任务', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    final result = await env.importService.importImages([path]);
    expect(result.success, 1);

    // 注意：必须先于启动调度器断言（调度器 start 会清空 AI 队列）
    expect(await env.db.colorAnalysisQueueDao.getPendingCount(), 1);
    expect(await env.db.ocrAnalysisQueueDao.getPendingCount(), 1);
    expect(await env.db.aiAnalysisQueueDao.getPendingCount(), 1);
  });

  testWidgets('启动调度器后颜色分析真实完成', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final scheduler = ParallelAnalysisScheduler(
      colorQueueDao: env.db.colorAnalysisQueueDao,
      ocrQueueDao: env.db.ocrAnalysisQueueDao,
      aiQueueDao: env.db.aiAnalysisQueueDao,
      analysisQueueDao: env.db.analysisQueueDao,
      memeRepo: env.memeRepo,
      colorExtractor: env.colorExtractor,
      storage: env.storage,
      log: LogService.instance,
    );
    scheduler.setOcrEnabled(false);
    scheduler.start();
    addTearDown(scheduler.stop);

    // 轮询等待颜色分析完成（颜色调度器 1s 轮询一次）
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    String? status;
    while (DateTime.now().isBefore(deadline)) {
      status = (await env.memeRepo.getById(meme.id))?.colorAnalysisStatus;
      if (status == 'done' || status == 'failed') break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    expect(status, 'done', reason: '颜色分析应在 15s 超时前完成');
    expect(await env.memeRepo.getColors(meme.id), isNotEmpty);
  });

  testWidgets('reindexMeme 补缺失的分析维度', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    // 清空入队任务并模拟颜色已完成，使 OCR/AI 缺失
    await env.db.colorAnalysisQueueDao.deleteByMemeId(meme.id);
    await env.db.ocrAnalysisQueueDao.deleteByMemeId(meme.id);
    await env.db.aiAnalysisQueueDao.deleteByMemeId(meme.id);
    await env.memeRepo.updateColorAnalysisStatus(meme.id, 'done');

    final enqueued = await env.memeRepo.reindexMeme(meme.id);
    expect(enqueued, 2);
    expect(await env.db.colorAnalysisQueueDao.getPendingCount(), 0);
    expect(await env.db.ocrAnalysisQueueDao.getPendingCount(), 1);
    expect(await env.db.aiAnalysisQueueDao.getPendingCount(), 1);
  });
}
