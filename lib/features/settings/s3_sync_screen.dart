import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gallery/gallery_provider.dart';
import '../../services/s3_config.dart';
import '../../services/s3_sync_service.dart';
import '../../l10n/app_localizations.dart';

/// S3 云同步管理页面
class S3SyncScreen extends ConsumerStatefulWidget {
  const S3SyncScreen({super.key});

  @override
  ConsumerState<S3SyncScreen> createState() => _S3SyncScreenState();
}

class _S3SyncScreenState extends ConsumerState<S3SyncScreen> {
  bool _testingConnection = false;
  bool? _connectionOk;
  SyncStats? _storageStats;
  bool _loadingStats = false;

  /// 「清理孤儿」被拒绝的原因（非 null 时在同步按钮下方提示）。
  String? _cleanupBlockedReason;

  @override
  void initState() {
    super.initState();
    // 监听全局同步状态：idle/error 时弹 snackbar，并在 idle 时刷新图库。
    // listener 由 widget lifecycle 管理，widget dispose 时自动清理。
    ref.listenManual<S3SyncProgress>(s3SyncStatusProvider, (prev, next) {
      if (!mounted) return;
      if (next.status == S3SyncStatus.idle || next.status == S3SyncStatus.error) {
        if (next.status == S3SyncStatus.idle) {
          ref.invalidate(memeListProvider);
          ref.invalidate(memeCountProvider);
          _refreshCleanupGuard();
        }
        if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.errorMessage!)),
          );
        } else if (next.summary != null && next.summary!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.summary!)),
          );
        }
      }
    });
  }

  Future<void> _startSync(Stream<S3SyncProgress> Function() syncFn) async {
    // 启动走全局 S3SyncStatusNotifier，里面有 inFlight 互斥，避免重复
    // 点击导致两次 incremental() 并行；返回 false 表示同步已在进行。
    final started = await ref.read(s3SyncStatusProvider.notifier).start(syncFn);
    if (!started) {
      // 已经在同步中，给用户提示一下（按钮 disable 也有兜底）。
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).s3SyncAlreadyRunning)),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionOk = null;
    });
    final service = ref.read(s3SyncServiceProvider);
    final ok = await service.testConnection();
    if (!mounted) return;
    setState(() {
      _testingConnection = false;
      _connectionOk = ok;
    });
  }

  Future<void> _refreshStorageStats() async {
    setState(() {
      _loadingStats = true;
      _storageStats = null;
    });
    try {
      final stats =
          await ref.read(s3SyncServiceProvider).getStorageStats();
      if (mounted) {
        setState(() => _storageStats = stats);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).s3StorageStatsFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
    await _refreshCleanupGuard();
  }

  /// 查询「清理孤儿」当前是否被前置条件阻止（未迁移 / manifest 不可读）。
  Future<void> _refreshCleanupGuard() async {
    final config = ref.read(s3ConfigProvider).valueOrNull ?? const S3Config();
    if (!config.isValid) {
      if (mounted) setState(() => _cleanupBlockedReason = null);
      return;
    }
    try {
      final reason =
          await ref.read(s3SyncServiceProvider).cleanupBlockedReason();
      if (mounted) setState(() => _cleanupBlockedReason = reason);
    } catch (_) {
      if (mounted) setState(() => _cleanupBlockedReason = null);
    }
  }

  Future<void> _cleanupOrphans() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).cleanupOrphans),
        content: Text(S.of(context).cleanupOrphansConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: Text(S.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            child: Text(S.of(context).confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final removed =
          await ref.read(s3SyncServiceProvider).cleanupOrphans();
      if (!mounted) return;
      final reason =
          await ref.read(s3SyncServiceProvider).cleanupBlockedReason();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason ?? S.of(context).cleanupOrphansDone(removed)),
        ),
      );
      await _refreshStorageStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).s3SyncFailed(e.toString()))),
      );
    }
  }

  Future<void> _showClearPasswordDialog() async {
    final passwordCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    final service = ref.read(s3SyncServiceProvider);
    final hasPw = await service.hasClearPassword();

    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        if (!hasPw) {
          // 首次设置密码
          return AlertDialog(
            title: Text(S.of(context).setClearPassword),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.of(context).clearPasswordHint),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: S.of(context).password,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: S.of(context).confirmPassword,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                child: Text(S.of(context).cancel),
              ),
              FilledButton(
                onPressed: () {
                  if (passwordCtl.text.isEmpty) return;
                  if (passwordCtl.text != confirmCtl.text) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(S.of(context).passwordMismatch)),
                    );
                    return;
                  }
                  Navigator.of(ctx, rootNavigator: true).pop(passwordCtl.text);
                },
                child: Text(S.of(context).setPassword),
              ),
            ],
          );
        }
        // 已有密码，输入密码确认清空
        return AlertDialog(
          title: Text(S.of(context).clearS3Data),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.of(context).clearS3Warning),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: S.of(context).enterPasswordToConfirm,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: Text(S.of(context).cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop(passwordCtl.text);
              },
              child: Text(S.of(context).confirmClear),
            ),
          ],
        );
      },
    );

    if (action == null || action.isEmpty) return;

    if (!hasPw) {
      // 首次设置，保存密码后再进入清空流程
      await service.setClearPassword(action);
      if (!mounted) return;
      _doClear(service, action);
    } else {
      _doClear(service, action);
    }
  }

  Future<void> _doClear(S3SyncService service, String password) async {
    try {
      await service.clearAllData(password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).s3DataCleared)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).clearFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(s3ConfigProvider).valueOrNull ?? const S3Config();
    final isConfigured = config.isValid;
    final theme = Theme.of(context);
    // 同步进度取自全局 provider，离开页面再回来也不会丢；同步过程中
    // 任何 watch 此 provider 的 widget 都会同步更新。
    final progress = ref.watch(s3SyncStatusProvider);
    final inProgress = progress.status == S3SyncStatus.uploading ||
        progress.status == S3SyncStatus.downloading;
    // 上传用 primary（紫），下载用 tertiary（青）——两者需在主题里定义为不同色。
    final syncAccent = progress.status == S3SyncStatus.uploading
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).s3Sync)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 配置摘要 ----
          Text(S.of(context).config, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: Text(S.of(context).s3Connection),
              subtitle: Text(
                isConfigured
                    ? '${config.endpoint}/${config.bucket}'
                    : S.of(context).notConfigured,
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _showConfigDialog(context, ref, config),
            ),
          ),
          const SizedBox(height: 16),

          // ---- 连接测试 ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.of(context).connectionTest),
                        if (_connectionOk != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _connectionOk!
                                      ? Icons.check_circle
                                      : Icons.error,
                                  size: 16,
                                  color: _connectionOk!
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _connectionOk! ? S.of(context).connectionOk : S.of(context).connectionFailed,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _connectionOk!
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _testingConnection ? null : _testConnection,
                    child: _testingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(S.of(context).test),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- 同步操作 ----
          Text(S.of(context).syncOperations, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _syncButton(
                    label: S.of(context).syncNow,
                    icon: Icons.sync,
                    enabled: isConfigured && !inProgress,
                    onPressed: () => _startSync(() =>
                        ref.read(s3SyncServiceProvider).incremental()),
                  ),
                  const SizedBox(height: 8),
                  // 同步不可中断（引擎没有取消点），因此不提供取消按钮。
                  Text(
                    S.of(context).s3SyncNoCancelHint,
                    style: theme.textTheme.bodySmall,
                  ),
                  // 「清理未引用图片」的已知限制（无墓碑，删除无法传播）。
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      S.of(context).s3CleanupLimitation,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  // 清理前置条件不满足时的提示（例如 bucket 还没完成 v1→v2 迁移）。
                  if (_cleanupBlockedReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _cleanupBlockedReason!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- 进度 ----
          if (inProgress ||
              progress.status == S3SyncStatus.error ||
              (progress.summary != null && progress.summary!.isNotEmpty)) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (progress.status == S3SyncStatus.error)
                          const Icon(Icons.error, color: Colors.red, size: 18),
                        if (progress.status == S3SyncStatus.uploading)
                          const Icon(Icons.cloud_upload, size: 18),
                        if (progress.status == S3SyncStatus.downloading)
                          const Icon(Icons.cloud_download, size: 18),
                        if (progress.status == S3SyncStatus.idle &&
                            progress.summary != null)
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        if (progress.status == S3SyncStatus.uploading ||
                            progress.status == S3SyncStatus.downloading ||
                            progress.status == S3SyncStatus.error)
                          Text(
                            progress.status == S3SyncStatus.uploading
                                ? S.of(context).uploading
                                : progress.status == S3SyncStatus.downloading
                                    ? S.of(context).downloading
                                    : S.of(context).error,
                            style: theme.textTheme.titleSmall,
                          ),
                      ],
                    ),
                    if (inProgress) ...[
                      const SizedBox(height: 12),
                      if (progress.total > 0) ...[
                        // 不同阶段用不同颜色：上传紫色（primary），下载青色
                        // （tertiary），让用户一眼区分状态；轨道用同色低透明度
                        // 保证填充边界清晰可见。
                        LinearProgressIndicator(
                          value: progress.fraction,
                          minHeight: 8,
                          valueColor: AlwaysStoppedAnimation<Color>(syncAccent),
                          backgroundColor: syncAccent.withValues(alpha: 0.18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${progress.completed}/${progress.total}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ] else
                        const LinearProgressIndicator(),
                    ],
                    if (progress.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        progress.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                    if (progress.summary != null &&
                        progress.summary!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        progress.summary!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---- 存储统计（手动触发） ----
          Text(S.of(context).storageStatistics, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.cloud),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(S.of(context).s3Storage),
                            const SizedBox(height: 4),
                            Text(
                              _storageStats != null
                                  ? S.of(context).storageStatsDetail(
                                      _formatBytes(_storageStats!.totalBytes),
                                      _storageStats!.objectCount)
                                  : _loadingStats
                                      ? S.of(context).calculating
                                      : S.of(context).clickToRefresh,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (_storageStats != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                S.of(context).s3StatsReferenced(
                                    _storageStats!.referencedImages),
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                S.of(context).s3StatsOrphan(
                                    _storageStats!.orphanImages),
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                S.of(context).s3StatsMeta(
                                    _storageStats!.metaFiles),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: _loadingStats
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(S.of(context).refresh),
                        onPressed: isConfigured && !_loadingStats
                            ? _refreshStorageStats
                            : null,
                      ),
                    ],
                  ),
                ),
                if (_storageStats != null) ...[
                  const Divider(height: 1),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextButton.icon(
                        icon: const Icon(Icons.cleaning_services, size: 18),
                        label: Text(S.of(context).cleanupOrphans),
                        onPressed: inProgress ? null : _cleanupOrphans,
                      ),
                    ),
                  ),
                ],
                FutureBuilder<int>(
                  future: ref.read(fileStorageServiceProvider).storageUsed(),
                  builder: (ctx, localSnapshot) {
                    final localBytes = localSnapshot.data ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.storage),
                      title: Text(S.of(context).localStorage),
                      subtitle: Text(
                        _formatBytes(localBytes),
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 上次同步 ----
          Card(
            child: FutureBuilder<int?>(
              future: ref.read(databaseProvider).syncStateDao.getLastSyncAt(),
              builder: (context, snapshot) {
                final ts = snapshot.data;
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(S.of(context).lastSync),
                  subtitle: Text(
                    ts != null
                        ? _formatDateTime(DateTime.fromMillisecondsSinceEpoch(ts))
                        : S.of(context).neverSynced,
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ---- 清空数据 ----
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(S.of(context).clearS3Data),
              subtitle: Text(
                S.of(context).deleteAllBucketFiles,
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: inProgress ? null : _showClearPasswordDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label, style: TextStyle(fontSize: 13)),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _showConfigDialog(BuildContext context, WidgetRef ref, S3Config config) {
    final endpointCtl = TextEditingController(text: config.endpoint);
    final bucketCtl = TextEditingController(text: config.bucket);
    final regionCtl = TextEditingController(text: config.region);
    final accessKeyCtl = TextEditingController(text: config.accessKey);
    final secretKeyCtl = TextEditingController(text: config.secretKey);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(S.of(context).s3Config),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: endpointCtl,
                  decoration: InputDecoration(
                    labelText: 'Endpoint',
                    hintText: 's3.amazonaws.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bucketCtl,
                  decoration: InputDecoration(
                    labelText: 'Bucket',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: regionCtl,
                  decoration: InputDecoration(
                    labelText: 'Region',
                    hintText: 'us-east-1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accessKeyCtl,
                  decoration: InputDecoration(
                    labelText: 'Access Key',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: secretKeyCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Secret Key',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: Text(S.of(context).cancel),
            ),
            FilledButton(
              onPressed: () {
                final newConfig = S3Config(
                  endpoint: endpointCtl.text.trim(),
                  bucket: bucketCtl.text.trim(),
                  region: regionCtl.text.trim(),
                  accessKey: accessKeyCtl.text.trim(),
                  secretKey: secretKeyCtl.text.trim(),
                  useSsl: true,
                );
                ref.read(s3ConfigProvider.notifier).save(newConfig);
                ref.read(s3SyncServiceProvider).updateConfig(newConfig);
                Navigator.of(ctx, rootNavigator: true).pop();
              },
              child: Text(S.of(context).save),
            ),
          ],
        );
      },
    );
  }
}
