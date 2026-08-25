import '../core/database/database.dart';
import '../core/llm/config.dart';
import '../core/repositories/album_repository.dart';
import '../core/repositories/meme_repository.dart';
import '../services/file_storage_service.dart';
import '../services/import_service.dart';
import '../services/meme_export_service.dart';
import '../services/s3_config.dart';
import '../services/search_service.dart';

/// CLI 上下文：持有组装好的引擎层对象，供各子命令使用。
class CliContext {
  final AppDatabase db;
  final MemeRepository memeRepo;
  final AlbumRepository albumRepo;
  final FileStorageService storage;
  final ImportService importService;
  final SearchService searchService;
  final MemeExportService exportService;

  /// LLM 配置（从 cli_config.json 加载，未配置时为默认值）
  final LlmConfig llmConfig;

  /// S3 配置（从 cli_config.json 加载，未配置时为默认值）
  final S3Config s3Config;

  /// 是否以 JSON 输出（由 CliApp 依据全局/子命令 --json 解析）
  final bool jsonOutput;

  CliContext({
    required this.db,
    required this.memeRepo,
    required this.albumRepo,
    required this.storage,
    required this.importService,
    required this.searchService,
    required this.exportService,
    this.llmConfig = const LlmConfig(),
    this.s3Config = const S3Config(),
    this.jsonOutput = false,
  });
}
