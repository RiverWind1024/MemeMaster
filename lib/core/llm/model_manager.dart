import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// 模型信息
class ModelInfo {
  final String id;
  final String name;
  final String description;
  final String ggufUrl;
  final String? mmprojUrl;
  final String sizeLabel;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.description,
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

  /// 预设推荐模型列表
  static const recommendedModels = [
    ModelInfo(
      id: 'qwen2-vl-2b-instruct-q4_k_m',
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
      name: 'Moondream 2B',
      description: '轻量多模态，专为图片描述优化',
      ggufUrl:
          'https://huggingface.co/vikhyatk/moondream2-GGUF/resolve/main/moondream2-q4_k_m.gguf',
      sizeLabel: '~1.2 GB',
    ),
  ];

  /// 模型存储目录
  String get storageDir => _storageDir;

  /// 下载模型（带进度回调）
  Future<void> downloadModel(
    ModelInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final modelPath = p.join(_storageDir, '${info.id}.gguf');
    // TODO: 实现断点续传下载
    // 1. 检查部分下载
    // 2. HTTP GET with Range header
    // 3. 流式写入文件，回调进度
    // 4. 下载 mmproj（如果有）
    throw UnimplementedError('模型下载将在后续实现');
  }

  /// 获取已下载的模型列表
  List<DownloadedModel> getDownloadedModels() {
    final dir = Directory(_storageDir);
    if (!dir.existsSync()) return [];

    return dir.listSync().whereType<File>().where((f) {
      return f.path.endsWith('.gguf');
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
