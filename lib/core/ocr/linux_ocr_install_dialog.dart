import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/log_service.dart';
import 'linux_distro_detector.dart';
import 'linux_ocr_installer.dart';

/// 显示 Linux OCR 安装向导对话框
///
/// [context] - BuildContext
/// [onInstalled] - 可选的回调，安装成功后调用
///
/// 返回一个 Future<InstallResult>，但对话框本身不阻塞 App 使用
void showLinuxOcrInstallDialog(BuildContext context, {VoidCallback? onInstalled}) {
  showDialog(
    context: context,
    barrierDismissible: false, // 安装过程中不允许关闭（避免误操作）
    builder: (context) => _LinuxOcrInstallDialog(
      onInstalled: onInstalled,
    ),
  );
}

class _LinuxOcrInstallDialog extends StatefulWidget {
  final VoidCallback? onInstalled;

  const _LinuxOcrInstallDialog({this.onInstalled});

  @override
  State<_LinuxOcrInstallDialog> createState() => _LinuxOcrInstallDialogState();
}

class _LinuxOcrInstallDialogState extends State<_LinuxOcrInstallDialog> {
  static final _log = LogService.instance;

  late LinuxOcrInstaller _installer;
  StreamSubscription<InstallProgressEvent>? _subscription;

  InstallStatus _status = InstallStatus.idle;
  String _outputLog = '';
  LinuxDistro? _distro;
  String? _errorMessage;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _installer = LinuxOcrInstaller();
    // 立即开始检测发行版
    _startInstallation();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _installer.dispose();
    super.dispose();
  }

  void _startInstallation() {
    _log.info('OCR', '[Install] 用户打开 OCR 安装向导');
    setState(() {
      _status = InstallStatus.detecting;
      _installing = true;
    });

    _subscription = _installer.progressStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _status = event.status;
        _outputLog = event.outputLog;
        _distro = event.distro ?? _distro;
        _errorMessage = event.errorMessage;
      });

      // 安装完成
      if (event.status == InstallStatus.success) {
        _log.info('OCR', '安装向导：安装成功');
        widget.onInstalled?.call();
      } else if (event.status == InstallStatus.failed) {
        _log.warning('OCR', '安装向导：安装失败');
      }
    });

    _installer.install().then((result) {
      if (!mounted) return;
      setState(() {
        _status = result.status;
        _outputLog = result.outputLog;
        _distro = result.distro ?? _distro;
        if (result.errorMessage != null) {
          _errorMessage = result.errorMessage;
        }
      });
    });
  }

  void _onCancel() {
    if (_status == InstallStatus.installing || _status == InstallStatus.detecting) {
      // 确认取消
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('取消安装？'),
          content: const Text('安装将在后台继续，但 OCR 功能暂时不可用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('继续安装'),
            ),
            TextButton(
              onPressed: () {
                _installer.cancel();
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // 关闭安装对话框
              },
              child: const Text('取消安装'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onClose() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.text_fields, size: 28),
          const SizedBox(width: 12),
          const Expanded(child: Text('启用 OCR 功能')),
          if (_installing && _status != InstallStatus.success && _status != InstallStatus.failed)
            IconButton(
              icon: const Icon(Icons.minimize),
              onPressed: () {
                // 最小化对话框，安装继续在后台
                Navigator.of(context).pop();
              },
              tooltip: '最小化（安装继续在后台）',
            ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      content: SizedBox(
        width: 500,
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明文字
            if (_status == InstallStatus.idle || _status == InstallStatus.detecting) ...[
              Text(
                'OCR 功能需要 Tesseract OCR 引擎。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '检测到您的系统为 ${_distro != null ? LinuxDistroDetector.getDisplayName(_distro!) : 'Linux'}。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],

            // 进度日志区域
            if (_status != InstallStatus.idle) ...[
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // 日志输出
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _outputLog,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.greenAccent,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    // 状态指示器
                    if (_status == InstallStatus.installing || _status == InstallStatus.detecting)
                      Positioned(
                        top: 8,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '安装中',
                                style: TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // 错误消息
            if (_status == InstallStatus.failed && _errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 成功提示
            if (_status == InstallStatus.success) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tesseract 安装成功！可以开始使用 OCR 功能了。',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 取消/关闭按钮
        TextButton(
          onPressed: _status == InstallStatus.success || _status == InstallStatus.failed || !_installing
              ? _onClose
              : _onCancel,
          child: Text(
            _status == InstallStatus.success || _status == InstallStatus.failed || !_installing
                ? '关闭'
                : '取消',
          ),
        ),

        // 重试按钮（失败时）
        if (_status == InstallStatus.failed) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _installing = false;
                _outputLog = '';
                _errorMessage = null;
              });
              _startInstallation();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    );
  }
}
