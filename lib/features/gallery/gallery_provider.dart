import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database.dart';
import '../../core/repositories/album_repository.dart';
import '../../core/repositories/color_repository.dart';
import '../../core/repositories/meme_repository.dart';
import '../../core/image/color_extraction_config.dart';
import '../../core/image/color_extractor.dart';
import '../../core/llm/config.dart';
import '../../core/llm/llm_service.dart';
import '../../core/llm/local_config.dart';
import '../../core/llm/local_service.dart';
import '../../core/llm/model_manager.dart';
import '../../core/llm/ollama_service.dart';
import '../../core/llm/openai_service.dart';
import '../../core/llm/vision_enricher.dart';
import '../../services/parallel_analysis_scheduler.dart';
import '../../services/file_storage_service.dart';
import '../../services/log_service.dart';
import '../../services/s3_config.dart';
import '../../services/s3_sync_service.dart';
import '../../services/s3_sync_serializer.dart';
import '../../services/import_service.dart';
import '../../services/model_search_service.dart';
import '../../services/search_service.dart';

// ---- Persistence ----

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences not initialized');
});

// ---- Database ----

final databaseProvider = Provider<AppDatabase>((ref) {
  final t0 = DateTime.now();
  final db = AppDatabase();
  debugPrint('[Startup] AppDatabase created: ${DateTime.now().difference(t0).inMilliseconds}ms');
  return db;
});

// ---- DAOs ----

final memeDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).memeDao;
});

final colorDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).colorDao;
});

final tagDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).tagDao;
});

final queueDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).analysisQueueDao;
});

final colorAnalysisQueueDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).colorAnalysisQueueDao;
});

final ocrAnalysisQueueDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).ocrAnalysisQueueDao;
});

final aiAnalysisQueueDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).aiAnalysisQueueDao;
});

final albumDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).albumDao;
});

// ---- Repositories ----

final memeRepositoryProvider = Provider<MemeRepository>((ref) {
  final db = ref.read(databaseProvider);
  return MemeRepository(
    memeDao: db.memeDao,
    tagDao: db.tagDao,
    colorDao: db.colorDao,
    queueDao: db.analysisQueueDao,
  );
});

final colorRepositoryProvider = Provider<ColorRepository>((ref) {
  return ColorRepository(ref.read(colorDaoProvider));
});

// ---- Services ----

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});

/// 由 main.dart 在 app 启动时设置的日志持久化路径
String? _logFilePath;

/// 设置日志持久化路径（仅由 main.dart 调用一次）
void initLogFilePath(String path) {
  _logFilePath = path;
}

final logServiceProvider = Provider<LogService>((ref) {
  return LogService(logFilePath: _logFilePath, mllmLogPath: getMllmLogFilePath());
});

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    memeRepo: ref.read(memeRepositoryProvider),
    storage: ref.read(fileStorageServiceProvider),
    userStatsDao: ref.read(databaseProvider).userStatsDao,
  );
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(
    memeRepo: ref.read(memeRepositoryProvider),
    colorRepo: ref.read(colorRepositoryProvider),
  );
});

// ---- 配置持久化 Notifier ----

class ColorExtractionConfigNotifier extends Notifier<ColorExtractionConfig> {
  @override
  ColorExtractionConfig build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString('color_extraction_config');
      if (jsonStr != null) {
        return ColorExtractionConfig.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const ColorExtractionConfig();
  }

  void update(ColorExtractionConfig config) {
    state = config;
    try {
      ref
          .read(sharedPreferencesProvider)
          .setString('color_extraction_config', jsonEncode(config.toJson()));
    } catch (_) {}
  }
}

final colorExtractionConfigProvider =
    NotifierProvider<ColorExtractionConfigNotifier, ColorExtractionConfig>(
  ColorExtractionConfigNotifier.new,
);

