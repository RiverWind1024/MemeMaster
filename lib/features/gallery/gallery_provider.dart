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
import '../../core/llm/enricher.dart';
import '../../core/llm/llm_service.dart';
import '../../core/llm/ollama_service.dart';
import '../../core/llm/openai_service.dart';
import '../../services/analysis_queue_scheduler.dart';
import '../../services/file_storage_service.dart';
import '../../services/log_service.dart';
import '../../services/s3_config.dart';
import '../../services/s3_sync_service.dart';
import '../../services/import_service.dart';
import '../../services/search_service.dart';

// ---- Persistence ----

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences not initialized');
});

// ---- Database ----

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
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
  final config = ref.watch(colorExtractionConfigProvider);
  final scheduler = AnalysisQueueScheduler(
    queueDao: ref.read(queueDaoProvider),
    memeRepo: ref.read(memeRepositoryProvider),
    colorExtractor: ColorExtractor(defaultConfig: config),
    storage: ref.read(fileStorageServiceProvider),
    log: ref.read(logServiceProvider),
  );

  // 同步颜色提取配置到调度器（运行时修改会即时生效）
  scheduler.setColorExtractionConfig(config);

  // 监听配置变化并同步
  ref.listen<ColorExtractionConfig>(colorExtractionConfigProvider, (_, next) {
    scheduler.setColorExtractionConfig(next);
  });

  final enricher = ref.watch(llmEnricherProvider);
  if (enricher != null) {
    scheduler.setLlmEnricher(enricher);
  }

  scheduler.setOcrEnabled(ref.read(ocrEnabledProvider));
  scheduler.setLlmEnabled(ref.read(llmEnabledProvider));

  scheduler.start();

  ref.onDispose(() {
    scheduler.stop();
  });

  return scheduler;
});

// ---- LLM ----

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

final llmServiceProvider = Provider<LlmService?>((ref) {
  final config = ref.watch(llmConfigProvider);
  switch (config.provider) {
    case LlmProviderType.openai:
      return OpenAiLlmService(
        baseUrl: config.baseUrl,
        apiKey: config.apiKey,
        model: config.model,
      );
    case LlmProviderType.ollama:
      return OllamaLlmService(
        baseUrl: config.baseUrl,
        model: config.model,
      );
  }
});

final llmEnricherProvider = Provider<LlmEnricher?>((ref) {
  final llm = ref.watch(llmServiceProvider);
  final repo = ref.watch(memeRepositoryProvider);
  if (llm == null || !llm.isAvailable) return null;
  return LlmEnricher(llm: llm, repo: repo);
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
  final service = S3SyncService(
    memeRepo: ref.read(memeRepositoryProvider),
    storage: ref.read(fileStorageServiceProvider),
  );
  final config = ref.read(s3ConfigProvider).valueOrNull;
  if (config != null) {
    service.updateConfig(config);
  }
  return service;
});

// ---- Gallery State ----

final memeListProvider = FutureProvider<List<Meme>>((ref) {
  return ref.read(memeRepositoryProvider).getAll();
});

final memeCountProvider = FutureProvider<int>((ref) {
  return ref.read(memeRepositoryProvider).count();
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

final memesByAlbumProvider = FutureProvider.family<List<Meme>, String>((ref, albumId) async {
  final albumDao = ref.read(albumDaoProvider);
  final memeIds = await albumDao.getMemeIdsByAlbum(albumId);
  if (memeIds.isEmpty) return [];
  final allMemes = await ref.watch(memeListProvider.future);
  final idSet = memeIds.toSet();
  return allMemes.where((m) => idSet.contains(m.id)).toList();
});
