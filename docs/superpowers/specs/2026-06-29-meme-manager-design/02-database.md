# MemeHelper 数据库 Schema 文档

> 所属项目: MemeHelper
> 文档编号: 02-database.md
> ORM: drift (SQLite) + sqlite-vec 扩展

---

## 1. Drift 表定义

以下为 drift 的 Dart 表定义代码（使用 `@DataClassName` 自定义数据类名）。

### 1.1 memes — Meme 主表

```dart
import 'package:drift/drift.dart';

@DataClassName('Meme')
class MemesTable extends Table {
  TextColumn get id => text()();                    // UUID v4
  TextColumn get filename => text()();              // 原始文件名
  TextColumn get filePath => text()();              // App 内部相对路径
  IntColumn get fileSize => integer()();            // 字节数
  TextColumn get mimeType => text()();              // image/png, image/jpeg, image/webp
  IntColumn get width => integer()();               // 像素宽
  IntColumn get height => integer()();              // 像素高
  TextColumn get folderId => text().nullable()();   // folders.id, nullable=根目录
  TextColumn get analysisStatus => text()();        // pending / processing / done / failed
  TextColumn get fileHash => text()();              // SHA256 hex, 用于去重
  IntColumn get createdAt => integer()();           // Unix ms
  IntColumn get updatedAt => integer()();           // Unix ms
  IntColumn get importedAt => integer()();          // Unix ms

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(file_hash)',
    'CHECK(analysis_status IN (\'pending\', \'processing\', \'done\', \'failed\'))',
  ];
}

// 索引
// CREATE INDEX idx_memes_folder ON memes(folder_id);
// CREATE INDEX idx_memes_status ON memes(analysis_status);
// CREATE INDEX idx_memes_updated ON memes(updated_at);
```

### 1.2 folders — 文件夹表

```dart
@DataClassName('Folder')
class FoldersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();   // 父文件夹, NULL=根级
  IntColumn get sortOrder => integer()();           // 同级排序
  TextColumn get icon => text().nullable()();       // 自定义图标 (emoji)
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(parent_id) REFERENCES folders(id) ON DELETE SET NULL',
  ];
}

// CREATE INDEX idx_folders_parent ON folders(parent_id);
```

### 1.3 tags — 标签表

```dart
@DataClassName('Tag')
class TagsTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text()();                 // memes.id FK
  TextColumn get source => text()();                 // ocr / llm / user
  TextColumn get content => text()();                // 标签文本
  RealColumn get confidence => real().nullable()();  // 置信度 0.0~1.0
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(meme_id) REFERENCES memes(id) ON DELETE CASCADE',
    'CHECK(source IN (\'ocr\', \'llm\', \'color\', \'user\'))',
  ];
}

// CREATE INDEX idx_tags_meme ON tags(meme_id);
// CREATE INDEX idx_tags_content ON tags(content);
```

### 1.4 colors — 主色调表

```dart
@DataClassName('MemeColor')
class ColorsTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text()();                // memes.id FK
  TextColumn get hexColor => text()();               // #RRGGBB
  RealColumn get ratio => real()();                  // 该颜色占比 0.0~1.0
  RealColumn get labL => real()();                   // CIE Lab 预计算
  RealColumn get labA => real()();
  RealColumn get labB => real()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(meme_id) REFERENCES memes(id) ON DELETE CASCADE',
  ];
}

// CREATE INDEX idx_colors_meme ON colors(meme_id);
// CREATE INDEX idx_colors_hue ON colors(lab_a);  -- 色相索引加速
```

### 1.5 embeddings — 向量索引表

```dart
@DataClassName('Embedding')
class EmbeddingsTable extends Table {
  TextColumn get memeId => text()();                 // memes.id PK+FK
  TextColumn get modelId => text()();                // 生成此向量的模型标识
  BlobColumn get vector => blob()();                 // float32 数组 (binary)
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {memeId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(meme_id) REFERENCES memes(id) ON DELETE CASCADE',
  ];
}
```

### 1.6 analysis_queue — 分析队列

```dart
@DataClassName('AnalysisJob')
class AnalysisQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get memeId => text()();                 // memes.id FK
  TextColumn get status => text()();                 // queued / running / done / failed
  IntColumn get priority => integer()();             // 默认0，手动触发可设置更高
  IntColumn get retryCount => integer()();
  TextColumn get errorMsg => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get startedAt => integer().nullable()();
  IntColumn get doneAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(meme_id) REFERENCES memes(id) ON DELETE CASCADE',
    'CHECK(status IN (\'queued\', \'running\', \'done\', \'failed\'))',
  ];
}

// CREATE INDEX idx_queue_status ON analysis_queue(status);
// CREATE INDEX idx_queue_meme ON analysis_queue(meme_id);
```