final analysisSchedulerProvider = Provider<ParallelAnalysisScheduler>((ref) {
  final t0 = DateTime.now();
  final config = ref.watch(colorExtractionConfigProvider);
  final scheduler = ParallelAnalysisScheduler(
    colorQueueDao: ref.read(colorAnalysisQueueDaoProvider),
    ocrQueueDao: ref.read(ocrAnalysisQueueDaoProvider),
    aiQueueDao: ref.read(aiAnalysisQueueDaoProvider),
    analysisQueueDao: ref.read(queueDaoProvider),
    memeRepo: ref.read(memeRepositoryProvider),
    colorExtractor: ColorExtractor(defaultConfig: config),
    storage: ref.read(fileStorageServiceProvider),
    log: ref.read(logServiceProvider),
  );

  debugPrint('[Startup] Scheduler created: ${DateTime.now().difference(t0).inMilliseconds}ms');

  // 同步颜色提取配置到调度器（运行时修改会即时生效）
  scheduler.setColorExtractionConfig(config);

  // 监听配置变化并同步
  ref.listen<ColorExtractionConfig>(colorExtractionConfigProvider, (_, next) {
    scheduler.setColorExtractionConfig(next);
  });

  // 同步应用语言设置到调度器（LLM 分析使用对应语言的 prompt 模板）
  final appLocale = ref.watch(localeProvider);
  scheduler.setAppLocale(appLocale);

  // 监听语言变化并同步
  ref.listen<Locale?>(localeProvider, (_, next) {
    scheduler.setAppLocale(next);
  });

  final visionEnricher = ref.watch(visionEnricherProvider);
  if (visionEnricher != null) {
    scheduler.setVisionLlmEnricher(visionEnricher);
  }

  scheduler.setOcrEnabled(ref.read(ocrEnabledProvider));

  scheduler.start();
  debugPrint('[Startup] Scheduler started: ${DateTime.now().difference(t0).inMilliseconds}ms');

  ref.onDispose(() {
    scheduler.stop();
  });

  return scheduler;
});

// ---- LLM 模式 ----

class LlmModeNotifier extends Notifier<LlmMode> {
  @override
  LlmMode build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final stored = prefs.getString('llm_mode');
      if (stored != null) return LlmMode.values.byName(stored);
    } catch (_) {}
    return LlmMode.off;
  }

  void setMode(LlmMode mode) {
    state = mode;
    try {
      ref.read(sharedPreferencesProvider).setString('llm_mode', mode.name);
    } catch (_) {}
  }
}

final llmModeProvider =
    NotifierProvider<LlmModeNotifier, LlmMode>(LlmModeNotifier.new);

// ---- 远程 LLM 配置 ----

class LlmConfigNotifier extends Notifier<LlmConfig> {
  @override
  LlmConfig build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString('llm_config');
      if (jsonStr != null) {
        return LlmConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const LlmConfig();
  }

  void update(LlmConfig config) {
    state = config;
    try {
      ref
          .read(sharedPreferencesProvider)
          .setString('llm_config', jsonEncode(config.toJson()));
    } catch (_) {}
  }
}

final llmConfigProvider =
    NotifierProvider<LlmConfigNotifier, LlmConfig>(LlmConfigNotifier.new);

// ---- 本地 LLM 配置 ----

class LocalLlmConfigNotifier extends Notifier<LocalLlmConfig> {
  static final _oldPathMarker = '/data/user/0/com.mememaster.app/app_flutter/';

  @override
  LocalLlmConfig build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString('local_llm_config');
      if (jsonStr != null) {
        final cfg = LocalLlmConfig.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>);
        // 兼容旧版路径改写
        final migrated = _migrateFromOldPath(cfg);
        // 如果 modelPath 文件不存在，打日志方便排查
        if (migrated.modelPath != null &&
            migrated.modelPath!.isNotEmpty &&
            !File(migrated.modelPath!).existsSync()) {
          debugPrint(
            '[LocalLlmConfig] 警告: modelPath 指向的文件不存在: ${migrated.modelPath}',
          );
        }
        return migrated;
      }
    } catch (_) {}
    return const LocalLlmConfig();
  }

  /// 把旧路径下的 .gguf 路径改写为当前 storageDir 下的路径
  ///
  /// 仅当以下条件同时满足时才改写：
  /// - path 以旧的基准路径标记（_oldPathMarker）开头
  /// - path 尚未指向当前 storageDir（防止 double-path）
  /// - 新路径下的文件实际存在（迁移已完成）
  LocalLlmConfig _migrateFromOldPath(LocalLlmConfig cfg) {
    final storageDir = ref.read(storageDirProvider);
    String? rewrite(String? path) {
      if (path == null) return null;
      // 已经指向当前 storageDir，无需改写
      if (path.startsWith(storageDir)) return path;
      if (!path.startsWith(_oldPathMarker)) return path;
      final fileName = path.substring(_oldPathMarker.length);
      final newPath = '$storageDir/$fileName';
      if (File(newPath).existsSync()) return newPath;
      return path;
    }

    final migrated = cfg.copyWith(
      modelPath: rewrite(cfg.modelPath),
      mmprojPath: rewrite(cfg.mmprojPath),
    );
    if (migrated.modelPath != cfg.modelPath ||
        migrated.mmprojPath != cfg.mmprojPath) {
      update(migrated); // 持久化改写后的值
    }
    return migrated;
  }

  void update(LocalLlmConfig config) {
    state = config;
    try {
      ref
          .read(sharedPreferencesProvider)
          .setString('local_llm_config', jsonEncode(config.toJson()));
    } catch (_) {}
  }
}

