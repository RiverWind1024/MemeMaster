import 'package:uuid/uuid.dart';

import '../database/daos/album_dao.dart';
import '../database/database.dart';

class AlbumRepository {
  final AlbumDao _dao;
  final Uuid _uuid = const Uuid();

  AlbumRepository(this._dao);

  Future<List<Album>> getAll() => _dao.getAll();
  Future<Album?> getById(String id) => _dao.getById(id);
  Future<Album?> getDefaultAlbum() => _dao.getDefaultAlbum();

  Future<Album> create({
    required String name,
    String? icon,
    int sortOrder = 0,
  }) async {
    final album = Album(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      sortOrder: sortOrder,
      isDefault: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.insert(album);
    return album;
  }

  Future<void> rename(String id, String name) => _dao.updateName(id, name);
  Future<void> delete(String id) => _dao.delete(id);

  // 关联操作
  Future<void> addMemeToAlbum(String memeId, String albumId) =>
      _dao.addMemeToAlbum(memeId, albumId);

  Future<void> removeMemeFromAlbum(String memeId, String albumId) =>
      _dao.removeMemeFromAlbum(memeId, albumId);

  Future<List<String>> getMemeIdsByAlbum(String albumId) =>
      _dao.getMemeIdsByAlbum(albumId);

  Future<List<String>> getAlbumIdsByMeme(String memeId) =>
      _dao.getAlbumIdsByMeme(memeId);

  Future<List<MemeAlbum>> getAllMemeAlbums() => _dao.getAllMemeAlbums();

  Future<int> countMemesInAlbum(String albumId) =>
      _dao.countMemesInAlbum(albumId);

  Future<void> removeMemeFromAllAlbums(String memeId) =>
      _dao.removeMemeFromAllAlbums(memeId);

  /// 批量将 meme 添加到相册
  Future<void> addMemesToAlbum(List<String> memeIds, String albumId) async {
    for (final id in memeIds) {
      await _dao.addMemeToAlbum(id, albumId);
    }
  }
}
