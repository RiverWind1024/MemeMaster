import '../core/database/database.dart';

/// 单条 meme 的完整可传输数据（含子资源）
class MemeSyncData {
  final Meme meme;
  final List<TagEntry> tags;
  final List<ColorEntry> colors;
  final List<String> albumIds;

  MemeSyncData({
    required this.meme,
    required this.tags,
    required this.colors,
    this.albumIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': meme.id,
        'filename': meme.filename,
        'filePath': meme.filePath,
        'customName': meme.customName,
        'fileHash': meme.fileHash,
        'fileSize': meme.fileSize,
        'mimeType': meme.mimeType,
        'width': meme.width,
        'height': meme.height,
        'folderId': meme.folderId,
        'description': meme.description,
        'analysisStatus': meme.analysisStatus,
        'colorAnalysisStatus': meme.colorAnalysisStatus,
        'ocrAnalysisStatus': meme.ocrAnalysisStatus,
        'aiAnalysisStatus': meme.aiAnalysisStatus,
        'createdAt': meme.createdAt,
        'updatedAt': meme.updatedAt,
        'importedAt': meme.importedAt,
        'copyCount': meme.copyCount,
        'source': meme.source,
        'deletedAt': meme.deletedAt,
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
        'albumIds': albumIds,
      };

  factory MemeSyncData.fromJson(Map<String, dynamic> json) {
    return MemeSyncData(
      meme: Meme(
        id: json['id'] as String,
        filename: json['filename'] as String,
        filePath: json['filePath'] as String,
        customName: json['customName'] as String?,
        fileHash: json['fileHash'] as String,
        fileSize: json['fileSize'] as int,
        mimeType: json['mimeType'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        folderId: json['folderId'] as String?,
        description: json['description'] as String?,
        analysisStatus: json['analysisStatus'] as String? ?? 'pending',
        colorAnalysisStatus: json['colorAnalysisStatus'] as String? ?? 'pending',
        ocrAnalysisStatus: json['ocrAnalysisStatus'] as String? ?? 'pending',
        aiAnalysisStatus: json['aiAnalysisStatus'] as String? ?? 'pending',
        copyCount: json['copyCount'] as int? ?? 0,
        source: json['source'] as String?,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
        importedAt: json['importedAt'] as int,
        deletedAt: json['deletedAt'] as int?,
      ),
      tags: (json['tags'] as List?)
              ?.map((t) => TagEntry(
                    id: t['id'] as String,
                    memeId: t['memeId'] as String,
                    source: t['source'] as String,
                    content: t['content'] as String,
                    confidence: (t['confidence'] as num).toDouble(),
                  ))
              .toList() ??
          [],
      colors: (json['colors'] as List?)
              ?.map((c) => ColorEntry(
                    id: c['id'] as String,
                    memeId: c['memeId'] as String,
                    hexColor: c['hexColor'] as String,
                    labL: (c['labL'] as num).toDouble(),
                    labA: (c['labA'] as num).toDouble(),
                    labB: (c['labB'] as num).toDouble(),
                    ratio: (c['ratio'] as num).toDouble(),
                  ))
              .toList() ??
          [],
      albumIds: (json['albumIds'] as List?)?.cast<String>() ?? const [],
    );
  }
}
