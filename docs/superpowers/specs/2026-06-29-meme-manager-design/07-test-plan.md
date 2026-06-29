# MemeHelper 测试计划

> 所属项目: MemeHelper
> 文档编号: 07-test-plan.md
> 框架: flutter_test + mocktail + drift_test

---

## 1. 测试策略

### 1.1 测试金字塔

```
         ╱╲
        ╱  ╲
       ╱ E2E╲     ← 少量: 完整设备/集成测试
      ╱──────╲
     ╱Integration╲  ← 中等: Service + Widget 测试
    ╱────────────╲
   ╱   Unit Test  ╲ ← 大量: Model + Repository + Utils
  ╱────────────────╲
```

| 层级 | 数量目标 | 运行时间 | CI 执行 |
|------|---------|---------|---------|
| Unit | 70%+ | <30s | 每次 PR |
| Integration | 20% | <2min | 每次 PR |
| Widget | 5% | <1min | 每次 PR |
| E2E/Device | 5% | >10min | 手动/定时 |

### 1.2 测试优先级

1. **数据层最高**：数据库 DAO、Repository（出错影响所有功能）
2. **服务层次高**：AnalysisService、SearchService（核心业务逻辑）
3. **工具类中等**：ColorExtractor、ColorUtils（算法正确性）
4. **UI 层最低**：Widget（变化频繁、维护成本高）

---

## 2. 单元测试

### 2.1 数据模型测试

```dart
// test/core/database/models_test.dart
void main() {
  group('Meme 模型', () {
    test('从 JSON 反序列化正确', () {
      final json = {
        'id': 'abc-123',
        'filename': 'cat.jpg',
        'filePath': 'memes/2026/06/abc-123.jpg',
        'fileSize': 102400,
        'mimeType': 'image/jpeg',
        'analysisStatus': 'pending',
        'fileHash': 'abcdef1234567890',
      };
      final meme = Meme.fromJson(json);
      expect(meme.id, 'abc-123');
      expect(meme.analysisStatus, 'pending');
    });

    test('copyWith 正确更新字段', () {
      final meme = Meme.testInstance();
      final updated = meme.copyWith(filename: 'new-name.jpg');
      expect(updated.filename, 'new-name.jpg');
      expect(updated.id, meme.id);  // 其他字段不变
    });

    test('analysisStatus 的值域约束', () {
      expect(MemeStatus.values, hasLength(4));
      expect(MemeStatus.values, contains('done'));
      expect(MemeStatus.values, contains('failed'));
    });
  });
}
```

### 2.2 Repository 测试（使用内存数据库）

```dart
// test/core/database/repositories/meme_repository_test.dart
void main() {
  late AppDatabase db;
  late MemeRepository repo;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    await db.createAll();
    repo = MemeRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MemeRepository', () {
    test('插入和查询 meme', () async {
      final meme = Meme.testInstance();
      await repo.insert(meme);
      final found = await repo.getById(meme.id);
      expect(found, isNotNull);
      expect(found!.filename, equals(meme.filename));
    });

    test('SHA256 去重检查', () async {
      final meme1 = Meme.testInstance(fileHash: 'hash123');
      final meme2 = Meme.testInstance(fileHash: 'hash123');
      await repo.insert(meme1);
      final dup = await repo.findByHash('hash123');
      expect(dup, isNotNull);
    });

    test('级联删除', () async {
      final meme = Meme.testInstance();
      await repo.insert(meme);
      // 插入关联数据
      await db.tagDao.insert(Tag.testInstance(memeId: meme.id));
      await db.colorDao.insert(MemeColor.testInstance(memeId: meme.id));

      await repo.delete(meme.id);

      // 验证级联删除
      final tags = await db.tagDao.getByMemeId(meme.id);
      expect(tags, isEmpty);
      final colors = await db.colorDao.getByMemeId(meme.id);
      expect(colors, isEmpty);
    });

    test('批量插入性能', () async {
      final memes = List.generate(100, (i) => Meme.testInstance());
      final stopwatch = Stopwatch()..start();
      await repo.batchInsert(memes);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}
```

### 2.3 颜色提取测试

