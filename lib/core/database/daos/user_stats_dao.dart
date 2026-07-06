import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/user_stats_table.dart';

/// 用户统计 DAO
class UserStatsDao {
  final AppDatabase _db;
  UserStatsDao(this._db);

  /// 获取指定日期的统计
  Future<UserStatsEntry?> getByDate(String date) async {
    return await (_db.select(_db.userStatsTable)
          ..where((t) => t.date.equals(date)))
        .getSingleOrNull();
  }

  /// 获取最近 N 天的统计
  Future<List<UserStatsEntry>> getRecentDays(int days) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    final startStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    return await (_db.select(_db.userStatsTable)
          ..where((t) => t.date.isBiggerOrEqualValue(startStr))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// 获取指定日期范围内的统计（含两端）
  Future<List<UserStatsEntry>> getByDateRange(DateTime start, DateTime end) async {
    final startStr =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    return await (_db.select(_db.userStatsTable)
          ..where((t) => t.date.isBetweenValues(startStr, endStr))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// 获取所有统计
  Future<List<UserStatsEntry>> getAll() async {
    return await (_db.select(_db.userStatsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// 增加导入计数
  Future<void> incrementImported() async {
    await _incrementField('importedCount');
  }

  /// 增加复制计数 (可指定次数)
  Future<void> incrementCopied({int count = 1}) async {
    for (int i = 0; i < count; i++) {
      await _incrementField('copiedCount');
    }
  }

  /// 增加收藏计数
  Future<void> incrementFavorited() async {
    await _incrementField('favoritedCount');
  }

  /// 增加 token 用量（累加模式）
  Future<void> incrementTokens({required int prompt, required int completion}) async {
    final today = _today();
    final existing = await getByDate(today);
    if (existing != null) {
      await (_db.update(_db.userStatsTable)
            ..where((t) => t.date.equals(today)))
          .write(UserStatsTableCompanion(
            promptTokens: Value(existing.promptTokens + prompt),
            completionTokens: Value(existing.completionTokens + completion),
          ));
    } else {
      await _db.into(_db.userStatsTable).insert(UserStatsEntry(
            date: today,
            importedCount: 0,
            copiedCount: 0,
            favoritedCount: 0,
            promptTokens: prompt,
            completionTokens: completion,
          ));
    }
  }

  /// 通用字段递增
  Future<void> _incrementField(String field) async {
    final today = _today();
    final existing = await getByDate(today);
    if (existing != null) {
      final newValue = _getField(existing, field) + 1;
      await (_db.update(_db.userStatsTable)
            ..where((t) => t.date.equals(today)))
          .write(_toCompanion(field, newValue));
    } else {
      final map = <String, int>{'importedCount': 0, 'copiedCount': 0, 'favoritedCount': 0, 'promptTokens': 0, 'completionTokens': 0};
      map[field] = 1;
      await _db.into(_db.userStatsTable).insert(UserStatsEntry(
            date: today,
            importedCount: map['importedCount']!,
            copiedCount: map['copiedCount']!,
            favoritedCount: map['favoritedCount']!,
            promptTokens: map['promptTokens']!,
            completionTokens: map['completionTokens']!,
          ));
    }
  }

  /// 获取今天的总数（无则创建默认条目）
  Future<UserStatsEntry> getOrCreateToday() async {
    final today = _today();
    final existing = await getByDate(today);
    if (existing != null) return existing;
    final entry = UserStatsEntry(
      date: today,
      importedCount: 0,
      copiedCount: 0,
      favoritedCount: 0,
      promptTokens: 0,
      completionTokens: 0,
    );
    await _db.into(_db.userStatsTable).insert(entry);
    return entry;
  }

  /// 累计总数
  Future<Map<String, int>> getTotals() async {
    final result = await _db.customSelect('''
      SELECT 
        COALESCE(SUM(imported_count), 0) as total_imported,
        COALESCE(SUM(copied_count), 0) as total_copied,
        COALESCE(SUM(favorited_count), 0) as total_favorited,
        COALESCE(SUM(prompt_tokens), 0) as total_prompt_tokens,
        COALESCE(SUM(completion_tokens), 0) as total_completion_tokens
      FROM user_stats_table
    ''').getSingle();
    return {
      'totalImported': result.data['total_imported'] as int,
      'totalCopied': result.data['total_copied'] as int,
      'totalFavorited': result.data['total_favorited'] as int,
      'totalPromptTokens': result.data['total_prompt_tokens'] as int,
      'totalCompletionTokens': result.data['total_completion_tokens'] as int,
    };
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _getField(UserStatsEntry entry, String field) {
    switch (field) {
      case 'importedCount':
        return entry.importedCount;
      case 'copiedCount':
        return entry.copiedCount;
      case 'favoritedCount':
        return entry.favoritedCount;
      default:
        return 0;
    }
  }

  UserStatsTableCompanion _toCompanion(String field, int value) {
    switch (field) {
      case 'importedCount':
        return UserStatsTableCompanion(importedCount: Value(value));
      case 'copiedCount':
        return UserStatsTableCompanion(copiedCount: Value(value));
      case 'favoritedCount':
        return UserStatsTableCompanion(favoritedCount: Value(value));
      default:
        return UserStatsTableCompanion();
    }
  }
}
