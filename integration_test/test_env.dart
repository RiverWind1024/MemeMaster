import 'dart:io';

import 'package:drift/native.dart';
import 'package:image/image.dart' as img;
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/image/color_extractor.dart';
import 'package:mememaster/core/repositories/album_repository.dart';
import 'package:mememaster/core/repositories/color_repository.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:mememaster/services/file_storage_service.dart';
import 'package:mememaster/services/import_service.dart';
import 'package:mememaster/services/meme_export_service.dart';
import 'package:mememaster/services/search_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// 集成测试环境：临时数据库 + 临时存储目录 + 真实服务。
///
/// 每次 create() 都新建独立临时目录，tearDown 时 dispose() 清理。
class TestEnv {
  late final Directory root;
  late final AppDatabase db;
  late final FileStorageService storage;
  late final MemeRepository memeRepo;
  late final AlbumRepository albumRepo;
  late final ColorExtractor colorExtractor;
  late final ImportService importService;
  late final SearchService searchService;
  late final MemeExportService exportService;

  String get srcDir => p.join(root.path, 'src');
  String get storageDir => p.join(root.path, 'storage');

  static Future<TestEnv> create() async {
    final env = TestEnv();
    env.root = await Directory.systemTemp.createTemp('meme_helper_it_');
    await Directory(env.srcDir).create(recursive: true);
    await Directory(env.storageDir).create(recursive: true);

    env.db = AppDatabase(
      NativeDatabase.opened(sqlite3.sqlite3.open(p.join(env.root.path, 'test.db'))),
    );
    env.storage = FileStorageService(basePath: env.storageDir);
    env.memeRepo = MemeRepository(
      memeDao: env.db.memeDao,
      tagDao: env.db.tagDao,
      colorDao: env.db.colorDao,
      queueDao: env.db.analysisQueueDao,
    );
    env.albumRepo = AlbumRepository(env.db.albumDao);
    env.colorExtractor = const ColorExtractor();
    env.importService = ImportService(
      memeRepo: env.memeRepo,
      storage: env.storage,
      userStatsDao: env.db.userStatsDao,
    );
    env.searchService = SearchService(
      memeRepo: env.memeRepo,
      colorRepo: ColorRepository(env.db.colorDao),
    );
    env.exportService = MemeExportService(
      memeRepo: env.memeRepo,
      storage: env.storage,
    );
    return env;
  }

  Future<void> dispose() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  /// 生成一张纯色 PNG 测试图片，返回路径。
  Future<String> createImage({
    required String name,
    required List<int> rgb,
  }) async {
    final image = img.Image(width: 64, height: 64);
    img.fill(image, color: img.ColorRgb8(rgb[0], rgb[1], rgb[2]));
    final path = p.join(srcDir, name);
    await File(path).writeAsBytes(img.encodePng(image));
    return path;
  }
}
