import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../../services/s3_config.dart';
import '../../services/s3_secret_store.dart';
import '../../services/s3_sync_service.dart';
import '../../services/s3_sync_serializer.dart';
import '../cli_context.dart';
import 'command.dart';

/// 纯内存版 S3SecretStore（CLI 用，不依赖 FlutterSecureStorage）。
///
/// S3 的 accessKey/secretKey 本身已由 [S3Config] 承载并入 cli_config.json，
/// 该 store 仅承载 [S3SyncService] 需要的"清空密码"等额外键，CLI 暂不暴露对应操作。
class _InMemoryS3SecretStore implements S3SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }
}

/// s3 命令：连接测试 / 同步 / 上传 / 下载 / 统计。
///
/// 复用 [S3SyncService]（纯 Dart，依赖 minio 包，无 Flutter 依赖）。
class S3Command extends CliCommand {
  S3Command() : super(name: 's3', description: 'S3 同步相关操作');

  @override
  bool get needsCliConfig => true;

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    if (args.rest.isEmpty) {
      stderr.writeln('用法: mememaster s3 <test|sync|upload|download|stats>');
      return 1;
    }
    final sub = args.rest.first;

    if (!context.s3Config.isValid) {
      stderr.writeln('S3 未配置，请先运行: mememaster config s3 '
          '--endpoint <url> --bucket <bucket> --access-key <key> --secret-key <key>');
      return 1;
    }

    final service = _buildService(context);
    switch (sub) {
      case 'test':
        return _test(context, service);
      case 'sync':
        return _consume(service.incremental(), '增量同步');
      case 'upload':
        return _consume(service.uploadAll(), '全量上传');
      case 'download':
        return _consume(service.downloadAll(), '全量下载');
      case 'stats':
        return _stats(context, service);
      default:
        stderr.writeln('未知 s3 子命令: $sub');
        return 1;
    }
  }

  S3SyncService _buildService(CliContext context) {
    final service = S3SyncService(
      memeRepo: context.memeRepo,
      albumRepo: context.albumRepo,
      storage: context.storage,
      syncStateDao: context.db.syncStateDao,
      serializer: S3SyncSerializer(
        memeRepo: context.memeRepo,
        albumRepo: context.albumRepo,
        db: context.db,
      ),
      secretStore: _InMemoryS3SecretStore(),
      db: context.db,
    );
    service.updateConfig(context.s3Config);
    return service;
  }

  Future<int> _test(CliContext context, S3SyncService service) async {
    print('测试 S3 连接（${context.s3Config.endpoint}/${context.s3Config.bucket}）...');
    final ok = await service.testConnection();
    print(ok ? '连接成功' : '连接失败');
    return ok ? 0 : 1;
  }

  /// 消费同步进度流，错误打到 stderr，进度打到 stdout。
  Future<int> _consume(Stream<S3SyncProgress> stream, String label) async {
    var hadError = false;
    await for (final p in stream) {
      if (p.errorMessage != null) {
        stderr.writeln('错误: ${p.errorMessage}');
        hadError = true;
      } else if (p.status == S3SyncStatus.uploading ||
          p.status == S3SyncStatus.downloading) {
        final verb = p.status == S3SyncStatus.uploading ? '上传' : '下载';
        print('$verb ${p.completed}/${p.total}');
      }
    }
    print('$label${hadError ? '完成（有错误）' : '完成'}');
    return hadError ? 1 : 0;
  }

  Future<int> _stats(CliContext context, S3SyncService service) async {
    try {
      final stats = await service.getStorageStats();
      if (context.jsonOutput) {
        print(jsonEncode({
          'totalBytes': stats.totalBytes,
          'objectCount': stats.objectCount,
        }));
      } else {
        print('S3 存储用量: ${stats.totalBytes} 字节, ${stats.objectCount} 个对象');
      }
      return 0;
    } catch (e) {
      stderr.writeln('获取 S3 统计失败: $e');
      return 1;
    }
  }
}
