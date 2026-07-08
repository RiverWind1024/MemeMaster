// GPU 诊断工具（OpenCL + Vulkan）
// 用于检测 Android 设备上的 OpenCL 及 Vulkan 支持情况
// 不依赖 adb 调试，用户安装后可在 App 内查看运行日志
// 注意：OpenCL 诊断功能尚未在真实设备上验证（标记为实验性）

import 'dart:ffi';
import 'dart:io';

import '../core/llm/local_config.dart';
import '../core/llm/local_service.dart';
import 'log_service.dart';

class OpenCLDiagnostic {
  static const _tag = 'OpenCLDiag';

  /// 常见 Vulkan 库路径
  static const List<String> _libVulkanPaths = [
    '/system/lib64/libvulkan.so',
    '/vendor/lib64/libvulkan.so',
    '/system/lib/libvulkan.so',
    '/vendor/lib/libvulkan.so',
  ];

  /// 常见 Vulkan ICD JSON 配置目录
  static const List<String> _vulkanIcdDirs = [
    '/vendor/etc/vulkan/icd.d',
    '/system/vendor/etc/vulkan/icd.d',
    '/data/vulkan/icd.d',
  ];

  /// 常见 Vulkan HW 驱动实现库（由 ICD JSON 指向的实际驱动）
  static const List<String> _vulkanHwDrivers = [
    'vulkan.qcom.so',     // Qualcomm Adreno
    'vulkan.mtk.so',      // MediaTek
    'vulkan.exynos.so',   // Samsung Exynos
    'vulkan.mali.so',     // ARM Mali
    'vulkan.pvr.so',      // PowerVR
    'vulkan.intel.so',    // Intel
    'vulkan.nvidia.so',   // NVIDIA
  ];

  /// 常见 OpenCL ICD 库路径
  static const List<String> _libOpenCLPaths = [
    '/system/vendor/lib64/libOpenCL.so',
    '/vendor/lib64/libOpenCL.so',
    '/system/lib64/libOpenCL.so',
    '/system/lib/libOpenCL.so',
    '/vendor/lib/libOpenCL.so',
    '/system/libegl/libOpenCL.so',
  ];

  /// 常见 ICD 配置文件目录
  static const List<String> _icdConfigDirs = [
    '/system/vendor/etc/OpenCL/vendors',
    '/vendor/etc/OpenCL/vendors',
    '/etc/OpenCL/vendors',
  ];

  /// 常见 GPU 渲染节点
  static const List<String> _gpuNodes = [
    '/dev/kgsl-3d0',
    '/dev/dri/renderD128',
    '/dev/dri/renderD129',
    '/dev/mali0',
    '/dev/pvr',
  ];

  /// 运行所有诊断检查 - 使用调用方传入的 LogService，确保日志写入同一实例
  static Future<void> runAll(LogService log) async {
    log.info(_tag, '========== GPU 诊断开始 ==========');
    _logBasicInfo(log);
    log.info(_tag, '--- [OpenCL] ---');
    _logLibOpenCL(log);
    _logICDConfig(log);
    await _logDlopenTest(log);
    log.info(_tag, '--- [Vulkan] ---');
    _logLibVulkan(log);
    _logVulkanHwDrivers(log);
    _logVulkanIcdConfig(log);
    await _logDlopenVulkanTest(log);
    _logGpuInfo(log);
    _logSummary(log);

    // 同时调用 C++ 端诊断（mllm_run_diagnostics），结果会写入 mllm.log
    // 用户在运行日志页面可以同时看到 Dart 端（OpenCLDiag 标签）和
    // C++ 端（[diagnostic] 标签）的诊断输出
    log.info(_tag, '正在调用 C++ 端 mllm_run_diagnostics...');
    try {
      final svc = LocalLlmService(config: _dummyConfig, log: log);
      final ret = svc.runDiagnostics();
      log.info(_tag, 'mllm_run_diagnostics 返回: $ret (0=成功)');
    } catch (e) {
      log.error(_tag, '调用 C++ 端诊断失败: $e');
    }

    log.info(_tag, '========== 诊断完成 ==========');
  }

  // 创建一个虚拟配置用于诊断（不需要真实模型路径）
  static final _dummyConfig = LocalLlmConfig();

