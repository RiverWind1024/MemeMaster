import 'dart:async';
import 'dart:io';

import '../core/database/daos/analysis_queue_dao.dart';
import '../core/database/database.dart';
import '../core/image/color_extraction_config.dart';
import '../core/image/color_extractor.dart';
import '../core/llm/enricher.dart';
import '../core/llm/vision_enricher.dart';
import '../core/ocr/ocr_service.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';
import 'log_service.dart';

class AnalysisQueueScheduler {
  static const int maxConcurrent = 2;
  static const Duration pollInterval = Duration(seconds: 3);

  final AnalysisQueueDao _queueDao;
  final MemeRepository _memeRepo;
  final ColorExtractor _colorExtractor;
  final FileStorageService _storage;
  final LogService _log;
  final Set<String> _runningJobs = {};
  Timer? _timer;
  bool _isRunning = false;
  bool _ocrEnabled = false;
  bool _llmEnabled = false;
  LlmEnricher? _llmEnricher;
  VisionLlmEnricher? _visionEnricher;
  ColorExtractionConfig _colorConfig = const ColorExtractionConfig();

  AnalysisQueueScheduler({
    required this._queueDao,
    required this._memeRepo,
    required this._colorExtractor,
    required this._storage,
    LogService? log,
  }) : _log = log ?? LogService();

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(pollInterval, (_) => _processNextBatch());
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  bool get isRunning => _isRunning;
  int get runningJobCount => _runningJobs.length;

  void setOcrEnabled(bool enabled) {
    _ocrEnabled = enabled;
  }

  void setLlmEnricher(LlmEnricher enricher) {
    _llmEnricher = enricher;
  }

  void setVisionEnricher(VisionLlmEnricher enricher) {
    _visionEnricher = enricher;
  }

  void setLlmEnabled(bool enabled) {
    _llmEnabled = enabled;
  }

  void setColorExtractionConfig(ColorExtractionConfig config) {
    _colorConfig = config;
  }

  Future<void> _processNextBatch() async {
    if (!_isRunning) return;

    while (_runningJobs.length < maxConcurrent) {
      final job = await _queueDao.getNextPending();
      if (job == null) break;

      _runningJobs.add(job.id);
      await _queueDao.markRunning(job.id);
      _processJob(job);
    }
  }

  Future<void> _processJob(AnalysisQueueItem job) async {
    _log.info('Scheduler', '开始处理 job=${job.id} memeId=${job.memeId}');
    try {
      final meme = await _memeRepo.getById(job.memeId);
      if (meme == null) {
        _log.error('Scheduler', 'Meme not found: ${job.memeId}');
        await _queueDao.markFailed(job.id, 'Meme not found');
        return;
      }

      await _memeRepo.updateAnalysisStatus(meme.id, 'processing');

      final imageFile = await _storage.getImage(meme.filePath);
      final imagePath = imageFile.absolute.path;
      _log.info('Scheduler', '图片路径: $imagePath');

      // ---- 步骤 1: 颜色提取 ----
      _log.info('Scheduler', '开始颜色提取: ${meme.id}');
      await _extractColors(job.memeId, imagePath);

      // ---- 步骤 2: OCR 识别 + LLM 富化 ----
      _log.info('Scheduler', '开始 OCR: ${meme.id}');
      final ocrText = await _runOcr(imagePath);
      if (ocrText != null) {
        _log.info('Scheduler', 'OCR 识别到 ${ocrText.length} 字: "${ocrText.substring(0, ocrText.length.clamp(0, 50))}"');
        await _saveOcrTags(job.memeId, ocrText);
        await _runLlmEnrichment(job.memeId, ocrText);
      } else {
        _log.info('Scheduler', 'OCR 未识别到文字 (_ocrEnabled=$_ocrEnabled)');
      }

      // ---- 步骤 3: 多模态视觉分析（独立于 OCR） ----
      await _runVisionLlm(job.memeId, imagePath);

      await _memeRepo.updateAnalysisStatus(meme.id, 'done');
      await _queueDao.markDone(job.id);
      _log.info('Scheduler', '分析完成: ${meme.id}');
    } catch (e) {
      _log.error('Scheduler', '分析失败: $e');
      await _queueDao.markFailed(job.id, e.toString());
    } finally {
      _runningJobs.remove(job.id);
    }
  }

  Future<void> _extractColors(String memeId, String imagePath) async {
    final dominantColors =
        await _colorExtractor.extract(imagePath, config: _colorConfig);
    if (dominantColors.isEmpty) return;

    final colorEntries = dominantColors.map((c) {
      return ColorEntry(
        id: '${memeId}_${c.hex.replaceFirst('#', '')}',
        memeId: memeId,
        hexColor: c.hex,
        labL: c.lChannel,
        labA: c.aChannel,
        labB: c.bChannel,
        ratio: c.ratio,
      );
    }).toList();
    await _memeRepo.saveColors(colorEntries);
  }

  Future<String?> _runOcr(String imagePath) async {
    if (!_ocrEnabled) {
      _log.info('OCR', 'OCR 未启用，跳过');
      return null;
    }

    final imgFile = File(imagePath);
    final imgLen = await imgFile.length();
    _log.info('OCR', '开始识别: $imagePath (${imgLen}bytes)');
    final ocr = OcrService();
    try {
      final result = await ocr.recognizeImage(imagePath);

      // 输出诊断信息（每个脚本的尝试结果）
      for (final d in result.diagnostics) {
        _log.info('OCR', d);
      }

      if (result.isEmpty) {
        _log.warning('OCR', '未识别到文字');
      } else {
        _log.info('OCR', '识别结果: ${result.text.length} 字');
      }
      return result.isEmpty ? null : result.text;
    } catch (e) {
      _log.error('OCR', '识别异常: $e');
      return null;
    } finally {
      ocr.close();
    }
  }

  Future<void> _saveOcrTags(String memeId, String ocrText) async {
    final tags = ocrText
        .split(RegExp(r'[\s,;:。，；：、\n]+'))
        .where((w) => w.trim().length >= 2)
        .map((w) => TagEntry(
              id: '${memeId}_ocr_${w.hashCode}',
              memeId: memeId,
              content: w.trim(),
              source: 'ocr',
              confidence: 1.0,
            ))
        .toList();
    if (tags.isNotEmpty) {
      await _memeRepo.saveTags(tags);
    }
  }

  Future<void> _runLlmEnrichment(String memeId, String ocrText) async {
    if (!_llmEnabled) return;
    final enricher = _llmEnricher;
    if (enricher == null) return;
    // TODO(Phase 2): 传入图片路径，让 LLM 多模态模型直接分析图像内容
    await enricher.enrich(memeId, ocrText);
  }

  Future<void> _runVisionLlm(String memeId, String imagePath) async {
    final enricher = _visionEnricher;
    if (enricher == null) {
      _log.info('VisionLLM', '未设置 VisionEnricher，跳过');
      return;
    }
    await enricher.enrich(memeId, imagePath);
  }
}
