import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mememaster/cli/cli_app.dart';
import 'package:mememaster/cli/cli_ocr.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:path/path.dart' as p;

/// 程序化生成一张白底黑字图片，供 tesseract 识别。
Future<String> _writeTextPng(String path) async {
  final image = img.Image(width: 480, height: 120);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  img.drawString(
    image,
    'HELLO WORLD 123',
    font: img.arial48,
    x: 20,
    y: 30,
    color: img.ColorRgb8(0, 0, 0),
  );
  await File(path).writeAsBytes(img.encodePng(image));
  return path;
}

/// 向临时库直插一条 meme，并写入真实纯色 PNG 物理文件。
Future<String> _insertMemeWithImage(
  AppDatabase db,
  String storagePath, {
  required String id,
  required String filename,
  int r = 255,
  int g = 0,
  int b = 0,
}) async {
  final relPath = '2026/08/$filename';
  final image = img.Image(width: 100, height: 100);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  final bytes = img.encodePng(image);

  final file = File(p.join(storagePath, relPath));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);

  await db.into(db.memesTable).insert(
        MemesTableCompanion.insert(
          id: id,
          filename: filename,
          filePath: relPath,
          fileSize: bytes.length,
          mimeType: 'image/png',
          width: 100,
          height: 100,
          fileHash: 'hash-$id',
          createdAt: 1000,
          updatedAt: 1000,
          importedAt: 1000,
        ),
      );
  return file.path;
}

