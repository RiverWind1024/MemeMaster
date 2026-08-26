import 'dart:io';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// render 命令：在终端中渲染图片（使用 Sixel 协议）。
///
/// 用法:
///   `mememaster render <memeId|短码> [--width <列数>]`
///   `mememaster render --file <图片路径> [--width <列数>]`
///
/// 依赖外部工具 `img2sixel`（来自 `libsixel-bin`）。
class RenderCommand extends CliCommand {
  RenderCommand()
      : super(name: 'render', description: '在终端中渲染图片（Sixel 协议）');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final width = args['width'] as String?;
    final filePath = args['file'] as String?;

    // 检查参数
    if (filePath == null && args.rest.isEmpty) {
      stderr.writeln('用法: mememaster render <memeId|短码> [--width <列数>]');
      stderr.writeln('      mememaster render --file <图片路径> [--width <列数>]');
      return 1;
    }
    if (filePath != null && args.rest.isNotEmpty) {
      stderr.writeln('不能同时指定 memeId 和 --file');
      return 1;
    }

    // 检查 img2sixel 是否安装
    if (!await _isImg2SixelInstalled()) {
      stderr.writeln('错误: 未找到 img2sixel 工具');
      stderr.writeln('');
      stderr.writeln('请先安装 libsixel-tools:');
      stderr.writeln('  Linux (Fedora): sudo dnf install libsixel-tools');
      stderr.writeln('  Linux (Ubuntu): sudo apt install libsixel-bin');
      stderr.writeln('  macOS:          brew install libsixel');
      stderr.writeln('');
      stderr.writeln('安装后重试。');
      return 1;
    }

    // 获取图片路径
    String imagePath;
    if (filePath != null) {
      // 直接使用文件路径
      final file = File(filePath);
      if (!await file.exists()) {
        stderr.writeln('文件不存在: $filePath');
        return 1;
      }
      imagePath = file.absolute.path;
    } else {
      // 从数据库查询 meme
      final input = args.rest.first;
      final meme = await context.findMeme(input);
      if (meme == null) {
        stderr.writeln('未找到 meme: $input');
        return 1;
      }
      final imageFile = await context.storage.getImage(meme.filePath);
      if (!await imageFile.exists()) {
        stderr.writeln('图片文件不存在: ${imageFile.path}');
        return 1;
      }
      imagePath = imageFile.absolute.path;
    }

    // 构建 img2sixel 命令
    final cmdArgs = <String>[];
    if (width != null) {
      final widthInt = int.tryParse(width);
      if (widthInt == null || widthInt <= 0) {
        stderr.writeln('--width 必须是正整数: $width');
        return 1;
      }
      cmdArgs.addAll(['--width', width]);
    }
    cmdArgs.add(imagePath);

    // 执行 img2sixel
    final result = await Process.run('img2sixel', cmdArgs);
    if (result.exitCode != 0) {
      stderr.writeln('img2sixel 执行失败:');
      stderr.writeln(result.stderr.toString().trim());
      return 1;
    }

    stdout.write(result.stdout);
    return 0;
  }

  /// 检查 img2sixel 是否已安装。
  Future<bool> _isImg2SixelInstalled() async {
    try {
      final result = await Process.run('img2sixel', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
