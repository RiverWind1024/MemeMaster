import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('成功导入图片入库并复制文件', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    final result = await env.importService.importImages([path], source: '集成测试');

    expect(result.success, 1);
    expect(result.skipped, 0);
    expect(result.errors, isEmpty);

    final memes = await env.memeRepo.getAllSorted(sortField: 'imported_at');
    expect(memes.length, 1);
    expect(memes.first.filename, 'red.png');
    expect(memes.first.source, '集成测试');
    expect(memes.first.fileHash.length, 64);

    final stored = await env.storage.getImage(memes.first.filePath);
    expect(stored.existsSync(), true);
  });

  testWidgets('重复导入同一文件被哈希去重跳过', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    final first = await env.importService.importImages([path]);
    expect(first.success, 1);

    final second = await env.importService.importImages([path]);
    expect(second.success, 0);
    expect(second.skipped, 1);
    expect(second.skippedFiles, contains('red.png'));

    expect(await env.memeRepo.count(), 1);
  });

  testWidgets('源文件不存在时跳过且不报错', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final result = await env.importService
        .importImages([p.join('/nonexistent', 'ghost.png')]);

    expect(result.success, 0);
    expect(result.skipped, 1);
    expect(result.errors, isEmpty);
    expect(result.skippedFiles, contains('ghost.png'));
    expect(await env.memeRepo.count(), 0);
  });

  testWidgets('批量导入多张图片全部成功', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final paths = <String>[
      await env.createImage(name: 'a.png', rgb: [255, 0, 0]),
      await env.createImage(name: 'b.png', rgb: [0, 255, 0]),
      await env.createImage(name: 'c.png', rgb: [0, 0, 255]),
    ];
    final result = await env.importService.importImages(paths);

    expect(result.success, 3);
    expect(result.errors, isEmpty);
    expect(await env.memeRepo.count(), 3);
  });
}
