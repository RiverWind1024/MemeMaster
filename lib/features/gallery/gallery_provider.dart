import 'dart:convert';

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
import '../../services/analysis_queue_scheduler.dart';
import '../../services/file_storage_service.dart';
import '../../services/log_service.dart';
import '../../services/s3_config.dart';
import '../../services/s3_sync_service.dart';
import '../../services/s3_sync_serializer.dart';
import '../../services/import_service.dart';
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
  return LogService(logFilePath: _logFilePath);
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

final analysisSchedulerProvider = Provider<AnalysisQueueScheduler>((ref) {
  final t0 = DateTime.now();
  final config = ref.watch(colorExtractionConfigProvider);
  final scheduler = AnalysisQueueScheduler(
    queueDao: ref.read(queueDaoProvider),
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
  @override
  LocalLlmConfig build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString('local_llm_config');
      if (jsonStr != null) {
        return LocalLlmConfig.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const LocalLlmConfig();
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
      service = LocalLlmService(config: localConfig);
      return service;
  }
  return null;
});

// ---- 视觉 LLM Enricher（多模态） ----

final visionEnricherProvider = Provider<VisionLlmEnricher?>((ref) {
  final llm = ref.watch(llmServiceProvider);
  final repo = ref.watch(memeRepositoryProvider);
  final log = ref.watch(logServiceProvider);
  if (llm == null || !llm.isAvailable) return null;
  return VisionLlmEnricher(llm: llm, repo: repo, log: log);
});

// ---- 模型下载状态 ----

/// 下载状态跟踪 Notifier
///
/// 使用 [downloadTaskId] 作为key，格式为 "{modelId}#{fileType}"，
/// 其中 fileType 为 "gguf" 或 "mmproj"，确保同一模型的不同文件可以并行下载。
class DownloadStatesNotifier extends StateNotifier<Map<String, DownloadState>> {
  DownloadStatesNotifier() : super({});

  /// 每个下载任务对应的取消令牌（用于暂停/取消）
  final Map<String, CancelToken> _cancelTokens = {};

  /// 生成唯一的下载任务ID
  static String makeTaskId(String modelId, String fileType) => '$modelId#$fileType';

  /// 获取指定下载任务当前的取消令牌
  CancelToken? getCancelToken(String taskId) => _cancelTokens[taskId];

  void startDownload(String taskId) {
    _cancelTokens[taskId] = CancelToken();
    state = {
      ...state,
      taskId: DownloadState(modelId: taskId, status: DownloadStatus.downloading),
    };
  }

  void updateProgress(String taskId, double progress) {
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(progress: progress) ??
          DownloadState(modelId: taskId, status: DownloadStatus.downloading, progress: progress),
    };
  }

  void pauseDownload(String taskId) {
    _cancelTokens[taskId]?.pause();
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(status: DownloadStatus.paused) ??
          DownloadState(modelId: taskId, status: DownloadStatus.paused),
    };
  }

  void resumeDownload(String taskId) {
    _cancelTokens[taskId]?.resume();
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(status: DownloadStatus.downloading) ??
          DownloadState(modelId: taskId, status: DownloadStatus.downloading),
    };
  }

  void failDownload(String taskId, String error) {
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(status: DownloadStatus.failed, errorMessage: error) ??
          DownloadState(modelId: taskId, status: DownloadStatus.failed, errorMessage: error),
    };
  }

  void completeDownload(String taskId) {
    _cancelTokens.remove(taskId);
    state = {
      ...state,
      taskId: state[taskId]?.copyWith(status: DownloadStatus.completed, progress: 1.0) ??
          DownloadState(modelId: taskId, status: DownloadStatus.completed, progress: 1.0),
    };
  }

  void removeState(String taskId) {
    _cancelTokens.remove(taskId);
    final map = Map<String, DownloadState>.from(state);
    map.remove(taskId);
    state = map;
  }
}

final downloadStatesProvider =
    StateNotifierProvider<DownloadStatesNotifier, Map<String, DownloadState>>((ref) {
  return DownloadStatesNotifier();
});

// ---- 模型管理 ----

final storageDirProvider = Provider<String>((ref) {
  throw UnimplementedError('storageDirProvider 需要在 main.dart 中覆盖');
});

final modelManagerProvider = Provider<ModelManager>((ref) {
  final dir = ref.watch(storageDirProvider);
  return ModelManager(storageDir: dir);
});

// ---- 管线配置 ----

class OcrEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
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

/// 近 7 天统计
final recentWeekStatsProvider = FutureProvider<List<UserStatsEntry>>((ref) {
  final dao = ref.read(userStatsDaoProvider);
  return dao.getRecentDays(7);
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

final analysisProgressProvider = StreamProvider<AnalysisProgress>((ref) async* {
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    final queueDao = ref.read(queueDaoProvider);
    try {
      final queued = await queueDao.countQueued();
      final running = (await queueDao.getRunning()).length;
      yield AnalysisProgress(queued: queued, running: running);
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
