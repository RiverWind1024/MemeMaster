/// 搜索能力级别，根据已有数据自动降级。
///
/// - L3: 语义 + 关键词 + 颜色（需要 embedding 模型）
/// - L2: 关键词 + 颜色（需要 OCR/LLM 标签）
/// - L1: 仅颜色 + 文件名（最基础）
/// - L0: 仅文件名浏览
enum SearchLevel {
  semantic(3),
  keyword(2),
  color(1),
  browse(0);

  final int rank;
  const SearchLevel(this.rank);

  bool get canSearchSemantic => this == SearchLevel.semantic;
  bool get canSearchKeyword => this == SearchLevel.semantic || this == SearchLevel.keyword;
  bool get canSearchColor => this != SearchLevel.browse;
  bool get canBrowse => true;

  static SearchLevel fromRank(int rank) {
    return SearchLevel.values.firstWhere(
      (e) => e.rank == rank,
      orElse: () => SearchLevel.browse,
    );
  }
}
