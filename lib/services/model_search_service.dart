import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/llm/model_manager.dart';

/// 搜索到的模型信息
class SearchableModel {
  final String id;
  final String name;
  final String author;
  final int downloads;
  final String? description;
  final List<String> tags;
  final String source; // 'huggingface' or 'modelscope'
  final String? parameterSize; // 参数量，例如 "7B", "13B", "70B"

  const SearchableModel({
    required this.id,
    required this.name,
    required this.author,
    required this.downloads,
    this.description,
    required this.tags,
    required this.source,
    this.parameterSize,
  });
}

/// 分页搜索结果
class SearchResult {
  final List<SearchableModel> models;
  final int totalCount; // 所有匹配的结果总数
  final int currentPage;
  final int pageSize;

  bool get hasMore => currentPage * pageSize < totalCount;

  const SearchResult({
    required this.models,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });
}

/// 模型文件信息（GGUF 文件）
class ModelFileInfo {
  final String path;
  final int size;
  final String downloadUrl;

  const ModelFileInfo({
    required this.path,
    required this.size,
    required this.downloadUrl,
  });
}

/// 模型搜索服务
///
/// 支持 HuggingFace 和 ModelScope 两个平台的模型搜索。
class ModelSearchService {
  final http.Client _client;

  ModelSearchService({http.Client? client}) : _client = client ?? http.Client();

