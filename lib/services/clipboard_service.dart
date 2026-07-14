import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
// Conditional import: 桌面平台用真正的 super_clipboard，移动平台用 stub
// 避免 Android 上因为删 super_clipboard 而编译失败
import 'clipboard_stub.dart'
    if (dart.library.io && (Platform.isLinux || Platform.isMacOS || Platform.isWindows))
    'package:super_clipboard/super_clipboard.dart';

class ClipboardService {
  static const _channel = MethodChannel('com.mememaster.app/clipboard');

  static Future<String?> readText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> copyImageToClipboard(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('ClipboardService: 文件不存在 $filePath');
        return false;
      }

      final bytes = await file.readAsBytes();

      // Android 使用 MethodChannel
      if (Platform.isAndroid || Platform.isIOS) {
        final mimeType = _mimeFromExtension(filePath);
        await _channel.invokeMethod('copyImageToClipboard', {
          'bytes': bytes,
          'mimeType': mimeType,
        });
        return true;
      }

      // Linux/macOS/Windows 使用 super_clipboard
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        return await _copyImageWithSuperClipboard(bytes, filePath);
      }

      return false;
    } catch (e) {
      print('复制到剪贴板失败: $e');
      return false;
    }
  }

  /// 使用 super_clipboard 复制图片到剪贴板
  static Future<bool> _copyImageWithSuperClipboard(
    Uint8List bytes,
    String filePath,
  ) async {
    try {
      final item = DataWriterItem();
      final ext = filePath.split('.').last.toLowerCase();

      if (ext == 'png') {
        item.add(Formats.png(bytes));
      } else if (ext == 'gif') {
        item.add(Formats.gif(bytes));
      } else if (ext == 'webp') {
        item.add(Formats.webp(bytes));
      } else if (ext == 'bmp') {
        item.add(Formats.bmp(bytes));
      } else {
        item.add(Formats.jpeg(bytes));
      }

      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        print('ClipboardService: 系统剪贴板不可用');
        return false;
      }

      await clipboard.write([item]);
      return true;
    } catch (e) {
      print('super_clipboard 复制失败: $e');
      return false;
    }
  }

  static Future<void> shareImage(String filePath) async {
    final file = XFile(filePath);
    await Share.shareXFiles([file], text: '分享表情包');
  }

  static Future<void> shareMultipleImages(List<String> filePaths) async {
    final files = filePaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(files, text: '分享表情包');
  }

  static String _mimeFromExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }
}
