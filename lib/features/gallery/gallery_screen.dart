import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/database.dart';
import '../../services/clipboard_service.dart';
import '../../services/file_storage_service.dart';
import '../../services/import_service.dart';
import '../../services/meme_export_service.dart';
import '../../services/meme_import_service.dart';
import '../../services/shared_media_handler.dart';
import 'gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _selectedTab = 0;
  bool _selectionMode = false;
  bool _dragOver = false;
  bool _radialOpen = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _syncTabController(int tabCount) {
    if (_tabController != null && _tabController!.length == tabCount) return;
    if (tabCount == 0) {
      _tabController?.dispose();
      _tabController = null;
      return;
    }
    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: oldIndex.clamp(0, tabCount - 1),
    );
    _tabController!.addListener(() {
      if (_tabController!.index != _selectedTab) {
        setState(() => _selectedTab = _tabController!.index);
      }
    });
    if (mounted) setState(() {});
  }

  void _enterSelectionMode(String memeId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(memeId);
    });
  }

  void _toggleSelection(String memeId) {
    setState(() {
      if (_selectedIds.contains(memeId)) {
        _selectedIds.remove(memeId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(memeId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _copySelected() async {
    final storage = ref.read(fileStorageServiceProvider);
    final memeRepo = ref.read(memeRepositoryProvider);
    final userStatsDao = ref.read(userStatsDaoProvider);
    final paths = <String>[];

    for (final id in _selectedIds) {
      final meme = await memeRepo.getById(id);
      if (meme != null) {
        final file = await storage.getImage(meme.filePath);
        paths.add(file.path);
        // 复制次数 +1
        await memeRepo.incrementCopyCount(id);
        await userStatsDao.incrementCopied();
      }
    }

    if (paths.isEmpty) return;

    if (paths.length == 1) {
      await ClipboardService.copyImageToClipboard(paths.first);
    } else {
      await ClipboardService.shareMultipleImages(paths);
    }

    _exitSelectionMode();
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;

    // 安全检查：如果没有选中任何图片，直接返回
    if (_selectedIds.isEmpty) {
      _exitSelectionMode();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 防止用户点击外部关闭对话框
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).confirmDeleteTitle),
        content: Text(S.of(context).confirmDeleteSelected(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(context).delete,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );

    // 确保 confirmed 为 true 才执行删除
    if (confirmed != true) {
      return;
    }

    try {
      final repo = ref.read(memeRepositoryProvider);
      for (final id in _selectedIds) {
        await repo.delete(id);
      }
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);
      _exitSelectionMode();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).deletedCountImages(count))),
        );
      }
    } catch (e) {
      // 如果删除过程中出错，也退出选择模式并显示错误
      _exitSelectionMode();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _moveSelectedToAlbum() async {
    final albumsAsync = ref.read(albumsProvider);
    final albums = albumsAsync.valueOrNull ?? [];
    if (albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).noAlbumsCreateFirst)),
      );
      return;
    }

    final album = await showDialog<Album>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(S.of(context).selectAlbum),
        children: albums
            .map((a) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, a),
                  child: Text(a.name),
                ))
            .toList(),
      ),
    );

    if (album == null) return;

    final albumRepo = ref.read(albumRepositoryProvider);
    await albumRepo.addMemesToAlbum(_selectedIds.toList(), album.id);

    // 刷新目标相册的 meme 列表
    ref.invalidate(memesByAlbumProvider(album.id));
    ref.invalidate(memeListProvider);

    final count = _selectedIds.length;
    _exitSelectionMode();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).addedToAlbum(count, album.name))),
      );
    }
  }

  Future<void> _showNewAlbumDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).newAlbum),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: S.of(context).albumName),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(S.of(context).create),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(albumsProvider.notifier).addAlbum(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final albumsAsync = ref.watch(albumsProvider);
    final albums = albumsAsync.asData?.value ?? [];
    final nonDefaultAlbums = albums.where((a) => a.isDefault != 1).toList();
    final tabCount = nonDefaultAlbums.length + 1;

    _syncTabController(tabCount);

    final memeListAsync = ref.watch(memeListProvider);

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) {
          _exitSelectionMode();
        }
      },
      child: DropTarget(
        onDragDone: _onDrop,
        onDragEntered: (_) => setState(() => _dragOver = true),
        onDragExited: (_) => setState(() => _dragOver = false),
        child: Stack(
          children: [
            // 径向菜单打开时的半透明遮罩（点击关闭）
            if (_radialOpen)
              GestureDetector(
                onTap: _closeRadial,
                child: Container(color: Colors.black12),
              ),
            Scaffold(
              appBar: _selectionMode
                  ? _buildSelectionAppBar()
                  : _buildNormalAppBar(tabCount, nonDefaultAlbums),
              body: _selectionMode
                  ? _buildSelectionGrid(memeListAsync)
                  : _buildTabbedBody(memeListAsync, nonDefaultAlbums),
              floatingActionButton: _selectionMode ? null : _buildFab(),
              // 点击页面内容也关闭径向菜单
              onDrawerChanged: (_) => _closeRadial(),
            ),
            if (_dragOver)
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_upload,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(S.of(context).releaseToImport,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(int tabCount, List<Album> nonDefaultAlbums) {
    // 构建 TabBar（不含专辑时居中显示「全部图片」）
    final tabs = <Widget>[
      Tab(text: S.of(context).allImages),
      ...nonDefaultAlbums.map((a) => Tab(text: a.name)),
    ];
    final actualTabCount = tabs.length;

    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: actualTabCount > 1,
      tabAlignment: actualTabCount > 1 ? null : TabAlignment.center,
      tabs: tabs,
    );

    final sortMode = ref.watch(memeSortModeProvider);
    const sortBarHeight = 36.0;
    const tabBarHeight = 48.0;
    final totalBottomHeight = (actualTabCount > 1 ? tabBarHeight : 0.0) + sortBarHeight;

    return AppBar(
      toolbarHeight: 0,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(totalBottomHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actualTabCount > 1) tabBar,
            // 排序栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 36,
              child: Row(
                children: [
                  Icon(Icons.sort, size: 16,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<MemeSortMode>(
                        value: sortMode,
                        isDense: true,
                        style: Theme.of(context).textTheme.bodySmall,
                        items: MemeSortMode.values.map((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(mode.label, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(memeSortModeProvider.notifier).set(v);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      title: Text(S.of(context).selectedItems(_selectedIds.length)),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.archive_outlined),
          onPressed: _exportSelected,
          tooltip: S.of(context).export,
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: _copySelected,
          tooltip: S.of(context).copy,
        ),
        IconButton(
          icon: const Icon(Icons.photo_album_outlined),
          onPressed: _moveSelectedToAlbum,
          tooltip: S.of(context).addToAlbum,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _deleteSelected,
          tooltip: S.of(context).delete,
        ),
      ],
    );
  }

  Widget _buildTabbedBody(
    AsyncValue<List<Meme>> memeListAsync,
    List<Album> nonDefaultAlbums,
  ) {
    if (_tabController == null) return const SizedBox();

    final children = <Widget>[
      _buildMemeGrid(memeListAsync),
      ...nonDefaultAlbums.map((a) {
        final albumMemes = ref.watch(memesByAlbumProvider(a.id));
        return _buildMemeGrid(albumMemes);
      }),
    ];

    return Column(
      children: [
        // 分析进度横幅
        _buildAnalysisBanner(),
        // 图库内容
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisBanner() {
    final theme = Theme.of(context);
    final s = S.of(context);
    final reindexState = ref.watch(reindexStateProvider);

    // 优先显示重新索引进度
    if (reindexState.isRunning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.colorScheme.primaryContainer,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '重新索引中... 已处理 ${reindexState.processed} 个，已入队 ${reindexState.enqueued} 个',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 分析进度
    final progressAsync = ref.watch(analysisProgressProvider);
    final progress = progressAsync.valueOrNull;
    if (progress == null || progress.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.analyzingProgress(progress.running > 0 ? s.analyzingRunning(progress.running) : '', progress.total)
              ,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemeGrid(AsyncValue<List<Meme>> memeListAsync) {
    final colorScheme = Theme.of(context).colorScheme;

    return memeListAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(S.of(context).loadFailedWithError(e.toString()))),
      data: (memes) {
        if (memes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 80, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(S.of(context).noMemesYet,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(S.of(context).tapToImport,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.outline)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.refresh(memeListProvider);
            ref.refresh(memeCountProvider);
            ref.refresh(albumsProvider);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: memes.length,
            itemBuilder: (context, index) {
              final meme = memes[index];
              return _MemeGridTile(
                meme: meme,
                selectionMode: _selectionMode,
                selected: _selectedIds.contains(meme.id),
                onTap: () {
                  if (_selectionMode) {
                    _toggleSelection(meme.id);
                  } else {
                    context.pushNamed('meme-detail',
                        pathParameters: {'id': meme.id});
                  }
                },
                onLongPress: () => _enterSelectionMode(meme.id),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSelectionGrid(AsyncValue<List<Meme>> memeListAsync) {
    final memes = memeListAsync.asData?.value ?? [];
    return _buildMemeGrid(AsyncValue.data(memes));
  }

  // ---- 速度旋盘 FAB（MUI Speed Dial 风格）----

  void _toggleRadial() => setState(() => _radialOpen = !_radialOpen);

  void _closeRadial() {
    if (_radialOpen) setState(() => _radialOpen = false);
  }

  Widget _buildFab() {
    final s = S.of(context);
    final theme = Theme.of(context);
    final fabActions = [
      _SpeedDialAction(Icons.search, s.scanFolder),
      _SpeedDialAction(Icons.add_photo_alternate, s.importImage),
      _SpeedDialAction(Icons.archive, s.importMemePack),
      _SpeedDialAction(Icons.content_paste, s.importFromClipboard),
      _SpeedDialAction(Icons.photo_library, s.newAlbumShort),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 展开的动作项
        for (int i = 0; i < fabActions.length; i++) ...[
          _SpeedDialItem(
            icon: fabActions[i].icon,
            label: fabActions[i].label,
            visible: _radialOpen,
            index: i,
            onTap: () {
              _closeRadial();
              switch (i) {
                case 0:
                  context.pushNamed('scan');
                case 1:
                  context.pushNamed('import');
                case 2:
                  _importMemePack();
                case 3:
                  _importFromClipboard();
                case 4:
                  _showNewAlbumDialog();
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        // 主 FAB（旋转动画）
        FloatingActionButton(
          onPressed: _toggleRadial,
          child: AnimatedRotation(
            turns: _radialOpen ? 0.125 : 0.0, // 45°
            duration: const Duration(milliseconds: 250),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // ---- 底部弹出菜单（保留作为备用，当前使用径向菜单）----

  Future<void> _onDrop(DropDoneDetails details) async {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final paths = details.files
        .where((f) => imageExtensions.contains(f.name.split('.').last.toLowerCase()))
        .map((f) => f.path)
        .where((p) => p != null)
        .cast<String>()
        .toList();

    if (paths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).noImageFilesFound)),
        );
      }
      return;
    }

    final service = ref.read(importServiceProvider);
    final result = await service.importImages(paths, source: '系统分享');

    ref.invalidate(memeListProvider);
    ref.invalidate(memeCountProvider);

    if (mounted) {
      _showImportResult(result);
    }
  }

  Future<void> _importFromClipboard() async {
    final log = ref.read(logServiceProvider);
    log.info('Clipboard', '_importFromClipboard 开始');
    String? path;
    String? clipboardData = await ClipboardService.readText();
    if (clipboardData != null && clipboardData.trim().isNotEmpty) {
      path = clipboardData.trim();
      log.info('Clipboard', '文本剪贴板内容: ${path.length > 100 ? path.substring(0, 100) : path}');
    } else {
      log.info('Clipboard', '文本剪贴板为空，尝试原生 getClipboardImage');
      final nativePath = await SharedMediaHandler().getClipboardImage();
      final clipPreview = nativePath != null && nativePath.length > 150 ? '${nativePath.substring(0, 150)}...' : nativePath;
      log.info('Clipboard', '原生 getClipboardImage 返回: $clipPreview');
      if (nativePath != null) {
        if (nativePath.startsWith('content://') || nativePath.startsWith('file://')) {
          final copied = await SharedMediaHandler().copyContentUri(nativePath);
          if (copied != null) {
            path = copied;
            log.info('Clipboard', 'URI 复制到缓存: $copied');
          } else {
            log.error('Clipboard', 'copyContentUri 失败: $nativePath');
          }
        } else {
          path = nativePath;
        }
      }
    }

    if (path == null) {
      log.warning('Clipboard', '剪贴板为空，无可用路径');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).clipboardEmpty)),
        );
      }
      return;
    }
    log.info('Clipboard', '最终待导入路径: $path');

    // 移除可能的 file:// 前缀
    if (path.startsWith('file://')) {
      path = path.substring(7);
      log.info('Clipboard', '已移除 file:// 前缀: $path');
    }

    // content:// URI：通过原生复制到缓存
    if (path.startsWith('content://')) {
      log.info('Clipboard', '检测到 content:// URI，尝试 copyContentUri');
      final copied = await SharedMediaHandler().copyContentUri(path);
      if (copied == null) {
        log.error('Clipboard', 'copyContentUri 失败，放弃导入');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).cannotReadClipboardUri)),
          );
        }
        return;
      }
      path = copied;
      log.info('Clipboard', 'URI 已复制到缓存: $path');
    }

    // HTTP/HTTPS URL：直接下载
    if (path.startsWith('http://') || path.startsWith('https://')) {
      log.info('Clipboard', '检测到 HTTP URL，开始下载: ${path.length > 100 ? path.substring(0, 100) : path}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).downloadingFromClipboardUrl)),
        );
      }
      final localFile = await _downloadToCache(path);
      if (localFile == null) {
        log.error('Clipboard', 'HTTP URL 下载失败');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).downloadFromUrlFailed)),
          );
        }
        return;
      }
      path = localFile;
      log.info('Clipboard', '下载完成: $path');
    }

    // http-url:// 前缀（来自原生 getClipboardImage 的 HTTP URL 检测）
    if (path.startsWith('http-url://')) {
      final url = path.substring(10);
      log.info('Clipboard', '检测到 http-url:// 前缀，开始下载: $url');
      final localFile = await _downloadToCache(url);
      if (localFile == null) {
        log.error('Clipboard', 'http-url:// 下载失败');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).downloadClipboardImageFailed)),
          );
        }
        return;
      }
      path = localFile;
      log.info('Clipboard', '下载完成: $path');
    }

    // 验证本地文件存在且为图片格式
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final ext = path.split('.').last.toLowerCase();
    final file = File(path);
    if (!await file.exists()) {
      log.error('Clipboard', '文件不存在: $path');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).clipboardNotValidPath)),
        );
      }
      return;
    }
    if (!imageExtensions.contains(ext)) {
      log.warning('Clipboard', '非图片格式: $path -> $ext');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).clipboardNotImage)),
        );
      }
      return;
    }

    log.info('Clipboard', '开始导入: $path');
    final service = ref.read(importServiceProvider);
    final result = await service.importImages([path], source: '剪贴板');
    log.info('Clipboard', '导入结果: 成功=${result.success} 跳过=${result.skipped} 错误=${result.errors.length}');

    ref.invalidate(memeListProvider);
    ref.invalidate(memeCountProvider);

    if (mounted) {
      _showImportResult(result);
    }
  }

  /// 从 URL 下载图片到缓存目录，返回本地路径
  Future<String?> _downloadToCache(String url) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('downloadToCache: HTTP ${response.statusCode}');
        return null;
      }
      final ext = _extFromUrl(url);
      final file = File(
          '${Directory.systemTemp.path}/clipboard_dl_${DateTime.now().millisecondsSinceEpoch}$ext');
      await response.pipe(file.openWrite());
      debugPrint('downloadToCache: $url -> ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('downloadToCache failed: $url -> $e');
      return null;
    }
  }

  String _extFromUrl(String url) {
    final uriPath = Uri.parse(url).path;
    final dot = uriPath.lastIndexOf('.');
    if (dot >= 0) {
      final ext = uriPath.substring(dot).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
        return ext;
      }
    }
    return '.jpg';
  }

  void _showImportResult(ImportResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.success > 0 ? S.of(context).importComplete : S.of(context).importResultTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.of(context).importSuccess(result.success)),
              Text(S.of(context).importSkipped(result.skipped)),
              if (result.skippedFiles.isNotEmpty && result.skippedFiles.length <= 10) ...[
                const SizedBox(height: 8),
                Text(S.of(context).existingFiles,
                    style: Theme.of(ctx).textTheme.bodySmall),
                ...result.skippedFiles.map((f) => Text('  • $f',
                    style: Theme.of(ctx).textTheme.bodySmall)),
              ],
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(S.of(context).importErrors(result.errors.length)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).ok),
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate),
              title: Text(S.of(context).importImage),
              onTap: () {
                Navigator.pop(ctx);
                context.pushNamed('import');
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: Text(S.of(context).importMemePack),
              onTap: () {
                Navigator.pop(ctx);
                _importMemePack();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(S.of(context).newAlbum),
              onTap: () {
                Navigator.pop(ctx);
                _showNewAlbumDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(S.of(context).importFromClipboard),
              onTap: () {
                Navigator.pop(ctx);
                _importFromClipboard();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSelected() async {
    if (_selectedIds.isEmpty) return;

    // 1. 弹出命名对话框
    final controller = TextEditingController(
      text: 'meme_export_${DateTime.now().millisecondsSinceEpoch}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).exportMemes),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: S.of(context).exportFileName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(S.of(context).export),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    // 2. 显示进度对话框
    final progressNotifier = ValueNotifier<double>(0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, progress, _) {
          return AlertDialog(
            title: Text(S.of(context).exporting),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress > 0 ? progress : null),
                const SizedBox(height: 16),
                Text('${(progress * 100).toInt()}%'),
              ],
            ),
          );
        },
      ),
    );

    try {
      final exportService = MemeExportService(
        memeRepo: ref.read(memeRepositoryProvider),
        storage: ref.read(fileStorageServiceProvider),
      );

      final zipBytes = await exportService.exportMemesAsBytes(
        memeIds: _selectedIds.toList(),
        onProgress: (current, total) {
          progressNotifier.value = current / total;
        },
      );

      if (Platform.isAndroid) {
        // Android: 通过原生方法直接用 MediaStore 写入 Downloads
        const channel = MethodChannel('com.mememaster.app/file');
        await channel.invokeMethod('saveBytesToDownloads', {
          'bytes': zipBytes,
          'displayName': '$name.zip',
          'subDir': '',
        });
      } else {
        // 其他平台直接写文件
        final dir = await getDownloadsDirectory();
        final destPath = dir != null
            ? p.join(dir.path, '$name.zip')
            : '${Directory.systemTemp.path}/$name.zip';
        await File(destPath).writeAsBytes(zipBytes);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).exportSuccess('$name.zip'))),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).exportFailed(e.toString()))),
        );
      }
    } finally {
      progressNotifier.dispose();
      _exitSelectionMode();
    }
  }

  Future<void> _importMemePack() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.isEmpty) return;

    final zipPath = result.files.first.path;
    if (zipPath == null) return;

    // 显示导入进度
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).importing),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('请稍候...'),
          ],
        ),
      ),
    );

    try {
      final importService = MemeImportService(
        memeRepo: ref.read(memeRepositoryProvider),
        storage: ref.read(fileStorageServiceProvider),
      );

      final importResult = await importService.importFromZip(zipPath: zipPath);

      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
        ref.invalidate(memeListProvider);
        ref.invalidate(memeCountProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            S.of(context).importMemePackResult(
              importResult.success,
              importResult.skipped,
              importResult.errors.length,
            ),
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).importMemePackFailed(e.toString()))),
        );
      }
    }
  }
}

