import 'dart:math';

import '../core/database/database.dart';
import '../core/repositories/color_repository.dart';
import '../core/repositories/meme_repository.dart';
import '../core/utils/color_utils.dart';

/// 搜索结果项
class SearchResult {
  final Meme meme;
  final double relevance;

  const SearchResult({required this.meme, required this.relevance});
}

/// 搜索级别（自动降级）
enum SearchLevel {
  /// L3: 语义 + 颜色 + 关键词（全功能，需 LLM + Embedding 模型）
  full,

  /// L2: 颜色 + 关键词（需颜色数据 + 标签数据）
  colorAndKeyword,

  /// L1: 仅颜色搜索
  colorOnly,

  /// L0: 浏览模式（无模型、无颜色数据时）
  browse,
}

/// 搜索服务
class SearchService {
  final MemeRepository _memeRepo;
  final ColorRepository _colorRepo;

  SearchService({
    required this._memeRepo,
    required this._colorRepo,
  });

  /// 综合搜索：文本 + 颜色同时生效，叠加过滤
  Future<List<SearchResult>> search({
    String query = '',
    List<ColorRgb>? colors,
    int limit = 50,
  }) async {
    final futures = <Future<List<SearchResult>>>[];

    // 文本搜索
    if (query.trim().isNotEmpty) {
      futures.add(_searchByText(query.trim()));
    }

    // 颜色搜索
    if (colors != null && colors.isNotEmpty) {
      for (final color in colors) {
        futures.add(searchByColor(color, limit: limit));
      }
    }

    // 无任何条件 → 浏览模式
    if (futures.isEmpty) {
      return _browseMode(limit);
    }

    // 合并结果
    final results = await Future.wait(futures);
    return _mergeResults(results, query.isNotEmpty, colors != null && colors.isNotEmpty);
  }

  /// 合并多个搜索结果：取交集 + 加权排序
  List<SearchResult> _mergeResults(
    List<List<SearchResult>> allResults,
    bool hasText,
    bool hasColor,
  ) {
    if (allResults.length == 1) {
      return allResults.first;
    }

    // 每个 meme 的累积分数
    final scores = <String, double>{};
    final memes = <String, Meme>{};

    if (hasText && hasColor) {
      // 文本 + 颜色：取交集（同时出现在两边的 meme），分数相乘
      final textMemeIds = <String>{};
      final colorMemeIds = <String>{};

      for (var i = 0; i < allResults.length; i++) {
        for (final r in allResults[i]) {
          memes[r.meme.id] = r.meme;
          if (i == 0) {
            // 第一个是文本结果
            textMemeIds.add(r.meme.id);
          } else {
            colorMemeIds.add(r.meme.id);
          }
        }
      }

      // 交集：必须同时匹配文本和颜色
      final intersection = textMemeIds.intersection(colorMemeIds);
      for (final id in intersection) {
        double score = 0;
        for (final list in allResults) {
          for (final r in list) {
            if (r.meme.id == id) {
              score += r.relevance;
            }
          }
        }
        // 归一化
        scores[id] = score / allResults.length;
      }

      // 如果交集太少(<3)，补充仅有文本或仅有颜色的结果
      if (intersection.length < 3) {
        final union = textMemeIds.union(colorMemeIds);
        for (final id in union) {
          if (!intersection.contains(id)) {
            double score = 0;
            for (final list in allResults) {
              for (final r in list) {
                if (r.meme.id == id) {
                  score = max(score, r.relevance * 0.5);
                }
              }
            }
            scores[id] = (scores[id] ?? 0) + score;
          }
        }
      }
    } else {
      // 多个颜色（无文本）：分数累加平均
      for (final list in allResults) {
        for (final r in list) {
          memes[r.meme.id] = r.meme;
          scores[r.meme.id] = (scores[r.meme.id] ?? 0) + r.relevance;
        }
      }
      // 归一化
      for (final id in scores.keys.toList()) {
        scores[id] = scores[id]! / allResults.length;
      }
    }

    // 排序
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .where((e) => e.value > 0)
        .map((e) => SearchResult(meme: memes[e.key]!, relevance: e.value))
        .toList();
  }

