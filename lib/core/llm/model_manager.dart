import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../services/log_service.dart' show LogService;

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

/// 模型类型
enum ModelType { normal, projection }

/// 模型信息
class ModelInfo {
  /// 完整ID，格式: author/repo/filename
  final String id;
  final String author;
  final String repo;
  final String filename;
  final String name;
  final String description;
  final DownloadSource source;
  final String? ggufUrl;
  /// 可选的 mmproj URL 列表，支持多版本选择
  final List<String>? mmprojUrls;
  final String? defaultMmprojUrl;
  final String sizeLabel;
  final ModelType modelType;

  const ModelInfo({
    required this.id,
    required this.author,
    required this.repo,
    required this.filename,
    required this.name,
    required this.description,
    required this.source,
    this.ggufUrl,
    this.mmprojUrls,
    this.defaultMmprojUrl,
    this.sizeLabel = '',
    this.modelType = ModelType.normal,
  });
}

/// 已下载的模型
class DownloadedModel {
  final String id;
  final String modelPath;
  final String? mmprojPath;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final String author;
  final String repo;
  final String filename;

  const DownloadedModel({
    required this.id,
    required this.modelPath,
    this.mmprojPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    required this.author,
    required this.repo,
    required this.filename,
  });
}

/// LLM 模型下载管理
///
/// 管理 GGUF 模型的下载、删除、列举。
/// 使用 HTTP Range 请求支持断点续传。
class ModelManager {
  final String _storageDir;
  final http.Client _client;
  final LogService? _log;

  ModelManager({required String storageDir, http.Client? client, LogService? log})
      : _storageDir = storageDir,
        _client = client ?? http.Client(),
        _log = log;

  String get _tag => 'ModelManager';