final localLlmConfigProvider =
    NotifierProvider<LocalLlmConfigNotifier, LocalLlmConfig>(
  LocalLlmConfigNotifier.new,
);

/// 本地 LLM 模型是否已加载到内存中
///
/// 与 [localLlmConfigProvider] 分离：配置持久化（模型路径），加载状态仅存运行时。
/// 应用重启后自动置为 false，不持久化。
final localLlmLoadedProvider = StateProvider<bool>((ref) => false);

/// 本地 LLM 模型是否正在加载中
final localLlmLoadingProvider = StateProvider<bool>((ref) => false);

/// 已启用模型 ID 集合（管理页「启用/禁用」开关控制）
///
/// 持久化到 SharedPreferences。只有已启用的模型才会出现在 AI 设置页的模型选择器中。
final enabledModelsProvider = NotifierProvider<EnabledModelsNotifier, Set<String>>(
  EnabledModelsNotifier.new,
);

class EnabledModelsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final stored = prefs.getString('enabled_models');
      if (stored != null && stored.isNotEmpty) {
        return stored.split(',').toSet();
      }
    } catch (_) {}
    return {};
  }

  void toggle(String modelId) {
    final updated = Set<String>.from(state);
    if (updated.contains(modelId)) {
      updated.remove(modelId);
    } else {
      updated.add(modelId);
    }
    state = updated;
    _persist(updated);
  }

  void enable(String modelId) {
    if (state.contains(modelId)) return;
    final updated = Set<String>.from(state)..add(modelId);
    state = updated;
    _persist(updated);
  }

  void disable(String modelId) {
    if (!state.contains(modelId)) return;
    final updated = Set<String>.from(state)..remove(modelId);
    state = updated;
    _persist(updated);
  }

  void _persist(Set<String> models) {
    try {
      ref.read(sharedPreferencesProvider).setString('enabled_models', models.join(','));
    } catch (_) {}
  }
}

// ---- LLM 服务（按模式创建） ----

final llmServiceProvider = Provider.autoDispose<LlmService?>((ref) {
  final mode = ref.watch(llmModeProvider);

  // token 用量持久化回调
  void onTokenUsage(int prompt, int completion) {
    try {
      ref.read(databaseProvider).userStatsDao.incrementTokens(
        prompt: prompt,
        completion: completion,
      );
    } catch (_) {
      // 静默失败，不影响 LLM 调用
    }
  }

  LlmService? service;
  ref.onDispose(() {
    service?.dispose();
  });

  switch (mode) {
    case LlmMode.off:
      return null;
    case LlmMode.remote:
      final config = ref.watch(llmConfigProvider);
      switch (config.provider) {
        case LlmProviderType.openai:
          service = OpenAiLlmService(
            baseUrl: config.baseUrl,
            apiKey: config.apiKey,
            model: config.model,
            onTokenUsage: onTokenUsage,
          );
          return service;
        case LlmProviderType.ollama:
          service = OllamaLlmService(
            baseUrl: config.baseUrl,
            model: config.model,
            onTokenUsage: onTokenUsage,
          );
          return service;
      }
    case LlmMode.local:
      final localConfig = ref.watch(localLlmConfigProvider);
      service = LocalLlmService(
        config: localConfig,
        log: ref.read(logServiceProvider),
      );
      return service;
  }
  return null;
});

// ---- 视觉 LLM Enricher（多模态） ----

final visionEnricherProvider = Provider<VisionLlmEnricher?>((ref) {
  final llm = ref.watch(llmServiceProvider);
  final repo = ref.watch(memeRepositoryProvider);
  final log = ref.watch(logServiceProvider);
  final mode = ref.watch(llmModeProvider);
  if (llm == null || !llm.isAvailable) return null;
  final llmConfig = mode == LlmMode.remote ? ref.watch(llmConfigProvider) : null;
  final localLlmConfig = mode == LlmMode.local ? ref.watch(localLlmConfigProvider) : null;
  return VisionLlmEnricher(
    llm: llm,
    repo: repo,
    log: log,
    llmConfig: llmConfig,
    localLlmConfig: localLlmConfig,
  );
});

// ---- 模型下载状态 ----