### 1.7 sync_state — 同步状态

```dart
@DataClassName('SyncState')
class SyncStateTable extends Table {
  TextColumn get id => text()();                     // key 标识符
  TextColumn get value => text()();                  // JSON value
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 1.8 settings — 设置表（可选，替代 SharedPreferences）

```dart
@DataClassName('Setting')
class SettingsTable extends Table {
  TextColumn get key => text()();                    // 配置键
  TextColumn get value => text()();                  // JSON 值
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}
```

---

## 2. 完整的 Drift Database 定义

```dart
import 'package:drift/drift.dart';
import 'package:sqlite_vec/sqlite_vec.dart';  // sqlite-vec 扩展

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    MemesTable,
    FoldersTable,
    TagsTable,
    ColorsTable,
    EmbeddingsTable,
    AnalysisQueueTable,
    SyncStateTable,
    SettingsTable,
  ],
  daos: [
    MemeDao,
    FolderDao,
    TagDao,
    ColorDao,
    EmbeddingDao,
    AnalysisQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // 创建 sqlite-vec 虚拟表
      await customStatement(
        'CREATE VIRTUAL TABLE vec_memes USING vec0('
        '  meme_id TEXT PRIMARY KEY,'
        '  vector FLOAT[384]'       // 取决于 embedding 模型维度
        ');'
      );
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // migration 逻辑见下方
    },
  );
}
```

---

## 3. sqlite-vec 向量搜索配置

### 3.1 虚拟表定义

sqlite-vec 使用虚拟表（virtual table）实现向量索引：

```sql
-- 创建向量表（在 AppDatabase.onCreate 中执行）
CREATE VIRTUAL TABLE vec_memes USING vec0(
  meme_id TEXT PRIMARY KEY,
  vector FLOAT[384]        -- all-MiniLM-L6-v2 输出 384 维
);

-- 插入向量
INSERT INTO vec_memes(meme_id, vector)
VALUES (?, ?);

-- 余弦相似度搜索
SELECT meme_id, distance
FROM vec_memes
WHERE vector MATCH ?
      AND k = 50            -- 返回 TOP 50
ORDER BY distance;
```

### 3.2 数据同步（embeddings 表 → vec 虚拟表）

vec0 虚拟表和普通 drift 表是独立的。保持二者同步的策略：

```
写入路径:
  AnalysisService 分析完成
      │
      ├── 写入 embeddings 表 (drift)
      └── 写入 vec_memes 虚拟表 (raw SQL)

删除路径:
  MemeRepo.delete(id)
      │
      ├── DELETE FROM memes WHERE id=? (ON CASCADE 自动清理 embeddings)
      └── DELETE FROM vec_memes WHERE meme_id=?
```

### 3.3 IVFFlat 索引

对于大规模数据（>10000 条），创建 IVF（Inverted File）索引加速：

```sql
-- 创建 IVF 索引（离线构建，在导入大量数据后触发）
SELECT vec_ivfflat_index('vec_memes_idx', 'vec_memes');

