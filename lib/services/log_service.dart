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

/// 带文件持久化的日志服务。
///
/// 日志以 JSON-Lines 格式追加写入 [logFilePath]，
/// 重启应用后自动恢复上一次会话的日志。
class LogService {
  static const int maxEntries = 1000;
  final Queue<LogEntry> _entries = Queue();

  /// 持久化文件路径，null = 不持久化（纯内存）
  String? logFilePath;

  LogService({this.logFilePath}) {
    _loadFromFile();
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
  }
}