/// 单个下载任务需要的上下文（用于 resume 重启协程、cancel 清理临时文件）
class _DownloadTask {
  final String taskId;
  final ModelInfo modelInfo;
  final String tempFilePath;
  final ModelManager manager;
  final void Function(String taskId)? onComplete;
  final void Function(String taskId, Object error)? onError;

  _DownloadTask({
    required this.taskId,
    required this.modelInfo,
    required this.tempFilePath,
    required this.manager,
    this.onComplete,
    this.onError,
  });
}

/// 下载状态跟踪 Notifier
///
/// 使用 [downloadTaskId] 作为key，格式为 "{modelId}#{fileType}"，
/// 其中 fileType 为 "gguf" 或 "mmproj"，确保同一模型的不同文件可以并行下载。
class DownloadStatesNotifier extends StateNotifier<Map<String, DownloadState>> {
  DownloadStatesNotifier({LogService? log}) : super({}) {
    _log = log;
  }

  LogService? _log;
  static const _tag = 'DownloadState';

  /// 每个下载任务对应的取消令牌（用于暂停/取消）
  final Map<String, CancelToken> _cancelTokens = {};

  /// 每个下载任务的完整上下文（resume/retry 时用来重启协程）
  final Map<String, _DownloadTask> _tasks = {};

  /// 生成唯一的下载任务ID
  static String makeTaskId(String modelId, String fileType) => '$modelId#$fileType';

  /// 启动一个新下载任务（notifier 内部 spawn 协程并接管生命周期）
  void startDownload({
    required String taskId,
    required ModelInfo modelInfo,
    required String tempFilePath,
    required ModelManager manager,
    void Function(String taskId)? onComplete,
    void Function(String taskId, Object error)? onError,
  }) {
    _cancelTokens[taskId] = CancelToken();
    _tasks[taskId] = _DownloadTask(
      taskId: taskId,
      modelInfo: modelInfo,
      tempFilePath: tempFilePath,
      manager: manager,
      onComplete: onComplete,
      onError: onError,
    );
    state = {
      ...state,
      taskId: DownloadState(modelId: taskId, status: DownloadStatus.downloading),
    };
    _log?.info(_tag, 'startDownload: taskId=$taskId, url=${modelInfo.ggufUrl}');
    _runDownload(taskId);
  }

