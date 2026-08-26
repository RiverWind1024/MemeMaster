import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// 图片协议类型
enum ImageProtocol {
  /// iTerm2 Image Protocol（macOS Terminal.app、iTerm2、Warp 等支持）
  iterm2,

  /// Sixel Graphics Protocol（mlterm、WezTerm、xterm 等支持）
  sixel,

  /// Kitty Graphics Protocol（Kitty 终端支持）
  kitty,

  /// ASCII 艺术降级显示
  ascii,
}

/// render 命令：在终端中渲染图片。
///
/// 支持多种图片协议，自动检测终端能力：
/// - iTerm2 Image Protocol（macOS 默认终端、iTerm2、Warp）
/// - Sixel Graphics Protocol（mlterm、WezTerm）
/// - Kitty Graphics Protocol（Kitty 终端）
/// - ASCII 艺术降级显示
///
/// 用法:
///   `mememaster render <memeId|短码> [--protocol <iterm2|sixel|kitty|ascii>]`
///   `mememaster render --file <图片路径> [--protocol <iterm2|sixel|kitty|ascii>]`
class RenderCommand extends CliCommand {
  RenderCommand()
      : super(name: 'render', description: '在终端中渲染图片');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    final protocolArg = args['protocol'] as String?;
    final filePath = args['file'] as String?;
    final width = args['width'] as String?;

    // 检查参数
    if (filePath == null && args.rest.isEmpty) {
      stderr.writeln('用法: mememaster render <memeId|短码> [--protocol <协议>] [--width <列数>]');
      stderr.writeln('      mememaster render --file <图片路径> [--protocol <协议>] [--width <列数>]');
      stderr.writeln('');
      stderr.writeln('支持的协议:');
      stderr.writeln('  iterm2  - iTerm2 Image Protocol（macOS Terminal.app、iTerm2、Warp）');
      stderr.writeln('  sixel   - Sixel Graphics Protocol（mlterm、WezTerm）');
      stderr.writeln('  kitty   - Kitty Graphics Protocol（Kitty 终端）');
      stderr.writeln('  ascii   - ASCII 艺术降级显示');
      stderr.writeln('');
      stderr.writeln('默认自动检测终端能力选择最佳协议。');
      return 1;
    }
    if (filePath != null && args.rest.isNotEmpty) {
      stderr.writeln('不能同时指定 memeId 和 --file');
      return 1;
    }

    // 获取图片路径
    String imagePath;
    if (filePath != null) {
      final file = File(filePath);
      if (!await file.exists()) {
        stderr.writeln('文件不存在: $filePath');
        return 1;
      }
      imagePath = file.absolute.path;
    } else {
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

    // 选择协议
    final protocol = protocolArg != null
        ? _parseProtocol(protocolArg)
        : await _detectProtocol();

    // 读取图片
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Data = base64Encode(imageBytes);

    // 根据协议渲染
    switch (protocol!) {
      case ImageProtocol.iterm2:
        return _renderIterm2(base64Data, width);
      case ImageProtocol.sixel:
        return _renderSixel(imagePath, width);
      case ImageProtocol.kitty:
        return _renderKitty(base64Data, width);
      case ImageProtocol.ascii:
        return _renderAscii(imagePath);
    }
  }

  /// 解析协议参数
  ImageProtocol? _parseProtocol(String name) {
    switch (name.toLowerCase()) {
      case 'iterm2':
        return ImageProtocol.iterm2;
      case 'sixel':
        return ImageProtocol.sixel;
      case 'kitty':
        return ImageProtocol.kitty;
      case 'ascii':
        return ImageProtocol.ascii;
      default:
        stderr.writeln('未知协议: $name');
        stderr.writeln('支持的协议: iterm2, sixel, kitty, ascii');
        return null;
    }
  }

