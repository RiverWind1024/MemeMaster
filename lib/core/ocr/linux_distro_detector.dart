import 'dart:async';
import 'dart:io';

/// Linux 发行版检测结果
enum LinuxDistro {
  fedora,    // Fedora, RHEL, CentOS, AlmaLinux, RockyLinux
  debian,    // Debian, Ubuntu, Linux Mint, Pop!_OS
  arch,      // Arch Linux, Manjaro, EndeavourOS
  opensuse,  // openSUSE, SUSE Linux Enterprise
  unknown,   // 未能检测到
}

/// 安装命令配置
class DistroInstallConfig {
  final LinuxDistro distro;
  final String displayName;
  final List<String> installCommand; // pkexec + 包管理器 + 参数

  const DistroInstallConfig({
    required this.distro,
    required this.displayName,
    required this.installCommand,
  });
}

/// Linux 发行版检测器
///
/// 通过检测系统中的包管理器来判断发行版类型
class LinuxDistroDetector {
  static LinuxDistro? _cached;

  /// 同步检测（仅检测包管理器，不执行命令）
  static LinuxDistro detectSync() {
    if (_cached != null) return _cached!;

    if (_commandExistsSync('dnf')) {
      _cached = LinuxDistro.fedora;
    } else if (_commandExistsSync('apt-get')) {
      _cached = LinuxDistro.debian;
    } else if (_commandExistsSync('pacman')) {
      _cached = LinuxDistro.arch;
    } else if (_commandExistsSync('zypper')) {
      _cached = LinuxDistro.opensuse;
    } else {
      _cached = LinuxDistro.unknown;
    }

    return _cached!;
  }

  /// 异步检测（通过 which 命令）
  static Future<LinuxDistro> detect() async {
    if (_cached != null) return _cached!;

    if (await _commandExists('dnf')) {
      _cached = LinuxDistro.fedora;
    } else if (await _commandExists('apt-get')) {
      _cached = LinuxDistro.debian;
    } else if (await _commandExists('pacman')) {
      _cached = LinuxDistro.arch;
    } else if (await _commandExists('zypper')) {
      _cached = LinuxDistro.opensuse;
    } else {
      _cached = LinuxDistro.unknown;
    }

    return _cached!;
  }

  /// 获取安装配置
  static DistroInstallConfig getInstallConfig(LinuxDistro distro) {
    switch (distro) {
      case LinuxDistro.fedora:
        return const DistroInstallConfig(
          distro: LinuxDistro.fedora,
          displayName: 'Fedora / RHEL',
          installCommand: ['pkexec', 'dnf', 'install', '-y', 'tesseract', 'tesseract-langpack-chi_sim', 'tesseract-langpack-eng', 'leptonica'],
        );
      case LinuxDistro.debian:
        return const DistroInstallConfig(
          distro: LinuxDistro.debian,
          displayName: 'Debian / Ubuntu',
          installCommand: ['pkexec', 'apt-get', 'install', '-y', 'tesseract-ocr', 'tesseract-ocr-chi-sim', 'tesseract-ocr-eng'],
        );
      case LinuxDistro.arch:
        return const DistroInstallConfig(
          distro: LinuxDistro.arch,
          displayName: 'Arch Linux',
          installCommand: ['pkexec', 'pacman', '-S', '--noconfirm', 'tesseract', 'tesseract-data-chi-sim'],
        );
      case LinuxDistro.opensuse:
        return const DistroInstallConfig(
          distro: LinuxDistro.opensuse,
          displayName: 'openSUSE',
          installCommand: ['pkexec', 'zypper', 'install', '-y', 'tesseract', 'tesseract-langpack-chi_sim', 'leptonica'],
        );
      case LinuxDistro.unknown:
        return const DistroInstallConfig(
          distro: LinuxDistro.unknown,
          displayName: '未知发行版',
          installCommand: ['pkexec', 'dnf', 'install', '-y', 'tesseract', 'tesseract-lang', 'leptonica'],
        );
    }
  }

  static bool _commandExistsSync(String command) {
    try {
      final result = Process.runSync('which', [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _commandExists(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// 获取显示名称
  static String getDisplayName(LinuxDistro distro) {
    return getInstallConfig(distro).displayName;
  }
}