  void updateProgress(String taskId, double progress) {
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(progress: progress) ??
          DownloadState(modelId: taskId, status: DownloadStatus.downloading, progress: progress),
    };
  }

  /// 暂停当前任务：仅置 flag，正在跑的协程下次循环检测到会抛 PauseException 退出
  void pauseDownload(String taskId) {
    _log?.info(_tag, 'pauseDownload: taskId=$taskId');
    _cancelTokens[taskId]?.pause();
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(status: DownloadStatus.paused) ??
          DownloadState(modelId: taskId, status: DownloadStatus.paused),
    };
  }

  /// 恢复任务：置 flag + 重新启动 downloadModel 协程（断点续传）
  void resumeDownload(String taskId) {
    final task = _tasks[taskId];
    if (task == null) {
      _log?.warning(_tag, 'resumeDownload 失败: task 不存在, taskId=$taskId');
      return;
    }
    _log?.info(_tag, 'resumeDownload: taskId=$taskId');
    _cancelTokens[taskId]?.resume();
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(status: DownloadStatus.downloading) ??
          DownloadState(modelId: taskId, status: DownloadStatus.downloading),
    };
    _runDownload(taskId);
  }

  /// 取消任务：取消 token + 清理上下文和临时文件 + 隐藏 UI 卡片
  void cancelDownload(String taskId) {
    _log?.info(_tag, 'cancelDownload: taskId=$taskId');
    final token = _cancelTokens[taskId];
    final task = _tasks[taskId];
    token?.cancel();
    _cancelTokens.remove(taskId);
    _tasks.remove(taskId);
    if (task != null) _deleteTempFile(task.tempFilePath);
    final map = Map<String, DownloadState>.from(state);
    map.remove(taskId);
    state = map;
  }

  /// 兼容旧 API：删除模型时调用，等价于 [cancelDownload]
  void removeState(String taskId) => cancelDownload(taskId);

  /// 标记下载失败
  ///
  /// 保留临时文件和任务上下文，以便用户后续重试时断点续传。
  /// 临时文件只会在用户主动取消或下载完成重命名时清理。
  void failDownload(String taskId, String error) {
    _log?.error(_tag, 'failDownload: taskId=$taskId, error=$error');
    // 保留 _tasks 和 _cancelTokens，不删临时文件，以便用户重试断点续传
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(status: DownloadStatus.failed, errorMessage: error) ??
          DownloadState(modelId: taskId, status: DownloadStatus.failed, errorMessage: error),
    };
  }

  void completeDownload(String taskId) {
    _log?.info(_tag, 'completeDownload: taskId=$taskId');
    _cancelTokens.remove(taskId);
    _tasks.remove(taskId);
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(status: DownloadStatus.completed, progress: 1.0) ??
          DownloadState(modelId: taskId, status: DownloadStatus.completed, progress: 1.0),
    };
  }

  /// 重试失败的下载（从断点续传）
  void retryDownload(String taskId) {
    final task = _tasks[taskId];
    if (task == null) {
      _log?.warning(_tag, 'retryDownload 失败: task 不存在, taskId=$taskId');
      return;
    }
    _log?.info(_tag, 'retryDownload: taskId=$taskId, url=${task.modelInfo.ggufUrl}');

    // 保证有一个可用的 CancelToken（旧的可能已取消）
    _cancelTokens[taskId] ??= CancelToken();
    _cancelTokens[taskId]?.resume();

    state = {
      ...state,
      taskId: state[taskId]?.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.0,
        errorMessage: null,
      ) ??
          DownloadState(
            modelId: taskId,
            status: DownloadStatus.downloading,
            progress: 0.0,
          ),
    };
    _runDownload(taskId);
  }

  /// 后台跑一次 downloadModel，失败/暂停/cancel 都正确处理
  void _runDownload(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;
    final token = _cancelTokens[taskId];
    if (token == null) return;

    task.manager
        .downloadModel(
      task.modelInfo,
      onProgress: (p) => updateProgress(taskId, p),
      cancelToken: token,
    )
        .then((_) async {
      // 主模型下载完成后，检查是否需要下载 mmproj
      // 如果本身已经是投影模型或没有主模型 URL，跳过
      if (task.modelInfo.modelType == ModelType.projection || task.modelInfo.ggufUrl == null) {
        completeDownload(taskId);
        task.onComplete?.call(taskId);
        return;
      }

      // 确定 mmproj URL: 优先用预设，没有则自动发现
      var mmprojUrl = task.modelInfo.defaultMmprojUrl;
      if (mmprojUrl == null && (task.modelInfo.source == DownloadSource.huggingface || task.modelInfo.source == DownloadSource.modelscope)) {
        try {
          final searchService = ModelSearchService();
          final repoId = '${task.modelInfo.author}/${task.modelInfo.repo}';
          _log?.info(_tag, '尝试自动发现 mmproj: repoId=$repoId');
          final mmprojFile = await searchService.findMmprojFile(
            source: task.modelInfo.source,
            modelId: repoId,
          );
          if (mmprojFile != null) {
            mmprojUrl = mmprojFile.downloadUrl;
            _log?.info(_tag, '自动发现 mmproj 成功: $mmprojUrl');
          } else {
            _log?.info(_tag, '未发现 mmproj 文件');
          }
        } catch (e) {
          _log?.warning(_tag, 'mmproj 自动发现失败: $e');
        }
      }

      if (mmprojUrl != null) {
        _log?.info(_tag, '主模型下载完成，开始下载 mmproj: $mmprojUrl');
        final mmprojTaskId = '${task.taskId}#mmproj';
        _cancelTokens[mmprojTaskId] = CancelToken();
        _tasks[mmprojTaskId] = _DownloadTask(
          taskId: mmprojTaskId,
          modelInfo: task.modelInfo,
          tempFilePath: '${task.tempFilePath}.mmproj',
          manager: task.manager,
          onComplete: (_) {
            _log?.info(_tag, 'mmproj 下载完成: $mmprojTaskId');
            _cancelTokens.remove(mmprojTaskId);
            _tasks.remove(mmprojTaskId);
          },
          onError: (id, e) {
            _log?.error(_tag, 'mmproj 下载失败: $mmprojTaskId, error=$e');
            _cancelTokens.remove(mmprojTaskId);
            _tasks.remove(mmprojTaskId);
          },
        );
        state = {
          ...state,
          mmprojTaskId: DownloadState(modelId: mmprojTaskId, status: DownloadStatus.downloading),
        };
        await _runMmprojDownload(mmprojTaskId);
        completeDownload(taskId);
        task.onComplete?.call(taskId);
      } else {
        completeDownload(taskId);
        task.onComplete?.call(taskId);
      }
    }).catchError((e) {
      // 暂停不算失败（用户后续会 resume）
      if (e is PauseException) return;
      // 取消：cancelDownload 已经清理过所有东西，这里什么都不做
      if (token.isCancelled) return;
      _log?.error(_tag, '_runDownload 异常: taskId=$taskId, error=$e');
      failDownload(taskId, e.toString());
      task.onError?.call(taskId, e);
    });
  }

  Future<void> _runMmprojDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    final token = _cancelTokens[taskId];
    if (token == null) return;

    await task.manager
        .downloadMmproj(
      task.modelInfo,
      onProgress: (p) => updateProgress(taskId, p),
      cancelToken: token,
    )
        .then((_) {
      completeDownload(taskId);
      task.onComplete?.call(taskId);
    }).catchError((e) {
      if (e is PauseException) return;
      if (token.isCancelled) return;
      _log?.error(_tag, '_runMmprojDownload 异常: taskId=$taskId, error=$e');
      failDownload(taskId, e.toString());
      task.onError?.call(taskId, e);
    });
  }

  static void _deleteTempFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // 删不掉不影响取消语义
    }
  }
}