  /// 自动检测终端能力，选择最佳协议
  Future<ImageProtocol> _detectProtocol() async {
    final term = Platform.environment['TERM'] ?? '';
    final termProgram = Platform.environment['TERM_PROGRAM'] ?? '';

    // Kitty 终端（通过 TERM=xterm-kitty 检测）
    if (term.toLowerCase().contains('kitty') ||
        termProgram.toLowerCase().contains('kitty')) {
      print('检测到 Kitty 终端，使用 Kitty 协议');
      return ImageProtocol.kitty;
    }

    // Warp 终端（支持 iTerm2 协议）
    if (termProgram.toLowerCase().contains('warp') || termProgram == 'Warp') {
      print('检测到 Warp 终端，使用 iTerm2 协议');
      return ImageProtocol.iterm2;
    }

    // iTerm2
    if (termProgram.toLowerCase().contains('iterm')) {
      print('检测到 iTerm2，使用 iTerm2 协议');
      return ImageProtocol.iterm2;
    }

    // mlterm（支持 Sixel）
    if (termProgram.toLowerCase().contains('mlterm')) {
      print('检测到 mlterm，使用 Sixel 协议');
      return ImageProtocol.sixel;
    }

    // WezTerm（支持 Sixel）
    if (termProgram.toLowerCase().contains('wezterm')) {
      print('检测到 WezTerm，使用 Sixel 协议');
      return ImageProtocol.sixel;
    }

    // macOS Terminal.app 或未识别的终端
    // 检查是否支持 Sixel（优先）或降级到 ASCII
    if (await _isSixelSupported()) {
      print('检测到 Sixel 支持，使用 Sixel 协议');
      return ImageProtocol.sixel;
    }

    // 降级到 ASCII
    print('未检测到图片协议支持，使用 ASCII 降级显示');
    return ImageProtocol.ascii;
  }

  /// 检测终端是否支持 Sixel
  Future<bool> _isSixelSupported() async {
    // 检查 img2sixel 是否可用
    try {
      final result = await Process.run('img2sixel', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// iTerm2 Image Protocol
  /// 格式: `\033]1337;File=inline=1:<base64数据>\a`
  int _renderIterm2(String base64Data, String? width) {
    // iTerm2 协议不直接支持宽度，需要先调整图片大小
    // 这里直接输出原始图片
    stdout.write('\x1b]1337;File=inline=1:$base64Data\x07');
    return 0;
  }

  /// Sixel Graphics Protocol
  /// 使用 img2sixel 工具
  Future<int> _renderSixel(String imagePath, String? width) async {
    // 检查 img2sixel 是否安装
    try {
      await Process.run('img2sixel', ['--version']);
    } catch (_) {
      stderr.writeln('错误: 未找到 img2sixel 工具');
      stderr.writeln('');
      stderr.writeln('请先安装:');
      stderr.writeln('  macOS:          brew install libsixel');
      stderr.writeln('  Linux (Fedora): sudo dnf install libsixel-utils');
      stderr.writeln('  Linux (Ubuntu): sudo apt install libsixel-bin');
      return 1;
    }

    final cmdArgs = <String>[];
    if (width != null) {
      cmdArgs.addAll(['--width', width]);
    }
    cmdArgs.add(imagePath);

    final result = await Process.run('img2sixel', cmdArgs);
    if (result.exitCode != 0) {
      stderr.writeln('img2sixel 执行失败:');
      stderr.writeln(result.stderr.toString().trim());
      return 1;
    }

    stdout.write(result.stdout);
    return 0;
  }

  /// Kitty Graphics Protocol
  /// 格式: `\033_Gf=100,t=d;<base64数据>\033\\`
  int _renderKitty(String base64Data, String? width) {
    // Kitty 协议：直接传输 base64 数据
    stdout.write('\x1b_Gf=100,t=d;$base64Data\x1b\\');
    return 0;
  }

  /// ASCII 艺术降级显示
  /// 使用 chafa 或 python PIL 生成 ASCII 艺术
  Future<int> _renderAscii(String imagePath) async {
    // 尝试使用 chafa
    try {
      final result = await Process.run('chafa', [
        '--size=40x20',
        '--format=symbols',
        imagePath,
      ]);
      if (result.exitCode == 0) {
        stdout.write(result.stdout);
        return 0;
      }
    } catch (_) {}

    // 降级：输出图片信息
    final file = File(imagePath);
    final size = await file.length();
    final bytes = await file.readAsBytes();

    print('┌────────────────────────────────────────┐');
    print('│         ASCII 降级显示（不可用）         │');
    print('├────────────────────────────────────────┤');
    print('│ 文件: ${imagePath.split('/').last}');
    print('│ 大小: $size 字节');
    print('│ 格式: ${_detectFormat(bytes)}');
    print('└────────────────────────────────────────┘');
    print('');
    print('提示: 安装 chafa 可显示 ASCII 艺术图片');
    print('      brew install chafa');

    return 0;
  }

  /// 检测图片格式
  String _detectFormat(List<int> bytes) {
    if (bytes.length < 4) return '未知';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'JPEG';
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'PNG';
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'GIF';
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return 'WEBP';
    return '未知';
  }
}
