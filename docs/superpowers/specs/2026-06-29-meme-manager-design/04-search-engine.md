# MemeHelper 搜索引擎设计

> 所属项目: MemeHelper
> 文档编号: 04-search-engine.md
> 涉及: 向量语义搜索、颜色搜索、混合排序

---

## 1. 搜索系统总览

### 1.0 智能降级 (Graceful Degradation)

搜索引擎根据当前可用数据自动调整搜索能力，无需用户手动选择"模式"：

```
用户输入: "悲伤的青蛙表情"
    │
    ▼
┌─ 是否有 Embedding 模型？ ──────────────────────────────┐
│                                                        │
│  ┌─ 是 ──────────────────────────────────────────┐     │
│  │  文本 → Embedding 模型 → 查询向量              │     │
│  │  → sqlite-vec 余弦相似度 → 语义结果 (权重 0.6) │     │
│  └────────────────────────────────────────────────┘     │
│                                                        │
│  同时执行 (无论如何):                                    │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 文本 → 分词 → tags 表 LIKE 搜索 → 关键词结果    │    │
│  │ (权重: 有语义时 0.3, 无语义时 0.7)              │    │
│  └─────────────────────────────────────────────────┘    │
│                                                        │
├─ 是否有颜色条件？ ──────────────────────────────────────┤
│  ┌─ 是 ──────────────────────────────────────────┐     │
│  │  目标色 → LAB转换 → ΔE色差搜索 → 颜色结果     │     │
│  │  (权重: 有语义时 0.1, 无语义时 0.3)            │     │
│  └────────────────────────────────────────────────┘     │
│                                                        │
├─ 过滤条件 (文件夹/日期/状态) ───────────────────────────┤
│                                                        │
└─────────────────────────────────────────────────────────┘
    │
    ▼
 加权合并 → TOP 50 结果
```

### 1.1 搜索级别

| 搜索级别 | 可用方式 | 适用场景 | 降级触发条件 |
|---------|---------|---------|------------|
| **L3 - 全功能** | 语义 + 关键词 + 颜色 | Embedding 模型已下载 | — |
| **L2 - 基础文本** | 关键词 + 颜色 | 无 Embedding 模型但有 OCR/LLM 标签 | Embedding 模型未下载 |
| **L1 - 仅颜色** | 颜色 + 文件名 | 无任何描述标签 | OCR/LLM 均关闭或模型缺失 |
| **L0 - 浏览模式** | 浏览列表 | 首次启动无任何数据 | 无搜索词无颜色条件 |

### 1.2 搜索模式

| 模式 | 输入 | 原理 | 最低要求 |
|------|------|------|---------|
| 语义搜索 | 自然语言文本 | 查询文本→embedding→向量余弦相似度 | L3 |
| 颜色搜索 | HSL 色值/色块 | 目标色→LAB→ΔE 色差计算 | L1 |
| 混合搜索 | 文本 + 颜色 | 自动降级加权合并 | L1+ |
| 标签搜索 | 关键词片段 | tags 表 LIKE 模糊匹配 | L2 |

---

## 2. 语义搜索

### 2.1 查询向量生成

```dart
/// 将用户查询文本转为向量
Future<Uint8List> encodeQuery(String query) async {
  // 查询文本预处理
  final processed = query.trim();

  // 若 embedding 模型未加载，先加载
  if (!llmService.isModelLoaded) {
    await llmService.loadModel(embeddingModelPath);
  }

  // 调用 llama.cpp embedding API
  return llmService.encode(processed);
}
```

### 2.2 向量相似度搜索

```dart
// lib/core/embedding/embedding_service.dart
class EmbeddingService {
  final LlmService _llm;
  final EmbeddingDao _embedDao;

  static const int dimension = 384;    // all-MiniLM-L6-v2 维度
  static const int topK = 50;
  static const double minSimilarity = 0.3;  // 低于此阈值的忽略

  Future<List<SearchResult>> search(String query) async {
    // 1. 生成查询向量
    final queryVec = await encodeQuery(query);

    // 2. 向量检索
    final vecResults = await _embedDao.searchByVector(
      queryVec,
      limit: topK,
      minDistance: 1.0 - minSimilarity,
    );

    // 3. 转换为 SearchResult
    return vecResults.map((r) => SearchResult(
      memeId: r.memeId,
      score: r.similarity,  // 1.0 - distance
      source: SearchSource.semantic,
    )).toList();
  }
}
```

