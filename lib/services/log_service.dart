import 'dart:collection';
import 'dart:convert';
import 'dart:io';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  String get formattedTimestamp {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'level': level.name,
        'tag': tag,
        'msg': message,
      };

  static LogEntry? fromJson(Map<String, dynamic> json) {
    try {
      return LogEntry(
        timestamp: DateTime.parse(json['ts'] as String),
        level: LogLevel.values.byName(json['level'] as String),
        tag: json['tag'] as String,
        message: json['msg'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 带文件持久化的日志服务（单例）。
///
/// 日志以 JSON-Lines 格式追加写入 [logFilePath]，
/// 重启应用后自动恢复上一次会话的日志。
///
/// 使用前必须调用 [LogService.init] 初始化（通常在 Riverpod Provider 中）。
/// 之后通过 [LogService.instance] 获取全局唯一的单例实例。
class LogService {
  static const int maxEntries = 1000;
  final Queue<LogEntry> _entries = Queue();

  /// 持久化文件路径，null = 不持久化（纯内存）
  String? logFilePath;

  /// C++ 端 mllm_init 写入的日志文件路径（plain 格式）
  String? mllmLogPath;

  // ---- 单例 ----

  static LogService? _instance;

  /// 全局单例。未初始化时返回一个纯内存实例（不会崩溃）。
  static LogService get instance => _instance ??= LogService._();

  /// 初始化全局单例并配置持久化路径。
  /// 通常在 Riverpod Provider 中调用一次即可。
  static void init({String? logFilePath, String? mllmLogPath}) {
    final existing = _instance;
    if (existing != null) {
      // 已有实例，更新路径并重新加载
      existing.logFilePath = logFilePath;
      existing.mllmLogPath = mllmLogPath;
      existing._loadFromFile();
      existing.loadMllmLog(mllmLogPath);
    } else {
      _instance = LogService._(logFilePath: logFilePath, mllmLogPath: mllmLogPath);
    }
  }

  LogService._({this.logFilePath, this.mllmLogPath}) {
    _loadFromFile();
    loadMllmLog(mllmLogPath);
  }

  /// @Deprecated 使用 [LogService.instance] 代替
  factory LogService({String? logFilePath, String? mllmLogPath}) {
    init(logFilePath: logFilePath, mllmLogPath: mllmLogPath);
    return _instance!;
  }

  // ---- 持久化 ----

  void _loadFromFile() {
    final path = logFilePath;
    if (path == null) return;
    try {
      final file = File(path);
      if (!file.existsSync()) return;

      final lines = file.readAsLinesSync();
      // 从尾部加载，保留最新 maxEntries 条
      for (int i = lines.length - 1; i >= 0; i--) {
        if (_entries.length >= maxEntries) break;
        try {
          final json = jsonDecode(lines[i]) as Map<String, dynamic>;
          final entry = LogEntry.fromJson(json);
          if (entry != null) _entries.addFirst(entry);
        } catch (_) {}
      }
    } catch (_) {
      // 文件读取失败不影响内存日志
    }
  }

  void _appendToFile(LogLevel level, String tag, String message) {
    final path = logFilePath;
    if (path == null) return;
    try {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        tag: tag,
        message: message,
      );
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('${jsonEncode(entry.toJson())}\n',
          mode: FileMode.append);
    } catch (_) {
      // 持久化失败不影响内存日志
    }
  }

  // ---- 日志写入 ----

  void info(String tag, String message) => _add(LogLevel.info, tag, message);
  void warning(String tag, String message) =>
      _add(LogLevel.warning, tag, message);
  void error(String tag, String message) =>
      _add(LogLevel.error, tag, message);

  void _add(LogLevel level, String tag, String message) {
    _entries.add(LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    ));
    _appendToFile(level, tag, message);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }

  // ---- 读取 & 清理 ----

  List<LogEntry> get logs => _entries.toList();

  void clear() {
    _entries.clear();
    final path = logFilePath;
    if (path != null) {
      try {
        File(path).writeAsStringSync('');
      } catch (_) {}
    }
    // 同时清空 C++ 端 mllm.log，方便重新观察新一轮启动日志
    final mllmPath = mllmLogPath;
    if (mllmPath != null) {
      try {
        File(mllmPath).writeAsStringSync('');
      } catch (_) {}
    }
  }

  /// 只重新加载 mllm.log（不清空 LogService 自身的 app.log 内存项）
  void reloadMllmLog() {
    if (mllmLogPath == null) return;
    loadMllmLog(mllmLogPath);
  }

  // ---- C++ mllm.log 读取 ----

  /// 从 C++ 端写入的 mllm.log 文件加载历史日志。
  /// 文件格式（每行）：I/W/E HH:MM:SS.mmm <msg>
  /// 追加到 _entries 末尾，不去重（保证完整历史）。
  void loadMllmLog(String? mllmLogPath) {
    if (mllmLogPath == null) return;
    final file = File(mllmLogPath);
    if (!file.existsSync()) return;
    try {
      final lines = file.readAsLinesSync();
      // 从尾部加载，保留最新 maxEntries 条
      for (int i = lines.length - 1; i >= 0; i--) {
        if (_entries.length >= maxEntries) break;
        final entry = _parseMllmLogLine(lines[i]);
        if (entry != null) _entries.addFirst(entry);
      }
    } catch (_) {
      // 文件读取失败不影响其他日志
    }
  }

  /// 解析一行 mllm.log，格式 "I/W/E HH:MM:SS.mmm <msg>"，无法解析返回 null。
  /// 若行以 "=== " 开头（session 分隔），作为 info 级别返回。
  static LogEntry? _parseMllmLogLine(String line) {
    if (line.isEmpty) return null;
    LogLevel level;
    int prefixLen;
    if (line.startsWith('E ')) {
      level = LogLevel.error;
      prefixLen = 2;
    } else if (line.startsWith('W ')) {
      level = LogLevel.warning;
      prefixLen = 2;
    } else if (line.startsWith('I ')) {
      level = LogLevel.info;
      prefixLen = 2;
    } else if (line.startsWith('=== ')) {
      level = LogLevel.info;
      prefixLen = 0;
    } else {
      return null;
    }
    final rest = line.substring(prefixLen);
    // rest 形如 "HH:MM:SS.mmm <msg>" 或 "<msg>"
    final spaceIdx = rest.indexOf(' ');
    final tsPart = spaceIdx > 0 ? rest.substring(0, spaceIdx) : '';
    final msg = spaceIdx > 0 ? rest.substring(spaceIdx + 1) : rest;
    DateTime ts;
    final parsed = DateTime.tryParse('1970-01-01T$tsPart');
    if (parsed != null) {
      // 用 1970-01-01 作占位日期，只保留时间部分
      final now = DateTime.now();
      ts = DateTime(now.year, now.month, now.day,
          parsed.hour, parsed.minute, parsed.second, parsed.millisecond);
    } else {
      ts = DateTime.now();
    }
    return LogEntry(
      timestamp: ts,
      level: level,
      tag: 'mllm',
      message: msg,
    );
  }
}
