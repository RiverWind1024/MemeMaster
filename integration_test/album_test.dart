import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('创建相册并加入图片', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final album = await env.albumRepo.create(name: '表情包');
    await env.albumRepo.addMemesToAlbum([meme.id], album.id);

    final ids = await env.albumRepo.getMemeIdsByAlbum(album.id);
    expect(ids, contains(meme.id));
    expect(await env.albumRepo.countMemesInAlbum(album.id), 1);
  });

  testWidgets('移出相册后计数归零', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final album = await env.albumRepo.create(name: '表情包');
    await env.albumRepo.addMemeToAlbum(meme.id, album.id);
    expect(await env.albumRepo.countMemesInAlbum(album.id), 1);

    await env.albumRepo.removeMemeFromAlbum(meme.id, album.id);
    expect(await env.albumRepo.countMemesInAlbum(album.id), 0);
  });

  testWidgets('按 meme 查询所属相册', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final album = await env.albumRepo.create(name: '表情包');
    await env.albumRepo.addMemeToAlbum(meme.id, album.id);

    final albumIds = await env.albumRepo.getAlbumIdsByMeme(meme.id);
    expect(albumIds, contains(album.id));
  });
}