  /// 预设推荐模型列表（按下载源分组）
  static const Map<DownloadSource, List<ModelInfo>> recommendedModels = {
    DownloadSource.huggingface: [
      // -------- Qwen2-VL --------
      ModelInfo(
        id: 'Qwen/Qwen2-VL-2B-Instruct-GGUF/qwen2-vl-2b-instruct-q4_k_m.gguf',
        author: 'Qwen',
        repo: 'Qwen2-VL-2B-Instruct-GGUF',
        filename: 'qwen2-vl-2b-instruct-q4_k_m.gguf',
        source: DownloadSource.huggingface,
        name: 'Qwen2-VL 2B',
        description: '阿里通义多模态，中文优秀，适合手机端推理',
        ggufUrl:
            'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/qwen2-vl-2b-instruct-q4_k_m.gguf',
        mmprojUrls: [
          'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-qwen2-vl-2b-instruct-f16.gguf',
        ],
        defaultMmprojUrl:
            'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-qwen2-vl-2b-instruct-f16.gguf',
        sizeLabel: '~1.8 GB',
      ),
      // -------- Moondream --------
      ModelInfo(
        id: 'vikhyatk/moondream2-GGUF/moondream2-q4_k_m.gguf',
        author: 'vikhyatk',
        repo: 'moondream2-GGUF',
        filename: 'moondream2-q4_k_m.gguf',
        source: DownloadSource.huggingface,
        name: 'Moondream 2B',
        description: '轻量多模态，专为图片描述优化',
        ggufUrl:
            'https://huggingface.co/vikhyatk/moondream2-GGUF/resolve/main/moondream2-q4_k_m.gguf',
        sizeLabel: '~1.2 GB',
      ),
      // -------- Qwen3.5 VL --------
      ModelInfo(
        id: 'unsloth/Qwen3.5-2B-GGUF/Qwen3.5-2B-Q4_K_M.gguf',
        author: 'unsloth',
        repo: 'Qwen3.5-2B-GGUF',
        filename: 'Qwen3.5-2B-Q4_K_M.gguf',
        source: DownloadSource.huggingface,
        name: 'Qwen3.5 2B',
        description: '阿里最新多模态，中文优秀，支持图片理解',
        ggufUrl:
            'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
        mmprojUrls: [
          'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-F16.gguf',
          'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-BF16.gguf',
        ],
        defaultMmprojUrl:
            'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-F16.gguf',
        sizeLabel: '~1.8 GB（含 mmproj）',
      ),
      // -------- mmproj 模型 (PocketPal 风格独立模型) --------
      ModelInfo(
        id: 'Qwen/Qwen2-VL-2B-Instruct-GGUF/mmproj-qwen2-vl-2b-instruct-f16.gguf',
        author: 'Qwen',
        repo: 'Qwen2-VL-2B-Instruct-GGUF',
        filename: 'mmproj-qwen2-vl-2b-instruct-f16.gguf',
        source: DownloadSource.huggingface,
        name: 'Qwen2-VL mmproj (f16)',
        description: 'Qwen2-VL 视觉投影器',
        ggufUrl:
            'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-qwen2-vl-2b-instruct-f16.gguf',
        sizeLabel: '~668 MB',
        modelType: ModelType.projection,
      ),
      ModelInfo(
        id: 'unsloth/Qwen3.5-2B-GGUF/mmproj-F16.gguf',
        author: 'unsloth',
        repo: 'Qwen3.5-2B-GGUF',
        filename: 'mmproj-F16.gguf',
        source: DownloadSource.huggingface,
        name: 'Qwen3.5 mmproj (F16)',
        description: 'Qwen3.5 视觉投影器',
        ggufUrl:
            'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-F16.gguf',
        sizeLabel: '~668 MB',
        modelType: ModelType.projection,
      ),
      ModelInfo(
        id: 'unsloth/Qwen3.5-2B-GGUF/mmproj-BF16.gguf',
        author: 'unsloth',
        repo: 'Qwen3.5-2B-GGUF',
        filename: 'mmproj-BF16.gguf',
        source: DownloadSource.huggingface,
        name: 'Qwen3.5 mmproj (BF16)',
        description: 'Qwen3.5 视觉投影器（BF16精度）',
        ggufUrl:
            'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-BF16.gguf',
        sizeLabel: '~671 MB',
        modelType: ModelType.projection,
      ),
    ],
    DownloadSource.modelscope: [


      // -------- Qwen3.5 VL (ModelScope) --------
      ModelInfo(
        id: 'unsloth/Qwen3.5-2B-GGUF/Qwen3.5-2B-Q4_K_M.gguf',
        author: 'unsloth',
        repo: 'Qwen3.5-2B-GGUF',
        filename: 'Qwen3.5-2B-Q4_K_M.gguf',
        source: DownloadSource.modelscope,
        name: 'Qwen3.5 2B',
        description: '阿里最新多模态，中文优秀，支持图片理解（需下载 mmproj）',
        ggufUrl:
            'https://modelscope.cn/models/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
        mmprojUrls: [
          'https://modelscope.cn/models/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-F16.gguf',
          'https://modelscope.cn/models/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-BF16.gguf',
        ],
        defaultMmprojUrl:
            'https://modelscope.cn/models/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-F16.gguf',
        sizeLabel: '~1.8 GB（含 mmproj）',
      ),
      // -------- mmproj 模型 (ModelScope) --------
      ModelInfo(
        id: 'unsloth/Qwen3.5-2B-GGUF/mmproj-F16.gguf',
        author: 'unsloth',
        repo: 'Qwen3.5-2B-GGUF',
        filename: 'mmproj-F16.gguf',
        source: DownloadSource.modelscope,
        name: 'Qwen3.5 mmproj (F16)',
        description: 'Qwen3.5 视觉投影器',
        ggufUrl:
            'https://modelscope.cn/models/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-F16.gguf',
        sizeLabel: '~668 MB',
        modelType: ModelType.projection,
      ),

    ],
  };

  /// 模型存储目录
  String get storageDir => _storageDir;

  /// 净化模型 ID，确保可安全用作文件名（替换 / 等路径分隔符）
  static String sanitizeId(String id) {
    return id.replaceAll('/', '_');
  }

