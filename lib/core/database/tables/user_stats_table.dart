import 'package:drift/drift.dart';

/// 用户统计表 - 按天记录用户行为统计
@DataClassName('UserStatsEntry')
class UserStatsTable extends Table {
  /// 日期字符串（yyyy-MM-dd）
  TextColumn get date => text()();

  /// 当天导入 meme 数量
  IntColumn get importedCount => integer().withDefault(const Constant(0))();

  /// 当天复制 meme 次数
  IntColumn get copiedCount => integer().withDefault(const Constant(0))();

  /// 当天收藏 meme 数量
  IntColumn get favoritedCount => integer().withDefault(const Constant(0))();

  /// 当天 remote LLM 调用 prompt token 数
  IntColumn get promptTokens => integer().withDefault(const Constant(0))();

  /// 当天 remote LLM 调用 completion token 数
  IntColumn get completionTokens => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {date};
}
