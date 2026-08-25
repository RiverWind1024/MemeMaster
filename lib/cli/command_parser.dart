import 'dart:io';

import 'package:args/args.dart';

/// 全部子命令名。
const List<String> cliCommandNames = [
  'import',
  'list',
  'get',
  'search',
  'export',
  'tags',
  'albums',
  's3',
  'reindex',
  'stats',
  'config',
  'analyze',
  'help',
];

/// 各子命令简介（帮助信息用）。
const Map<String, String> cliCommandDescriptions = {
  'import': '导入图片',
  'list': '列出所有 meme',
  'get': '查看单个 meme 详情',
  'search': '搜索（关键词/颜色）',
  'export': '导出为 zip 数据包',
  'tags': '管理标签',
  'albums': '管理相册',
  's3': 'S3 同步相关操作',
  'reindex': '重新索引分析',
  'stats': '统计信息',
  'config': '查看/修改配置',
  'analyze': '分析 meme（颜色/OCR/AI）',
  'help': '显示帮助信息',
};

/// 全局默认参数：与 GUI 共用同一数据库/存储目录。
const String defaultDbPath = '~/Documents/meme_helper.db';
const String defaultStoragePath = '~/Documents/memes';

/// 命令行解析：全局参数 + 子命令。
class CommandParser {
  final ArgParser parser;
  final List<String> _commandNames;

  CommandParser(List<String> commandNames)
      : parser = _buildParser(commandNames),
        _commandNames = List.unmodifiable(commandNames);

  /// 构建根 parser：全局参数 + 每个子命令。
  ///
  /// 全局参数同时在子命令 parser 上注册（无默认值），
  /// 使 `list --db xxx`（全局参数在子命令后）也能解析；
  /// 取值时优先子命令显式提供的值，否则回退根 parser 的默认值。
  static ArgParser _buildParser(List<String> commandNames) {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: '显示帮助')
      ..addOption('db',
          defaultsTo: defaultDbPath,
          help: 'SQLite 数据库路径（默认 $defaultDbPath）')
      ..addOption('storage',
          defaultsTo: defaultStoragePath,
          help: '图片存储根目录（默认 $defaultStoragePath）')
      ..addFlag('json', negatable: false, help: 'JSON 输出');
    for (final name in commandNames) {
      final cmd = parser.addCommand(name);
      _addGlobalOptions(cmd);
      _addCommandOptions(cmd, name);
    }
    return parser;
  }

  static void _addGlobalOptions(ArgParser parser) {
    parser
      ..addOption('db', help: 'SQLite 数据库路径')
      ..addOption('storage', help: '图片存储根目录')
      ..addFlag('json', negatable: false, help: 'JSON 输出');
  }

  /// 注册子命令专属参数。
  static void _addCommandOptions(ArgParser cmd, String name) {
    switch (name) {
      case 'import':
        cmd
          ..addOption('source', help: '来源标记（如 clipboard, wechat, album）')
          ..addFlag('recursive', negatable: false, help: '递归扫描目录');
        break;
      case 'list':
        cmd.addOption('limit', help: '限制返回条数');
        break;
      case 'search':
        cmd
          ..addOption('color', help: '颜色搜索（#RRGGBB）')
          ..addOption('limit', help: '限制返回条数');
        break;
      case 'export':
        cmd
          ..addOption('ids', help: '导出的 meme id（逗号分隔）')
          ..addFlag('all', negatable: false, help: '导出全部')
          ..addOption('output', help: '输出 zip 路径');
        break;
      case 'tags':
        cmd.addOption('source', help: '标签来源（默认 custom）');
        break;
      case 'analyze':
        cmd
          ..addFlag('all', negatable: false, help: '分析全部 meme')
          ..addFlag('color', negatable: false, help: '仅提取颜色')
          ..addFlag('ocr', negatable: false, help: '仅 OCR 识别')
          ..addFlag('ai', negatable: false, help: '仅 AI 分析');
        break;
    }
  }

  ArgResults parse(List<String> args) => parser.parse(args);

  /// 帮助文本：全局参数 + 子命令列表。
  String get usage {
    final buffer = StringBuffer()
      ..writeln('MemeMaster - 表情包管理 CLI')
      ..writeln()
      ..writeln('用法: mememaster <子命令> [参数]')
      ..writeln()
      ..writeln('全局参数:')
      ..writeln(parser.usage)
      ..writeln('子命令:');
    for (final name in _commandNames) {
      buffer.writeln('  ${name.padRight(10)}${cliCommandDescriptions[name] ?? ''}');
    }
    return buffer.toString().trimRight();
  }

  /// 展开 ~ 前缀为用户主目录（无 HOME 时原样返回）。
  static String expandPath(String path) {
    if (path == '~') return Platform.environment['HOME'] ?? path;
    if (path.startsWith('~/')) {
      final home = Platform.environment['HOME'];
      if (home != null) return '$home${path.substring(1)}';
    }
    return path;
  }
}
