import 'dart:io';

import 'package:args/args.dart';

import '../core/database/database.dart';

/// 将 [dt] 格式化为本地时区字符串 `yyyy-MM-dd HH:mm:ss`。
String formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// 解析并校验 `--limit`：返回正整数；未传返回 null。
///
/// 非法时通过 [onError] 输出错误（默认写到 stderr）并返回 null，
/// 调用方应据此返回退出码 1。
int? parsePositiveLimit(
  ArgResults args, {
  void Function(String message)? onError,
}) {
  final limitArg = args['limit'] as String?;
  if (limitArg == null) return null;
  final limit = int.tryParse(limitArg);
  if (limit == null || limit <= 0) {
    (onError ?? stderr.writeln)('--limit 必须是正整数: $limitArg');
    return null;
  }
  return limit;
}

/// 文本行：短ID + 文件名 + 尺寸 + 导入时间 + 分析状态。
String formatMemeRow(Meme meme) {
  return '${meme.id.substring(0, 8)}  ${meme.filename}  '
      '${meme.width}x${meme.height}  '
      '${formatDateTime(DateTime.fromMillisecondsSinceEpoch(meme.importedAt))}  '
      '${meme.analysisStatus}';
}

/// JSON 字段映射：id / shortId / filename / width / height / importedAt / analysisStatus。
Map<String, Object?> memeToJson(Meme meme) => {
      'id': meme.id,
      'shortId': meme.id.substring(0, 8),
      'filename': meme.filename,
      'width': meme.width,
      'height': meme.height,
      'importedAt': meme.importedAt,
      'analysisStatus': meme.analysisStatus,
    };
