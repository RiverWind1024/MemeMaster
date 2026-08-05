import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('导出 zip 包含 manifest 与图片元数据', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final bytes = await env.exportService.exportMemesAsBytes(memeIds: [meme.id]);
    expect(bytes, isNotEmpty);

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('manifest.json'));
    expect(names.any((n) => n.endsWith('.png')), isTrue);
    expect(names.any((n) => n.startsWith('memes/') && n.endsWith('.json')), isTrue);

    final manifestFile = archive.files.firstWhere((f) => f.name == 'manifest.json');
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    expect(manifest['count'], 1);
  });

  testWidgets('导出不存在的 id 时静默跳过', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final bytes = await env.exportService.exportMemesAsBytes(memeIds: ['no_such_id']);
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.files.firstWhere((f) => f.name == 'manifest.json');
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    expect(manifest['count'], 0);
  });
}
