import 'dart:async';
import 'dart:io';

import '../../services/log_service.dart';
import 'linux_distro_detector.dart';

/// 安装状态
enum InstallStatus {
  idle,       // 空闲，未开始
  detecting,  // 检测发行版中
  installing,  // 安装中
  verifying,   // 验证中
  success,    // 安装成功
  failed,     // 安装失败
  cancelled,  // 用户取消
}

/// 安装结果
class InstallResult {
  final InstallStatus status;
  final String? errorMessage;
  final String outputLog;
  final LinuxDistro? distro;

  const InstallResult({
    required this.status,
    this.errorMessage,
    this.outputLog = '',
    this.distro,
  });

  bool get isSuccess => status == InstallStatus.success;
  bool get isFailed => status == InstallStatus.failed;
  bool get isCancelled => status == InstallStatus.cancelled;
}

/// 安装进度事件
class InstallProgressEvent {
  final InstallStatus status;
  final String? line;
  final String? error;
  final String outputLog;
  final LinuxDistro? distro;
  final String? errorMessage;

  const InstallProgressEvent({
    required this.status,
    this.line,
    this.error,
    this.outputLog = '',
    this.distro,
    this.errorMessage,
  });

  factory InstallProgressEvent.output(String line, String currentLog) {
    return InstallProgressEvent(
      status: InstallStatus.installing,
      line: line,
      outputLog: currentLog,
    );
  }

  factory InstallProgressEvent.error(String error, String currentLog) {
    return InstallProgressEvent(
      status: InstallStatus.installing,
      error: error,
      outputLog: currentLog,
    );
  }

  factory InstallProgressEvent.status(InstallStatus status, {String? message, LinuxDistro? distro, String? outputLog}) {
    return InstallProgressEvent(
      status: status,
      errorMessage: message,
      distro: distro,
      outputLog: outputLog ?? '',
    );
  }
}

/// Linux OCR 后台安装服务
///
/// 使用 Process.start 实现非阻塞安装，输出通过 Stream 实时推送
class LinuxOcrInstaller {
  static final _log = LogService.instance;

  Process? _process;
  final _progressController = StreamController<InstallProgressEvent>.broadcast();
  bool _cancelled = false;
  String _outputLog = '';

  /// 进度流（外部监听此 Stream 获取安装进度）
  Stream<InstallProgressEvent> get progressStream => _progressController.stream;