-- IVF 索引配置
-- lists: 聚类中心数，推荐 sqrt(N) 如 10000 条→100
-- probes: 搜索时探针数，推荐 lists/10 或 10~20
```

---

## 4. 关键 DAO 查询

### 4.1 语义搜索

```dart
// EmbeddingDao
Future<List<MemeSearchResult>> searchByVector(
  Uint8List queryVector, {
  int limit = 50,
}) async {
  // 步骤 1: 从 vec_memes 虚拟表获取候选
  final candidates = await customSelect(
    'SELECT meme_id, distance FROM vec_memes '
    'WHERE vector MATCH ? AND k = ? '
    'ORDER BY distance',
    variables: [Variable(queryVector), Variable(limit)],
  ).get();

  if (candidates.isEmpty) return [];

  // 步骤 2: 用 meme_id 回表查询完整信息
  final ids = candidates.map((r) => r.read<String>('meme_id')).toList();
  final placeholders = ids.map((_) => '?').join(',');
  final memes = await customSelect(
    'SELECT m.* FROM memes m WHERE m.id IN ($placeholders)',
    variables: ids.map((id) => Variable(id)).toList(),
  ).get();

  // 步骤 3: 组装结果（保持 vec_memes 的排序顺序）
  return ids.map((id) {
    final meme = memes.firstWhere((m) => m.read<String>('id') == id);
    final dist = candidates.firstWhere(
      (c) => c.read<String>('meme_id') == id,
    ).read<double>('distance');
    return MemeSearchResult(meme: meme, similarity: 1.0 - dist);
  }).toList();
}
```

### 4.2 关键词兜底搜索

```dart
// TagDao
Future<List<String>> searchByKeyword(String query) async {
  // 将用户输入分词后模糊匹配
  final terms = query.trim().split(RegExp(r'\s+'));
  if (terms.isEmpty) return [];

  final likeClauses = terms.map((_) => 't.content LIKE ?').join(' OR ');
  final params = terms.map((t) => Variable('%$t%')).toList();

  final result = await customSelect(
    'SELECT DISTINCT t.meme_id FROM tags t WHERE $likeClauses',
    variables: params,
  ).get();

  return result.map((r) => r.read<String>('meme_id')).toList();
}
```

### 4.3 颜色搜索

```dart
// ColorDao
Future<List<MemeColorResult>> searchByColor({
  required double targetL,
  required double targetA,
  required double targetB,
  double? secondTargetL,
  double? secondTargetA,
  double? secondTargetB,
}) async {
  // 第一步: 色相桶预筛选 (lab_a 是色相相关通道)
  const double hueTolerance = 20.0;
  final candidates = await customSelect(
    'SELECT c.* FROM colors c '
    'WHERE c.lab_a BETWEEN ? AND ?',
    variables: [
      Variable(targetA - hueTolerance),
      Variable(targetA + hueTolerance),
    ],
  ).get();

  // 第二步: 逐 ΔE 计算精确相似度
  final Map<String, List<_ColorMatch>> memeColors = {};
  for (final row in candidates) {
    final memeId = row.read<String>('meme_id');
    final dE = _deltaE76(
      targetL, targetA, targetB,
      row.read<double>('lab_l'),
      row.read<double>('lab_a'),
      row.read<double>('lab_b'),
    );
    memeColors.putIfAbsent(memeId, () => []).add(
      _ColorMatch(dE: dE, ratio: row.read<double>('ratio')),
    );
  }

  // 第三步: 每个 meme 取最小 ΔE 作为匹配度
  final results = memeColors.entries.map((e) {
    final bestMatch = e.value.reduce(
      (a, b) => a.dE < b.dE ? a : b,
    );
    return MemeColorResult(
      memeId: e.key,
      similarity: 1.0 - (bestMatch.dE / 100.0),  // ΔE 范围 0~100 归一化
    );
  }).toList();

  results.sort((a, b) => b.similarity.compareTo(a.similarity));
  return results.take(100).toList();
}

/// CIE76 ΔE 色差公式
double _deltaE76(double l1, double a1, double b1, double l2, double a2, double b2) {
  final dl = l1 - l2;
  final da = a1 - a2;
  final db = b1 - b2;
  return sqrt(dl * dl + da * da + db * db);
}
```

### 4.4 混合搜索

```dart
// SearchService
Future<List<MemeSearchResult>> hybridSearch({
  required String textQuery,
  List<LabColor>? colorFilters,
  String? folderId,
  double semanticWeight = 0.6,
  double colorWeight = 0.3,
  double keywordWeight = 0.1,
}) async {
  // 1. 语义搜索
  final queryVector = await embeddingService.encode(textQuery);
  final semanticResults = await embeddingDao.searchByVector(queryVector);

  // 2. 颜色搜索
  List<MemeColorResult> colorResults = [];
  if (colorFilters != null && colorFilters.isNotEmpty) {
    colorResults = await colorDao.searchByColor(
      targetL: colorFilters.first.l,
      targetA: colorFilters.first.a,
      targetB: colorFilters.first.b,
    );
  }

  // 3. 关键词兜底
  final keywordMatches = await tagDao.searchByKeyword(textQuery);

  // 4. 加权合并
  final scoredResults = <String, _ScoredMeme>{};
  for (final sr in semanticResults) {
    scoredResults.putIfAbsent(sr.memeId, () => _ScoredMeme())
      ..semanticScore = sr.similarity;
  }
  for (final cr in colorResults) {
    scoredResults.putIfAbsent(cr.memeId, () => _ScoredMeme())
      ..colorScore = cr.similarity;
  }
  for (final kid in keywordMatches) {
    scoredResults.putIfAbsent(kid, () => _ScoredMeme())
      ..keywordScore += 0.3;  // 每匹配一个关键字加 0.3
  }

  // 计算加权总分
  final sorted = scoredResults.entries
    .map((e) => MemeSearchResult(
      memeId: e.key,
      similarity:
        e.value.semanticScore * semanticWeight +
        e.value.colorScore * colorWeight +
        (e.value.keywordScore.clamp(0, 1)) * keywordWeight,
    ))
    .where((r) => r.similarity > 0.1)  // 过滤掉完全不相关的
    .toList()
    ..sort((a, b) => b.similarity.compareTo(a.similarity));

  return sorted.take(50).toList();
}
```

### 4.5 导入去重检查

```dart
// MemeDao
Future<Meme?> findByHash(String sha256Hex) async {
  return (select(memesTable)
        ..where((m) => m.fileHash.equals(sha256Hex)))
      .getSingleOrNull();
}
```

### 4.6 分析队列轮询

```dart
// AnalysisQueueDao
Future<List<AnalysisJob>> pollNextJobs({int limit = 2}) async {
  return (select(analysisQueueTable)
        ..where((q) => q.status.equals('queued'))
        ..orderBy([
          (q) => OrderingTerm(expression: q.priority, mode: OrderingMode.desc),
          (q) => OrderingTerm(expression: q.createdAt),
        ])
        ..limit(limit))
      .get();
}