### 2.3 sqlite-vec 查询（详细）

```dart
Future<List<VectorMatch>> searchByVector(
  Uint8List queryVector, {
  int limit = 50,
  double minDistance = 0.7,  // 余弦距离 > 0.7 表示不相似
}) async {
  // vec_memes 是 sqlite-vec 的虚拟表
  // 使用 vec_distance_cosine 函数计算余弦距离
  final rows = await customSelect(
    'SELECT meme_id, distance '
    'FROM vec_memes '
    'WHERE vector MATCH ? '
    'AND distance <= ? '          // 距离越小越相似
    'AND k = ? '
    'ORDER BY distance ASC',
    variables: [
      Variable(queryVector),
      Variable(minDistance),
      Variable(limit),
    ],
  ).get();

  return rows.map((r) => VectorMatch(
    memeId: r.read<String>('meme_id'),
    distance: r.read<double>('distance'),
    similarity: 1.0 - r.read<double>('distance'),
  )).toList();
}
```

### 2.4 关键词兜底搜索

当向量搜索返回结果不足时（例如新模型、冷启动），用关键词搜索补充：

```dart
Future<List<SearchResult>> keywordFallback(String query, {int limit = 20}) async {
  // 分词（支持中文）
  final terms = segmentText(query);  // 简单按空格/标点分割

  // 对每个词做 LIKE 搜索
  final results = <String, double>{};  // meme_id → score
  for (final term in terms) {
    final matchingMemeIds = await tagDao.searchByContent('%$term%');
    for (final memeId in matchingMemeIds) {
      results[memeId] = (results[memeId] ?? 0.0) + 1.0;
    }
  }

  // 归一化并排序
  final maxScore = results.values.isEmpty ? 1.0 : results.values.reduce(max);
  return results.entries
    .map((e) => SearchResult(
      memeId: e.key,
      score: e.value / maxScore * 0.8,  // 关键词最高 0.8
      source: SearchSource.keyword,
    ))
    .sorted((a, b) => b.score.compareTo(a.score))
    .take(limit)
    .toList();
}
```

---

## 3. 颜色搜索

### 3.1 颜色选择器

颜色搜索无需向量模型，纯计算。用户通过颜色选择器选取目标色：

```dart
/// 颜色拾取 → LAB 值 → 搜索
Future<List<SearchResult>> searchByColor({
  required Color target,           // Flutter Color (sRGB)
  Color? secondary,                // 可选第二配色
  int limit = 100,
}) async {
  final lab = rgbToLab(target);

  // 单色搜索
  if (secondary == null) {
    return _searchSingleColor(lab, limit: limit);
  }

  // 双色搜索：要求 meme 同时包含这两种颜色的匹配
  final lab2 = rgbToLab(secondary);
  return _searchDualColor(lab, lab2, limit: limit);
}
```

### 3.2 单色搜索

```dart
Future<List<SearchResult>> _searchSingleColor(LabColor target, {int limit = 100}) async {
  // 色相桶预筛选（加速）
  final candidates = await colorDao.findCandidates(
    targetA: target.a,
    tolerance: 25.0,  // 色相容忍度
  );

  if (candidates.isEmpty) return [];

  // 精确计算 ΔE
  final scored = <_ColorScore>[];
  for (final row in candidates) {
    final dE = deltaE76(
      target.l, target.a, target.b,
      row.labL, row.labA, row.labB,
    );
    scored.add(_ColorScore(
      memeId: row.memeId,
      bestDE: scored
        .where((s) => s.memeId == row.memeId)
        .fold<double>(double.infinity, (min, s) => s.bestDE < min ? s.bestDE : min)
      ,
    ));
  }

  // 每个 meme 取最佳匹配颜色
  final bestPerMeme = <String, double>{};
  for (final s in scored) {
    final existing = bestPerMeme[s.memeId] ?? double.infinity;
    if (s.bestDE < existing) {
      bestPerMeme[s.memeId] = s.bestDE;
    }
  }

  // 按 ΔE 升序排列，转换为相似度（ΔE 范围 0~100, 越小越相似）
  // 相似度 = 1 - (ΔE / 100)，低于 0.3 的忽略
  return bestPerMeme.entries
    .map((e) => SearchResult(
      memeId: e.key,
      score: (1.0 - (e.value / 100.0)).clamp(0.0, 1.0),
      source: SearchSource.color,
    ))
    .where((r) => r.score > 0.3)
    .sorted((a, b) => b.score.compareTo(a.score))
    .take(limit)
    .toList();
}
```

