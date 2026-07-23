import 'dart:async';
import 'dart:math';
import 'dart:ui';

import '../core/database/daos/ai_analysis_queue_dao.dart';
import '../core/database/daos/analysis_queue_dao.dart';
import '../core/database/daos/color_analysis_queue_dao.dart';
import '../core/database/daos/ocr_analysis_queue_dao.dart';
import '../core/database/database.dart';
import '../core/image/color_extraction_config.dart';
import '../core/image/color_extractor.dart';
import '../core/llm/vision_enricher.dart';
import '../core/llm/local_service.dart';
import '../core/ocr/ocr_service.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';
import 'log_service.dart';

/// 并行分析调度器
/// 
/// 将颜色提取、OCR、AI分析拆分为三个独立的队列，并行处理
class ParallelAnalysisScheduler {
  // 各队列的并发数和轮询间隔
  static const int _colorMaxConcurrent = 5;
  static const int _ocrMaxConcurrent = 5;
  static const int _aiMaxConcurrent = 1;

  static const Duration _colorPollInterval = Duration(seconds: 1);
  static const Duration _ocrPollInterval = Duration(seconds: 1);
  static const Duration _aiPollInterval = Duration(seconds: 5);

  final ColorAnalysisQueueDao _colorQueueDao;
  final OcrAnalysisQueueDao _ocrQueueDao;
  final AiAnalysisQueueDao _aiQueueDao;
  final AnalysisQueueDao _analysisQueueDao; // 旧统一队列表
  final MemeRepository _memeRepo;
  final ColorExtractor _colorExtractor;
  final FileStorageService _storage;
  final LogService _log;

  Timer? _colorTimer;
  Timer? _ocrTimer;
  Timer? _aiTimer;

  bool _isRunning = false;
  bool _ocrEnabled = false;
  VisionLlmEnricher? _visionEnricher;
  ColorExtractionConfig _colorConfig = const ColorExtractionConfig();
  Locale? _appLocale;

  // 正在运行的任务
  final Set<String> _colorRunningJobs = {};
  final Set<String> _ocrRunningJobs = {};
  final Set<String> _aiRunningJobs = {};

  ParallelAnalysisScheduler({
    required ColorAnalysisQueueDao colorQueueDao,
    required OcrAnalysisQueueDao ocrQueueDao,
    required AiAnalysisQueueDao aiQueueDao,
    required AnalysisQueueDao analysisQueueDao,
    required MemeRepository memeRepo,
    required ColorExtractor colorExtractor,
    required FileStorageService storage,
    LogService? log,
  })  : _colorQueueDao = colorQueueDao,
        _ocrQueueDao = ocrQueueDao,
        _aiQueueDao = aiQueueDao,
        _analysisQueueDao = analysisQueueDao,
        _memeRepo = memeRepo,
        _colorExtractor = colorExtractor,
        _storage = storage,
        _log = log ?? LogService.instance;

  /// 启动所有调度器
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // 清理闪退遗留的 running 任务
    _cleanupStuckJobs();

    // 启动三个独立的调度器
    _colorTimer = Timer.periodic(_colorPollInterval, (_) => _processColorQueue());
    _ocrTimer = Timer.periodic(_ocrPollInterval, (_) => _processOcrQueue());
    _aiTimer = Timer.periodic(_aiPollInterval, (_) => _processAiQueue());