  /// 搜索模型
  ///
  /// [source] 下载源
  /// [query] 搜索关键词
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页结果数量
  Future<SearchResult> search({
    required DownloadSource source,
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (source == DownloadSource.huggingface) {
      return _searchHuggingFace(query, page, pageSize);
    } else {
      return _searchModelScope(query, page, pageSize);
    }
  }

  /// 获取模型的 GGUF 文件列表
  ///
  /// 返回该模型仓库中的所有 .gguf 文件
  Future<List<ModelFileInfo>> getGgufFiles({
    required DownloadSource source,
    required String modelId,
  }) async {
    if (source == DownloadSource.huggingface) {
      return _getHuggingFaceFiles(modelId);
    } else {
      return _getModelScopeFiles(modelId);
    }
  }

  // ---- HuggingFace ----

  Future<SearchResult> _searchHuggingFace(String query, int page, int pageSize) async {
    final offset = (page - 1) * pageSize;
    final url = Uri.parse(
      'https://huggingface.co/api/models'
      '?search=${Uri.encodeComponent(query)}'
      '&filter=gguf'
      '&sort=downloads'
      '&direction=-1'
      '&limit=$pageSize'
      '&offset=$offset',
    );

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw Exception('HuggingFace API 错误: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    final models = data.map((item) {
      final id = item['id'] as String? ?? '';
      final parts = id.split('/');
      final author = parts.length > 1 ? parts[0] : '';
      final name = parts.length > 1 ? parts[1] : id;

      return SearchableModel(
        id: id,
        name: name,
        author: author,
        downloads: item['downloads'] as int? ?? 0,
        description: item['description'] as String?,
        tags: (item['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        source: 'huggingface',
        parameterSize: null,
      );
    }).toList();

    // 从响应头获取总数量
    final totalCountStr = response.headers['x-total-count'];
    final totalCount =
        totalCountStr != null ? int.tryParse(totalCountStr) ?? models.length : models.length;

    return SearchResult(
      models: models,
      totalCount: totalCount,
      currentPage: page,
      pageSize: pageSize,
    );
  }

  Future<List<ModelFileInfo>> _getHuggingFaceFiles(String modelId) async {
    final url = Uri.parse(
      'https://huggingface.co/api/models/$modelId/tree/main',
    );

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw Exception('HuggingFace API 错误: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data
        .where((item) => (item['path'] as String?)?.endsWith('.gguf') == true)
        .map((item) {
      final path = item['path'] as String;
      return ModelFileInfo(
        path: path,
        size: item['size'] as int? ?? 0,
        downloadUrl:
            'https://huggingface.co/$modelId/resolve/main/$path',
      );
    }).toList();
  }

  // ---- ModelScope ----

  Future<SearchResult> _searchModelScope(String query, int page, int pageSize) async {
    // ModelScope OpenAPI: GET /openapi/v1/models?search=...&page_number=...&page_size=...
    final url = Uri.parse(
      'https://modelscope.cn/openapi/v1/models'
      '?search=${Uri.encodeComponent(query)}'
      '&page_number=$page'
      '&page_size=$pageSize',
    );

    try {
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw Exception('ModelScope API 错误: ${response.statusCode}');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception('ModelScope API 失败: ${data['message'] ?? 'unknown'}');
      }

      final Map<String, dynamic> resultData = data['data'] ?? {};
      final List<dynamic> models = resultData['models'] ?? [];

      // 从响应中获取总数（各字段名可能不同，尝试多个常见字段）
      final totalCount = resultData['total'] as int? ??
          resultData['total_count'] as int? ??
          resultData['totalCount'] as int? ??
          models.length;

      final parsedModels = models.map((item) {
        final id = item['id'] as String? ?? '';
        final displayName = item['display_name'] as String?;
        final name = displayName ?? id;
        final parts = id.split('/');
        final author = parts.length > 1 ? parts[0] : '';

        // 从 API 的 params 字段获取参数量（如果有的话）
        final params = item['params'] as int?;
        String? parameterSize;
        if (params != null && params > 0) {
          // 转换为人类可读格式：如 396802360816 -> "396B" 或 "396.8B"
          parameterSize = _formatParameterSize(params);
        }

        return SearchableModel(
          id: id,
          name: name,
          author: author,
          downloads: item['downloads'] as int? ?? 0,
          description: item['description'] as String?,
          tags: (item['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          source: 'modelscope',
          parameterSize: parameterSize,
        );
      }).toList();

      return SearchResult(
        models: parsedModels,
        totalCount: totalCount,
        currentPage: page,
        pageSize: pageSize,
      );
    } catch (e) {
      throw Exception('ModelScope 搜索失败: $e');
    }
  }

  Future<List<ModelFileInfo>> _getModelScopeFiles(String modelId) async {
    // ModelScope 获取文件列表 API: GET /api/v1/models/{owner}/{name}/repo/files?Recursive=true
    final parts = modelId.split('/');
    if (parts.length < 2) {
      throw Exception('无效的 ModelScope 模型 ID: $modelId');
    }
    final owner = parts[0];
    final name = parts[1];

    final url = Uri.parse(
      'https://modelscope.cn/api/v1/models/$owner/$name/repo/files?Recursive=true',
    );

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw Exception('ModelScope API 错误: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['Code'] != 200) {
      throw Exception('ModelScope API 失败: ${data['Message'] ?? 'unknown'}');
    }

    final List<dynamic> files = data['Data']['Files'] ?? [];

    return files
        .where((item) => (item['Path'] as String?)?.endsWith('.gguf') == true)
        .map((item) {
      final path = item['Path'] as String;
      return ModelFileInfo(
        path: path,
        size: item['Size'] as int? ?? 0,
        downloadUrl:
            'https://modelscope.cn/models/$modelId/resolve/master/$path',
      );
    }).toList();
  }

  /// 格式化参数量为人类可读字符串
  ///
  /// 例如: 396802360816 -> "397B", 7000000000 -> "7B", 13000000000 -> "13B"
  String? _formatParameterSize(int params) {
    if (params <= 0) return null;

    // 转换为十亿/百万为单位
    if (params >= 1_000_000_000) {
      final billions = params / 1_000_000_000;
      // 如果接近整数，显示整数，否则保留一位小数
      if (billions == billions.roundToDouble()) {
        return '${billions.round()}B';
      }
      return '${billions.toStringAsFixed(1)}B';
    } else if (params >= 1_000_000) {
      final millions = params / 1_000_000;
      if (millions == millions.roundToDouble()) {
        return '${millions.round()}M';
      }
      return '${millions.toStringAsFixed(1)}M';
    } else if (params >= 1_000) {
      final thousands = params / 1_000;
      if (thousands == thousands.roundToDouble()) {
        return '${thousands.round()}K';
      }
      return '${thousands.toStringAsFixed(1)}K';
    }

    return '${params}';
  }

  void dispose() {
    _client.close();
  }
}
