// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import '../core/database/database.dart';
import '../core/repositories/album_repository.dart';
import '../core/repositories/meme_repository.dart';

/// 单条 meme 的完整可传输数据（含子资源）
class MemeSyncData {
  final Meme meme;
  final List<TagEntry> tags;
  final List<ColorEntry> colors;

  MemeSyncData({
    required this.meme,
    required this.tags,
    required this.colors,
  });

  Map<String, dynamic> toJson() => {
        'id': meme.id,
        'filename': meme.filename,
        'filePath': meme.filePath,
        'fileHash': meme.fileHash,
        'fileSize': meme.fileSize,
        'mimeType': meme.mimeType,
        'width': meme.width,
        'height': meme.height,
        'folderId': meme.folderId,
        'description': meme.description,
        'analysisStatus': meme.analysisStatus,
        'createdAt': meme.createdAt,
        'updatedAt': meme.updatedAt,
        'importedAt': meme.importedAt,
        'tags': tags
            .map((t) => {
                  'id': t.id,
                  'memeId': t.memeId,
                  'source': t.source,
                  'content': t.content,
                  'confidence': t.confidence,
                })
            .toList(),
        'colors': colors
            .map((c) => {
                  'id': c.id,
                  'memeId': c.memeId,
                  'hexColor': c.hexColor,
                  'labL': c.labL,
                  'labA': c.labA,
                  'labB': c.labB,
                  'ratio': c.ratio,
                })
            .toList(),
      };

  factory MemeSyncData.fromJson(Map<String, dynamic> json) {
    return MemeSyncData(
      meme: Meme(
        id: json['id'] as String,
        filename: json['filename'] as String,
        filePath: json['filePath'] as String,
        fileHash: json['fileHash'] as String,
        fileSize: json['fileSize'] as int,
        mimeType: json['mimeType'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        folderId: json['folderId'] as String?,
        description: json['description'] as String?,
        analysisStatus: json['analysisStatus'] as String,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
        importedAt: json['importedAt'] as int,
      ),
      tags: (json['tags'] as List)
          .map((t) => TagEntry(
                id: t['id'] as String,
                memeId: t['memeId'] as String,
                source: t['source'] as String,
                content: t['content'] as String,
                confidence: (t['confidence'] as num).toDouble(),
              ))
          .toList(),
      colors: (json['colors'] as List)
          .map((c) => ColorEntry(
                id: c['id'] as String,
                memeId: c['memeId'] as String,
                hexColor: c['hexColor'] as String,
                labL: (c['labL'] as num).toDouble(),
                labA: (c['labA'] as num).toDouble(),
                labB: (c['labB'] as num).toDouble(),
                ratio: (c['ratio'] as num).toDouble(),
              ))
          .toList(),
    );
  }
}

/// 全量同步数据：所有 memes + 所有 albums + 关联
class FullSyncData {
  final List<MemeSyncData> memes;
  final List<Album> albums;
  final List<MemeAlbum> memeAlbums;
  final int version;
  final int exportedAt;

  FullSyncData({
    required this.memes,
    required this.albums,
    required this.memeAlbums,
    required this.version,
    required this.exportedAt,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt,
        'memes': memes.map((m) => m.toJson()).toList(),
        'albums': albums
            .map((a) => {
                  'id': a.id,
                  'name': a.name,
                  'icon': a.icon,
                  'sortOrder': a.sortOrder,
                  'isDefault': a.isDefault,
                  'createdAt': a.createdAt,
                })
            .toList(),
        'memeAlbums': memeAlbums
            .map((ma) => {
                  'memeId': ma.memeId,
                  'albumId': ma.albumId,
                  'addedAt': ma.addedAt,
                })
            .toList(),
      };

  factory FullSyncData.fromJson(Map<String, dynamic> json) {
    return FullSyncData(
      version: json['version'] as int,
      exportedAt: json['exportedAt'] as int,
      memes: (json['memes'] as List)
          .map((m) => MemeSyncData.fromJson(m as Map<String, dynamic>))
          .toList(),
      albums: (json['albums'] as List)
          .map((a) => Album(
                id: a['id'] as String,
                name: a['name'] as String,
                icon: a['icon'] as String?,
                sortOrder: a['sortOrder'] as int,
                isDefault: a['isDefault'] as int,
                createdAt: a['createdAt'] as int,
              ))
          .toList(),
      memeAlbums: (json['memeAlbums'] as List)
          .map((ma) => MemeAlbum(
                memeId: ma['memeId'] as String,
                albumId: ma['albumId'] as String,
                addedAt: ma['addedAt'] as int,
              ))
          .toList(),
    );
  }

  String toJsonString() => jsonEncode(toJson());
}

/// 序列化/反序列化 memes 及相关关联数据（tags/colors/albums）
///
/// 导出时从 Repository 读取，导入时直接写 DAO（批量场景）。
class S3SyncSerializer {
  final MemeRepository _memeRepo;
  final AlbumRepository _albumRepo;
  final AppDatabase _db;

  S3SyncSerializer({
    required MemeRepository memeRepo,
    required AlbumRepository albumRepo,
    required AppDatabase db,
  })  : _memeRepo = memeRepo,
        _albumRepo = albumRepo,
        _db = db;

  /// 导出全量数据
  Future<FullSyncData> exportFull(int version) async {
    final memes = await _memeRepo.getAll();
    final memesWithData =
        await Future.wait(memes.map((m) => _exportMeme(m)));
    final albums = await _albumRepo.getAll();
    final memeAlbums = await _albumRepo.getAllMemeAlbums();
    return FullSyncData(
      memes: memesWithData,
      albums: albums,
      memeAlbums: memeAlbums,
      version: version,
      exportedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<MemeSyncData> _exportMeme(Meme meme) async {
    final tags = await _memeRepo.getTags(meme.id);
    final colors = await _memeRepo.getColors(meme.id);
    return MemeSyncData(meme: meme, tags: tags, colors: colors);
  }

  /// 全量导入（在事务中清空旧数据 → 写入新数据）
  Future<void> importFull(FullSyncData data) async {
    await _db.transaction(() async {
      // 1. 清空所有关联表（FK 顺序：先子表再父表）
      await _db.delete(_db.syncStateTable).go();
      await _db.delete(_db.memeAlbumsTable).go();
      await _db.delete(_db.colorsTable).go();
      await _db.delete(_db.tagsTable).go();
      await _db.delete(_db.memesTable).go();
      await _db.delete(_db.albumsTable).go();

      // 2. 导入 albums
      for (final album in data.albums) {
        await _db.into(_db.albumsTable).insertOnConflictUpdate(album);
      }

      // 3. 导入 memes
      for (final memeData in data.memes) {
        await _db.into(_db.memesTable).insertOnConflictUpdate(memeData.meme);

        // 4. 导入 tags
        for (final tag in memeData.tags) {
          await _db.into(_db.tagsTable).insertOnConflictUpdate(tag);
        }

        // 5. 导入 colors
        for (final color in memeData.colors) {
          await _db.into(_db.colorsTable).insertOnConflictUpdate(color);
        }
      }

      // 6. 导入 meme-album 关联
      for (final ma in data.memeAlbums) {
        await _db.into(_db.memeAlbumsTable).insertOnConflictUpdate(ma);
      }
    });
  }
}