final downloadStatesProvider =
    StateNotifierProvider<DownloadStatesNotifier, Map<String, DownloadState>>((ref) {
  final log = ref.watch(logServiceProvider);
  return DownloadStatesNotifier(log: log);
});

// ---- 模型管理 ----

final storageDirProvider = Provider<String>((ref) {
  throw UnimplementedError('storageDirProvider 需要在 main.dart 中覆盖');
});

final modelManagerProvider = Provider<ModelManager>((ref) {
  final dir = ref.watch(storageDirProvider);
  final log = ref.watch(logServiceProvider);
  return ModelManager(storageDir: dir, log: log);
});

// ---- 管线配置 ----

class OcrEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Linux/macOS: 检查 Tesseract 是否安装，未安装则强制关闭 OCR
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        // 用 tesseract --version 直接检测，比 which 更可靠
        final result = Process.runSync('tesseract', ['--version']);
        if (result.exitCode != 0) {
          debugPrint('[OCR] Tesseract check failed: exitCode=${result.exitCode}');
          return false;
        }
        debugPrint('[OCR] Tesseract detected: ${result.stdout.toString().split('\n').first}');
      } catch (e) {
        debugPrint('[OCR] Tesseract not found: $e');
        return false;
      }
    }

    try {
      return ref.read(sharedPreferencesProvider).getBool('ocr_enabled') ?? true;
    } catch (_) {
      return false;
    }
  }

  void setEnabled(bool value) {
    state = value;
    try {
      ref.read(sharedPreferencesProvider).setBool('ocr_enabled', value);
    } catch (_) {}
  }
}

final ocrEnabledProvider =
    NotifierProvider<OcrEnabledNotifier, bool>(OcrEnabledNotifier.new);

class LlmEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.read(sharedPreferencesProvider).getBool('llm_enabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  void setEnabled(bool value) {
    state = value;
    try {
      ref.read(sharedPreferencesProvider).setBool('llm_enabled', value);
    } catch (_) {}
  }
}

final llmEnabledProvider =
    NotifierProvider<LlmEnabledNotifier, bool>(LlmEnabledNotifier.new);

// ---- S3 同步 ----

/// S3 配置持久化到 FlutterSecureStorage（密钥不会明文暴露）
class S3ConfigNotifier extends AsyncNotifier<S3Config> {
  @override
  Future<S3Config> build() async {
    try {
      const storage = FlutterSecureStorage();
      return S3Config(
        endpoint: await storage.read(key: 's3_endpoint') ?? '',
        bucket: await storage.read(key: 's3_bucket') ?? '',
        region: await storage.read(key: 's3_region') ?? 'us-east-1',
        accessKey: await storage.read(key: 's3_access_key') ?? '',
        secretKey: await storage.read(key: 's3_secret_key') ?? '',
        useSsl: true,
        pathStyle: true,
        connectTimeout: 30,
      );
    } catch (_) {
      return const S3Config();
    }
  }

  Future<void> save(S3Config config) async {
    state = AsyncData(config);
    const storage = FlutterSecureStorage();
    await Future.wait([
      storage.write(key: 's3_endpoint', value: config.endpoint),
      storage.write(key: 's3_bucket', value: config.bucket),
      storage.write(key: 's3_region', value: config.region),
      storage.write(key: 's3_access_key', value: config.accessKey),
      storage.write(key: 's3_secret_key', value: config.secretKey),
    ]);
  }
}

