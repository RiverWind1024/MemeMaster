import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/repositories/album_repository.dart';
import '../gallery/gallery_provider.dart';

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository(ref.read(albumDaoProvider));
});

final albumListProvider = FutureProvider<List<Album>>((ref) {
  return ref.read(albumRepositoryProvider).getAll();
});

final albumByIdProvider = FutureProvider.family<Album?, String>((ref, id) {
  return ref.read(albumRepositoryProvider).getById(id);
});

/// 当前选中的相册 ID（默认是所有图片）
final currentAlbumIdProvider = StateProvider<String?>((ref) => null);

/// 当前相册的 meme 列表
final currentAlbumMemesProvider = FutureProvider<List<Meme>>((ref) {
  final albumId = ref.watch(currentAlbumIdProvider);
  final repo = ref.read(memeRepositoryProvider);
  final albumRepo = ref.read(albumRepositoryProvider);

  if (albumId == null) {
    // null = "所有图片" → 展示全部
    return repo.getAll();
  }
  // 获取指定相册的 meme
  return albumRepo.getMemeIdsByAlbum(albumId).then((ids) async {
    if (ids.isEmpty) return <Meme>[];
    final memes = <Meme>[];
    for (final id in ids) {
      final meme = await repo.getById(id);
      if (meme != null) memes.add(meme);
    }
    return memes;
  });
});

/// 默认相册 ID（用于初始化）
final defaultAlbumIdProvider = FutureProvider<String?>((ref) async {
  final album = await ref.read(albumRepositoryProvider).getDefaultAlbum();
  return album?.id;
});