class _MemeGridTile extends ConsumerWidget {
  final Meme meme;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MemeGridTile({
    required this.meme,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  Future<void> _copyMeme(WidgetRef ref) async {
    final storage = ref.read(fileStorageServiceProvider);
    final memeRepo = ref.read(memeRepositoryProvider);
    final userStatsDao = ref.read(userStatsDaoProvider);
    final file = await storage.getImage(meme.filePath);
    await ClipboardService.copyImageToClipboard(file.path);
    // 复制次数 +1
    await memeRepo.incrementCopyCount(meme.id);
    await userStatsDao.incrementCopied();
    if (ref.context.mounted) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        SnackBar(content: Text(S.of(ref.context).copiedToClipboard)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(fileStorageServiceProvider);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: FutureBuilder<ImageProvider>(
              future: _loadImage(storage),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image(
                    image: snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image),
                  );
                }
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              },
            ),
          ),
          // 分析状态角标（左下）
          Positioned(
            left: 4,
            bottom: 4,
            child: _AnalysisStatusBadge(status: meme.analysisStatus),
          ),
          // 右上角复制按钮（始终显示）
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _copyMeme(ref),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy, size: 16, color: Colors.white70),
                ),
              ),
            ),
          ),
          if (selectionMode)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Colors.white70,
                  size: 22,
                ),
              ),
            ),
          if (selectionMode && selected)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.7),
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Text(
                  meme.filename,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<ImageProvider> _loadImage(FileStorageService storage) async {
    final file = await storage.getImage(meme.filePath);
    return FileImage(file);
  }
}