```dart
// test/core/image/color_extractor_test.dart
void main() {
  group('ColorExtractor', () {
    test('纯红色图片提取主色调', () async {
      // 创建一个 100x100 的纯红色图片
      final image = Image(100, 100);
      fill(image, ColorRgb8(255, 0, 0));
      final tempPath = '/tmp/test_red.png';
      await File(tempPath).writeAsBytes(encodePng(image));

      final extractor = ColorExtractor();
      final colors = await extractor.extract(tempPath, count: 3);

      expect(colors.length, equals(1));  // 只有一种颜色
      expect(colors.first.hexColor, equals('#FF0000'));
      expect(colors.first.ratio, closeTo(1.0, 0.01));
    });

    test('半红半蓝图片提取主色调', () async {
      // 创建一个上半红下半蓝的图片
      final image = Image(100, 100);
      fillRect(image, 0, 0, 100, 50, ColorRgb8(255, 0, 0));   // 上半红
      fillRect(image, 0, 50, 100, 50, ColorRgb8(0, 0, 255));   // 下半蓝
      // ... 验证提取到两种颜色各占 50%
    });
  });
}
```

### 2.4 颜色工具测试

```dart
// test/core/image/color_utils_test.dart
void main() {
  group('RGB → LAB 转换', () {
    test('纯白', () {
      final lab = rgbToLab(Color(0xFFFFFFFF));
      expect(lab.l, closeTo(100.0, 1.0));
      expect(lab.a, closeTo(0.0, 1.0));
      expect(lab.b, closeTo(0.0, 1.0));
    });

    test('纯黑', () {
      final lab = rgbToLab(Color(0xFF000000));
      expect(lab.l, closeTo(0.0, 1.0));
    });

    test('sRGB 红', () {
      final lab = rgbToLab(Color(0xFFFF0000));
      expect(lab.l, closeTo(53.2, 1.0));
      expect(lab.a, closeTo(80.1, 1.0));
      expect(lab.b, closeTo(67.2, 1.0));
    });
  });

  group('ΔE 色差', () {
    test('相同颜色 ΔE=0', () {
      final dE = deltaE76(50, 0, 0, 50, 0, 0);
      expect(dE, closeTo(0.0, 0.001));
    });

    test('红 vs 绿 ΔE 应该很大', () {
      final red = rgbToLab(Color(0xFFFF0000));
      final green = rgbToLab(Color(0xFF00FF00));
      final dE = deltaE76(red.l, red.a, red.b, green.l, green.a, green.b);
      expect(dE, greaterThan(50.0));  // 完全不同
    });
  });
}
```

### 2.5 搜索引擎测试

```dart
// test/core/search/search_score_test.dart
void main() {
  group('混合搜索计分', () {
    test('仅有语义分', () {
      final score = HybridScorer.compute(
        semanticScore: 0.8,
        colorScore: 0.0,
        keywordScore: 0.0,
        semanticWeight: 0.6,
        colorWeight: 0.3,
        keywordWeight: 0.1,
      );
      expect(score, closeTo(0.48, 0.01));  // 0.8 * 0.6
    });

    test('语义 + 颜色组合', () {
      final score = HybridScorer.compute(
        semanticScore: 0.7,
        colorScore: 0.5,
        keywordScore: 0.0,
      );
      expect(score, closeTo(0.57, 0.01));  // 0.7*0.6 + 0.5*0.3
    });

    test('全零分 = 0', () {
      final score = HybridScorer.compute(
        semanticScore: 0.0,
        colorScore: 0.0,
        keywordScore: 0.0,
      );
      expect(score, 0.0);
    });
  });
}
```

### 2.6 同步冲突测试

```dart
// test/features/sync/conflict_resolution_test.dart
void main() {
  group('冲突解决', () {
    test('双方更新 - 保留较新的', () {
      final result = SyncResolver.resolve(
        local: MockMeme(updatedAt: DateTime(2026, 6, 29, 10, 0)),
        remote: MockMeme(updatedAt: DateTime(2026, 6, 29, 11, 0)),
        localDeleted: false,
        remoteDeleted: false,
      );
      expect(result, ConflictAction.applyRemote);
    });

    test('远端删除但本地有未同步更新 - 保留本地', () {
      final result = SyncResolver.resolve(
        local: MockMeme(updatedAt: DateTime(2026, 6, 29, 12, 0)),
        remote: MockMeme(updatedAt: DateTime(2026, 6, 29, 11, 0)),
        localDeleted: false,
        remoteDeleted: true,
      );
      expect(result, ConflictAction.keepLocal);
    });
  });
}
```

