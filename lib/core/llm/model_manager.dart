import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const _fileChannel = MethodChannel('com.memehelper.app/file');

/// 模型下载源
enum DownloadSource { huggingface, modelscope }

/// 下载状态
enum DownloadStatus { pending, downloading, paused, completed, failed }

/// 单个模型的下载跟踪状态
class DownloadState {
  final String modelId;
  final DownloadStatus status;
  final double progress; // 0.0 ~ 1.0
  final String? errorMessage;

  const DownloadState({
    required this.modelId,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return DownloadState(
      modelId: modelId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 下载取消令牌（支持暂停/继续）
class CancelToken {
  bool _cancelled = false;
  bool _paused = false;
  bool get isCancelled => _cancelled;
  bool get isPaused => _paused;
  void cancel() => _cancelled = true;
  void pause() => _paused = true;
  void resume() => _paused = false;
}

/// 下载已暂停（可恢复）
class PauseException implements Exception {
  final String message;
  const PauseException([this.message = '下载已暂停']);
  @override
  String toString() => message;
}

/// 模型信息
class ModelInfo {
  final String id;
  final String name;
  final String description;
  final DownloadSource source;
  final String ggufUrl;
  final String? mmprojUrl;
  final String sizeLabel;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    required this.ggufUrl,
    this.mmprojUrl,
    this.sizeLabel = '',
  });
}

/// 已下载的模型
class DownloadedModel {
  final String id;
  final String modelPath;
  final String? mmprojPath;
  final int fileSizeBytes;
  final DateTime downloadedAt;

  const DownloadedModel({
    required this.id,
    required this.modelPath,
    this.mmprojPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
  });
}

/// LLM 模型下载管理
///
/// 管理 GGUF 模型的下载、删除、列举。
/// 使用 HTTP Range 请求支持断点续传。
class ModelManager {
  final String _storageDir;
  final http.Client _client;

  ModelManager({required String storageDir, http.Client? client})
      : _storageDir = storageDir,
        _client = client ?? http.Client();

  /// 预设推荐模型列表（按下载源分组）
  static const Map<DownloadSource, List<ModelInfo>> recommendedModels = {
    DownloadSource.huggingface: [
      ModelInfo(
        id: 'qwen2-vl-2b-instruct-q4_k_m',
        source: DownloadSource.huggingface,
        name: 'Qwen2-VL 2B',
        description: '阿里通义多模态，中文优秀，适合手机端推理',
        ggufUrl:
            'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/qwen2-vl-2b-instruct-q4_k_m.gguf',
        mmprojUrl:
            'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-qwen2-vl-2b-instruct-f16.gguf',
        sizeLabel: '~1.8 GB',
      ),
      ModelInfo(
        id: 'moondream-2b-q4_k_m',
        source: DownloadSource.huggingface,
        name: 'Moondream 2B',
        description: '轻量多模态，专为图片描述优化',
        ggufUrl:
            'https://huggingface.co/vikhyatk/moondream2-GGUF/resolve/main/moondream2-q4_k_m.gguf',
        sizeLabel: '~1.2 GB',
      ),
    ],
    DownloadSource.modelscope: [
      ModelInfo(
        id: 'qwen2-vl-2b-instruct-q4_k_m',
        source: DownloadSource.modelscope,
        name: 'Qwen2-VL 2B',
        description: '阿里通义多模态，中文优秀（ModelScope 镜像）',
        ggufUrl:
            'https://modelscope.cn/models/AI-ModelScope/Qwen2-VL-2B-Instruct-GGUF/resolve/main/Qwen2-VL-2B-Instruct-Q4_K_M.gguf',
        // ModelScope 仓库不含 mmproj 文件，仅 HuggingFace 源提供
        sizeLabel: '~1.0 GB',
      ),
      ModelInfo(
        id: 'moondream-2b-q4_k_m',
        source: DownloadSource.modelscope,
        name: 'Moondream 2B',
        description: '轻量多模态，专为图片描述优化（ModelScope 镜像）',
        ggufUrl:
            'https://modelscope.cn/models/AI-ModelScope/moondream2-GGUF/resolve/main/moondream2-q4_k_m.gguf',
        sizeLabel: '~1.2 GB',
      ),
    ],
  };

  /// 模型存储目录
  String get storageDir => _storageDir;

  /// 净化模型 ID，确保可安全用作文件名（替换 / 等路径分隔符）
  static String sanitizeId(String id) {
    return id.replaceAll('/', '_');
  }

  /// 下载模型（带进度回调与取消支持）
  ///
  /// 返回下载的文件路径，用于UI更新。
  Future<String> downloadModel(
    ModelInfo info, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final safeId = sanitizeId(info.id);
    final mainPath = p.join(_storageDir, '$safeId.gguf');
    // 下载主模型文件
    await _downloadFile(
      url: info.ggufUrl,
      destPath: mainPath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    // 下载 mmproj 文件（如果有）
    if (info.mmprojUrl != null) {
      final mmprojPath = p.join(_storageDir, 'mmproj-$safeId.gguf');
      await _downloadFile(
        url: info.mmprojUrl!,
        destPath: mmprojPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }

    return mainPath;
  }

  /// 单个文件的断点续传下载
  Future<void> _downloadFile({
    required String url,
    required String destPath,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempPath = '$destPath.download';
    final tempFile = File(tempPath);

    // 确保父目录存在
    final parentDir = tempFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    // 检查已有临时文件大小
    int downloadedBytes = 0;
    if (await tempFile.exists()) {
      downloadedBytes = await tempFile.length();
    }

    // HEAD 请求获取总大小（部分 CDN/镜像不支持 HEAD，容错）
    int totalBytes = -1;
    try {
      final headResp = await _client.send(http.Request('HEAD', Uri.parse(url)));
      if (headResp.headers['content-length'] != null) {
        totalBytes = int.parse(headResp.headers['content-length']!);
      }
    } catch (_) {
      // HEAD 请求失败，继续尝试 GET
    }

    // 如果已下载完整，直接跳过
    if (totalBytes > 0 && downloadedBytes >= totalBytes) {
      if (await File(destPath).exists()) await File(destPath).delete();
      await tempFile.rename(destPath);
      onProgress?.call(1.0);
      return;
    }

    // GET 请求 + Range 头（支持断点续传）
    final request = http.Request('GET', Uri.parse(url));
    if (downloadedBytes > 0) {
      request.headers['Range'] = 'bytes=$downloadedBytes-';
    }
    final response = await _client.send(request);

    // 处理响应码
    final statusCode = response.statusCode;
    if (downloadedBytes > 0 && statusCode == 206) {
      // 正常: 206 Partial Content（续传）
    } else if (downloadedBytes == 0 && statusCode == 200) {
      // 正常: 200（全新下载）
    } else if (downloadedBytes > 0 && statusCode == 200) {
      // 服务器不支持 Range，重新下载
      downloadedBytes = 0;
      if (await tempFile.exists()) await tempFile.delete();
    } else {
      throw HttpException('下载失败: HTTP $statusCode', uri: Uri.parse(url));
    }

    // 从 GET 响应头获取 Content-Length（HEAD 未获取到时）
    if (totalBytes <= 0 && response.headers['content-length'] != null) {
      totalBytes = int.parse(response.headers['content-length']!);
    }

    // 流式写入
    IOSink? sink;
    try {
      sink = tempFile.openWrite(mode: FileMode.writeOnlyAppend);
    } catch (e) {
      throw Exception('无法创建下载文件: $tempPath, 错误: $e');
    }
    
    int lastReportedProgress = -1;
    try {
      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled == true) {
          // 取消：先关 sink 释放 fd，再抛错
          if (sink != null) {
            try { await sink!.close(); } catch (_) {}
            sink = null;
          }
          throw Exception('下载已取消');
        }
        if (cancelToken?.isPaused == true) {
          // 暂停：关闭 sink 保存已下载部分，中断后由 resume 续传
          await sink!.close();
          sink = null;
          throw const PauseException();
        }
        sink!.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          final p = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
          // 避免过于频繁的回调（每 0.01% 才更新）
          final pct = (p * 10000).toInt();
          if (pct != lastReportedProgress) {
            lastReportedProgress = pct;
            onProgress?.call(p);
          }
        } else {
          // 无总大小信息：用已下载字节数作为估算（单位 MB）
          final mb = downloadedBytes / (1024 * 1024);
          // 每下载约 1MB 刷新一次界面
          if ((mb * 10).toInt() != lastReportedProgress) {
            lastReportedProgress = (mb * 10).toInt();
            onProgress?.call(mb / 100.0); // 以 100MB 为100%
          }
        }
      }
      await sink!.flush();
    } catch (e) {
      if (sink != null) {
        await sink.close();
        sink = null;
      }
      rethrow;
    }
    await sink.close();

    // 重命名完成
    if (await File(destPath).exists()) await File(destPath).delete();
    await tempFile.rename(destPath);
    onProgress?.call(1.0);
  }

  /// 获取已下载的模型列表
  List<DownloadedModel> getDownloadedModels() {
    final dir = Directory(_storageDir);
    if (!dir.existsSync()) return [];

    return dir.listSync().whereType<File>().where((f) {
      return f.path.endsWith('.gguf') && !f.path.endsWith('.download');
    }).map((f) {
      final name = p.basenameWithoutExtension(f.path);
      final mmproj = File(p.join(_storageDir, 'mmproj-$name.gguf'));
      return DownloadedModel(
        id: name,
        modelPath: f.path,
        mmprojPath: mmproj.existsSync() ? mmproj.path : null,
        fileSizeBytes: f.lengthSync(),
        downloadedAt: f.lastModifiedSync(),
      );
    }).toList();
  }

  /// 删除模型
  Future<void> deleteModel(String modelId) async {
    final safeId = sanitizeId(modelId);
    final modelFile = File(p.join(_storageDir, '$safeId.gguf'));
    if (await modelFile.exists()) await modelFile.delete();

    final mmprojFile = File(p.join(_storageDir, 'mmproj-$safeId.gguf'));
    if (await mmprojFile.exists()) await mmprojFile.delete();

    // 清理残留的临时文件
    final tempFile = File(p.join(_storageDir, '$safeId.gguf.download'));
    if (await tempFile.exists()) await tempFile.delete();
  }

  /// 列出指定模型在存储目录中的所有相关文件
  /// （主模型 .gguf、mmproj、临时 .download 等）
  Future<List<File>> listModelFiles(String modelId) async {
    final safeId = sanitizeId(modelId);
    final candidates = [
      File(p.join(_storageDir, '$safeId.gguf')),
      File(p.join(_storageDir, 'mmproj-$safeId.gguf')),
      File(p.join(_storageDir, '$safeId.gguf.download')),
    ];
    final result = <File>[];
    for (final f in candidates) {
      if (await f.exists()) result.add(f);
    }
    return result;
  }

/// 启动 SAF picker 让用户浏览 Downloads/MemeHelper
  Future<void> openDownloadsFolder() async {
    if (!Platform.isAndroid) return;
    await _fileChannel.invokeMethod('openDownloadsFolder');
  }

  /// 获取存储占用（字节）
  int getStorageUsageBytes() {
    return getDownloadedModels()
        .fold<int>(0, (sum, m) => sum + m.fileSizeBytes);
  }

  void dispose() {
    _client.close();
  }
}