  /// 从完整 ID (author/repo/filename) 中解析各部分
  /// 例如: "unsloth/Qwen3.5-2B-GGUF/mmproj-F16.gguf" -> (author, repo, filename)
  static (String author, String repo, String filename) parseModelId(String id) {
    final parts = id.split('/');
    if (parts.length >= 3) {
      return (parts[0], parts[1], parts.sublist(2).join('/'));
    } else if (parts.length == 2) {
      return (parts[0], parts[1], '');
    } else {
      return ('', id, '');
    }
  }

  /// 构建存储路径: {storageDir}/{author}/{repo}/{filename}
  static String buildStoragePath(String storageDir, String author, String repo, String filename) {
    return p.join(storageDir, author, repo, filename);
  }

  /// 从存储路径解析出 (author, repo, filename)
  static (String author, String repo, String filename)? parseStoragePath(String storageDir, String path) {
    if (!path.startsWith(storageDir)) return null;
    final relative = path.substring(storageDir.length).replaceAll('\\', '/');
    final parts = relative.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3) {
      return (parts[0], parts[1], parts.sublist(2).join('/'));
    }
    return null;
  }

  /// 下载模型（带进度回调与取消支持）
  ///
  /// 返回下载的文件路径，用于UI更新。
  /// 使用 PocketPal 风格路径: {storageDir}/{author}/{repo}/{filename}
  Future<String> downloadModel(
    ModelInfo info, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // 使用新的路径结构
    final storagePath = buildStoragePath(_storageDir, info.author, info.repo, info.filename);
    _log?.info(_tag, 'downloadModel 开始: id=${info.id}, path=$storagePath');

    // 下载模型文件
    if (info.ggufUrl != null) {
      await _downloadFile(
        url: info.ggufUrl!,
        destPath: storagePath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }

    _log?.info(_tag, 'downloadModel 完成: path=$storagePath');
    return storagePath;
  }

  /// 下载 mmproj 文件（如果有配置）
  Future<String?> downloadMmproj(
    ModelInfo info, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (info.defaultMmprojUrl == null) return null;

    // 从 URL 解析文件名
    final urlUri = Uri.parse(info.defaultMmprojUrl!);
    final segments = urlUri.pathSegments;
    final mmprojFilename = segments.isNotEmpty ? segments.last : 'mmproj.gguf';

    final mmprojPath = buildStoragePath(_storageDir, info.author, info.repo, mmprojFilename);
    _log?.info(_tag, 'downloadMmproj 开始: path=$mmprojPath');

    await _downloadFile(
      url: info.defaultMmprojUrl!,
      destPath: mmprojPath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    _log?.info(_tag, 'downloadMmproj 完成: path=$mmprojPath');
    return mmprojPath;
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

    _log?.info(_tag, '_downloadFile 开始: url=$url, dest=$destPath');

    // 确保父目录存在
    final parentDir = tempFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    // 检查已有临时文件大小
    int downloadedBytes = 0;
    if (await tempFile.exists()) {
      downloadedBytes = await tempFile.length();
      _log?.info(_tag, '发现已有临时文件: ${_formatBytes(downloadedBytes)}');
    }

    // HEAD 请求获取总大小（部分 CDN/镜像不支持 HEAD，容错）
    int totalBytes = -1;
    try {
      final headResp = await _client.send(http.Request('HEAD', Uri.parse(url)));
      if (headResp.headers['content-length'] != null) {
        totalBytes = int.parse(headResp.headers['content-length']!);
        _log?.info(_tag, 'HEAD 响应: content-length=$totalBytes (${_formatBytes(totalBytes)})');
      } else {
        _log?.info(_tag, 'HEAD 响应: 无 content-length 头');
      }
    } catch (e) {
      _log?.warning(_tag, 'HEAD 请求失败: $e');
    }

    // 如果已下载完整，直接跳过
    if (totalBytes > 0 && downloadedBytes >= totalBytes) {
      _log?.info(_tag, '临时文件已完整，跳过下载');
      if (await File(destPath).exists()) await File(destPath).delete();
      await tempFile.rename(destPath);
      onProgress?.call(1.0);
      return;
    }

    // GET 请求 + Range 头（支持断点续传）
    final request = http.Request('GET', Uri.parse(url));
    if (downloadedBytes > 0) {
      request.headers['Range'] = 'bytes=$downloadedBytes-';
      _log?.info(_tag, '使用 Range 续传: bytes=$downloadedBytes-');
    }
    final response = await _client.send(request);

    // 处理响应码
    final statusCode = response.statusCode;
    _log?.info(_tag, 'GET 响应: statusCode=$statusCode, content-length=${response.headers['content-length']}');
    if (downloadedBytes > 0 && statusCode == 206) {
      // 正常: 206 Partial Content（续传）
    } else if (downloadedBytes == 0 && statusCode == 200) {
      // 正常: 200（全新下载）
    } else if (downloadedBytes > 0 && statusCode == 200) {
      // 服务器不支持 Range，重新下载
      _log?.warning(_tag, '服务器不支持 Range，重新从头下载');
      downloadedBytes = 0;
      if (await tempFile.exists()) await tempFile.delete();
    } else {
      final errMsg = '下载失败: HTTP $statusCode';
      _log?.error(_tag, errMsg);
      throw HttpException(errMsg, uri: Uri.parse(url));
    }

    // 从 GET 响应头获取 Content-Length（HEAD 未获取到时）
    if (totalBytes <= 0 && response.headers['content-length'] != null) {
      totalBytes = int.parse(response.headers['content-length']!);
      _log?.info(_tag, '从 GET 响应获取 content-length: $totalBytes');
    }

    // 流式写入
    IOSink? sink;
    try {
      sink = tempFile.openWrite(mode: FileMode.writeOnlyAppend);
    } catch (e) {
      _log?.error(_tag, '无法创建下载文件: $tempPath, 错误: $e');
      throw Exception('无法创建下载文件: $tempPath, 错误: $e');
    }
    
    int lastReportedProgress = -1;
    int lastLogProgress = -1; // 每 10% 打一次日志
    try {
      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled == true) {
          _log?.info(_tag, '下载被取消');
          if (sink != null) {
            try { await sink!.close(); } catch (_) {}
            sink = null;
          }
          throw Exception('下载已取消');
        }
        if (cancelToken?.isPaused == true) {
          _log?.info(_tag, '下载被暂停，已下载: ${_formatBytes(downloadedBytes)}');
          await sink!.close();
          sink = null;
          throw const PauseException();
        }
        sink!.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          final p = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
          final pct = (p * 10000).toInt();
          if (pct != lastReportedProgress && p < 1.0) {
            lastReportedProgress = pct;
            onProgress?.call(p);
          }
          // 每 10% 记一次日志
          final logPct = (p * 10).floor() * 10;
          if (logPct != lastLogProgress) {
            lastLogProgress = logPct;
            _log?.info(_tag, '下载进度: $logPct% (${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)})');
          }
        } else {
          final mb = downloadedBytes / (1024 * 1024);
          if ((mb * 10).toInt() != lastReportedProgress) {
            lastReportedProgress = (mb * 10).toInt();
            onProgress?.call(mb / 100.0);
          }
          final logMb = (mb / 10).floor() * 10;
          if (logMb != lastLogProgress && logMb > 0) {
            lastLogProgress = logMb;
            _log?.info(_tag, '下载进度: ~${_formatBytes(downloadedBytes)}');
          }
        }
      }
      await sink!.flush();
    } catch (e) {
      if (sink != null) {
        await sink.close();
        sink = null;
      }
      _log?.error(_tag, '下载流异常: $e (已下载 ${_formatBytes(downloadedBytes)})');
      rethrow;
    }
    await sink.close();

    // 重命名完成
    _log?.info(_tag, '下载完成，重命名: $tempPath -> $destPath');
    if (await File(destPath).exists()) await File(destPath).delete();
    await tempFile.rename(destPath);
    onProgress?.call(1.0);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 获取已下载的模型列表
  /// 递归扫描 {storageDir}/{author}/{repo}/ 下的所有 .gguf 文件
  List<DownloadedModel> getDownloadedModels() {
    final dir = Directory(_storageDir);
    if (!dir.existsSync()) return [];

    final result = <DownloadedModel>[];

    // 递归扫描所有子目录
    for (final authorDir in dir.listSync().whereType<Directory>()) {
      for (final repoDir in authorDir.listSync().whereType<Directory>()) {
        for (final file in repoDir.listSync().whereType<File>()) {
          if (!file.path.endsWith('.gguf') || file.path.endsWith('.download')) {
            continue;
          }

          final filename = p.basename(file.path);
          final author = p.basename(authorDir.path);
          final repo = p.basename(repoDir.path);
          final id = '$author/$repo/$filename';

          // 查找同目录下的 mmproj 文件
          String? mmprojPath;
          for (final sibling in repoDir.listSync().whereType<File>()) {
            if (sibling.path.endsWith('.gguf') &&
                sibling.path.contains('mmproj') &&
                !sibling.path.endsWith('.download')) {
              mmprojPath = sibling.path;
              break;
            }
          }

          result.add(DownloadedModel(
            id: id,
            modelPath: file.path,
            mmprojPath: mmprojPath,
            fileSizeBytes: file.lengthSync(),
            downloadedAt: file.lastModifiedSync(),
            author: author,
            repo: repo,
            filename: filename,
          ));
        }
      }
    }

    return result;
  }

  /// 删除模型
  /// 根据 ID (author/repo/filename) 删除文件及同目录下的 mmproj
  Future<void> deleteModel(String modelId) async {
    final (author, repo, filename) = parseModelId(modelId);
    if (author.isEmpty || repo.isEmpty || filename.isEmpty) {
      _log?.warning(_tag, 'deleteModel: 无效的 modelId: $modelId');
      return;
    }

    final modelPath = buildStoragePath(_storageDir, author, repo, filename);
    final modelFile = File(modelPath);
    if (await modelFile.exists()) {
      await modelFile.delete();
      _log?.info(_tag, 'deleteModel: 已删除 $modelPath');
    }

    // 删除同目录下的 mmproj 文件
    final repoDir = Directory(p.join(_storageDir, author, repo));
    if (await repoDir.exists()) {
      for (final file in repoDir.listSync().whereType<File>()) {
        if (file.path.contains('mmproj') && file.path.endsWith('.gguf')) {
          await file.delete();
          _log?.info(_tag, 'deleteModel: 已删除 mmproj ${file.path}');
        }
      }
    }

    // 清理残留的临时文件
    final tempFile = File('$modelPath.download');
    if (await tempFile.exists()) await tempFile.delete();
  }

  /// 列出指定模型在存储目录中的所有相关文件
  /// （主模型 .gguf、mmproj、临时 .download 等）
  Future<List<File>> listModelFiles(String modelId) async {
    final (author, repo, filename) = parseModelId(modelId);
    if (author.isEmpty || repo.isEmpty) {
      return [];
    }

    final modelPath = buildStoragePath(_storageDir, author, repo, filename);
    final candidates = [
      File(modelPath),
      File('$modelPath.download'),
    ];

    // 添加同目录下的 mmproj 文件
    final repoDir = Directory(p.join(_storageDir, author, repo));
    if (await repoDir.exists()) {
      for (final file in repoDir.listSync().whereType<File>()) {
        if (file.path.contains('mmproj') && file.path.endsWith('.gguf')) {
          candidates.add(file);
        }
      }
    }

    final result = <File>[];
    for (final f in candidates) {
      if (await f.exists()) result.add(f);
    }
    return result;
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
