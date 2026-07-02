import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// 模型下载源
enum DownloadSource { huggingface, modelscope }

/// 下载状态
enum DownloadStatus { pending, downloading, completed, failed }

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

/// 下载取消令牌
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
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
            'https://modelscope.cn/models/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/qwen2-vl-2b-instruct-q4_k_m.gguf',
        mmprojUrl:
            'https://modelscope.cn/models/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-qwen2-vl-2b-instruct-f16.gguf',
        sizeLabel: '~1.8 GB',
      ),
      ModelInfo(
        id: 'moondream-2b-q4_k_m',
        source: DownloadSource.modelscope,
        name: 'Moondream 2B',
        description: '轻量多模态，专为图片描述优化（ModelScope 镜像）',
        ggufUrl:
            'https://modelscope.cn/models/vikhyatk/moondream2-GGUF/resolve/main/moondream2-q4_k_m.gguf',
        sizeLabel: '~1.2 GB',
      ),
    ],
  };

  /// 模型存储目录
  String get storageDir => _storageDir;

  /// 下载模型（带进度回调与取消支持）
  Future<void> downloadModel(
    ModelInfo info, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // 下载主模型文件
    await _downloadFile(
      url: info.ggufUrl,
      destPath: p.join(_storageDir, '${info.id}.gguf'),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    // 下载 mmproj 文件（如果有）
    if (info.mmprojUrl != null) {
      await _downloadFile(
        url: info.mmprojUrl!,
        destPath: p.join(_storageDir, 'mmproj-${info.id}.gguf'),
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
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

    // 检查已有临时文件大小
    int downloadedBytes = 0;
    if (await tempFile.exists()) {
      downloadedBytes = await tempFile.length();
    }

    // HEAD 请求获取总大小
    final headResp = await _client.send(http.Request('HEAD', Uri.parse(url)));
    final totalBytes = headResp.headers['content-length'] != null
        ? int.parse(headResp.headers['content-length']!)
        : -1;

    // 如果已下载完整，直接跳过
    if (totalBytes > 0 && downloadedBytes >= totalBytes) {
      if (await File(destPath).exists()) await File(destPath).delete();
      await tempFile.rename(destPath);
      onProgress?.call(1.0);
      return;
    }

    // GET 请求 + Range 头
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

    // 流式写入
    final sink = tempFile.openWrite(mode: FileMode.writeOnlyAppend);
    try {
      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled == true) {
          throw Exception('下载已取消');
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(downloadedBytes / totalBytes);
        }
      }
      await sink.flush();
    } catch (e) {
      await sink.close();
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
    final modelFile = File(p.join(_storageDir, '$modelId.gguf'));
    if (await modelFile.exists()) await modelFile.delete();

    final mmprojFile = File(p.join(_storageDir, 'mmproj-$modelId.gguf'));
    if (await mmprojFile.exists()) await mmprojFile.delete();

    // 清理残留的临时文件
    final tempFile = File(p.join(_storageDir, '$modelId.gguf.download'));
    if (await tempFile.exists()) await tempFile.delete();
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