final s3ConfigProvider =
    AsyncNotifierProvider<S3ConfigNotifier, S3Config>(S3ConfigNotifier.new);

final s3SyncServiceProvider = Provider<S3SyncService>((ref) {
  final db = ref.read(databaseProvider);
  final service = S3SyncService(
    memeRepo: ref.read(memeRepositoryProvider),
    albumRepo: ref.read(albumRepositoryProvider),
    storage: ref.read(fileStorageServiceProvider),
    syncStateDao: db.syncStateDao,
    serializer: S3SyncSerializer(
      memeRepo: ref.read(memeRepositoryProvider),
      albumRepo: ref.read(albumRepositoryProvider),
      db: db,
    ),
    db: db,
    log: ref.read(logServiceProvider),
  );
  final config = ref.read(s3ConfigProvider).valueOrNull;
  if (config != null) {
    service.updateConfig(config);
  }
  return service;
});

// ---- Gallery State ----

/// 图库排序模式
enum MemeSortMode {
  importedAtDesc('imported_at', false, '导入时间 ↓'),
  importedAtAsc('imported_at', true, '导入时间 ↑'),
  fileSizeAsc('file_size', true, '大小 ↑'),
  fileSizeDesc('file_size', false, '大小 ↓'),
  copyCountDesc('copy_count', false, '复制次数 ↓'),
  copyCountAsc('copy_count', true, '复制次数 ↑'),
  createdAtDesc('created_at', false, '创建时间 ↓'),
  createdAtAsc('created_at', true, '创建时间 ↑');

  final String field;
  final bool ascending;
  final String label;
  const MemeSortMode(this.field, this.ascending, this.label);
}

/// 排序模式提供器
class MemeSortModeNotifier extends Notifier<MemeSortMode> {
  @override
  MemeSortMode build() => MemeSortMode.importedAtDesc;

  void set(MemeSortMode mode) => state = mode;
}

final memeSortModeProvider =
    NotifierProvider<MemeSortModeNotifier, MemeSortMode>(
  MemeSortModeNotifier.new,
);

final memeListProvider = FutureProvider<List<Meme>>((ref) {
  final sortMode = ref.watch(memeSortModeProvider);
  return ref.read(memeRepositoryProvider).getAllSorted(
        sortField: sortMode.field,
        ascending: sortMode.ascending,
      );
});

final memeCountProvider = FutureProvider<int>((ref) {
  return ref.read(memeRepositoryProvider).count();
});

// ---- User Stats ----

final userStatsDaoProvider = Provider((ref) {
  return ref.read(databaseProvider).userStatsDao;
});

/// 今日统计
final todayStatsProvider = FutureProvider<UserStatsEntry?>((ref) {
  final dao = ref.read(userStatsDaoProvider);
  return dao.getOrCreateToday();
});

/// 当前选择的统计日期范围（默认最近 7 天）
final selectedDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - 6);
  final end = now;
  return DateTimeRange(start: start, end: end);
});

/// 根据选择的日期范围获取统计
final rangeStatsProvider = FutureProvider<List<UserStatsEntry>>((ref) {
  final range = ref.watch(selectedDateRangeProvider);
  final dao = ref.read(userStatsDaoProvider);
  return dao.getByDateRange(range.start, range.end);
});

/// 汇总统计
final totalStatsProvider = FutureProvider<Map<String, int>>((ref) {
  final dao = ref.read(userStatsDaoProvider);
  return dao.getTotals();
});

// ---- Albums ----

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository(ref.read(albumDaoProvider));
});

class AlbumsNotifier extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() {
    return ref.read(albumRepositoryProvider).getAll();
  }

  Future<void> addAlbum(String name) async {
    final album = await ref.read(albumRepositoryProvider).create(name: name);
    // 直接在当前状态后追加新相册，避免 invalidateSelf() 的异步重建时序问题
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, album]);
  }
}

final albumsProvider =
    AsyncNotifierProvider<AlbumsNotifier, List<Album>>(AlbumsNotifier.new);

