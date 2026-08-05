import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/utils/color_utils.dart';
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('按文件名关键词搜索', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final cat = await env.createImage(name: 'cats_meme.png', rgb: [255, 0, 0]);
    final dog = await env.createImage(name: 'dogs_meme.png', rgb: [0, 255, 0]);
    await env.importService.importImages([cat, dog]);

    final results = await env.searchService.search(query: 'cats');
    expect(results.length, 1);
    expect(results.first.meme.filename, 'cats_meme.png');
  });

  testWidgets('按标签内容搜索', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    await env.db.tagDao.insert(TagEntry(
      id: 'tag_1',
      memeId: meme.id,
      source: 'ocr',
      content: '哈哈哈',
      confidence: 0.9,
    ));

    final results = await env.searchService.search(query: '哈哈');
    expect(results, isNotEmpty);
    expect(results.first.meme.id, meme.id);
  });

  testWidgets('按颜色搜索（提取主色保存后命中）', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    // 模拟调度器处理完颜色：提取主色并入库
    final imageFile = await env.storage.getImage(meme.filePath);
    final dominant = await env.colorExtractor.extract(imageFile.path);
    expect(dominant, isNotEmpty);
    expect(dominant.first.hex, '#ff0000');
    await env.memeRepo.saveColors(dominant
        .map((c) => ColorEntry(
              id: '${meme.id}_${c.hex.replaceFirst('#', '')}',
              memeId: meme.id,
              hexColor: c.hex,
              labL: c.lChannel,
              labA: c.aChannel,
              labB: c.bChannel,
              ratio: c.ratio,
            ))
        .toList());

    final results =
        await env.searchService.search(colors: [const ColorRgb(255, 0, 0)]);
    expect(results, isNotEmpty);
    expect(results.first.meme.id, meme.id);
  });

  testWidgets('无查询条件时进入浏览模式', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);

    final results = await env.searchService.search();
    expect(results.length, 1);
  });
}
