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
  StreamSubscription<S3SyncProgress>? _syncSubscription;
  S3SyncProgress _lastProgress = const S3SyncProgress();
  bool _testingConnection = false;
  bool? _connectionOk;
  SyncStats? _storageStats;
  bool _loadingStats = false;

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _startSync(Stream<S3SyncProgress> Function() syncFn) {
    _syncSubscription?.cancel();
    setState(() {
      _lastProgress = const S3SyncProgress();
    });
    _syncSubscription = syncFn().listen((progress) {
      if (!mounted) return;
      setState(() => _lastProgress = progress);
    });
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
    final progress = _lastProgress;
    final inProgress = progress.status == S3SyncStatus.uploading ||
        progress.status == S3SyncStatus.downloading;

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
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _syncButton(
                          label: S.of(context).fullUpload,
                          icon: Icons.cloud_upload,
                          enabled: isConfigured && !inProgress,
                          onPressed: () => _startSync(
                              () => ref.read(s3SyncServiceProvider).uploadAll()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _syncButton(
                          label: S.of(context).fullDownload,
                          icon: Icons.cloud_download,
                          enabled: isConfigured && !inProgress,
                          onPressed: () => _startSync(() =>
                              ref.read(s3SyncServiceProvider).downloadAll()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _syncButton(
                          label: S.of(context).incrementalSync,
                          icon: Icons.sync,
                          enabled: isConfigured && !inProgress,
                          onPressed: () => _startSync(() =>
                              ref.read(s3SyncServiceProvider).incremental()),
                        ),
                      ),
                    ],
                  ),
                  if (inProgress)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel, size: 18),
                          label: Text(S.of(context).cancel),
                          onPressed: () {
                            ref.read(s3SyncServiceProvider).cancel();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- 进度 ----
          if (inProgress || progress.status == S3SyncStatus.error) ...[
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
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 12),
                    if (progress.total > 0) ...[
                      LinearProgressIndicator(
                        value: progress.fraction,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${progress.completed}/${progress.total}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else
                      const LinearProgressIndicator(),
                    if (progress.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        progress.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---- 定时自动同步 ----
          if (isConfigured) ...[
            Text(S.of(context).scheduledSync, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.timer),
                    title: Text(S.of(context).autoSync),
                    subtitle: Text(
                      ref.watch(autoSyncEnabledProvider)
                          ? S.of(context).syncIntervalSummary(_intervalLabel(ref.watch(autoSyncIntervalProvider)))
                          : S.of(context).manualSyncOnly,
                      style: theme.textTheme.bodySmall,
                    ),
                    value: ref.watch(autoSyncEnabledProvider),
                    onChanged: (v) {
                      ref.read(autoSyncEnabledProvider.notifier).setEnabled(v);
                      final service = ref.read(s3SyncServiceProvider);
                      if (v) {
                        service.startPeriodicSync(
                            ref.read(autoSyncIntervalProvider));
                      } else {
                        service.stopPeriodicSync();
                      }
                    },
                  ),
                  if (ref.watch(autoSyncEnabledProvider))
                    ListTile(
                      title: Text(S.of(context).syncInterval),
                      trailing: DropdownButton<Duration>(
                        value: ref.watch(autoSyncIntervalProvider),
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: Duration(minutes: 5),
                            child: Text(S.of(context).fiveMinutes),
                          ),
                          DropdownMenuItem(
                            value: Duration(minutes: 15),
                            child: Text(S.of(context).fifteenMinutes),
                          ),
                          DropdownMenuItem(
                            value: Duration(minutes: 30),
                            child: Text(S.of(context).thirtyMinutes),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 1),
                            child: Text(S.of(context).oneHour),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 6),
                            child: Text(S.of(context).sixHours),
                          ),
                          DropdownMenuItem(
                            value: Duration(days: 1),
                            child: Text(S.of(context).oneDay),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          ref.read(autoSyncIntervalProvider.notifier).setInterval(v);
                          final service = ref.read(s3SyncServiceProvider);
                          service.stopPeriodicSync();
                          service.startPeriodicSync(v);
                        },
                      ),
                    ),
                ],
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
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: Text(S.of(context).s3Storage),
                  subtitle: Text(
                    _storageStats != null
                        ? S.of(context).storageStatsDetail(_formatBytes(_storageStats!.totalBytes), _storageStats!.objectCount)
                        : _loadingStats
                            ? S.of(context).calculating
                            : S.of(context).clickToRefresh,
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: TextButton.icon(
                    icon: _loadingStats
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(S.of(context).refresh),
                    onPressed: isConfigured && !_loadingStats
                        ? _refreshStorageStats
                        : null,
                  ),
                ),
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

  String _intervalLabel(Duration d) {
    if (d.inMinutes < 60) return S.of(context).intervalMinutes(d.inMinutes);
    if (d.inHours < 24) return S.of(context).intervalHours(d.inHours);
    return S.of(context).intervalDays(d.inDays);
  }

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
