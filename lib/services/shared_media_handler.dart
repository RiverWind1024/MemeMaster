import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedMediaHandler {
  static const _channel = MethodChannel('com.memehelper.app/share');

  static final SharedMediaHandler _instance = SharedMediaHandler._();
  factory SharedMediaHandler() => _instance;
  SharedMediaHandler._();

  static const _tag = '[SharedMediaHandler]';

  /// 检查是否有其他应用分享过来的待处理文件。
  /// 调用后内部缓存会被清空（避免重复处理）。
  Future<List<String>> getPendingFiles() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSharedMedia');
      if (result == null) {
        debugPrint('$_tag getPendingFiles: result is null');
        return [];
      }
      final paths = result.cast<String>();
      debugPrint('$_tag getPendingFiles: ${paths.length} paths: $paths');
      return paths;
    } catch (e) {
      debugPrint('$_tag getPendingFiles failed: $e');
      return [];
    }
  }

  /// 检查 Android 剪贴板是否包含图片，有则复制到缓存并返回路径。
  Future<String?> getClipboardImage() async {
    try {
      final result = await _channel.invokeMethod<String>('getClipboardImage');
      final preview = result != null && result.length > 150 ? '${result.substring(0, 150)}...' : result;
      debugPrint('$_tag getClipboardImage: $preview');
      return result;
    } catch (e) {
      debugPrint('$_tag getClipboardImage failed: $e');
      return null;
    }
  }

  /// 将 content:// URI 复制到本地缓存目录，返回真实路径。
  Future<String?> copyContentUri(String uri) async {
    try {
      debugPrint('$_tag copyContentUri: $uri');
      final result = await _channel.invokeMethod<String>('copyContentUri', {
        'uri': uri,
      });
      debugPrint('$_tag copyContentUri result: $result');
      return result;
    } catch (e) {
      debugPrint('$_tag copyContentUri failed: $e');
      return null;
    }
  }
}