  /// 检测发行版并安装
  ///
  /// 返回安装结果（也通过 progressStream 实时推送进度）
  Future<InstallResult> install() async {
    _cancelled = false;
    _outputLog = '';

    // 1. 检测发行版
    _progressController.add(InstallProgressEvent.status(
      InstallStatus.detecting,
      outputLog: '检测 Linux 发行版...\n',
    ));
    _log.info('OCR', '[Install] 开始检测 Linux 发行版...');

    final distro = await LinuxDistroDetector.detect();
    final config = LinuxDistroDetector.getInstallConfig(distro);
    final distroName = config.displayName;

    _log.info('OCR', '[Install] 检测到发行版: $distroName');
    _updateLog('检测到发行版: $distroName\n');
    _progressController.add(InstallProgressEvent.status(
      InstallStatus.installing,
      distro: distro,
      outputLog: _outputLog,
    ));

    if (distro == LinuxDistro.unknown) {
      _log.warning('OCR', '[Install] 无法识别 Linux 发行版，尝试使用默认命令');
      _updateLog('无法识别发行版，尝试使用 dnf 安装...\n');
    }

    // 2. 执行安装
    final cmdStr = config.installCommand.join(' ');
    _log.info('OCR', '[Install] 执行安装命令: $cmdStr');
    _updateLog('\n开始安装...\n');
    _updateLog('执行: $cmdStr\n');
    _updateLog('（可能需要输入密码）\n\n');

    final installResult = await _runInstall(config.installCommand);

    if (_cancelled) {
      _log.info('OCR', '[Install] 用户取消安装');
      _progressController.add(InstallProgressEvent.status(
        InstallStatus.cancelled,
        outputLog: _outputLog,
      ));
      return InstallResult(
        status: InstallStatus.cancelled,
        outputLog: _outputLog,
        distro: distro,
      );
    }

    if (!installResult) {
      _log.error('OCR', '[Install] 安装命令执行失败');
      _progressController.add(InstallProgressEvent.status(
        InstallStatus.failed,
        message: '安装失败，请查看下方日志',
        distro: distro,
        outputLog: _outputLog,
      ));
      return InstallResult(
        status: InstallStatus.failed,
        outputLog: _outputLog,
        distro: distro,
        errorMessage: '安装命令执行失败',
      );
    }

    // 3. 验证安装
    _log.info('OCR', '[Install] 验证安装结果...');
    _updateLog('\n\n验证安装...\n');
    _progressController.add(InstallProgressEvent.status(
      InstallStatus.verifying,
      distro: distro,
      outputLog: _outputLog,
    ));

    final verified = await _verifyInstallation();
    if (verified) {
      _log.info('OCR', '[Install] ✓ Tesseract 安装成功！');
      _updateLog('\n✓ Tesseract 安装成功！\n');
      _progressController.add(InstallProgressEvent.status(
        InstallStatus.success,
        distro: distro,
        outputLog: _outputLog,
      ));
      return InstallResult(
        status: InstallStatus.success,
        outputLog: _outputLog,
        distro: distro,
      );
    } else {
      _log.error('OCR', '[Install] ✗ Tesseract 验证失败');
      _updateLog('\n✗ Tesseract 验证失败\n');
      _progressController.add(InstallProgressEvent.status(
        InstallStatus.failed,
        message: '安装后验证失败',
        distro: distro,
        outputLog: _outputLog,
      ));
      return InstallResult(
        status: InstallStatus.failed,
        outputLog: _outputLog,
        distro: distro,
        errorMessage: '安装后验证失败',
      );
    }
  }

  /// 取消安装
  void cancel() {
    _cancelled = true;
    if (_process != null && !_process!.kill(ProcessSignal.sigterm)) {
      _process!.kill(ProcessSignal.sigkill);
    }
    _log.info('OCR', '用户取消 Tesseract 安装');
  }

  /// 释放资源
  void dispose() {
    _process?.kill();
    _progressController.close();
  }

  Future<bool> _runInstall(List<String> command) async {
    try {
      _process = await Process.start(
        command.first,
        command.sublist(1),
        mode: ProcessStartMode.normal,
      );

      // 实时捕获 stdout
      _process!.stdout.listen(
        (data) {
          final line = String.fromCharCodes(data);
          _updateLog(line);
          _progressController.add(InstallProgressEvent.output(
            line,
            _outputLog,
          ));
        },
        onError: (e) {
          _log.error('OCR', '安装进程 stdout 错误: $e');
        },
      );

      // 实时捕获 stderr
      _process!.stderr.listen(
        (data) {
          final line = String.fromCharCodes(data);
          _updateLog('[stderr] $line');
          _progressController.add(InstallProgressEvent.error(
            line,
            _outputLog,
          ));
        },
        onError: (e) {
          _log.error('OCR', '安装进程 stderr 错误: $e');
        },
      );

      final exitCode = await _process!.exitCode;
      _process = null;
      return exitCode == 0;
    } catch (e, st) {
      _log.error('OCR', '启动安装进程失败: $e\n$st');
      _updateLog('\n✗ 启动安装进程失败: $e\n');
      _process = null;
      return false;
    }
  }

  Future<bool> _verifyInstallation() async {
    try {
      final result = await Process.run('tesseract', ['--version']);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().split('\n').first;
        _updateLog('版本: $version\n');
        return true;
      }
      return false;
    } catch (e) {
      _updateLog('验证失败: $e\n');
      return false;
    }
  }

  void _updateLog(String line) {
    _outputLog += line;
    // 限制日志长度，避免内存问题
    if (_outputLog.length > 50000) {
      _outputLog = _outputLog.substring(_outputLog.length - 40000);
    }
  }
}
