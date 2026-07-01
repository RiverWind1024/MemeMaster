import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OCR 识别测试图片中的文字', () async {
    final imagePath = 'test/img/微信图片_20260630204014_145_84.jpg';
    final file = File(imagePath);
    expect(file.existsSync(), true, reason: '测试图片应该存在');

    final inputImage = InputImage.fromFile(file);
    // 中文简体识别
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final recognisedText = await recognizer.processImage(inputImage);
      print('===== OCR 测试结果 =====');
      print('识别到文本: "${recognisedText.text}"');
      print('文本长度: ${recognisedText.text.length}');
      print('文本块数量: ${recognisedText.blocks.length}');
      for (final block in recognisedText.blocks) {
        print('  [块] ${block.text}');
      }
      expect(
        recognisedText.text.isNotEmpty,
        true,
        reason: '应该能识别出图片中的文字',
      );
    } finally {
      recognizer.close();
    }
  });
}
