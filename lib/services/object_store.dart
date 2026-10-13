import 'dart:io';
import 'dart:typed_data';

import 'package:minio/io.dart';
import 'package:minio/minio.dart';

/// S3「对象确实不存在」的判定。
///
/// 只有真正的 not-found（404 / NoSuchKey / NoSuchBucket / NotFound）才算「不存在」；
/// 其余错误（5xx、503、限流、网络抖动）必须抛出，绝不能当成「对象缺失」——
/// 否则一次瞬时故障会被同步引擎当成「远端是空的」，进而重写 manifest、
/// 制造大批孤儿 blob，最后被清理逻辑误删。
bool isS3NotFound(MinioS3Error e) {
  final status = e.response?.statusCode;
  if (status != null) return status == 404;
  final code = e.error?.code;
  return code == 'NoSuchKey' ||
      code == 'NoSuchBucket' ||
      code == 'NotFound';
}

/// 对象存储抽象：把 S3 操作与同步逻辑解耦，便于单测（内存实现）。
abstract class ObjectStore {
  /// 读取字节；对象不存在返回 `null`，其他错误抛出。
  Future<Uint8List?> getBytes(String key);

  /// 写入字节。
  Future<void> putBytes(String key, Uint8List bytes);

  /// 上传本地文件。
  Future<void> uploadFile(String key, String srcPath);

  /// 下载到本地文件。
  Future<void> downloadToFile(String key, String destPath);

  /// key 是否存在；非 not-found 的错误抛出。
  Future<bool> exists(String key);

  /// 列出指定前缀下的所有 key。
  Future<List<String>> list(String prefix);

  /// 列出指定前缀下每个 key 对应的字节大小。
  Future<Map<String, int>> listWithSizes(String prefix);

  /// 删除 key（不存在时忽略）。
  Future<void> delete(String key);
}

/// 内存实现，仅用于测试。
class InMemoryObjectStore implements ObjectStore {
  final Map<String, Uint8List> _data = {};

  @override
  Future<Uint8List?> getBytes(String key) async => _data[key];

  @override
  Future<void> putBytes(String key, Uint8List bytes) async {
    _data[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> uploadFile(String key, String srcPath) async {
    _data[key] = await File(srcPath).readAsBytes();
  }

  @override
  Future<void> downloadToFile(String key, String destPath) async {
    final bytes = _data[key];
    if (bytes == null) throw FileSystemException('not found', key);
    await File(destPath).writeAsBytes(bytes);
  }

  @override
  Future<bool> exists(String key) async => _data.containsKey(key);

  @override
  Future<List<String>> list(String prefix) async =>
      _data.keys.where((k) => k.startsWith(prefix)).toList();

  @override
  Future<Map<String, int>> listWithSizes(String prefix) async => {
        for (final entry in _data.entries)
          if (entry.key.startsWith(prefix)) entry.key: entry.value.length,
      };

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

/// 基于 minio 的实现。传入 client 工厂以便复用/懒加载。
class MinioObjectStore implements ObjectStore {
  final Minio Function() _client;
  final String bucket;

  MinioObjectStore({required Minio Function() client, required this.bucket})
      : _client = client;

  @override
  Future<Uint8List?> getBytes(String key) async {
    try {
      final stream = await _client().getObject(bucket, key);
      final builder = BytesBuilder();
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } on MinioS3Error catch (e) {
      if (isS3NotFound(e)) return null;
      rethrow;
    }
  }

  @override
  Future<void> putBytes(String key, Uint8List bytes) async {
    await _client().putObject(bucket, key, Stream.value(bytes),
        size: bytes.length);
  }

  @override
  Future<void> uploadFile(String key, String srcPath) async {
    await _client().fPutObject(bucket, key, srcPath);
  }

  @override
  Future<void> downloadToFile(String key, String destPath) async {
    final stream = await _client().getObject(bucket, key);
    await stream.pipe(File(destPath).openWrite());
  }

  @override
  Future<bool> exists(String key) async {
    try {
      await _client().statObject(bucket, key);
      return true;
    } on MinioS3Error catch (e) {
      if (isS3NotFound(e)) return false;
      rethrow;
    }
  }

  @override
  Future<List<String>> list(String prefix) async {
    final result = <String>[];
    final stream =
        _client().listObjects(bucket, prefix: prefix, recursive: true);
    await for (final batch in stream) {
      for (final obj in batch.objects) {
        if (obj.key != null) result.add(obj.key!);
      }
    }
    return result;
  }

  @override
  Future<Map<String, int>> listWithSizes(String prefix) async {
    final result = <String, int>{};
    final stream =
        _client().listObjects(bucket, prefix: prefix, recursive: true);
    await for (final batch in stream) {
      for (final obj in batch.objects) {
        if (obj.key != null) result[obj.key!] = obj.size ?? 0;
      }
    }
    return result;
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _client().removeObject(bucket, key);
    } on MinioS3Error {
      // 忽略不存在
    }
  }
}