  static void _logBasicInfo(LogService log) {
    log.info(_tag, '--- 设备基础信息 ---');
    log.info(_tag, 'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    log.info(_tag, 'Android version: ${Platform.version}');
    log.info(_tag, 'Dart version: ${Platform.version}');
    log.info(_tag, 'Number of processors: ${Platform.numberOfProcessors}');
    log.info(_tag, 'Path separator: ${Platform.pathSeparator}');
  }

  static void _logLibOpenCL(LogService log) {
    log.info(_tag, '--- libOpenCL.so 查找 ---');
    int found = 0;
    for (final path in _libOpenCLPaths) {
      final exists = File(path).existsSync();
      log.info(_tag, '${exists ? "✓" : "✗"} $path');
      if (exists) {
        found++;
        try {
          final stat = File(path).statSync();
          log.info(_tag, '    size: ${stat.size} bytes');
        } catch (_) {}
      }
    }
    log.info(_tag, '找到 $found 个 libOpenCL.so');
  }

  static void _logICDConfig(LogService log) {
    log.info(_tag, '--- OpenCL ICD 配置文件 ---');
    int totalFiles = 0;
    for (final dir in _icdConfigDirs) {
      final exists = Directory(dir).existsSync();
      log.info(_tag, '${exists ? "✓" : "✗"} 目录: $dir');
      if (exists) {
        try {
          final files = Directory(dir).listSync();
          log.info(_tag, '    文件数: ${files.length}');
          for (final f in files) {
            log.info(_tag, '    - ${f.path}');
            totalFiles++;
            if (f is File) {
              try {
                final content = f.readAsStringSync();
                log.info(_tag, '      内容: ${content.trim()}');
              } catch (_) {}
            }
          }
        } catch (e) {
          log.warning(_tag, '    列出失败: $e');
        }
      }
    }
    log.info(_tag, '找到 $totalFiles 个 ICD 配置文件');
  }

  static void _logGpuInfo(LogService log) {
    log.info(_tag, '--- GPU 设备节点 ---');
    for (final path in _gpuNodes) {
      final exists = File(path).existsSync();
      log.info(_tag, '${exists ? "✓" : "✗"} $path');
      if (exists) {
        try {
          final stat = File(path).statSync();
          log.info(_tag, '    size: ${stat.size}, mode: ${stat.mode}');
        } catch (_) {}
      }
    }

    // 读取 /proc/cpuinfo
    try {
      final cpuInfo = File('/proc/cpuinfo').readAsStringSync();
      final hardwareLine = cpuInfo.split('\n').firstWhere(
        (l) => l.startsWith('Hardware') || l.startsWith('model name') || l.startsWith('Processor'),
        orElse: () => '',
      );
      if (hardwareLine.isNotEmpty) {
        log.info(_tag, 'CPU 硬件: ${hardwareLine.trim()}');
      }
    } catch (_) {}

    // 尝试读取 /sys/class/kgsl 信息 (Adreno GPU)
    try {
      final kgslModel = File('/sys/class/kgsl/kgsl-3d0/gpu_model');
      if (kgslModel.existsSync()) {
        final model = kgslModel.readAsStringSync().trim();
        log.info(_tag, 'Adreno GPU 型号: $model');
      }
    } catch (_) {}

    // 尝试读取 DRI 信息
    try {
      final driDir = Directory('/sys/class/drm');
      if (driDir.existsSync()) {
        for (final entry in driDir.listSync()) {
          if (entry.path.contains('card')) {
            try {
              final device = File('${entry.path}/device/device');
              if (device.existsSync()) {
                final v = device.readAsStringSync().trim();
                log.info(_tag, 'DRM 设备 ${entry.path}: $v');
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> _logDlopenTest(LogService log) async {
    log.info(_tag, '--- DynamicLibrary.open 实际测试 ---');
    try {
      final lib = DynamicLibrary.open('libOpenCL.so');
      log.info(_tag, '✓ libOpenCL.so DynamicLibrary.open 成功');
      try {
        // 尝试查找一个 OpenCL 函数符号来确认库加载成功
        final sym = lib.lookup<NativeFunction<Void Function()>>('clGetPlatformIDs');
        log.info(_tag, '✓ 找到 clGetPlatformIDs 符号: ${sym.address != 0}');
      } catch (e) {
        log.warning(_tag, '✗ 查找 clGetPlatformIDs 失败: $e');
      }
    } catch (e) {
      log.error(_tag, '✗ DynamicLibrary.open("libOpenCL.so") 失败: $e');
    }
  }

  static void _logLibVulkan(LogService log) {
    log.info(_tag, '--- libvulkan.so 查找 ---');
    int found = 0;
    for (final path in _libVulkanPaths) {
      final exists = File(path).existsSync();
      log.info(_tag, '${exists ? "✓" : "✗"} $path');
      if (exists) {
        found++;
        try {
          final stat = File(path).statSync();
          log.info(_tag, '    size: ${stat.size} bytes');
        } catch (_) {}
      }
    }
    log.info(_tag, '找到 $found 个 libvulkan.so');
  }

  static void _logVulkanHwDrivers(LogService log) {
    log.info(_tag, '--- Vulkan HW 驱动实现库（/vendor/lib64/hw/vulkan.*） ---');
    final hwDir = Directory('/vendor/lib64/hw');
    if (!hwDir.existsSync()) {
      log.info(_tag, '✗ 目录 /vendor/lib64/hw 不存在');
      return;
    }
    int found = 0;
    try {
      for (final entry in hwDir.listSync()) {
        final name = entry.path.split('/').last;
        if (name.startsWith('vulkan.')) {
          found++;
          final stat = entry.statSync();
          log.info(_tag, '✓ ${entry.path}  (${stat.size} bytes)');
        }
      }
    } catch (e) {
      log.warning(_tag, '    列出 HW 驱动失败: $e');
    }
    if (found == 0) {
      log.info(_tag, '未找到任何 vulkan.*.so HW 驱动（在 /vendor/lib64/hw/ 下）');
    }
  }

  static void _logVulkanIcdConfig(LogService log) {
    log.info(_tag, '--- Vulkan ICD JSON 配置文件 ---');
    int totalFiles = 0;
    for (final dir in _vulkanIcdDirs) {
      final exists = Directory(dir).existsSync();
      log.info(_tag, '${exists ? "✓" : "✗"} 目录: $dir');
      if (exists) {
        try {
          final files = Directory(dir).listSync();
          log.info(_tag, '    文件数: ${files.length}');
          for (final f in files) {
            log.info(_tag, '    - ${f.path}');
            totalFiles++;
            if (f is File) {
              try {
                final content = f.readAsStringSync();
                log.info(_tag, '      内容: ${content.trim()}');
              } catch (_) {}
            }
          }
        } catch (e) {
          log.warning(_tag, '    列出失败: $e');
        }
      }
    }
    log.info(_tag, '找到 $totalFiles 个 Vulkan ICD 配置文件');
  }

  static Future<void> _logDlopenVulkanTest(LogService log) async {
    log.info(_tag, '--- DynamicLibrary.open libvulkan.so 实际测试 ---');
    try {
      final lib = DynamicLibrary.open('libvulkan.so');
      log.info(_tag, '✓ libvulkan.so DynamicLibrary.open 成功');
      try {
        final sym = lib.lookup<NativeFunction<Void Function()>>('vkCreateInstance');
        log.info(_tag, '✓ 找到 vkCreateInstance 符号: ${sym.address != 0}');
      } catch (e) {
        log.warning(_tag, '✗ 查找 vkCreateInstance 失败: $e');
      }
    } catch (e) {
      log.error(_tag, '✗ DynamicLibrary.open("libvulkan.so") 失败: $e');
    }
  }

  static void _logSummary(LogService log) {
    log.info(_tag, '--- 结论 ---');
    log.info(_tag, '如需 OpenCL/Vulkan GPU 加速，需要：');
    log.info(_tag, '1. libOpenCL.so / libvulkan.so 至少存在一个有效路径');
    log.info(_tag, '2. 对应 ICD 配置文件存在（OpenCL: .../OpenCL/vendors/, Vulkan: .../vulkan/icd.d/）');
    log.info(_tag, '3. DynamicLibrary.open 能成功加载对应库');
    log.info(_tag, '如果以上任何一项缺失对应项，该 GPU 加速方案将无法使用。');
  }
}
