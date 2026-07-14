// Stub implementation for platforms that don't use super_clipboard (e.g. Android/iOS)
//
// Android uses MethodChannel to copy images, so this stub is only used as a
// type placeholder for the conditional import in clipboard_service.dart.

import 'dart:typed_data';

class DataWriterItem {
  void add(Object format) {}
}

class SystemClipboard {
  static SystemClipboard? get instance => null;

  Future<void> write(List<DataWriterItem> items) async {}
}

class Formats {
  static Object png(Uint8List bytes) => bytes;
  static Object gif(Uint8List bytes) => bytes;
  static Object webp(Uint8List bytes) => bytes;
  static Object bmp(Uint8List bytes) => bytes;
  static Object jpeg(Uint8List bytes) => bytes;
}