  /// 文本搜索：优先语义（TODO），降级为关键词+标签
  Future<List<SearchResult>> _searchByText(String query) async {
    // TODO: 当 Embedding 模型可用时，使用语义搜索
    // 目前实现关键词搜索：tags + filename + description

    final memeIds = <String, double>{};

    // 1. 搜索标签表（OCR/LLM 生成的内容）
    final tagResults = await _memeRepo.searchByTagContent(query);
    for (final meme in tagResults) {
      memeIds[meme.id] = max(memeIds[meme.id] ?? 0, 0.9);
    }

    // 2. 搜索文件名和描述（memes 表）
    final keywordResults = await _memeRepo.searchByKeyword(query);
    for (final meme in keywordResults) {
      memeIds[meme.id] = max(memeIds[meme.id] ?? 0, 0.8);
    }

    // 3. 搜索文件名（额外确保文件名匹配到）
    final filenameResults = await _memeRepo.searchByFilename(query);
    for (final meme in filenameResults) {
      memeIds[meme.id] = max(memeIds[meme.id] ?? 0, 0.7);
    }

    if (memeIds.isEmpty) return [];

    // 加载 meme 数据，按分数排序
    final results = <SearchResult>[];
    for (final entry in memeIds.entries) {
      final meme = await _memeRepo.getById(entry.key);
      if (meme != null) {
        results.add(SearchResult(meme: meme, relevance: entry.value));
      }
    }

    results.sort((a, b) => b.relevance.compareTo(a.relevance));
    return results;
  }

  /// 按颜色搜索
  Future<List<SearchResult>> searchByColor(ColorRgb targetColor,
      {int limit = 50}) async {
    final targetLab = rgbToLab(targetColor);

    final matchedColors = await _colorRepo.searchByColor(
      targetL: targetLab.l,
      targetA: targetLab.a,
      targetB: targetLab.b,
      limit: limit,
    );

    // 去重 memeId，保留最小色差
    final memeDistances = <String, double>{};
    for (final c in matchedColors) {
      final de = deltaE(
        targetLab,
        ColorLab(c.labL, c.labA, c.labB),
      );
      final existing = memeDistances[c.memeId];
      if (existing == null || de < existing) {
        memeDistances[c.memeId] = de;
      }
    }

    final results = <SearchResult>[];
    for (final entry in memeDistances.entries) {
      final meme = await _memeRepo.getById(entry.key);
      if (meme != null) {
        final relevance = 1.0 / (1.0 + entry.value);
        results.add(SearchResult(meme: meme, relevance: relevance));
      }
    }

    results.sort((a, b) => b.relevance.compareTo(a.relevance));
    return results;
  }

  /// 浏览模式：最近导入
  Future<List<SearchResult>> _browseMode(int limit) async {
    final memes = await _memeRepo.getAll(limit: limit);
    return memes
        .map((m) => SearchResult(meme: m, relevance: 1.0))
        .toList();
  }

  /// 检测当前可用的搜索级别
  Future<SearchLevel> detectLevel() async {
    final memeCount = await _memeRepo.count();
    if (memeCount == 0) return SearchLevel.browse;

    // 检查是否有颜色数据
    final colorMemeIds = await _colorRepo.getAllMemeIds();
    if (colorMemeIds.isEmpty) return SearchLevel.browse;

    // 检查是否有 OCR/标签数据
    final ocrTagCount = await _memeRepo.countTagsBySource('ocr');
    final llmTagCount = await _memeRepo.countTagsBySource('llm');
    if (ocrTagCount + llmTagCount > 0) {
      return SearchLevel.colorAndKeyword;
    }

    return SearchLevel.colorOnly;
  }
}