/// 检测本机 Ollama 服务是否可达，用于决定 --ai 优雅报错测试是否执行。
Future<bool> _ollamaReachable() async {
  try {
    final socket = await Socket.connect('localhost', 11434,
        timeout: const Duration(seconds: 1));
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> _tesseractInstalled() async {
  final ocr = CliOcr();
  return ocr.isInstalled();
}

void main() {
  group('CliOcr', () {
    late CliOcr ocr;
    setUp(() => ocr = CliOcr());

    test('识别含文字的 PNG 返回非空文本', () async {
      final installed = await _tesseractInstalled();
      if (!installed) {
        markTestSkipped('系统未安装 tesseract，跳过识别测试');
        return;
      }
      final tempDir = await Directory.systemTemp.createTemp('cli_ocr_');
      addTearDown(() => tempDir.delete(recursive: true));
      final path = await _writeTextPng(p.join(tempDir.path, 'text.png'));

      final text = await ocr.recognize(path);
      expect(text.trim(), isNotEmpty);
    });

    test('语言包缺失时降级 eng 仍能识别', () async {
      final installed = await _tesseractInstalled();
      if (!installed) {
        markTestSkipped('系统未安装 tesseract，跳过识别测试');
        return;
      }
      final tempDir = await Directory.systemTemp.createTemp('cli_ocr_');
      addTearDown(() => tempDir.delete(recursive: true));
      final path = await _writeTextPng(p.join(tempDir.path, 'text.png'));

      // 用不存在的语言包触发降级，最终应回退 eng 识别到英文
      final text = await CliOcr(language: 'no_such_lang').recognize(path);
      expect(text.trim(), isNotEmpty);
    });
  });

  group('analyze --color', () {
    late Directory tempDir;
    late String dbPath;
    late String storagePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_analyze_');
      dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
      storagePath = p.join(tempDir.path, 'memes');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('提取主色并写入 colors 表，更新颜色状态', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMemeWithImage(db, storagePath,
          id: 'color-0000000001', filename: 'red.png');
      await db.close();

      final exitCode = await CliApp().run([
        'analyze', 'color-0000000001', '--color',
        '--db', dbPath, '--storage', storagePath,
      ]);
      expect(exitCode, 0);

      final verify = AppDatabase.open(dbPath);
      final meme = await verify.memeDao.getById('color-0000000001');
      expect(meme?.colorAnalysisStatus, 'done');
      final colors = await verify.colorDao.getByMemeId('color-0000000001');
      expect(colors, isNotEmpty);
      await verify.close();
    });

    test('未指定维度时默认三纬度都做（颜色维度至少完成）', () async {
      final db = AppDatabase.open(dbPath);
      await _insertMemeWithImage(db, storagePath,
          id: 'color-0000000002', filename: 'green.png', r: 0, g: 255, b: 0);
      await db.close();

      // 不给 --color/--ocr/--ai，默认三个都做。
      // 颜色摄取离线可执行；OCR 若系统无 tesseract 会失败但不应影响颜色。
      final exitCode = await CliApp().run([
        'analyze', 'color-0000000002',
        '--db', dbPath, '--storage', storagePath,
      ]);
      // 结果取决于本机 OCR/AI 服务，这里只断言颜色被成功提取
      final verify = AppDatabase.open(dbPath);
      final colors = await verify.colorDao.getByMemeId('color-0000000002');
      expect(colors, isNotEmpty, reason: '未指定维度时应默认执行颜色分析');
      expect(exitCode, isNotNull);
      await verify.close();
    });
  });

  group('analyze --ocr', () {
    late Directory tempDir;
    late String dbPath;
    late String storagePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_ocr_cmd_');
      dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
      storagePath = p.join(tempDir.path, 'memes');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('OCR 识别写入 source=ocr 标签', () async {
      if (!await _tesseractInstalled()) {
        markTestSkipped('系统未安装 tesseract，跳过 OCR 命令测试');
        return;
      }
      final db = AppDatabase.open(dbPath);
      // 直接写一张含文字的物理文件，再通过 meme 关联
      const relPath = '2026/08/text.png';
      final file = File(p.join(storagePath, relPath));
      await file.parent.create(recursive: true);
      await _writeTextPng(file.path);
      await db.into(db.memesTable).insert(
            MemesTableCompanion.insert(
              id: 'ocr-0000000001',
              filename: 'text.png',
              filePath: relPath,
              fileSize: 100,
              mimeType: 'image/png',
              width: 480,
              height: 120,
              fileHash: 'hash-ocr',
              createdAt: 1000,
              updatedAt: 1000,
              importedAt: 1000,
            ),
          );
      await db.close();

      final exitCode = await CliApp().run([
        'analyze', 'ocr-0000000001', '--ocr',
        '--db', dbPath, '--storage', storagePath,
      ]);
      expect(exitCode, 0);

      final verify = AppDatabase.open(dbPath);
      final meme = await verify.memeDao.getById('ocr-0000000001');
      expect(meme?.ocrAnalysisStatus, 'done');
      final tags = await verify.tagDao.getByMemeId('ocr-0000000001');
      expect(tags.where((t) => t.source == 'ocr'), isNotEmpty);
      await verify.close();
    });
  });

  group('analyze --ai', () {
    late Directory tempDir;
    late String dbPath;
    late String storagePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_ai_');
      dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
      storagePath = p.join(tempDir.path, 'memes');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('无 Ollama/OpenAI 服务时优雅报错，标记 AI 状态失败', () async {
      if (await _ollamaReachable()) {
        markTestSkipped('本机 Ollama 服务可用，跳过无服务优雅报错测试');
        return;
      }
      final db = AppDatabase.open(dbPath);
      await _insertMemeWithImage(db, storagePath,
          id: 'ai-0000000001', filename: 'ai.png');
      await db.close();

      var exitCode = -1;
      exitCode = await CliApp().run([
        'analyze', 'ai-0000000001', '--ai',
        '--db', dbPath, '--storage', storagePath,
      ]);
      expect(exitCode, isNot(0));

      final verify = AppDatabase.open(dbPath);
      final meme = await verify.memeDao.getById('ai-0000000001');
      expect(meme?.aiAnalysisStatus, 'failed');
      await verify.close();
    });
  });

  group('analyze 参数校验', () {
    late Directory tempDir;
    late String dbPath;
    late String storagePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_analyze_arg_');
      dbPath = p.join(tempDir.path, 'data', 'meme_helper.db');
      storagePath = p.join(tempDir.path, 'memes');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('未指定 id 且未给 --all 返回非 0', () async {
      final exitCode = await CliApp().run([
        'analyze', '--color', '--db', dbPath, '--storage', storagePath,
      ]);
      expect(exitCode, isNot(0));
    });

    test('不存在的 meme id 返回非 0', () async {
      final exitCode = await CliApp().run([
        'analyze', 'no-such-id', '--color',
        '--db', dbPath, '--storage', storagePath,
      ]);
      expect(exitCode, isNot(0));
    });
  });
}