    _log.info('ParallelScheduler', '并行分析调度器已启动');
  }

  /// 停止所有调度器
  void stop() {
    _isRunning = false;
    _colorTimer?.cancel();
    _ocrTimer?.cancel();
    _aiTimer?.cancel();
    _colorTimer = null;
    _ocrTimer = null;
    _aiTimer = null;
    _log.info('ParallelScheduler', '并行分析调度器已停止');
  }

  bool get isRunning => _isRunning;

  void setOcrEnabled(bool enabled) {
    _ocrEnabled = enabled;
  }

  void setVisionLlmEnricher(VisionLlmEnricher enricher) {
    _visionEnricher = enricher;
  }

  void setColorExtractionConfig(ColorExtractionConfig config) {
    _colorConfig = config;
  }

  void setAppLocale(Locale? locale) {
    _appLocale = locale;
  }

  /// 将图片添加到分析队列
  Future<void> enqueueAnalysis(String memeId, {int priority = 0}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uuid = _generateUuid();

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

    _log.info('ParallelScheduler', '已添加分析任务: memeId=$memeId');
  }

  // ==================== 颜色提取队列处理 ====================

  Future<void> _processColorQueue() async {
    if (!_isRunning) return;

    while (_colorRunningJobs.length < _colorMaxConcurrent) {
      final job = await _colorQueueDao.getNextPending();
      if (job == null) break;

      _colorRunningJobs.add(job.id);
      _processColorJob(job);
    }
  }

  Future<void> _processColorJob(ColorAnalysisQueueItem job) async {
    _log.info('ColorScheduler', '开始颜色提取: memeId=${job.memeId}');
    try {
      await _colorQueueDao.markRunning(job.id);
      await _memeRepo.updateColorAnalysisStatus(job.memeId, 'running');

      final meme = await _memeRepo.getById(job.memeId);
      if (meme == null) {
        throw Exception('Meme not found: ${job.memeId}');
      }

      final imageFile = await _storage.getImage(meme.filePath);
      final dominantColors = await _colorExtractor.extract(
        imageFile.absolute.path,
        config: _colorConfig,
      );

      if (dominantColors.isNotEmpty) {
        final colorEntries = dominantColors.map((c) {
          return ColorEntry(
            id: '${meme.id}_${c.hex.replaceFirst('#', '')}',
            memeId: meme.id,
            hexColor: c.hex,
            labL: c.lChannel,
            labA: c.aChannel,
            labB: c.bChannel,
            ratio: c.ratio,
          );
        }).toList();
        await _memeRepo.saveColors(colorEntries);
      }

      await _colorQueueDao.markDone(job.id);
      await _memeRepo.updateColorAnalysisStatus(job.memeId, 'done');
      _log.info('ColorScheduler', '颜色提取完成: ${job.memeId}');
    } catch (e) {
      _log.error('ColorScheduler', '颜色提取失败: $e');
      await _colorQueueDao.markFailed(job.id, e.toString());
      await _memeRepo.updateColorAnalysisStatus(job.memeId, 'failed');
    } finally {
      _colorRunningJobs.remove(job.id);
      _checkOverallStatus(job.memeId);
    }
  }

  // ==================== OCR 队列处理 ====================

  Future<void> _processOcrQueue() async {
    if (!_isRunning) return;

    while (_ocrRunningJobs.length < _ocrMaxConcurrent) {
      final job = await _ocrQueueDao.getNextPending();
      if (job == null) break;

      _ocrRunningJobs.add(job.id);
      _processOcrJob(job);
    }
  }

  Future<void> _processOcrJob(OcrAnalysisQueueItem job) async {
    _log.info('OcrScheduler', '开始 OCR: memeId=${job.memeId}');
    try {
      await _ocrQueueDao.markRunning(job.id);
      await _memeRepo.updateOcrAnalysisStatus(job.memeId, 'running');

      if (!_ocrEnabled) {
        _log.info('OcrScheduler', 'OCR 未启用，跳过');
        await _ocrQueueDao.markDone(job.id);
        await _memeRepo.updateOcrAnalysisStatus(job.memeId, 'done');
        return;
      }

      final meme = await _memeRepo.getById(job.memeId);
      if (meme == null) {
        throw Exception('Meme not found: ${job.memeId}');
      }

      _log.info('OcrScheduler', '图片路径: ${meme.filePath}');
      final imageFile = await _storage.getImage(meme.filePath);
      _log.info('OcrScheduler', '图片文件: ${imageFile.absolute.path}, 存在: ${imageFile.existsSync()}');
      
      final ocr = OcrService();
      try {
        _log.info('OcrScheduler', '开始 OCR 识别...');
        final result = await ocr.recognizeImage(imageFile.absolute.path);
        _log.info('OcrScheduler', 'OCR 结果: 文字长度=${result.text.length}, 空=${result.isEmpty}');
        _log.info('OcrScheduler', 'OCR 文本: ${result.text}');
        _log.info('OcrScheduler', 'OCR 诊断: ${result.diagnostics}');

        if (!result.isEmpty) {
          // OCR 文本预处理：
          // 1. 合并被空格分开的中文字符（Tesseract 中文输出的常见 artifact）
          // 2. 按换行和标点分割成行/句
          var text = result.text;
          // 合并单个空格分隔的中文字符：`那 老 子` → `那老子`
          text = text.replaceAllMapped(
            RegExp(r'([\u4e00-\u9fff])\s+([\u4e00-\u9fff])'),
            (m) => '${m[1]}${m[2]}',
          );
          // 多次执行以处理连续多个空格分隔的中文
          var prev = '';
          while (prev != text) {
            prev = text;
            text = text.replaceAllMapped(
              RegExp(r'([\u4e00-\u9fff])\s+([\u4e00-\u9fff])'),
              (m) => '${m[1]}${m[2]}',
            );
          }
          // 按换行和标点分割（保留中文文本完整）
          final lines = text.split(RegExp(r'[\n;：:，,。.、]+'))
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          
          final tags = <TagEntry>[];
          for (final line in lines) {
            // 过滤规则：
            // - 长度 >= 2
            // - 不能全是 ASCII 符号/数字（排除乱码如 L=, NG 等）
            // - 不能全是空格
            final trimmed = line.trim();
            if (trimmed.length < 2) continue;
            // 如果全是 ASCII 字符，必须包含至少一个字母或数字（排除纯符号）
            if (RegExp(r'^[\x00-\x7f]+$').hasMatch(trimmed) &&
                !RegExp(r'[a-zA-Z0-9]{2,}').hasMatch(trimmed)) {
              continue;
            }
            tags.add(TagEntry(
              id: '${meme.id}_ocr_${trimmed.hashCode}',
              memeId: meme.id,
              content: trimmed,
              source: 'ocr',
              confidence: 1.0,
            ));
          }

          _log.info('OcrScheduler', 'OCR 标签数量: ${tags.length}');
          if (tags.isNotEmpty) {
            await _memeRepo.saveTags(tags);
          }
        }

        await _ocrQueueDao.markDone(job.id);
        await _memeRepo.updateOcrAnalysisStatus(job.memeId, 'done');
        _log.info('OcrScheduler', 'OCR 完成: ${job.memeId}');
      } finally {
        ocr.close();
      }
    } catch (e) {
      _log.error('OcrScheduler', 'OCR 失败: $e');
      await _ocrQueueDao.markFailed(job.id, e.toString());
      await _memeRepo.updateOcrAnalysisStatus(job.memeId, 'failed');
    } finally {
      _ocrRunningJobs.remove(job.id);
      _checkOverallStatus(job.memeId);
    }
  }

  // ==================== AI 分析队列处理 ====================

  Future<void> _processAiQueue() async {
    if (!_isRunning) return;

    while (_aiRunningJobs.length < _aiMaxConcurrent) {
      final job = await _aiQueueDao.getNextPending();
      if (job == null) break;

      _aiRunningJobs.add(job.id);
      // 使用await确保异常能被捕获
      await _processAiJob(job);
    }
  }

  Future<void> _processAiJob(AiAnalysisQueueItem job) async {
    _log.info('AiScheduler', '开始 AI 分析: memeId=${job.memeId}');
    try {
      await _aiQueueDao.markRunning(job.id);
      await _memeRepo.updateAiAnalysisStatus(job.memeId, 'running');

      final enricher = _visionEnricher;
      if (enricher == null) {
        _log.info('AiScheduler', '未设置 VisionEnricher，跳过');
        await _aiQueueDao.markDone(job.id);
        await _memeRepo.updateAiAnalysisStatus(job.memeId, 'done');
        return;
      }

      // 检查是否是本地LLM且未加载
      final llm = enricher.llm;
      if (llm is LocalLlmService && !llm.isLoaded) {
        // 自动加载模型并继续（ensureLoaded 内部会检查 _handle != null 防重复加载）
        _log.info('AiScheduler', '本地LLM模型未加载，开始加载: memeId=${job.memeId}');
        await llm.ensureLoaded();
      }

      final meme = await _memeRepo.getById(job.memeId);
      if (meme == null) {
        throw Exception('Meme not found: ${job.memeId}');
      }

      final imageFile = await _storage.getImage(meme.filePath);
      await enricher.enrich(meme.id, imageFile.absolute.path, locale: _appLocale);

      await _aiQueueDao.markDone(job.id);
      await _memeRepo.updateAiAnalysisStatus(job.memeId, 'done');
      _log.info('AiScheduler', 'AI 分析完成: ${job.memeId}');
    } catch (e) {
      _log.error('AiScheduler', 'AI 分析失败: $e');
      await _aiQueueDao.markFailed(job.id, e.toString());
      await _memeRepo.updateAiAnalysisStatus(job.memeId, 'failed');
    } finally {
      _aiRunningJobs.remove(job.id);
      _checkOverallStatus(job.memeId);
    }
  }

  // ==================== 辅助方法 ====================

  /// 检查整体分析状态，如果所有模块都完成，更新整体状态
  Future<void> _checkOverallStatus(String memeId) async {
    final meme = await _memeRepo.getById(memeId);
    if (meme == null) return;

    // 检查各模块状态
    final colorDone = meme.colorAnalysisStatus == 'done' || meme.colorAnalysisStatus == 'failed';
    final ocrDone = meme.ocrAnalysisStatus == 'done' || meme.ocrAnalysisStatus == 'failed';
    final aiDone = meme.aiAnalysisStatus == 'done' || meme.aiAnalysisStatus == 'failed';

    if (colorDone && ocrDone && aiDone) {
      // 所有模块都已完成
      final hasFailed = meme.colorAnalysisStatus == 'failed' ||
          meme.ocrAnalysisStatus == 'failed' ||
          meme.aiAnalysisStatus == 'failed';

      if (hasFailed) {
        await _memeRepo.updateAnalysisStatus(memeId, 'failed');
      } else {
        await _memeRepo.updateAnalysisStatus(memeId, 'done');
      }
      _log.info('ParallelScheduler', '所有分析完成: memeId=$memeId');
    }
  }

  /// 清理闪退遗留的 running 任务
  Future<void> _cleanupStuckJobs() async {
    try {
      await _colorQueueDao.resetAllRunningToPending();
      await _ocrQueueDao.resetAllRunningToPending();
      await _aiQueueDao.resetAllRunningToPending();
      // 清空 AI 队列中所有遗留任务，防止启动时自动加载 LLM 模型
      // （颜色/OCR 队列保留，因为它们不需要加载 LLM 模型，执行速度快）
      await _aiQueueDao.deleteAll();
      // 清空旧版 unified analysis_queue_table 的残留数据
      // 迁移到并行队列后该表不再使用，旧数据会造成进度栏虚假显示
      await _analysisQueueDao.deleteAll();
      _log.info('ParallelScheduler', '卡住任务清理完成（AI 队列 + 旧表已清空）');
    } catch (e) {
      _log.error('ParallelScheduler', '清理卡住任务失败: $e');
    }
  }

  /// 获取各队列的进度
  Future<Map<String, int>> getProgress() async {
    return {
      'colorPending': await _colorQueueDao.getPendingCount(),
      'colorRunning': await _colorQueueDao.getRunningCount(),
      'ocrPending': await _ocrQueueDao.getPendingCount(),
      'ocrRunning': await _ocrQueueDao.getRunningCount(),
      'aiPending': await _aiQueueDao.getPendingCount(),
      'aiRunning': await _aiQueueDao.getRunningCount(),
    };
  }

  String _generateUuid() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}';
  }
}