---

## 3. 集成测试

### 3.1 数据库集成测试

```dart
// test/integration/database_integration_test.dart
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    await db.createAll();
  });

  group('数据库完整流程', () {
    test('插入 → 分析 → 搜索 完整链路', () async {
      // 插入 meme
      final meme = Meme.testInstance();
      await db.memeDao.insert(meme);

      // 插入标签
      await db.tagDao.insertBatch([
        Tag.testInstance(memeId: meme.id, source: 'ocr', content: '哈哈哈'),
        Tag.testInstance(memeId: meme.id, source: 'llm', content: '搞笑猫表情'),
      ]);

      // 插入颜色
      await db.colorDao.insertBatch([
        MemeColor.testInstance(memeId: meme.id, hexColor: '#FF5722'),
      ]);

      // 插入向量
      final vector = Uint8List(384 * 4);  // 384维 float32
      await db.embeddingDao.upsert(Embedding(
        memeId: meme.id, modelId: 'test-model', vector: vector,
      ));

      // 标记完成
      await db.memeDao.updateStatus(meme.id, 'done');

      // 验证搜索能找到
      final found = await db.memeDao.findByStatus('done');
      expect(found.length, greaterThanOrEqualTo(1));
    });
  });

  group('Schema Migration', () {
    test('v1 → v2 migration 不丢数据', () async {
      // 创建 v1 schema
      // 插入数据
      // 升级到 v2
      // 验证数据完整
    });
  });
}
```

### 3.2 分析管线集成测试

```dart
// test/integration/analysis_pipeline_test.dart
void main() {
  test('完整分析管线（mock LLM）', () async {
    final db = await createTestDatabase();
    final llm = MockLlmService();
    final ocr = MockOcrService();
    final colorExtractor = MockColorExtractor();

    // mock: OCR 返回文字
    when(() => ocr.recognize(any())).thenReturn([
      OcrResult(text: '我太难了', confidence: 0.95),
    ]);

    // mock: LLM 返回描述
    when(() => llm.multimodalInference(any(), any())).thenReturn(
      '一只悲伤的青蛙表情包'
    );

    // mock: 颜色
    when(() => colorExtractor.extract(any())).thenReturn([
      DominantColor(hexColor: '#4CAF50', labL: 50, labA: -30, labB: 20, ratio: 0.6),
    ]);

    final service = AnalysisService(db, llm, ocr, colorExtractor);
    final meme = Meme.testInstance();
    final result = await service.analyzeOne(meme);

    expect(result.success, isTrue);
    expect(result.tagCount, greaterThan(0));
    expect(result.colorCount, greaterThan(0));

    // 验证数据库中已有分析结果
    final tags = await db.tagDao.getByMemeId(meme.id);
    expect(tags, isNotEmpty);
  });
}
```

---

## 4. Widget 测试

```dart
// test/features/gallery/widgets/meme_grid_tile_test.dart
void main() {
  testWidgets('MemeGridTile 显示缩略图和状态角标', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemeGridTile(
          meme: Meme.testInstance(analysisStatus: 'done'),
          onTap: () {},
        ),
      ),
    );

    // 验证缩略图存在
    expect(find.byType(Image), findsOneWidget);

    // 验证分析完成角标
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('空状态显示导入按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: EmptyState(onImport: () {})),
    );

    expect(find.text('导入你的第一个表情包'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('搜索栏输入触发回调', (tester) async {
    String? query;
    await tester.pumpWidget(
      MaterialApp(
        home: SearchBarWidget(onSubmitted: (q) => query = q),
      ),
    );

    await tester.enterText(find.byType(TextField), '悲伤的猫');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(query, equals('悲伤的猫'));
  });
}
```

---

## 5. 设备测试（Android）

### 5.1 性能基准

