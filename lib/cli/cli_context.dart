import '../core/database/database.dart';
import '../core/repositories/album_repository.dart';
import '../core/repositories/meme_repository.dart';
import '../services/file_storage_service.dart';
import '../services/import_service.dart';
import '../services/meme_export_service.dart';
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
    this.jsonOutput = false,
  });
}