/// 图片右下角的分析状态标记
class _AnalysisStatusBadge extends StatelessWidget {
  final String? status;
  const _AnalysisStatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null || status == 'done') return const SizedBox.shrink();

    IconData icon;
    Color color;
    switch (status) {
      case 'pending':
        icon = Icons.schedule;
        color = Colors.white70;
      case 'processing':
        icon = Icons.sync;
        color = Colors.lightBlueAccent;
      case 'failed':
        icon = Icons.warning_amber;
        color = Colors.orangeAccent;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 14,
        height: 14,
        child: status == 'processing'
            ? CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              )
            : Icon(icon, size: 14, color: color),
      ),
    );
  }
}

/// 速度旋盘动作定义
class _SpeedDialAction {
  final IconData icon;
  final String label;
  const _SpeedDialAction(this.icon, this.label);
}

/// MUI Speed Dial 风格的动作项：左侧标签 + 右侧小圆按钮
class _SpeedDialItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool visible;
  final int index;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.icon,
    required this.label,
    required this.visible,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: visible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 250),
      curve: Interval(
        (index * 0.12).clamp(0.0, 0.7),
        (0.25 + index * 0.12).clamp(0.25, 1.0),
        curve: Curves.easeOut,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 文字标签（MUI 风格 tooltip，在左侧）
          if (visible)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                      )),
            ),
          // 小圆按钮（mini FAB）
          FloatingActionButton.small(
            heroTag: 'speed_dial_$index',
            onPressed: visible ? onTap : null,
            child: Icon(icon, color: colorScheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