| 测试场景 | 目标 | 测试方法 |
|---------|------|---------|
| Gallery 滑动 1000 条 | 60fps | Flutter DevTools 性能检测 |
| 向量搜索 | <500ms | Stopwatch 计时（100次取平均） |
| 颜色搜索 | <200ms | Stopwatch 计时（100次取平均） |
| 导入单个图片 | <500ms | Stopwatch |
| 导入 100 张 | <30s | Stopwatch |
| LLM 分析单张 | <20s | Stopwatch |
| 内存峰值（分析中） | <200MB | Android Profiler |

### 5.2 测试设备推荐

| 级别 | 设备 | 配置 | 用途 |
|------|------|------|------|
| 低端 | 模拟器 2GB RAM | ARM, 2GB | 内存不足场景 |
| 中端 | Pixel 6 / 类似 | 8GB RAM | 主要测试设备 |
| 高端 | 旗舰机 12GB+ | 12-16GB | 性能上限测试 |

### 5.3 Android 专项测试

```dart
// 测试场景 checklist:
// 1. 后台分析时 App 被杀死 → 重新打开 → 恢复队列
// 2. 存储空间不足时导入 → 错误提示
// 3. 模型下载中断 → 恢复下载
// 4. 权限未授予 → 引导授权
// 5. 快速切换 Tab → 不闪退
// 6. 分析过程中切换模型 → 优雅处理
```

---

## 6. CI/CD 配置

### 6.1 GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Run unit + integration tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  # 设备测试（需要连接的设备）
  device-test:
    runs-on: macos-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - name: Run device tests
        run: flutter test integration_test/
```

### 6.2 代码覆盖率目标

| 模块 | 覆盖率目标 |
|------|-----------|
| core/database (DAO) | >85% |
| core/llm (LLM Service) | >60% (mock LLM) |
| core/ocr (OCR Service) | >60% (mock ML Kit) |
| core/image (Color) | >90% |
| core/embedding | >80% |
| services (Import/Search/Sync) | >75% |
| features (Providers) | >50% |
| features (Widgets) | >30% |
| **整体** | **>70%** |

---

## 7. 各功能测试清单

### 7.1 导入功能

- [ ] 单文件导入（PNG/JPG/GIF/WebP）
- [ ] 批量导入（10、50、200 张）
- [ ] ZIP 导入（含子目录、不含子目录）
- [ ] 目录导入（保留目录结构）
- [ ] 重复文件检测（SHA256 相同→跳过）
- [ ] 不支持的格式（.txt/.mp4→跳过并报告）
- [ ] 存储空间不足时导入→友好提示
- [ ] 导入时取消→已复制文件清理

### 7.2 分析管线

- [ ] 完整管线（颜色+OCR+LLM+Embedding）
- [ ] 轻量模式（无 LLM，仅 OCR+颜色）
- [ ] OCR 中英文混合识别
- [ ] 图片损坏→标记 failed
- [ ] LLM 超时→跳过 LLM 步骤
- [ ] 后台分析队列调度（先进先出）
- [ ] 队列重试（失败 3 次后停止）
- [ ] 内存不足时 isolate 优雅退出

### 7.3 搜索功能

- [ ] 语义搜索（自然语言→匹配结果）
- [ ] 颜色搜索（单色、双色）
- [ ] 混合搜索（语义+颜色）
- [ ] 关键词兜底搜索
- [ ] 空搜索→显示最近/全部
- [ ] 无结果→友好提示
- [ ] 搜索建议（输入过程中）
- [ ] 按文件夹过滤
- [ ] 按分析状态过滤

### 7.4 同步功能

- [ ] S3 配置（保存/读取/验证）
- [ ] 首次同步（全量上传）
- [ ] 增量同步（仅上传变更）
- [ ] 冲突解决（保留较新）
- [ ] 网络中断→错误提示+重试
- [ ] 后台自动同步（WiFi+充电）
- [ ] 凭证错误→友好提示
- [ ] 下载新 meme→自动入队分析

### 7.5 文件夹管理

- [ ] 创建/重命名/删除文件夹
- [ ] 移动 meme 到文件夹
- [ ] 文件夹嵌套（最多 3 层）
- [ ] 删除非空文件夹（确认对话框）
- [ ] 按文件夹过滤搜索
