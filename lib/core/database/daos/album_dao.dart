import 'package:drift/drift.dart';

import '../../database/database.dart';

/// 相册 DAO
class AlbumDao {
  final AppDatabase _db;
  AlbumDao(this._db);

  // ---- Albums ----

  Future<void> insert(Album album) async {
    await _db.into(_db.albumsTable).insertOnConflictUpdate(album);
  }

  Future<Album?> getById(String id) {
    return (_db.select(_db.albumsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Album>> getAll() {
    return (_db.select(_db.albumsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<int> updateName(String id, String name) {
    return (_db.update(_db.albumsTable)
          ..where((t) => t.id.equals(id)))
        .write(AlbumsTableCompanion(name: Value(name)));
  }

  Future<int> updateSortOrder(String id, int sortOrder) {
    return (_db.update(_db.albumsTable)
          ..where((t) => t.id.equals(id)))
        .write(AlbumsTableCompanion(sortOrder: Value(sortOrder)));
  }

  Future<int> delete(String id) {
    // 先删除关联记录，再删相册
    return (_db.delete(_db.albumsTable)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// 获取默认相册（"所有图片"）
  Future<Album?> getDefaultAlbum() {
    return (_db.select(_db.albumsTable)
          ..where((t) => t.isDefault.equals(1)))
        .getSingleOrNull();
  }

  // ---- Meme-Album 关联 ----

  Future<void> addMemeToAlbum(String memeId, String albumId) async {
    await _db.into(_db.memeAlbumsTable).insert(
      MemeAlbum(
        memeId: memeId,
        albumId: albumId,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> removeMemeFromAlbum(String memeId, String albumId) async {
    await (_db.delete(_db.memeAlbumsTable)
          ..where((t) =>
              t.memeId.equals(memeId) & t.albumId.equals(albumId)))
        .go();
  }

  /// 获取相册中的所有 memeId
  Future<List<String>> getMemeIdsByAlbum(String albumId) async {
    final rows = await (_db.select(_db.memeAlbumsTable)
          ..where((t) => t.albumId.equals(albumId))
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
    return rows.map((r) => r.memeId).toList();
  }

  /// 获取 meme 所属的所有相册 ID
  Future<List<String>> getAlbumIdsByMeme(String memeId) async {
    final rows = await (_db.select(_db.memeAlbumsTable)
          ..where((t) => t.memeId.equals(memeId)))
        .get();
    return rows.map((r) => r.albumId).toList();
  }

  /// 获取不属于默认相册的 meme 数量（用户自建相册中的 meme）
  Future<int> countMemesInAlbum(String albumId) async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) FROM meme_albums_table WHERE album_id = ?',
      variables: [Variable.withString(albumId)],
    ).getSingle();
    return result.data.values.first as int;
  }

  /// 获取所有 meme-album 关联
  Future<List<MemeAlbum>> getAllMemeAlbums() {
    return _db.select(_db.memeAlbumsTable).get();
  }

  /// 删除 meme 的所有相册关联
  Future<int> removeMemeFromAllAlbums(String memeId) async {
    return await (_db.delete(_db.memeAlbumsTable)
          ..where((t) => t.memeId.equals(memeId)))
        .go();
  }
}
