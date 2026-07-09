// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MemeMaster';

  @override
  String get tabGallery => 'Gallery';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabSettings => 'Settings';

  @override
  String get downloadingClipboardImage => 'Downloading clipboard image...';

  @override
  String get clipboardImageDownloadFailed =>
      'Failed to download clipboard image';

  @override
  String get clipboardImageAlreadyImported =>
      'Clipboard image already imported';

  @override
  String get scanMeme => 'Scan Memes';

  @override
  String get selectDirectoryToScan => 'Select directory to scan';

  @override
  String get scanningDirectory => 'Scanning directory...';

  @override
  String scanningProgress(int completed, int total) {
    return 'Scanning $completed/$total';
  }

  @override
  String get hasText => 'Has text';

  @override
  String get noText => 'No text';

  @override
  String detectedMemes(int count) {
    return 'Detected $count Memes';
  }

  @override
  String matchScore(int score) {
    return 'Match $score%';
  }

  @override
  String charCount(int count) {
    return '$count chars';
  }

  @override
  String get remove => 'Remove';

  @override
  String get importing => 'Importing...';

  @override
  String importCountMeme(int count) {
    return 'Import $count Memes';
  }

  @override
  String get noMemeDetected => 'No memes detected';

  @override
  String get selectScanDirectory => 'Select Scan Directory';

  @override
  String get directoryDownloads => 'Downloads';

  @override
  String get directoryPictures => 'Pictures';

  @override
  String get directoryCamera => 'Camera';

  @override
  String get directoryWechat => 'WeChat Downloads';

  @override
  String get directoryStorage => 'All Storage';

  @override
  String get selectDirectoryEllipsis => 'Select directory…';

  @override
  String selectDirectoryFailed(String error) {
    return 'Failed to select directory: $error';
  }

  @override
  String get noImagesInDirectory => 'No image files found in this directory';

  @override
  String importSuccessWithSkip(int success, String skip) {
    return 'Successfully imported $success Meme(s)$skip';
  }

  @override
  String skippedCount(int count) {
    return ', skipped $count';
  }

  @override
  String get modelManager => 'Model Manager';

  @override
  String get recommendedModels => 'Recommended Models';

  @override
  String get noRecommendedModels => 'No recommended models for this source';

  @override
  String get downloadedModels => 'Downloaded Models';

  @override
  String get noDownloadedModels => 'No downloaded models yet';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get loadModel => 'Load';

  @override
  String get deleteModel => 'Delete';

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get download => 'Download';

  @override
  String modelDownloadComplete(String name) {
    return '$name download complete';
  }

  @override
  String downloadFailedWithError(String error) {
    return 'Download failed: $error';
  }

  @override
  String get modelLoadedSwitchToLocal =>
      'Model loaded, switch to local mode to use';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String confirmDeleteModel(String name) {
    return 'Are you sure you want to delete $name?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get modelLoaded => 'Model loaded';

  @override
  String modelDeleted(String id) {
    return '$id deleted';
  }

  @override
  String get aiTagsAndDescription => 'AI Tags & Description';

  @override
  String get analysisMode => 'Analysis Mode';

  @override
  String get modeOff => 'Off';

  @override
  String get modeRemoteApi => 'Remote API';

  @override
  String get modeLocalModel => 'Local Model';

  @override
  String get modeOffDescription =>
      'AI tagging is off. Images won\'t be analyzed.';

  @override
  String get modeRemoteDescription =>
      'Analyze images via remote API. Requires internet and API credits.';

  @override
  String get modeLocalDescription =>
      'Run models locally on device. No internet needed, but requires model download.';

  @override
  String get remoteApiConfig => 'Remote API Configuration';

  @override
  String get analysisParams => 'Analysis Parameters';

  @override
  String get imageCompression => 'Image Compression';

  @override
  String get imageCompressionHint =>
      'Resize/compress images before analysis to reduce token usage. Disable for better quality but slower processing';

  @override
  String get provider => 'Provider';

  @override
  String get openaiCompatible => 'OpenAI Compatible';

  @override
  String get model => 'Model';

  @override
  String get multimodalModelHint =>
      'Requires a multimodal vision model, e.g. GPT-4o, GPT-4o-mini, Qwen2-VL, etc.';

  @override
  String get localModel => 'Local Model';

  @override
  String get localModelConfig => 'Local Model Config';

  @override
  String get loaded => 'Loaded';

  @override
  String get manage => 'Manage';

  @override
  String get gpuAcceleration => 'GPU Acceleration';

  @override
  String get contextLength => 'Context Length';

  @override
  String get noDownloadedModelsHint => 'No downloaded models yet';

  @override
  String get downloadOrSelectLocal =>
      'Download recommended models or select a local GGUF file';

  @override
  String get downloadRecommended => 'Download Recommended';

  @override
  String get selectLocalFile => 'Select Local File';

  @override
  String get ggufModelFile => 'GGUF Model File';

  @override
  String get loadMultimodalProjection => 'Load Multimodal Projection?';

  @override
  String get multimodalProjectionHint =>
      'If your model supports image input (multimodal), it\'s recommended to also select the mmproj file.\n\nClick \"Skip\" if not needed.';

  @override
  String get skip => 'Skip';

  @override
  String get selectProjectionFile => 'Select Projection File';

  @override
  String get ggufProjectionFile => 'GGUF Projection File';

  @override
  String get modelFileLoaded => 'Model file loaded';

  @override
  String get invalidGgufFile => 'Please select a .gguf model file';

  @override
  String invalidGgufFileDetail(String filename) {
    return 'The selected file \"$filename\" is not in GGUF format and cannot be used for local inference.';
  }

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get analysis => 'Analysis';

  @override
  String get ocrTextRecognition => 'OCR Text Recognition';

  @override
  String get ocrDescription =>
      'Automatically extract text from images as tags on import';

  @override
  String get aiTagsDescription => 'AI Tags & Description';

  @override
  String get aiConfig => 'AI Config';

  @override
  String get llmOff => 'Off';

  @override
  String llmRemote(String model) {
    return 'Remote ($model)';
  }

  @override
  String get llmLocal => 'Local Model';

  @override
  String get sync => 'Sync';

  @override
  String get storage => 'Storage';

  @override
  String get storageSpace => 'Storage Space';

  @override
  String get imageCount => 'Image Count';

  @override
  String get debug => 'Debug';

  @override
  String get runLogs => 'Run Logs';

  @override
  String logCount(int count) {
    return '$count entries';
  }

  @override
  String get about => 'About';

  @override
  String get s3CloudSync => 'S3 Cloud Sync';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get colorExtraction => 'Color Extraction';

  @override
  String get methodKmeans => 'K-means Clustering';

  @override
  String get maxDominantColors => 'Max Dominant Colors';

  @override
  String colorCount(int n) {
    return '$n colors';
  }

  @override
  String get minRatio => 'Min Ratio';

  @override
  String get colorMergeThreshold => 'Color Merge Threshold';

  @override
  String get initialClusterK => 'Initial Clusters (K)';

  @override
  String get pixelSampleRate => 'Pixel Sample Rate';

  @override
  String get maxIterations => 'Max Iterations';

  @override
  String get lightThemeSubtitle => 'Always use light theme';

  @override
  String get darkThemeSubtitle => 'Always use dark theme';

  @override
  String get systemThemeSubtitle => 'Follow system setting';

  @override
  String get s3Sync => 'S3 Cloud Sync';

  @override
  String get s3StorageStatsFailed =>
      'Failed to get S3 storage stats, check configuration';

  @override
  String get setClearPassword => 'Set Clear Password';

  @override
  String get clearPasswordHint =>
      'Clearing S3 data requires password confirmation. Please set a password.';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get setPassword => 'Set';

  @override
  String get clearS3Data => 'Clear S3 Data';

  @override
  String get clearS3Warning =>
      'This will delete all files in the S3 bucket and cannot be undone!';

  @override
  String get enterPasswordToConfirm => 'Enter password to confirm';

  @override
  String get confirmClear => 'Confirm Clear';

  @override
  String get s3DataCleared => 'S3 data cleared';

  @override
  String clearFailed(String error) {
    return 'Clear failed: $error';
  }

  @override
  String get config => 'Configuration';

  @override
  String get s3Connection => 'S3 Connection';

  @override
  String get connectionTest => 'Connection Test';

  @override
  String get connectionOk => 'Connection OK';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get test => 'Test';

  @override
  String get syncOperations => 'Sync Operations';

  @override
  String get fullUpload => 'Full Upload';

  @override
  String get fullDownload => 'Full Download';

  @override
  String get incrementalSync => 'Incremental Sync';

  @override
  String get uploading => 'Uploading';

  @override
  String get downloading => 'Downloading';

  @override
  String get error => 'Error';

  @override
  String get scheduledSync => 'Scheduled Sync';

  @override
  String get autoSync => 'Auto Sync';

  @override
  String syncIntervalSummary(String interval) {
    return 'Sync every $interval';
  }

  @override
  String get manualSyncOnly => 'Manual sync only';

  @override
  String get syncInterval => 'Sync Interval';

  @override
  String get fiveMinutes => '5 minutes';

  @override
  String get fifteenMinutes => '15 minutes';

  @override
  String get thirtyMinutes => '30 minutes';

  @override
  String get oneHour => '1 hour';

  @override
  String get sixHours => '6 hours';

  @override
  String get oneDay => '1 day';

  @override
  String get storageStatistics => 'Storage Statistics';

  @override
  String get s3Storage => 'S3 Storage';

  @override
  String storageStatsDetail(String size, int count) {
    return '$size · $count files';
  }

  @override
  String get calculating => 'Calculating...';

  @override
  String get clickToRefresh => 'Click the button to refresh';

  @override
  String get refresh => 'Refresh';

  @override
  String get localStorage => 'Local Storage';

  @override
  String get lastSync => 'Last Sync';

  @override
  String get neverSynced => 'Never synced';

  @override
  String get clearS3DataShort => 'Clear S3 Data';

  @override
  String get deleteAllBucketFiles => 'Delete all files in bucket';

  @override
  String intervalMinutes(int count) {
    return '$count min';
  }

  @override
  String intervalHours(int count) {
    return '$count hr';
  }

  @override
  String intervalDays(int count) {
    return '$count day(s)';
  }

  @override
  String get s3Config => 'S3 Configuration';

  @override
  String get save => 'Save';

  @override
  String get logViewer => 'Run Logs';

  @override
  String get logCopied => 'Logs copied to clipboard';

  @override
  String get logExported => 'Log exported';

  @override
  String get noLogs => 'No logs';

  @override
  String get logSearchHint => 'Search logs (matches message / tag / level)';

  @override
  String get logNoMatch => 'No matching logs';

  @override
  String logFilteredCount(Object count, Object total) {
    return '$count/$total';
  }

  @override
  String get importComplete => 'Import Complete';

  @override
  String get importImages => 'Import Images';

  @override
  String importCountImages(int count) {
    return 'Import $count images';
  }

  @override
  String importSuccessCount(int count, String skip) {
    return 'Success $count$skip';
  }

  @override
  String skippedExisting(int count) {
    return ', skipped (existing) $count';
  }

  @override
  String get done => 'Done';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get cannotLoadImage => 'Cannot load image';

  @override
  String get importFromAlbum => 'Select from Album';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clear => 'Clear';

  @override
  String get importDone => 'Import Done';

  @override
  String importResultSummary(int success, int skipped) {
    return 'Success: $success  Skipped: $skipped';
  }

  @override
  String get errorLabel => 'Error:';

  @override
  String selectFileFailed(String error) {
    return 'Failed to select file: $error';
  }

  @override
  String importSuccessCountImages(int count) {
    return 'Successfully imported $count images';
  }

  @override
  String get addedToAnalysisQueue => 'Added to analysis queue';

  @override
  String reanalysisFailed(String error) {
    return 'Re-analysis failed: $error';
  }

  @override
  String get confirmDeleteTitle => 'Confirm Delete';

  @override
  String confirmDeleteMeme(String filename) {
    return 'Are you sure you want to delete \"$filename\"?\nImage file and all analysis data will be removed.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get loading => 'Loading...';

  @override
  String get loadFailed => 'Load Failed';

  @override
  String get notFound => 'Not Found';

  @override
  String get memeNotExist => 'Meme does not exist';

  @override
  String get reAnalyze => 'Re-analyze';

  @override
  String get fileName => 'Filename';

  @override
  String get dimensions => 'Dimensions';

  @override
  String get fileSize => 'Size';

  @override
  String get colorExtractionDone => 'Color extraction done';

  @override
  String get colorExtracting => 'Extracting colors...';

  @override
  String get colorExtractionFailed => 'Color extraction failed';

  @override
  String get pendingColorExtraction => 'Pending color extraction';

  @override
  String get ocrEnabled => 'OCR Enabled';

  @override
  String get ocrDisabled => 'OCR Disabled';

  @override
  String get aiEnabled => 'AI Enabled';

  @override
  String get aiDisabled => 'AI Disabled';

  @override
  String get dominantColors => 'Dominant Colors';

  @override
  String get noDominantColors => 'No dominant colors extracted';

  @override
  String get extractingDominantColors => 'Extracting dominant colors...';

  @override
  String get deleteTag => 'Delete Tag';

  @override
  String confirmDeleteTag(String content) {
    return 'Are you sure you want to delete tag \"$content\"?';
  }

  @override
  String get customTags => 'Custom Tags';

  @override
  String tagCount(int count) {
    return '$count tags';
  }

  @override
  String get noCustomTags => 'No custom tags';

  @override
  String get inputTag => 'Enter tag';

  @override
  String get add => 'Add';

  @override
  String get ocrRecognition => 'OCR Recognition';

  @override
  String ocrWordCount(int count) {
    return '$count words';
  }

  @override
  String get noOcrText => 'No text recognized';

  @override
  String get receiveShare => 'Receive Shared';

  @override
  String importingProgress(int processed, int total) {
    return 'Importing $processed/$total images...';
  }

  @override
  String get deduplicating => 'SHA256 deduplicating';

  @override
  String get importCompleteTitle => 'Import Complete';

  @override
  String importSuccess(int count) {
    return 'Success: $count';
  }

  @override
  String importSkipped(int count) {
    return 'Skipped (existing): $count';
  }

  @override
  String importErrors(int count) {
    return 'Errors: $count';
  }

  @override
  String get viewGallery => 'View Gallery';

  @override
  String searchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get search => 'Search';

  @override
  String get reset => 'Reset';

  @override
  String get searchHint => 'Search images (semantic/keyword)...';

  @override
  String get filterByColor => 'Filter by Color';

  @override
  String get clearFilter => 'Clear';

  @override
  String get startSearchHint => 'Enter keywords or select colors to search';

  @override
  String get noImageData => 'No image data yet, import images first';

  @override
  String get combinedSearchHint =>
      'Supports text search + color filter combined';

  @override
  String get noMatchingImages => 'No matching images found';

  @override
  String get tryOtherKeywords => 'Try different keywords or colors';

  @override
  String foundResults(int count) {
    return 'Found $count results';
  }

  @override
  String get searchLevelFull => 'L3 Full';

  @override
  String get searchLevelColorKeyword => 'L2 Keyword+Color';

  @override
  String get searchLevelColorOnly => 'L1 Color Only';

  @override
  String get searchLevelBrowse => 'L0 Browse';

  @override
  String get customColor => 'Custom Color';

  @override
  String get confirm => 'OK';

  @override
  String get colorRed => 'Red';

  @override
  String get colorDeepOrange => 'Deep Orange';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorLime => 'Lime';

  @override
  String get colorLightGreen => 'Light Green';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorLightBlue => 'Light Blue';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorIndigo => 'Indigo';

  @override
  String get colorDeepPurple => 'Deep Purple';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorGrey => 'Grey';

  @override
  String get colorBlueGrey => 'Blue Grey';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorWhite => 'White';

  @override
  String confirmDeleteSelected(int count) {
    return 'Are you sure you want to delete $count selected images?\nImage files and all analysis data will be removed.';
  }

  @override
  String deletedCountImages(int count) {
    return 'Deleted $count images';
  }

  @override
  String get noAlbumsCreateFirst => 'No albums yet, create one first';

  @override
  String get selectAlbum => 'Select Album';

  @override
  String addedToAlbum(int count, String albumName) {
    return 'Added $count images to \"$albumName\"';
  }

  @override
  String get newAlbum => 'New Album';

  @override
  String get albumName => 'Album Name';

  @override
  String get create => 'Create';

  @override
  String get releaseToImport => 'Release to import images';

  @override
  String get allImages => 'All Images';

  @override
  String selectedItems(int count) {
    return '$count selected';
  }

  @override
  String get copy => 'Copy';

  @override
  String get addToAlbum => 'Add to Album';

  @override
  String analyzingProgress(String running, int total) {
    return 'Analyzing$running $total remaining…';
  }

  @override
  String analyzingRunning(int count) {
    return ' ($count in progress)';
  }

  @override
  String loadFailedWithError(String error) {
    return 'Load failed: $error';
  }

  @override
  String get noMemesYet => 'No memes yet';

  @override
  String get tapToImport => 'Tap the button below to import images';

  @override
  String get scanFolder => 'Scan Folder';

  @override
  String get importImage => 'Import Image';

  @override
  String get importFromClipboard => 'Import from Clipboard';

  @override
  String get newAlbumShort => 'New Album';

  @override
  String get noImageFilesFound => 'No image files found';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get cannotReadClipboardUri => 'Cannot read clipboard URI';

  @override
  String get downloadingFromClipboardUrl => 'Downloading from clipboard URL...';

  @override
  String get downloadFromUrlFailed => 'Failed to download from URL';

  @override
  String get downloadClipboardImageFailed =>
      'Failed to download clipboard image';

  @override
  String get clipboardNotValidPath =>
      'Clipboard content is not a valid file path';

  @override
  String get clipboardNotImage => 'Clipboard file is not an image format';

  @override
  String get importResultTitle => 'Import Result';

  @override
  String get existingFiles => 'Existing files:';

  @override
  String get ok => 'OK';

  @override
  String get exportMemes => 'Export Memes';

  @override
  String get export => 'Export';

  @override
  String get exportFileName => 'File name';

  @override
  String get exporting => 'Exporting...';

  @override
  String exportSuccess(String path) {
    return 'Export successful: $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get importMemePack => 'Import Meme Pack';

  @override
  String importMemePackResult(int success, int skipped, int errors) {
    return 'Import complete: $success success, $skipped skipped, $errors failed';
  }

  @override
  String importMemePackFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get aiChatTest => 'AI Chat';

  @override
  String get aiChatWelcome => 'Start chatting with AI';

  @override
  String get aiChatHint => 'Send a message to test AI response';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get shareMeme => 'Share meme';

  @override
  String get s3NotConfigured => 'S3 not configured';

  @override
  String get cancelled => 'Cancelled';

  @override
  String imageUploadFailed(String filename, String error) {
    return 'Image upload failed: $filename: $error';
  }

  @override
  String syncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get passwordIncorrect => 'Incorrect password';

  @override
  String get noBackupOnS3 => 'No backup data found on S3';

  @override
  String get pleaseFullDownloadFirst => 'Please perform a full download first';

  @override
  String incrementalSyncFailed(String error) {
    return 'Incremental sync failed: $error';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get aiRecognition => 'AI Recognition';

  @override
  String get noAiTags => 'No AI tags';

  @override
  String llmTagCount(int count) {
    return '$count';
  }

  @override
  String get descriptionLabel => 'Description';

  @override
  String get mmprojHint =>
      'If your model supports image input (multimodal), it\'s recommended to also select the mmproj projection file.\n\nSkip if not needed';

  @override
  String get uriReadFailed => 'Cannot read URI';

  @override
  String get userStatsTitle => 'User Statistics';

  @override
  String get todayStats => 'Today';

  @override
  String get recent7DayTrend => '7-Day Trend';

  @override
  String get totalSummary => 'All Time';

  @override
  String get imported => 'Imported';

  @override
  String get copied => 'Copied';

  @override
  String get favorited => 'Favorited';

  @override
  String get total => 'Total';

  @override
  String get filter => 'Filter';

  @override
  String get tokenUsage => 'Token Usage';

  @override
  String get promptTokens => 'Prompt Tokens';

  @override
  String get completionTokens => 'Completion Tokens';

  @override
  String get totalTokens => 'Total Tokens';

  @override
  String get day => 'day(s)';

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get last30Days => 'Last 30 Days';

  @override
  String get last365Days => 'Last 365 Days';

  @override
  String get heatmap => 'Heatmap';

  @override
  String get statsDateRange => 'Date Range';

  @override
  String get exportConfig => 'Export Config';

  @override
  String get importConfig => 'Import Config';

  @override
  String get configExported => 'Config exported';

  @override
  String get configImportSuccess => 'Config imported successfully';

  @override
  String configImportFailed(String error) {
    return 'Config import failed: $error';
  }

  @override
  String get reindexMemes => 'Re-index all memes';

  @override
  String get reindexDescription => 'Check and enqueue missing analysis data';

  @override
  String get reindexStarted => 'Reindex started, progress shown in gallery';
}
