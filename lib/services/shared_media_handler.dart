import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedMediaHandler {
  static const _channel = MethodChannel('com.memehelper.app/share');

  static final SharedMediaHandler _instance = SharedMediaHandler._();
  factory SharedMediaHandler() => _instance;
  SharedMediaHandler._();

  /// 检查是否有其他应用分享过来的待处理文件。
  /// 调用后内部缓存会被清空（避免重复处理）。
  Future<List<String>> getPendingFiles() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSharedMedia');
      if (result == null) return [];
      return result.cast<String>();
    } catch (e) {
      debugPrint('SharedMediaHandler.getPendingFiles failed: $e');
      return [];
    }
  }

  /// 检查 Android 剪贴板是否包含图片，有则复制到缓存并返回路径。
  Future<String?> getClipboardImage() async {
    try {
      return await _channel.invokeMethod<String>('getClipboardImage');
    } catch (e) {
      return null;
    }
  }

  /// 将 content:// URI 复制到本地缓存目录，返回真实路径。
  Future<String?> copyContentUri(String uri) async {
    try {
      final result = await _channel.invokeMethod<String>('copyContentUri', {
        'uri': uri,
      });
      return result;
    } catch (e) {
      debugPrint('SharedMediaHandler.copyContentUri failed: $e');
      return null;
    }
  }
}