### 3.3 CIE76 ΔE 色差公式

```dart
/// CIE76 色差公式
/// ΔE < 1: 肉眼无法区分
/// ΔE < 10: 可接受的颜色匹配
/// ΔE > 50: 完全不同的颜色
double deltaE76(double l1, double a1, double b1, double l2, double a2, double b2) {
  final dl = l1 - l2;
  final da = a1 - a2;
  final db = b1 - b2;
  return sqrt(dl * dl + da * da + db * db);
}
```

### 3.4 色相桶预筛选

```dart
// colors 表的 lab_a 通道大致对应红-绿轴
// CIE Lab 的 a 轴范围: -128 ~ +127
// 我们将 a 轴量化为 15° 的桶

// 预筛选 SQL:
// SELECT c.meme_id, c.lab_l, c.lab_a, c.lab_b, c.ratio
// FROM colors c
// WHERE c.lab_a BETWEEN ? AND ?   -- 色相桶筛选
// ORDER BY c.ratio DESC

// 性能: 假设 50,000 meme × 5 色 = 250,000 行
// 色相桶筛选可将候选缩小到 ~8,000 行
// 再对 8,000 行做 ΔE 计算，约 10-30ms
```

---

## 4. 混合搜索（文本 + 颜色）

### 4.1 搜索服务（自动降级）

```dart
// lib/services/search_service.dart
class SearchService {
  final EmbeddingService _embedding;
  final ColorSearchService _colorSearch;
  final TagDao _tagDao;
  final MemeDao _memeDao;

  /// 搜索级别 (自动判断)
  SearchLevel get currentLevel => _determineLevel();

  SearchLevel _determineLevel() {
    if (_embedding.isModelLoaded) return SearchLevel.full;       // L3
    if (_tagDao.hasAnyTags()) return SearchLevel.basicText;      // L2
    return SearchLevel.colorOnly;                                 // L1
  }

  Future<List<SearchResult>> search({
    required String query,
    List<Color>? colors,
    String? folderId,
    int page = 0,
    int pageSize = 50,
  }) async {
    final level = currentLevel;
    final futures = <Future<List<SearchResult>>>[];

    // L3: 语义搜索（有 embedding 模型时）
    if (level.index >= SearchLevel.full.index && query.isNotEmpty) {
      futures.add(_embedding.search(query));
    }

    // L2+: 关键词搜索（有标签数据时）
    if (level.index >= SearchLevel.basicText.index && query.isNotEmpty) {
      futures.add(keywordSearch(query));
    }

    // L1+: 颜色搜索
    if (colors != null && colors.isNotEmpty) {
      futures.add(_colorSearch.searchByColor(colors.first));
    }

    // 无任何活跃搜索 → 返回最新 meme 列表（浏览模式 L0）
    if (futures.isEmpty) {
      return _browseMode(page, pageSize);
    }

    // 2. 合并评分
    final results = await Future.wait(futures);
    final merged = <String, _AggregatedScore>{};

    for (final resultList in results) {
      for (final r in resultList) {
        merged.putIfAbsent(r.memeId, () => _AggregatedScore());
        switch (r.source) {
          case SearchSource.semantic:
            merged[r.memeId]!.semantic = max(merged[r.memeId]!.semantic, r.score);
          case SearchSource.color:
            merged[r.memeId]!.color = max(merged[r.memeId]!.color, r.score);
          case SearchSource.keyword:
            merged[r.memeId]!.keyword = max(merged[r.memeId]!.keyword, r.score);
        }
      }
    }

    // 3. 加权总分（权重根据级别自适应）
    final (semW, colW, keyW) = _weightsForLevel(level);
    final scored = merged.entries.map((e) {
      final s = e.value;
      final total = s.semantic * semW
                  + s.color * colW
                  + s.keyword * keyW;
      return SearchResult(
        memeId: e.key,
        score: total,
        source: SearchSource.hybrid,
      );
    }).where((r) => r.score > 0.1).toList();

    // 4. 排序 + 分页
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.skip(page * pageSize).take(pageSize).toList();
  }

  /// 根据搜索级别返回自适应权重
  (double, double, double) _weightsForLevel(SearchLevel level) {
    switch (level) {
      case SearchLevel.full:
        return (0.6, 0.3, 0.1);   // 语义为主
      case SearchLevel.basicText:
        return (0.0, 0.3, 0.7);   // 关键词为主
      case SearchLevel.colorOnly:
        return (0.0, 1.0, 0.0);   // 仅颜色
    }
  }

  Future<List<SearchResult>> _browseMode(int page, int pageSize) async {
    final memes = await _memeDao.findAll(
      orderBy: 'imported_at DESC',
      limit: pageSize,
      offset: page * pageSize,
    );
    return memes.map((m) => SearchResult(
      memeId: m.id,
      score: 1.0,
      source: SearchSource.hybrid,
    )).toList();
  }
}

enum SearchLevel { colorOnly, basicText, full }

class _AggregatedScore {
  double semantic = 0.0;
  double color = 0.0;
  double keyword = 0.0;
}
```