Future<void> markRunning(String jobId) async {
  await (update(analysisQueueTable)
        ..where((q) => q.id.equals(jobId)))
      .write(const AnalysisQueueCompanion(
        status: Value('running'),
        startedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
}
```

---

## 5. Migration 策略

### 5.1 版本管理

```dart
@override
int get schemaVersion => 2;  // 每次 schema 变更需 +1

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (Migrator m, int from, int to) async {
    if (from == 1) {
      await _migrateV1ToV2(m);
    }
    if (from == 2) {
      await _migrateV2ToV3(m);
    }
    // 逐版本升级，确保降级设备也能正确迁移
  },
);
```

### 5.2 Migration 示例（v1 → v2: 新增 memo 字段）

```dart
Future<void> _migrateV1ToV2(Migrator m) async {
  await m.addColumn(memesTable, memesTable.memo);  // 新增 TEXT memo 列
}

// 对应 drift 需在 MemesTable 中新增字段:
// TextColumn get memo => text().nullable()();
```

### 5.3 Migration 测试

```dart
@TestOn('vm')
import 'package:drift/native.dart';

void main() {
  test('migration v1 to v2 keeps existing data', () async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));

    // 创建 v1 schema（手动，不经过 onCreate）
    // ... 插入测试数据

    // 升级到 v2
    // 验证数据完整
    // 验证新字段可用
  });
}
```

---

## 6. 性能考虑

### 6.1 索引策略

| 表 | 索引 | 目的 |
|----|------|------|
| memes | `folder_id` | 按文件夹筛选 |
| memes | `analysis_status` | 过滤未分析/已分析 |
| memes | `updated_at` | 排序+同步增量检测 |
| memes | `file_hash` (UNIQUE) | 去重（自动索引） |
| tags | `meme_id` | 按 meme 查标签 |
| tags | `content` | 关键词搜索 |
| colors | `meme_id` | 按 meme 查颜色 |
| colors | `lab_a` | 色相桶筛选 |
| analysis_queue | `status` | 队列轮询 |

### 6.2 批量写入优化

```dart
// 批量导入时使用事务减少磁盘 I/O
Future<void> batchInsert(List<Meme> memes) async {
  await batch((b) {
    for (final meme in memes) {
      b.insert(memesTable, MemesTableCompanion(
        id: Value(meme.id),
        filename: Value(meme.filename),
        // ...
      ));
    }
  });
}
```

### 6.3 预估数据规模

| 指标 | 小规模 | 中规模 | 大规模 | 应对策略 |
|------|--------|--------|--------|---------|
| Meme 数 | 100 | 5,000 | 50,000 | 分页加载 |
| 向量表大小 | <1MB | ~30MB | ~300MB | IVFFlat 索引 |
| tags 行数 | 500 | 25,000 | 250,000 | content 索引 |
| colors 行数 | 500 | 25,000 | 250,000 | lab_a 索引 |
| 颜色搜索耗时 | <5ms | ~20ms | ~150ms | 色相桶预筛选 + 缓存 |
| 向量搜索耗时 | <10ms | ~50ms | ~200ms | IVFFlat + 缩减 lists |
