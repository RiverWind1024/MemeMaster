import 'package:minio/io.dart';
import 'package:minio/minio.dart';

import '../core/database/database.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';
import 's3_config.dart';

/// S3 同步服务
///
/// 使用 `minio` 包将本地 meme 图片上传到 S3 兼容存储。
class S3SyncService {
  final MemeRepository _memeRepo;
  final FileStorageService _storage;
  S3Config _config = const S3Config();
  Minio? _client;

  S3SyncService({
    required this._memeRepo,
    required this._storage,
  });

  S3Config get config => _config;

  void updateConfig(S3Config config) {
    _config = config;
    _client = null; // 下次使用时重建 client
  }

  bool get isConfigured => _config.isValid;

  Minio _getClient() {
    _client ??= Minio(
      endPoint: _config.endpoint,
      accessKey: _config.accessKey,
      secretKey: _config.secretKey,
      region: _config.region,
      useSSL: _config.useSsl,
    );
    return _client!;
  }

  /// 上传所有 meme 到 S3
  Stream<S3SyncProgress> uploadAll() async* {
    if (!isConfigured) {
      yield const S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: 'S3 未配置',
      );
      return;
    }

    final memes = await _memeRepo.getAll();
    if (memes.isEmpty) {
      yield const S3SyncProgress(completed: 0, total: 0);
      return;
    }

    var completed = 0;
    for (final meme in memes) {
      yield S3SyncProgress(
        status: S3SyncStatus.uploading,
        completed: completed,
        total: memes.length,
      );

      try {
        await _uploadFile(meme);
        completed++;
      } catch (e) {
        yield S3SyncProgress(
          status: S3SyncStatus.error,
          completed: completed,
          total: memes.length,
          errorMessage: '上传失败: ${meme.filename}: $e',
        );
        return;
      }
    }

    yield S3SyncProgress(
      status: S3SyncStatus.idle,
      completed: completed,
      total: memes.length,
    );
  }

  Future<void> _uploadFile(Meme meme) async {
    final file = await _storage.getImage(meme.filePath);
    final client = _getClient();
    await client.fPutObject(
      _config.bucket,
      meme.filePath,
      file.absolute.path,
    );
  }
}
