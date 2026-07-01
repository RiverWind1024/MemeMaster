import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('OCR 识别测试图片中的文字', () async {
    // 图片通过 adb push 传入设备:
    // adb push test/img/微信图片_20260630204014_145_84.jpg /sdcard/Download/ocr_test.jpg
    final imagePath = '/sdcard/Download/ocr_test.jpg';
    final file = File(imagePath);
    expect(file.existsSync(), true,
        reason: '请先执行: adb push test/img/微信图片_20260630204014_145_84.jpg /sdcard/Download/ocr_test.jpg');

    final inputImage = InputImage.fromFile(file);
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final recognisedText = await recognizer.processImage(inputImage);
      print('===== OCR 测试结果 =====');
      print('识别到文本: "${recognisedText.text}"');
      print('文本块数量: ${recognisedText.blocks.length}');
      for (final block in recognisedText.blocks) {
        print('  [块] ${block.text}');
      }
      expect(recognisedText.text.isNotEmpty, true,
          reason: '应该能识别出图片中的文字');
    } finally {
      recognizer.close();
    }
  });
}
