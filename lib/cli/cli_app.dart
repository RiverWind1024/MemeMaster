import 'dart:io';

import 'package:args/args.dart';

import '../core/database/database.dart';
import '../core/repositories/album_repository.dart';
import '../core/repositories/color_repository.dart';
import '../core/repositories/meme_repository.dart';
import '../services/file_storage_service.dart';
import '../services/import_service.dart';
import '../services/meme_export_service.dart';
import '../services/search_service.dart';
import 'cli_config_store.dart';
import 'cli_context.dart';
import 'command_parser.dart';
import 'commands/albums_command.dart';
import 'commands/analyze_command.dart';
import 'commands/command.dart';
import 'commands/config_command.dart';
import 'commands/export_command.dart';
import 'commands/get_command.dart';
import 'commands/help_command.dart';
import 'commands/import_command.dart';
import 'commands/list_command.dart';
import 'commands/reindex_command.dart';
import 'commands/s3_command.dart';
import 'commands/search_command.dart';
import 'commands/stats_command.dart';
import 'commands/tags_command.dart';
import 'commands/unimplemented_command.dart';

/// CLI 应用：解析全局参数 → 组装上下文 → 分发到子命令。
class CliApp {
  /// 配置文件路径（测试注入临时路径；null 用默认 ~/.config/mememaster/cli_config.json）。
  final String? configPath;

  CliApp({this.configPath});

  Future<int> run(List<String> args) async {
    final parser = CommandParser(cliCommandNames);
    final store = CliConfigStore(configPath: configPath);
    final commands = _buildCommands(() => parser.usage, store);

    final ArgResults results;
    try {
      results = parser.parse(args);
    } on FormatException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(parser.usage);
      return 1;
    }

    final commandName = results.command?.name;

    // --help / help 子命令：打印帮助（不打开数据库，避免副作用）
    if (results.wasParsed('help') || commandName == 'help') {
      print(parser.usage);
      return 0;
    }

    // 无子命令：有残余参数说明是不认识的子命令，否则打印帮助
    if (commandName == null) {
      if (results.rest.isNotEmpty) {
        stderr.writeln('未知子命令: ${results.rest.first}');
        stderr.writeln(parser.usage);
        return 1;
      }
      print(parser.usage);
      return 0;
    }

    final command = commands[commandName];
    if (command == null) {
      stderr.writeln('未知子命令: $commandName');
      stderr.writeln(parser.usage);
      return 1;
    }

    // 占位命令：直接短路，不打开数据库、不组装上下文
    if (command is UnimplementedCommand) {
      stderr.writeln(command.unimplementedMessage);
      return 1;
    }

    final commandResults = results.command!;
    final jsonOutput =
        results.wasParsed('json') || commandResults.wasParsed('json');

    // config 命令：不依赖数据库，直接短路（避免触碰 ~/Documents 默认库）
    if (command is ConfigCommand) {
      return command.execute(commandResults, jsonOutput: jsonOutput);
    }

    final dbPath = CommandParser.expandPath(
      _globalOption(results, commandResults, 'db'),
    );
    final storagePath = CommandParser.expandPath(
      _globalOption(results, commandResults, 'storage'),
    );

    // 仅对需要配置的命令加载 cli_config.json（避免无关命令触碰 ~/.config）
    final cliConfig =
        command.needsCliConfig ? await store.load() : const CliConfig();

    final db = AppDatabase.open(dbPath);
    try {
      final context = _buildContext(
        db,
        storagePath,
        cliConfig,
        jsonOutput: jsonOutput,
      );
      return await command.run(context, commandResults);
    } finally {
      await db.close();
    }
  }

  /// 取值：优先子命令显式提供的全局参数，否则回退根 parser 的默认值。
  String _globalOption(ArgResults root, ArgResults command, String name) {
    if (command.wasParsed(name)) return command[name] as String;
    return root[name] as String;
  }

  /// 组装 CLI 上下文（复用纯 Dart 引擎层，与 GUI 共用同一数据库）。
  CliContext _buildContext(AppDatabase db, String storagePath, CliConfig cliConfig,
      {bool jsonOutput = false}) {
    final storage = FileStorageService(basePath: storagePath);
    final memeRepo = MemeRepository(
      memeDao: db.memeDao,
      tagDao: db.tagDao,
      colorDao: db.colorDao,
      queueDao: db.analysisQueueDao,
      fileStorage: storage,
    );
    final colorRepo = ColorRepository(db.colorDao);
    final albumRepo = AlbumRepository(db.albumDao);

    return CliContext(
      db: db,
      memeRepo: memeRepo,
      albumRepo: albumRepo,
      storage: storage,
      importService: ImportService(
        memeRepo: memeRepo,
        storage: storage,
        userStatsDao: db.userStatsDao,
      ),
      searchService: SearchService(memeRepo: memeRepo, colorRepo: colorRepo),
      exportService: MemeExportService(memeRepo: memeRepo, storage: storage),
      llmConfig: cliConfig.llm,
      s3Config: cliConfig.s3,
      jsonOutput: jsonOutput,
    );
  }

  Map<String, CliCommand> _buildCommands(
      String Function() usage, CliConfigStore store) {
    final commands = <String, CliCommand>{
      for (final name in cliCommandNames)
        name: UnimplementedCommand(
          name: name,
          description: cliCommandDescriptions[name] ?? '',
        ),
      'import': ImportCommand(),
      'list': ListCommand(),
      'get': GetCommand(),
      'search': SearchCommand(),
      'export': ExportCommand(),
      'tags': TagsCommand(),
      'albums': AlbumsCommand(),
      'analyze': AnalyzeCommand(),
      's3': S3Command(),
      'reindex': ReindexCommand(),
      'stats': StatsCommand(),
      'config': ConfigCommand(store),
      'help': HelpCommand(usage),
    };
    return commands;
  }
}
