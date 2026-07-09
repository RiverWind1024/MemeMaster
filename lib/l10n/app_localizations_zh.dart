// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MemeManager';

  @override
  String get tabGallery => '图库';

  @override
  String get tabSearch => '搜索';

  @override
  String get tabSettings => '设置';

  @override
  String get downloadingClipboardImage => '正在下载剪贴板中的图片...';

  @override
  String get clipboardImageDownloadFailed => '剪贴板图片下载失败';

  @override
  String get clipboardImageAlreadyImported => '剪贴板图片已导入过';

  @override
  String get scanMeme => '扫描 Meme';

  @override
  String get selectDirectoryToScan => '选择要扫描的目录';

  @override
  String get scanningDirectory => '正在扫描目录...';

  @override
  String scanningProgress(int completed, int total) {
    return '扫描中 $completed/$total';
  }

  @override
  String get hasText => '有文字';

  @override
  String get noText => '无文字';

  @override
  String detectedMemes(int count) {
    return '检测到 $count 张 Meme';
  }

  @override
  String matchScore(int score) {
    return '匹配度 $score%';
  }

  @override
  String charCount(int count) {
    return '$count字';
  }

  @override
  String get remove => '移除';

  @override
  String get importing => '导入中...';

  @override
  String importCountMeme(int count) {
    return '导入 $count 张 Meme';
  }

  @override
  String get noMemeDetected => '未检测到 Meme';

  @override
  String get selectScanDirectory => '选择扫描目录';

  @override
  String get directoryDownloads => '下载';

  @override
  String get directoryPictures => '图片';

  @override
  String get directoryCamera => '相机';

  @override
  String get directoryWechat => '微信下载';

  @override
  String get directoryStorage => '全部存储';

  @override
  String get selectDirectoryEllipsis => '选择目录…';

  @override
  String selectDirectoryFailed(String error) {
    return '选择目录失败: $error';
  }

  @override
  String get noImagesInDirectory => '该目录未找到图片文件';

  @override
  String importSuccessWithSkip(int success, String skip) {
    return '成功导入 $success 张 Meme$skip';
  }

  @override
  String skippedCount(int count) {
    return '，跳过 $count 张';
  }

  @override
  String get modelManager => '模型管理';

  @override
  String get recommendedModels => '推荐模型';

  @override
  String get noRecommendedModels => '该源暂无推荐模型';

  @override
  String get downloadedModels => '已下载模型';

  @override
  String get noDownloadedModels => '暂无已下载的模型';

  @override
  String get downloaded => '已下载';

  @override
  String get loadModel => '加载';

  @override
  String get deleteModel => '删除';

  @override
  String downloadFailed(String error) {
    return '下载失败: $error';
  }

  @override
  String get download => '下载';

  @override
  String modelDownloadComplete(String name) {
    return '$name 下载完成';
  }

  @override
  String downloadFailedWithError(String error) {
    return '下载失败: $error';
  }

  @override
  String get modelLoadedSwitchToLocal => '模型已加载，请切换至本地模式使用';

  @override
  String get confirmDelete => '确认删除';

  @override
  String confirmDeleteModel(String name) {
    return '确定要删除 $name 吗？';
  }

  @override
  String get cancel => '取消';

  @override
  String get modelLoaded => '模型已加载';

  @override
  String modelDeleted(String id) {
    return '$id 已删除';
  }

  @override
  String get aiTagsAndDescription => 'AI 标签与描述';

  @override
  String get analysisMode => '分析模式';

  @override
  String get modeOff => '关闭';

  @override
  String get modeRemoteApi => '远程 API';

  @override
  String get modeLocalModel => '本地模型';

  @override
  String get modeOffDescription => 'AI 标签功能已关闭，不会分析图片内容。';

  @override
  String get modeRemoteDescription => '通过远程 API 分析图片，需联网且消耗 API 额度。';

  @override
  String get modeLocalDescription => '在设备端本地运行模型，无需联网，需下载模型文件。';

  @override
  String get remoteApiConfig => '远程 API 配置';

  @override
  String get analysisParams => '分析参数';

  @override
  String get imageCompression => '图片压缩';

  @override
  String get imageCompressionHint => '分析前将图片缩小/压缩，减少 token 消耗。关闭可提升分析质量但增加处理时间';

  @override
  String get provider => '供应商';

  @override
  String get openaiCompatible => 'OpenAI 兼容';

  @override
  String get model => '模型';

  @override
  String get multimodalModelHint =>
      '需要支持多模态视觉的模型，如 GPT-4o、GPT-4o-mini、Qwen2-VL 等。';

  @override
  String get localModel => '本地模型';

  @override
  String get localModelConfig => '本地模型详细配置';

  @override
  String get loaded => '已加载';

  @override
  String get manage => '管理';

  @override
  String get gpuAcceleration => 'GPU 加速';

  @override
  String get contextLength => '上下文长度';

  @override
  String get noDownloadedModelsHint => '暂无已下载的模型';

  @override
  String get downloadOrSelectLocal => '可以从网络下载推荐模型，或手动选择本地 GGUF 文件';

  @override
  String get downloadRecommended => '下载推荐模型';

  @override
  String get selectLocalFile => '选择本地文件';

  @override
  String get ggufModelFile => 'GGUF 模型文件';

  @override
  String get loadMultimodalProjection => '加载多模态投影？';

  @override
  String get multimodalProjectionHint =>
      '如果你的模型支持图片输入（多模态），建议同时选择 mmproj 投影文件。\n\n不需要请点「跳过」';

  @override
  String get skip => '跳过';

  @override
  String get selectProjectionFile => '选择投影文件';

  @override
  String get ggufProjectionFile => 'GGUF 投影文件';

  @override
  String get modelFileLoaded => '模型文件已加载';

  @override
  String get invalidGgufFile => '请选择 .gguf 格式的模型文件';

  @override
  String invalidGgufFileDetail(String filename) {
    return '所选文件「$filename」不是 GGUF 格式，无法用于本地推理。';
  }

  @override
  String get settings => '设置';

  @override
  String get appearance => '外观';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get analysis => '分析';

  @override
  String get ocrTextRecognition => 'OCR 文字识别';

  @override
  String get ocrDescription => '导入图片时自动提取图片中的文字作为标签';

  @override
  String get aiTagsDescription => 'AI 标签与描述';

  @override
  String get aiConfig => 'AI 配置';

  @override
  String get llmOff => '已关闭';

  @override
  String llmRemote(String model) {
    return '远程 ($model)';
  }

  @override
  String get llmLocal => '本地模型';

  @override
  String get sync => '同步';

  @override
  String get storage => '存储';

  @override
  String get storageSpace => '存储空间';

  @override
  String get imageCount => '图片数量';

  @override
  String get debug => '调试';

  @override
  String get runLogs => '运行日志';

  @override
  String logCount(int count) {
    return '共 $count 条';
  }

  @override
  String get about => '关于';

  @override
  String get s3CloudSync => 'S3 云同步';

  @override
  String get notConfigured => '未配置';

  @override
  String get colorExtraction => '颜色提取';

  @override
  String get methodKmeans => 'K-means 聚类';

  @override
  String get maxDominantColors => '最大主色调数';

  @override
  String colorCount(int n) {
    return '$n 色';
  }

  @override
  String get minRatio => '最小占比';

  @override
  String get colorMergeThreshold => '颜色合并阈值';

  @override
  String get initialClusterK => '初始聚类数 (K)';

  @override
  String get pixelSampleRate => '像素采样率';

  @override
  String get maxIterations => '最大迭代次数';

  @override
  String get lightThemeSubtitle => '始终使用浅色主题';

  @override
  String get darkThemeSubtitle => '始终使用深色主题';

  @override
  String get systemThemeSubtitle => '跟随系统设置自动切换';

  @override
  String get s3Sync => 'S3 云同步';

  @override
  String get s3StorageStatsFailed => '获取 S3 存储统计失败，请检查配置';

  @override
  String get setClearPassword => '设置清空密码';

  @override
  String get clearPasswordHint => '清空 S3 数据需要密码确认，请设置一个密码。';

  @override
  String get password => '密码';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get setPassword => '设置';

  @override
  String get clearS3Data => '清空 S3 数据';

  @override
  String get clearS3Warning => '此操作将删除 S3 bucket 中的所有文件，且不可恢复！';

  @override
  String get enterPasswordToConfirm => '输入密码确认';

  @override
  String get confirmClear => '确认清空';

  @override
  String get s3DataCleared => 'S3 数据已清空';

  @override
  String clearFailed(String error) {
    return '清空失败: $error';
  }

  @override
  String get config => '配置';

  @override
  String get s3Connection => 'S3 连接';

  @override
  String get connectionTest => '连接测试';

  @override
  String get connectionOk => '连接正常';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get test => '测试';

  @override
  String get syncOperations => '同步操作';

  @override
  String get fullUpload => '全量上传';

  @override
  String get fullDownload => '全量下载';

  @override
  String get incrementalSync => '增量同步';

  @override
  String get uploading => '上传中';

  @override
  String get downloading => '下载中';

  @override
  String get error => '错误';

  @override
  String get scheduledSync => '定时同步';

  @override
  String get autoSync => '定时自动同步';

  @override
  String syncIntervalSummary(String interval) {
    return '每 $interval 同步一次';
  }

  @override
  String get manualSyncOnly => '仅手动同步';

  @override
  String get syncInterval => '同步间隔';

  @override
  String get fiveMinutes => '5 分钟';

  @override
  String get fifteenMinutes => '15 分钟';

  @override
  String get thirtyMinutes => '30 分钟';

  @override
  String get oneHour => '1 小时';

  @override
  String get sixHours => '6 小时';

  @override
  String get oneDay => '1 天';

  @override
  String get storageStatistics => '存储统计';

  @override
  String get s3Storage => 'S3 存储';

  @override
  String storageStatsDetail(String size, int count) {
    return '$size · $count 个文件';
  }

  @override
  String get calculating => '统计中...';

  @override
  String get clickToRefresh => '点击右侧按钮刷新';

  @override
  String get refresh => '刷新';

  @override
  String get localStorage => '本地存储';

  @override
  String get lastSync => '上次同步';

  @override
  String get neverSynced => '从未同步';

  @override
  String get clearS3DataShort => '清空 S3 数据';

  @override
  String get deleteAllBucketFiles => '删除 bucket 中所有文件';

  @override
  String intervalMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String intervalHours(int count) {
    return '$count 小时';
  }

  @override
  String intervalDays(int count) {
    return '$count 天';
  }

  @override
  String get s3Config => 'S3 配置';

  @override
  String get save => '保存';

  @override
  String get logViewer => '运行日志';

  @override
  String get logCopied => '日志已复制到剪贴板';

  @override
  String get logExported => '日志已导出';

  @override
  String get noLogs => '暂无日志';

  @override
  String get logSearchHint => '搜索日志 (支持 message / tag / level)';

  @override
  String get logNoMatch => '无匹配日志';

  @override
  String logFilteredCount(Object count, Object total) {
    return '$count/$total 条';
  }

  @override
  String get importComplete => '导入完成';

  @override
  String get importImages => '导入图片';

  @override
  String importCountImages(int count) {
    return '导入 $count 张图片';
  }

  @override
  String importSuccessCount(int count, String skip) {
    return '成功 $count 张$skip';
  }

  @override
  String skippedExisting(int count) {
    return '，跳过（已存在）$count 张';
  }

  @override
  String get done => '完成';

  @override
  String importFailed(String error) {
    return '导入失败: $error';
  }

  @override
  String get cannotLoadImage => '无法加载图片';

  @override
  String get importFromAlbum => '从相册选择';

  @override
  String selectedCount(int count) {
    return '已选 $count 张';
  }

  @override
  String get clear => '清空';

  @override
  String get importDone => '导入完成';

  @override
  String importResultSummary(int success, int skipped) {
    return '成功: $success  跳过: $skipped';
  }

  @override
  String get errorLabel => '错误:';

  @override
  String selectFileFailed(String error) {
    return '选择文件失败: $error';
  }

  @override
  String importSuccessCountImages(int count) {
    return '成功导入 $count 张图片';
  }

  @override
  String get addedToAnalysisQueue => '已加入分析队列，即将开始分析';

  @override
  String reanalysisFailed(String error) {
    return '重新分析失败: $error';
  }

  @override
  String get confirmDeleteTitle => '确认删除';

  @override
  String confirmDeleteMeme(String filename) {
    return '确定要删除「$filename」吗？\n图片文件和所有分析数据都会被移除。';
  }

  @override
  String get delete => '删除';

  @override
  String get loading => '加载中...';

  @override
  String get loadFailed => '加载失败';

  @override
  String get notFound => '未找到';

  @override
  String get memeNotExist => 'Meme 不存在';

  @override
  String get reAnalyze => '重新分析';

  @override
  String get fileName => '文件名';

  @override
  String get dimensions => '尺寸';

  @override
  String get fileSize => '大小';

  @override
  String get colorExtractionDone => '颜色提取完成';

  @override
  String get colorExtracting => '正在提取颜色...';

  @override
  String get colorExtractionFailed => '颜色提取失败';

  @override
  String get pendingColorExtraction => '待提取主色调';

  @override
  String get ocrEnabled => 'OCR 已开启';

  @override
  String get ocrDisabled => '未开启 OCR 识别';

  @override
  String get aiEnabled => 'AI 已开启';

  @override
  String get aiDisabled => '未开启 AI 识别';

  @override
  String get dominantColors => '主色调';

  @override
  String get noDominantColors => '未提取到主色调';

  @override
  String get extractingDominantColors => '正在提取主色调...';

  @override
  String get deleteTag => '删除标签';

  @override
  String confirmDeleteTag(String content) {
    return '确定删除标签「$content」吗？';
  }

  @override
  String get customTags => '自定义标签';

  @override
  String tagCount(int count) {
    return '$count 个';
  }

  @override
  String get noCustomTags => '暂无自定义标签';

  @override
  String get inputTag => '输入标签';

  @override
  String get add => '添加';

  @override
  String get ocrRecognition => 'OCR 识别';

  @override
  String ocrWordCount(int count) {
    return '$count 词';
  }

  @override
  String get noOcrText => '暂未识别到文字';

  @override
  String get receiveShare => '接收分享';

  @override
  String importingProgress(int processed, int total) {
    return '正在导入 $processed/$total 张图片...';
  }

  @override
  String get deduplicating => 'SHA256 去重中';

  @override
  String get importCompleteTitle => '导入完成';

  @override
  String importSuccess(int count) {
    return '成功: $count';
  }

  @override
  String importSkipped(int count) {
    return '跳过（已存在）: $count';
  }

  @override
  String importErrors(int count) {
    return '错误: $count';
  }

  @override
  String get viewGallery => '查看图库';

  @override
  String searchFailed(String error) {
    return '搜索失败: $error';
  }

  @override
  String get search => '搜索';

  @override
  String get reset => '重置';

  @override
  String get searchHint => '搜索图片（语义/关键词）...';

  @override
  String get filterByColor => '按颜色筛选';

  @override
  String get clearFilter => '清除';

  @override
  String get startSearchHint => '输入关键词或选择颜色开始搜索';

  @override
  String get noImageData => '暂无图片数据，请先导入图片';

  @override
  String get combinedSearchHint => '支持文字搜索 + 颜色筛选叠加使用';

  @override
  String get noMatchingImages => '没有找到匹配的图片';

  @override
  String get tryOtherKeywords => '试试其他关键词或颜色';

  @override
  String foundResults(int count) {
    return '找到 $count 个结果';
  }

  @override
  String get searchLevelFull => 'L3 全功能';

  @override
  String get searchLevelColorKeyword => 'L2 关键词+颜色';

  @override
  String get searchLevelColorOnly => 'L1 仅颜色';

  @override
  String get searchLevelBrowse => 'L0 浏览';

  @override
  String get customColor => '自定义颜色';

  @override
  String get confirm => '确定';

  @override
  String get colorRed => '红';

  @override
  String get colorDeepOrange => '深橙';

  @override
  String get colorOrange => '橙';

  @override
  String get colorAmber => '琥珀';

  @override
  String get colorYellow => '黄';

  @override
  String get colorLime => '柠绿';

  @override
  String get colorLightGreen => '浅绿';

  @override
  String get colorGreen => '绿';

  @override
  String get colorCyan => '青';

  @override
  String get colorLightBlue => '浅蓝';

  @override
  String get colorBlue => '蓝';

  @override
  String get colorIndigo => '靛蓝';

  @override
  String get colorDeepPurple => '深紫';

  @override
  String get colorPurple => '紫';

  @override
  String get colorPink => '粉';

  @override
  String get colorBrown => '棕';

  @override
  String get colorGrey => '灰';

  @override
  String get colorBlueGrey => '蓝灰';

  @override
  String get colorBlack => '黑';

  @override
  String get colorWhite => '白';

  @override
  String confirmDeleteSelected(int count) {
    return '确定要删除选中的 $count 张图片吗？\n图片文件和所有分析数据都会被移除。';
  }

  @override
  String deletedCountImages(int count) {
    return '已删除 $count 张图片';
  }

  @override
  String get noAlbumsCreateFirst => '还没有相册，请先创建';

  @override
  String get selectAlbum => '选择相册';

  @override
  String addedToAlbum(int count, String albumName) {
    return '已将 $count 张图片添加到「$albumName」';
  }

  @override
  String get newAlbum => '新建相册';

  @override
  String get albumName => '相册名称';

  @override
  String get create => '创建';

  @override
  String get releaseToImport => '松开导入图片';

  @override
  String get allImages => '全部图片';

  @override
  String selectedItems(int count) {
    return '已选择 $count 项';
  }

  @override
  String get copy => '复制';

  @override
  String get addToAlbum => '添加到相册';

  @override
  String analyzingProgress(String running, int total) {
    return '正在分析$running剩余 $total 张…';
  }

  @override
  String analyzingRunning(int count) {
    return '($count 进行中)';
  }

  @override
  String loadFailedWithError(String error) {
    return '加载失败: $error';
  }

  @override
  String get noMemesYet => '还没有任何 Meme';

  @override
  String get tapToImport => '点击右下角按钮导入图片';

  @override
  String get scanFolder => '扫描文件夹';

  @override
  String get importImage => '导入图片';

  @override
  String get importFromClipboard => '从剪贴板导入';

  @override
  String get newAlbumShort => '新建相册';

  @override
  String get noImageFilesFound => '未发现图片文件';

  @override
  String get clipboardEmpty => '剪贴板为空';

  @override
  String get cannotReadClipboardUri => '无法读取剪贴板 URI';

  @override
  String get downloadingFromClipboardUrl => '正在从剪贴板 URL 下载图片...';

  @override
  String get downloadFromUrlFailed => '从 URL 下载图片失败';

  @override
  String get downloadClipboardImageFailed => '下载剪贴板图片失败';

  @override
  String get clipboardNotValidPath => '剪贴板内容不是有效的文件路径';

  @override
  String get clipboardNotImage => '剪贴板文件不是图片格式';

  @override
  String get importResultTitle => '导入结果';

  @override
  String get existingFiles => '已存在的文件:';

  @override
  String get ok => '确定';

  @override
  String get exportMemes => '导出表情包';

  @override
  String get export => '导出';

  @override
  String get exportFileName => '文件名';

  @override
  String get exporting => '正在导出...';

  @override
  String exportSuccess(String path) {
    return '导出成功: $path';
  }

  @override
  String exportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String get importMemePack => '导入表情包';

  @override
  String importMemePackResult(int success, int skipped, int errors) {
    return '导入完成: 成功 $success, 跳过 $skipped, 失败 $errors';
  }

  @override
  String importMemePackFailed(String error) {
    return '导入失败: $error';
  }

  @override
  String get aiChatTest => 'AI 对话';

  @override
  String get aiChatWelcome => '开始与 AI 对话';

  @override
  String get aiChatHint => '发送消息测试 AI 回复';

  @override
  String get typeMessage => '输入消息...';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get shareMeme => '分享表情包';

  @override
  String get s3NotConfigured => 'S3 未配置';

  @override
  String get cancelled => '已取消';

  @override
  String imageUploadFailed(String filename, String error) {
    return '图片上传失败: $filename: $error';
  }

  @override
  String syncFailed(String error) {
    return '同步失败: $error';
  }

  @override
  String get passwordIncorrect => '密码错误';

  @override
  String get noBackupOnS3 => 'S3 上没有找到备份数据';

  @override
  String get pleaseFullDownloadFirst => '请先执行全量下载';

  @override
  String incrementalSyncFailed(String error) {
    return '增量同步失败: $error';
  }

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get aiRecognition => 'AI 识别';

  @override
  String get noAiTags => '暂无 AI 标签';

  @override
  String llmTagCount(int count) {
    return '$count 个';
  }

  @override
  String get descriptionLabel => '描述';

  @override
  String get mmprojHint => '如果你的模型支持图片输入（多模态），建议同时选择 mmproj 投影文件。\n\n不需要请点「跳过」';

  @override
  String get uriReadFailed => '无法读取 URI';

  @override
  String get userStatsTitle => '用户统计';

  @override
  String get todayStats => '今日统计';

  @override
  String get recent7DayTrend => '近 7 天趋势';

  @override
  String get totalSummary => '全部汇总';

  @override
  String get imported => '导入';

  @override
  String get copied => '复制';

  @override
  String get favorited => '收藏';

  @override
  String get total => '总计';

  @override
  String get filter => '筛选';

  @override
  String get tokenUsage => 'Token 用量';

  @override
  String get promptTokens => 'Prompt Token';

  @override
  String get completionTokens => 'Completion Token';

  @override
  String get totalTokens => '总 Token';

  @override
  String get day => '天';

  @override
  String get last7Days => '近 7 天';

  @override
  String get last30Days => '近 30 天';

  @override
  String get last365Days => '近 365 天';

  @override
  String get heatmap => '热度图';

  @override
  String get statsDateRange => '统计范围';

  @override
  String get exportConfig => '导出配置';

  @override
  String get importConfig => '导入配置';

  @override
  String get configExported => '配置已导出';

  @override
  String get configImportSuccess => '配置导入成功';

  @override
  String configImportFailed(String error) {
    return '配置导入失败: $error';
  }

  @override
  String get reindexMemes => '重新索引所有表情';

  @override
  String get reindexDescription => '检查并补充缺失的分析数据';

  @override
  String get reindexStarted => '重新索引已开始，进度显示在图库顶部';
}