// ---- 主题 ----

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    try {
      final stored = ref.read(sharedPreferencesProvider).getString('theme_mode');
      if (stored != null) return ThemeMode.values.byName(stored);
    } catch (_) {}
    return ThemeMode.system;
  }

  void set(ThemeMode mode) {
    state = mode;
    try {
      ref.read(sharedPreferencesProvider).setString('theme_mode', mode.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ---- 语言 ----

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    try {
      final stored = ref.read(sharedPreferencesProvider).getString('locale');
      if (stored != null) {
        final parts = stored.split('_');
        return Locale(parts[0], parts.length > 1 ? parts[1] : null);
      }
    } catch (_) {}
    return null; // null = 跟随系统
  }

  void set(Locale? locale) {
    state = locale;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (locale == null) {
        prefs.remove('locale');
      } else {
        prefs.setString('locale', locale.toString());
      }
    } catch (_) {}
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

// ---- 定时同步 ----

class AutoSyncEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.read(sharedPreferencesProvider).getBool('auto_sync_enabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  void setEnabled(bool value) {
    state = value;
    try {
      ref.read(sharedPreferencesProvider).setBool('auto_sync_enabled', value);
    } catch (_) {}
  }
}

final autoSyncEnabledProvider =
    NotifierProvider<AutoSyncEnabledNotifier, bool>(AutoSyncEnabledNotifier.new);

class AutoSyncIntervalNotifier extends Notifier<Duration> {
  @override
  Duration build() {
    try {
      final minutes = ref.read(sharedPreferencesProvider).getInt('auto_sync_interval_minutes');
      if (minutes != null) return Duration(minutes: minutes);
    } catch (_) {}
    return const Duration(hours: 1);
  }

  void setInterval(Duration interval) {
    state = interval;
    try {
      ref.read(sharedPreferencesProvider).setInt(
        'auto_sync_interval_minutes',
        interval.inMinutes,
      );
    } catch (_) {}
  }
}

final autoSyncIntervalProvider =
    NotifierProvider<AutoSyncIntervalNotifier, Duration>(
  AutoSyncIntervalNotifier.new,
);

// ---- 分析进度 ----

class AnalysisProgress {
  final int queued;
  final int running;
  final int total;
  const AnalysisProgress({
    this.queued = 0,
    this.running = 0,
  }) : total = queued + running;
  bool get isEmpty => total == 0;
}

// ---- 重新索引状态 ----

class ReindexState {
  final bool isRunning;
  final int processed;
  final int enqueued;
  final int? totalMemes;

  const ReindexState({
    this.isRunning = false,
    this.processed = 0,
    this.enqueued = 0,
    this.totalMemes,
  });

  bool get isEmpty => !isRunning && processed == 0;
}

final reindexStateProvider =
    StateNotifierProvider<ReindexStateNotifier, ReindexState>((ref) {
  return ReindexStateNotifier(ref);
});

class ReindexStateNotifier extends StateNotifier<ReindexState> {
  final Ref _ref;

  ReindexStateNotifier(this._ref) : super(const ReindexState());

  Future<void> startReindex() async {
    state = const ReindexState(isRunning: true);
    try {
      final repo = _ref.read(memeRepositoryProvider);
      final result = await repo.reindexAll(
        onProgress: (processed, enqueued) {
          state = ReindexState(
            isRunning: true,
            processed: processed,
            enqueued: enqueued,
          );
        },
      );
      state = ReindexState(
        isRunning: false,
        processed: result['total']!,
        enqueued: result['enqueued']!,
        totalMemes: result['total']!,
      );
    } catch (e) {
      state = ReindexState(
        isRunning: false,
        processed: state.processed,
        enqueued: state.enqueued,
        totalMemes: state.totalMemes,
      );
    }
  }
}

final analysisProgressProvider = StreamProvider<AnalysisProgress>((ref) async* {
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    final colorDao = ref.read(colorAnalysisQueueDaoProvider);
    final ocrDao = ref.read(ocrAnalysisQueueDaoProvider);
    final aiDao = ref.read(aiAnalysisQueueDaoProvider);
    try {
      final total = await Future.wait([
        colorDao.getPendingCount(),
        colorDao.getRunningCount(),
        ocrDao.getPendingCount(),
        ocrDao.getRunningCount(),
        aiDao.getPendingCount(),
        aiDao.getRunningCount(),
      ]);
      yield AnalysisProgress(
        queued: total[0] + total[2] + total[4],
        running: total[1] + total[3] + total[5],
      );
    } catch (_) {
      yield const AnalysisProgress();
    }
  }
});

final memesByAlbumProvider = FutureProvider.family<List<Meme>, String>((ref, albumId) async {
  final albumDao = ref.read(albumDaoProvider);
  final memeIds = await albumDao.getMemeIdsByAlbum(albumId);
  if (memeIds.isEmpty) return [];
  final allMemes = await ref.watch(memeListProvider.future);
  final idSet = memeIds.toSet();
  return allMemes.where((m) => idSet.contains(m.id)).toList();
});