### 4.2 搜索结果结构

```dart
@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    required String memeId,
    required double score,        // 0.0 ~ 1.0
    required SearchSource source, // 主要来源
    String? matchedText,          // 匹配的文本片段（高亮用）
    double? colorSimilarity,      // 颜色相似度（颜色搜索时）
  }) = _SearchResult;
}

enum SearchSource {
  semantic,   // 向量语义匹配
  color,      // 颜色匹配
  keyword,    // 关键词匹配
  hybrid,     // 混合
}
```

---

## 5. 搜索过滤与排序

### 5.1 过滤条件

```dart
class SearchFilter {
  final String? folderId;           // 限定文件夹
  final DateTime? importedAfter;    // 导入日期筛选
  final DateTime? importedBefore;
  final String? analysisStatus;     // done / pending (搜索未分析的)
  final String? mimeType;           // image/png 等
  final List<String> excludeFolderIds;  // 排除的文件夹
}
```

### 5.2 排序模式

| 模式 | 说明 | 默认 |
|------|------|------|
| `relevance` | 按相关度降序（混合搜索默认） | 语义搜索 |
| `dateDesc` | 按导入时间降序 | 浏览模式 |
| `dateAsc` | 按导入时间升序 | - |
| `fileSize` | 按文件大小降序 | - |
| `nameAsc` | 按文件名升序 | - |

### 5.3 搜索建议（Search Suggestion）

当用户输入过程中，提供实时建议：

```dart
Future<List<String>> suggest(String partial) async {
  if (partial.length < 2) return [];

  // 从 tags 表里找匹配的内容
  final suggestions = await tagDao.searchContent('%$partial%', limit: 10);
  return suggestions;
}
```

---

## 6. 索引维护

### 6.1 全量重新索引

```dart
/// 更换 embedding 模型后需要全量重新索引
Future<void> rebuildIndex() async {
  // 1. 清空旧向量
  await embedDao.deleteAll();

  // 2. 重新生成所有已完成分析 meme 的向量
  final memes = await memeDao.findByStatus('done');
  for (final meme in memes) {
    // 合并标签文本
    final tags = await tagDao.getByMemeId(meme.id);
    final text = tags.map((t) => t.content).join(' ');
    final vector = await embeddingService.encode(text);
    await embedDao.upsert(Embedding(
      memeId: meme.id,
      modelId: embeddingService.currentModelId,
      vector: vector,
    ));
  }

  // 3. 重建 IVFFlat 索引
  await customStatement('SELECT vec_ivfflat_index(\'vec_memes_idx\', \'vec_memes\')');
}
```

### 6.2 增量索引

每次分析管线完成单个 meme 后自动增量更新 embedding：

```dart
// 在 AnalysisService.analyzeOne() 的最后一步
final vector = await embeddingService.encode(combinedText);
await embedRepo.upsert(Embedding(
  memeId: meme.id,
  modelId: currentModelId,
  vector: vector,
));
// 向量索引自动包含新条目，无需重建
```

### 6.3 后台维护触发器

| 事件 | 操作 |
|------|------|
| 切换模型 | 提示用户是否全量重索引 |
| 新分析完成 | 增量 upsert 向量 |
| 用户手动触发 | 全量重索引 |
| App 版本更新 | 检查是否需要迁移或重索引 |
