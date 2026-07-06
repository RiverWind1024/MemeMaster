import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// 应用标题
  ///
  /// In zh, this message translates to:
  /// **'MemeManager'**
  String get appTitle;

  /// No description provided for @tabGallery.
  ///
  /// In zh, this message translates to:
  /// **'图库'**
  String get tabGallery;

  /// No description provided for @tabSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get tabSearch;

  /// No description provided for @tabSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get tabSettings;

  /// No description provided for @downloadingClipboardImage.
  ///
  /// In zh, this message translates to:
  /// **'正在下载剪贴板中的图片...'**
  String get downloadingClipboardImage;

  /// No description provided for @clipboardImageDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板图片下载失败'**
  String get clipboardImageDownloadFailed;

  /// No description provided for @clipboardImageAlreadyImported.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板图片已导入过'**
  String get clipboardImageAlreadyImported;

  /// No description provided for @scanMeme.
  ///
  /// In zh, this message translates to:
  /// **'扫描 Meme'**
  String get scanMeme;

  /// No description provided for @selectDirectoryToScan.
  ///
  /// In zh, this message translates to:
  /// **'选择要扫描的目录'**
  String get selectDirectoryToScan;

  /// No description provided for @scanningProgress.
  ///
  /// In zh, this message translates to:
  /// **'扫描中 {completed}/{total}'**
  String scanningProgress(int completed, int total);

  /// No description provided for @hasText.
  ///
  /// In zh, this message translates to:
  /// **'有文字'**
  String get hasText;

  /// No description provided for @noText.
  ///
  /// In zh, this message translates to:
  /// **'无文字'**
  String get noText;

  /// No description provided for @detectedMemes.
  ///
  /// In zh, this message translates to:
  /// **'检测到 {count} 张 Meme'**
  String detectedMemes(int count);

  /// No description provided for @matchScore.
  ///
  /// In zh, this message translates to:
  /// **'匹配度 {score}%'**
  String matchScore(int score);

  /// No description provided for @charCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}字'**
  String charCount(int count);

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @importing.
  ///
  /// In zh, this message translates to:
  /// **'导入中...'**
  String get importing;

  /// No description provided for @importCountMeme.
  ///
  /// In zh, this message translates to:
  /// **'导入 {count} 张 Meme'**
  String importCountMeme(int count);

  /// No description provided for @noMemeDetected.
  ///
  /// In zh, this message translates to:
  /// **'未检测到 Meme'**
  String get noMemeDetected;

  /// No description provided for @selectScanDirectory.
  ///
  /// In zh, this message translates to:
  /// **'选择扫描目录'**
  String get selectScanDirectory;

  /// No description provided for @directoryDownloads.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get directoryDownloads;

  /// No description provided for @directoryPictures.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get directoryPictures;

  /// No description provided for @directoryCamera.
  ///
  /// In zh, this message translates to:
  /// **'相机'**
  String get directoryCamera;

  /// No description provided for @directoryWechat.
  ///
  /// In zh, this message translates to:
  /// **'微信下载'**
  String get directoryWechat;

  /// No description provided for @directoryStorage.
  ///
  /// In zh, this message translates to:
  /// **'全部存储'**
  String get directoryStorage;

  /// No description provided for @selectDirectoryEllipsis.
  ///
  /// In zh, this message translates to:
  /// **'选择目录…'**
  String get selectDirectoryEllipsis;

  /// No description provided for @selectDirectoryFailed.
  ///
  /// In zh, this message translates to:
  /// **'选择目录失败: {error}'**
  String selectDirectoryFailed(String error);

  /// No description provided for @noImagesInDirectory.
  ///
  /// In zh, this message translates to:
  /// **'该目录未找到图片文件'**
  String get noImagesInDirectory;

  /// No description provided for @importSuccessWithSkip.
  ///
  /// In zh, this message translates to:
  /// **'成功导入 {success} 张 Meme{skip}'**
  String importSuccessWithSkip(int success, String skip);

  /// No description provided for @skippedCount.
  ///
  /// In zh, this message translates to:
  /// **'，跳过 {count} 张'**
  String skippedCount(int count);

  /// No description provided for @modelManager.
  ///
  /// In zh, this message translates to:
  /// **'模型管理'**
  String get modelManager;

  /// No description provided for @recommendedModels.
  ///
  /// In zh, this message translates to:
  /// **'推荐模型'**
  String get recommendedModels;

  /// No description provided for @noRecommendedModels.
  ///
  /// In zh, this message translates to:
  /// **'该源暂无推荐模型'**
  String get noRecommendedModels;

  /// No description provided for @downloadedModels.
  ///
  /// In zh, this message translates to:
  /// **'已下载模型'**
  String get downloadedModels;

  /// No description provided for @noDownloadedModels.
  ///
  /// In zh, this message translates to:
  /// **'暂无已下载的模型'**
  String get noDownloadedModels;

  /// No description provided for @downloaded.
  ///
  /// In zh, this message translates to:
  /// **'已下载'**
  String get downloaded;

  /// No description provided for @loadModel.
  ///
  /// In zh, this message translates to:
  /// **'加载'**
  String get loadModel;

  /// No description provided for @deleteModel.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteModel;

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败: {error}'**
  String downloadFailed(String error);

  /// No description provided for @download.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// No description provided for @modelDownloadComplete.
  ///
  /// In zh, this message translates to:
  /// **'{name} 下载完成'**
  String modelDownloadComplete(String name);

  /// No description provided for @downloadFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'下载失败: {error}'**
  String downloadFailedWithError(String error);

  /// No description provided for @modelLoadedSwitchToLocal.
  ///
  /// In zh, this message translates to:
  /// **'模型已加载，请切换至本地模式使用'**
  String get modelLoadedSwitchToLocal;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteModel.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 {name} 吗？'**
  String confirmDeleteModel(String name);

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @modelLoaded.
  ///
  /// In zh, this message translates to:
  /// **'模型已加载'**
  String get modelLoaded;

  /// No description provided for @modelDeleted.
  ///
  /// In zh, this message translates to:
  /// **'{id} 已删除'**
  String modelDeleted(String id);

  /// No description provided for @aiTagsAndDescription.
  ///
  /// In zh, this message translates to:
  /// **'AI 标签与描述'**
  String get aiTagsAndDescription;

  /// No description provided for @analysisMode.
  ///
  /// In zh, this message translates to:
  /// **'分析模式'**
  String get analysisMode;

  /// No description provided for @modeOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get modeOff;

  /// No description provided for @modeRemoteApi.
  ///
  /// In zh, this message translates to:
  /// **'远程 API'**
  String get modeRemoteApi;

  /// No description provided for @modeLocalModel.
  ///
  /// In zh, this message translates to:
  /// **'本地模型'**
  String get modeLocalModel;

  /// No description provided for @modeOffDescription.
  ///
  /// In zh, this message translates to:
  /// **'AI 标签功能已关闭，不会分析图片内容。'**
  String get modeOffDescription;

  /// No description provided for @modeRemoteDescription.
  ///
  /// In zh, this message translates to:
  /// **'通过远程 API 分析图片，需联网且消耗 API 额度。'**
  String get modeRemoteDescription;

  /// No description provided for @modeLocalDescription.
  ///
  /// In zh, this message translates to:
  /// **'在设备端本地运行模型，无需联网，需下载模型文件。'**
  String get modeLocalDescription;

  /// No description provided for @remoteApiConfig.
  ///
  /// In zh, this message translates to:
  /// **'远程 API 配置'**
  String get remoteApiConfig;

  /// No description provided for @provider.
  ///
  /// In zh, this message translates to:
  /// **'供应商'**
  String get provider;

  /// No description provided for @openaiCompatible.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容'**
  String get openaiCompatible;

  /// No description provided for @model.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get model;

  /// No description provided for @multimodalModelHint.
  ///
  /// In zh, this message translates to:
  /// **'需要支持多模态视觉的模型，如 GPT-4o、GPT-4o-mini、Qwen2-VL 等。'**
  String get multimodalModelHint;

  /// No description provided for @localModel.
  ///
  /// In zh, this message translates to:
  /// **'本地模型'**
  String get localModel;

  /// No description provided for @loaded.
  ///
  /// In zh, this message translates to:
  /// **'已加载'**
  String get loaded;

  /// No description provided for @manage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get manage;

  /// No description provided for @gpuAcceleration.
  ///
  /// In zh, this message translates to:
  /// **'GPU 加速'**
  String get gpuAcceleration;

  /// No description provided for @contextLength.
  ///
  /// In zh, this message translates to:
  /// **'上下文长度'**
  String get contextLength;

  /// No description provided for @noDownloadedModelsHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无已下载的模型'**
  String get noDownloadedModelsHint;

  /// No description provided for @downloadOrSelectLocal.
  ///
  /// In zh, this message translates to:
  /// **'可以从网络下载推荐模型，或手动选择本地 GGUF 文件'**
  String get downloadOrSelectLocal;

  /// No description provided for @downloadRecommended.
  ///
  /// In zh, this message translates to:
  /// **'下载推荐模型'**
  String get downloadRecommended;

  /// No description provided for @selectLocalFile.
  ///
  /// In zh, this message translates to:
  /// **'选择本地文件'**
  String get selectLocalFile;

  /// No description provided for @ggufModelFile.
  ///
  /// In zh, this message translates to:
  /// **'GGUF 模型文件'**
  String get ggufModelFile;

  /// No description provided for @loadMultimodalProjection.
  ///
  /// In zh, this message translates to:
  /// **'加载多模态投影？'**
  String get loadMultimodalProjection;

  /// No description provided for @multimodalProjectionHint.
  ///
  /// In zh, this message translates to:
  /// **'如果你的模型支持图片输入（多模态），建议同时选择 mmproj 投影文件。\n\n不需要请点「跳过」'**
  String get multimodalProjectionHint;

  /// No description provided for @skip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get skip;

  /// No description provided for @selectProjectionFile.
  ///
  /// In zh, this message translates to:
  /// **'选择投影文件'**
  String get selectProjectionFile;

  /// No description provided for @ggufProjectionFile.
  ///
  /// In zh, this message translates to:
  /// **'GGUF 投影文件'**
  String get ggufProjectionFile;

  /// No description provided for @modelFileLoaded.
  ///
  /// In zh, this message translates to:
  /// **'模型文件已加载'**
  String get modelFileLoaded;

  /// No description provided for @invalidGgufFile.
  ///
  /// In zh, this message translates to:
  /// **'请选择 .gguf 格式的模型文件'**
  String get invalidGgufFile;

  /// No description provided for @invalidGgufFileDetail.
  ///
  /// In zh, this message translates to:
  /// **'所选文件「{filename}」不是 GGUF 格式，无法用于本地推理。'**
  String invalidGgufFileDetail(String filename);

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @analysis.
  ///
  /// In zh, this message translates to:
  /// **'分析'**
  String get analysis;

  /// No description provided for @ocrTextRecognition.
  ///
  /// In zh, this message translates to:
  /// **'OCR 文字识别'**
  String get ocrTextRecognition;

  /// No description provided for @ocrDescription.
  ///
  /// In zh, this message translates to:
  /// **'导入图片时自动提取图片中的文字作为标签'**
  String get ocrDescription;

  /// No description provided for @aiTagsDescription.
  ///
  /// In zh, this message translates to:
  /// **'AI 标签与描述'**
  String get aiTagsDescription;

  /// No description provided for @llmOff.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get llmOff;

  /// No description provided for @llmRemote.
  ///
  /// In zh, this message translates to:
  /// **'远程 ({model})'**
  String llmRemote(String model);

  /// No description provided for @llmLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地模型'**
  String get llmLocal;

  /// No description provided for @sync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get sync;

  /// No description provided for @storage.
  ///
  /// In zh, this message translates to:
  /// **'存储'**
  String get storage;

  /// No description provided for @storageSpace.
  ///
  /// In zh, this message translates to:
  /// **'存储空间'**
  String get storageSpace;

  /// No description provided for @imageCount.
  ///
  /// In zh, this message translates to:
  /// **'图片数量'**
  String get imageCount;

  /// No description provided for @debug.
  ///
  /// In zh, this message translates to:
  /// **'调试'**
  String get debug;

  /// No description provided for @runLogs.
  ///
  /// In zh, this message translates to:
  /// **'运行日志'**
  String get runLogs;

  /// No description provided for @logCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条'**
  String logCount(int count);

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @s3CloudSync.
  ///
  /// In zh, this message translates to:
  /// **'S3 云同步'**
  String get s3CloudSync;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get notConfigured;

  /// No description provided for @colorExtraction.
  ///
  /// In zh, this message translates to:
  /// **'颜色提取'**
  String get colorExtraction;

  /// No description provided for @methodNeuralQuantizer.
  ///
  /// In zh, this message translates to:
  /// **'神经网络量化'**
  String get methodNeuralQuantizer;

  /// No description provided for @methodHistogram.
  ///
  /// In zh, this message translates to:
  /// **'直方图分桶'**
  String get methodHistogram;

  /// No description provided for @methodKmeans.
  ///
  /// In zh, this message translates to:
  /// **'K-means 聚类'**
  String get methodKmeans;

  /// No description provided for @methodMeanShift.
  ///
  /// In zh, this message translates to:
  /// **'均值漂移'**
  String get methodMeanShift;

  /// No description provided for @algorithm.
  ///
  /// In zh, this message translates to:
  /// **'算法'**
  String get algorithm;

  /// No description provided for @maxDominantColors.
  ///
  /// In zh, this message translates to:
  /// **'最大主色调数'**
  String get maxDominantColors;

  /// No description provided for @colorCount.
  ///
  /// In zh, this message translates to:
  /// **'{n} 色'**
  String colorCount(int n);

  /// No description provided for @minRatio.
  ///
  /// In zh, this message translates to:
  /// **'最小占比'**
  String get minRatio;

  /// No description provided for @colorMergeThreshold.
  ///
  /// In zh, this message translates to:
  /// **'颜色合并阈值'**
  String get colorMergeThreshold;

  /// No description provided for @initialColorCount.
  ///
  /// In zh, this message translates to:
  /// **'初始颜色数量'**
  String get initialColorCount;

  /// No description provided for @rgbBins.
  ///
  /// In zh, this message translates to:
  /// **'RGB 分桶数'**
  String get rgbBins;

  /// No description provided for @rgbBinsDetail.
  ///
  /// In zh, this message translates to:
  /// **'{bins}³ = {total} 桶'**
  String rgbBinsDetail(int bins, int total);

  /// No description provided for @initialClusterK.
  ///
  /// In zh, this message translates to:
  /// **'初始聚类数 (K)'**
  String get initialClusterK;

  /// No description provided for @pixelSampleRate.
  ///
  /// In zh, this message translates to:
  /// **'像素采样率'**
  String get pixelSampleRate;

  /// No description provided for @maxIterations.
  ///
  /// In zh, this message translates to:
  /// **'最大迭代次数'**
  String get maxIterations;

  /// No description provided for @kernelRadius.
  ///
  /// In zh, this message translates to:
  /// **'核半径'**
  String get kernelRadius;

  /// No description provided for @lightThemeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'始终使用浅色主题'**
  String get lightThemeSubtitle;

  /// No description provided for @darkThemeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'始终使用深色主题'**
  String get darkThemeSubtitle;

  /// No description provided for @systemThemeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统设置自动切换'**
  String get systemThemeSubtitle;

  /// No description provided for @s3Sync.
  ///
  /// In zh, this message translates to:
  /// **'S3 云同步'**
  String get s3Sync;

  /// No description provided for @s3StorageStatsFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取 S3 存储统计失败，请检查配置'**
  String get s3StorageStatsFailed;

  /// No description provided for @setClearPassword.
  ///
  /// In zh, this message translates to:
  /// **'设置清空密码'**
  String get setClearPassword;

  /// No description provided for @clearPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'清空 S3 数据需要密码确认，请设置一个密码。'**
  String get clearPasswordHint;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get passwordMismatch;

  /// No description provided for @setPassword.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get setPassword;

  /// No description provided for @clearS3Data.
  ///
  /// In zh, this message translates to:
  /// **'清空 S3 数据'**
  String get clearS3Data;

  /// No description provided for @clearS3Warning.
  ///
  /// In zh, this message translates to:
  /// **'此操作将删除 S3 bucket 中的所有文件，且不可恢复！'**
  String get clearS3Warning;

  /// No description provided for @enterPasswordToConfirm.
  ///
  /// In zh, this message translates to:
  /// **'输入密码确认'**
  String get enterPasswordToConfirm;

  /// No description provided for @confirmClear.
  ///
  /// In zh, this message translates to:
  /// **'确认清空'**
  String get confirmClear;

  /// No description provided for @s3DataCleared.
  ///
  /// In zh, this message translates to:
  /// **'S3 数据已清空'**
  String get s3DataCleared;

  /// No description provided for @clearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空失败: {error}'**
  String clearFailed(String error);

  /// No description provided for @config.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get config;

  /// No description provided for @s3Connection.
  ///
  /// In zh, this message translates to:
  /// **'S3 连接'**
  String get s3Connection;

  /// No description provided for @connectionTest.
  ///
  /// In zh, this message translates to:
  /// **'连接测试'**
  String get connectionTest;

  /// No description provided for @connectionOk.
  ///
  /// In zh, this message translates to:
  /// **'连接正常'**
  String get connectionOk;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get connectionFailed;

  /// No description provided for @test.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get test;

  /// No description provided for @syncOperations.
  ///
  /// In zh, this message translates to:
  /// **'同步操作'**
  String get syncOperations;

  /// No description provided for @fullUpload.
  ///
  /// In zh, this message translates to:
  /// **'全量上传'**
  String get fullUpload;

  /// No description provided for @fullDownload.
  ///
  /// In zh, this message translates to:
  /// **'全量下载'**
  String get fullDownload;

  /// No description provided for @incrementalSync.
  ///
  /// In zh, this message translates to:
  /// **'增量同步'**
  String get incrementalSync;

  /// No description provided for @uploading.
  ///
  /// In zh, this message translates to:
  /// **'上传中'**
  String get uploading;

  /// No description provided for @downloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloading;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get error;

  /// No description provided for @scheduledSync.
  ///
  /// In zh, this message translates to:
  /// **'定时同步'**
  String get scheduledSync;

  /// No description provided for @autoSync.
  ///
  /// In zh, this message translates to:
  /// **'定时自动同步'**
  String get autoSync;

  /// No description provided for @syncIntervalSummary.
  ///
  /// In zh, this message translates to:
  /// **'每 {interval} 同步一次'**
  String syncIntervalSummary(String interval);

  /// No description provided for @manualSyncOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅手动同步'**
  String get manualSyncOnly;

  /// No description provided for @syncInterval.
  ///
  /// In zh, this message translates to:
  /// **'同步间隔'**
  String get syncInterval;

  /// No description provided for @fiveMinutes.
  ///
  /// In zh, this message translates to:
  /// **'5 分钟'**
  String get fiveMinutes;

  /// No description provided for @fifteenMinutes.
  ///
  /// In zh, this message translates to:
  /// **'15 分钟'**
  String get fifteenMinutes;

  /// No description provided for @thirtyMinutes.
  ///
  /// In zh, this message translates to:
  /// **'30 分钟'**
  String get thirtyMinutes;

  /// No description provided for @oneHour.
  ///
  /// In zh, this message translates to:
  /// **'1 小时'**
  String get oneHour;

  /// No description provided for @sixHours.
  ///
  /// In zh, this message translates to:
  /// **'6 小时'**
  String get sixHours;

  /// No description provided for @oneDay.
  ///
  /// In zh, this message translates to:
  /// **'1 天'**
  String get oneDay;

  /// No description provided for @storageStatistics.
  ///
  /// In zh, this message translates to:
  /// **'存储统计'**
  String get storageStatistics;

  /// No description provided for @s3Storage.
  ///
  /// In zh, this message translates to:
  /// **'S3 存储'**
  String get s3Storage;

  /// No description provided for @storageStatsDetail.
  ///
  /// In zh, this message translates to:
  /// **'{size} · {count} 个文件'**
  String storageStatsDetail(String size, int count);

  /// No description provided for @calculating.
  ///
  /// In zh, this message translates to:
  /// **'统计中...'**
  String get calculating;

  /// No description provided for @clickToRefresh.
  ///
  /// In zh, this message translates to:
  /// **'点击右侧按钮刷新'**
  String get clickToRefresh;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @localStorage.
  ///
  /// In zh, this message translates to:
  /// **'本地存储'**
  String get localStorage;

  /// No description provided for @lastSync.
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get lastSync;

  /// No description provided for @neverSynced.
  ///
  /// In zh, this message translates to:
  /// **'从未同步'**
  String get neverSynced;

  /// No description provided for @clearS3DataShort.
  ///
  /// In zh, this message translates to:
  /// **'清空 S3 数据'**
  String get clearS3DataShort;

  /// No description provided for @deleteAllBucketFiles.
  ///
  /// In zh, this message translates to:
  /// **'删除 bucket 中所有文件'**
  String get deleteAllBucketFiles;

  /// No description provided for @intervalMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟'**
  String intervalMinutes(int count);

  /// No description provided for @intervalHours.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时'**
  String intervalHours(int count);

  /// No description provided for @intervalDays.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天'**
  String intervalDays(int count);

  /// No description provided for @s3Config.
  ///
  /// In zh, this message translates to:
  /// **'S3 配置'**
  String get s3Config;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @logViewer.
  ///
  /// In zh, this message translates to:
  /// **'运行日志'**
  String get logViewer;

  /// No description provided for @logCopied.
  ///
  /// In zh, this message translates to:
  /// **'日志已复制到剪贴板'**
  String get logCopied;

  /// No description provided for @noLogs.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get noLogs;

  /// No description provided for @logSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索日志 (支持 message / tag / level)'**
  String get logSearchHint;

  /// No description provided for @logNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'无匹配日志'**
  String get logNoMatch;

  /// No description provided for @logFilteredCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}/{total} 条'**
  String logFilteredCount(Object count, Object total);

  /// No description provided for @importComplete.
  ///
  /// In zh, this message translates to:
  /// **'导入完成'**
  String get importComplete;

  /// No description provided for @importImages.
  ///
  /// In zh, this message translates to:
  /// **'导入图片'**
  String get importImages;

  /// No description provided for @importCountImages.
  ///
  /// In zh, this message translates to:
  /// **'导入 {count} 张图片'**
  String importCountImages(int count);

  /// No description provided for @importSuccessCount.
  ///
  /// In zh, this message translates to:
  /// **'成功 {count} 张{skip}'**
  String importSuccessCount(int count, String skip);

  /// No description provided for @skippedExisting.
  ///
  /// In zh, this message translates to:
  /// **'，跳过（已存在）{count} 张'**
  String skippedExisting(int count);

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败: {error}'**
  String importFailed(String error);

  /// No description provided for @cannotLoadImage.
  ///
  /// In zh, this message translates to:
  /// **'无法加载图片'**
  String get cannotLoadImage;

  /// No description provided for @importFromAlbum.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get importFromAlbum;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 张'**
  String selectedCount(int count);

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @importDone.
  ///
  /// In zh, this message translates to:
  /// **'导入完成'**
  String get importDone;

  /// No description provided for @importResultSummary.
  ///
  /// In zh, this message translates to:
  /// **'成功: {success}  跳过: {skipped}'**
  String importResultSummary(int success, int skipped);

  /// No description provided for @errorLabel.
  ///
  /// In zh, this message translates to:
  /// **'错误:'**
  String get errorLabel;

  /// No description provided for @selectFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'选择文件失败: {error}'**
  String selectFileFailed(String error);

  /// No description provided for @importSuccessCountImages.
  ///
  /// In zh, this message translates to:
  /// **'成功导入 {count} 张图片'**
  String importSuccessCountImages(int count);

  /// No description provided for @addedToAnalysisQueue.
  ///
  /// In zh, this message translates to:
  /// **'已加入分析队列，即将开始分析'**
  String get addedToAnalysisQueue;

  /// No description provided for @reanalysisFailed.
  ///
  /// In zh, this message translates to:
  /// **'重新分析失败: {error}'**
  String reanalysisFailed(String error);

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMeme.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除「{filename}」吗？\n图片文件和所有分析数据都会被移除。'**
  String confirmDeleteMeme(String filename);

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @notFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到'**
  String get notFound;

  /// No description provided for @memeNotExist.
  ///
  /// In zh, this message translates to:
  /// **'Meme 不存在'**
  String get memeNotExist;

  /// No description provided for @reAnalyze.
  ///
  /// In zh, this message translates to:
  /// **'重新分析'**
  String get reAnalyze;

  /// No description provided for @fileName.
  ///
  /// In zh, this message translates to:
  /// **'文件名'**
  String get fileName;

  /// No description provided for @dimensions.
  ///
  /// In zh, this message translates to:
  /// **'尺寸'**
  String get dimensions;

  /// No description provided for @fileSize.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get fileSize;

  /// No description provided for @colorExtractionDone.
  ///
  /// In zh, this message translates to:
  /// **'颜色提取完成'**
  String get colorExtractionDone;

  /// No description provided for @colorExtracting.
  ///
  /// In zh, this message translates to:
  /// **'正在提取颜色...'**
  String get colorExtracting;

  /// No description provided for @colorExtractionFailed.
  ///
  /// In zh, this message translates to:
  /// **'颜色提取失败'**
  String get colorExtractionFailed;

  /// No description provided for @pendingColorExtraction.
  ///
  /// In zh, this message translates to:
  /// **'待提取主色调'**
  String get pendingColorExtraction;

  /// No description provided for @ocrEnabled.
  ///
  /// In zh, this message translates to:
  /// **'OCR 已开启'**
  String get ocrEnabled;

  /// No description provided for @ocrDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未开启 OCR 识别'**
  String get ocrDisabled;

  /// No description provided for @aiEnabled.
  ///
  /// In zh, this message translates to:
  /// **'AI 已开启'**
  String get aiEnabled;

  /// No description provided for @aiDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未开启 AI 识别'**
  String get aiDisabled;

  /// No description provided for @dominantColors.
  ///
  /// In zh, this message translates to:
  /// **'主色调'**
  String get dominantColors;

  /// No description provided for @noDominantColors.
  ///
  /// In zh, this message translates to:
  /// **'未提取到主色调'**
  String get noDominantColors;

  /// No description provided for @extractingDominantColors.
  ///
  /// In zh, this message translates to:
  /// **'正在提取主色调...'**
  String get extractingDominantColors;

  /// No description provided for @deleteTag.
  ///
  /// In zh, this message translates to:
  /// **'删除标签'**
  String get deleteTag;

  /// No description provided for @confirmDeleteTag.
  ///
  /// In zh, this message translates to:
  /// **'确定删除标签「{content}」吗？'**
  String confirmDeleteTag(String content);

  /// No description provided for @customTags.
  ///
  /// In zh, this message translates to:
  /// **'自定义标签'**
  String get customTags;

  /// No description provided for @tagCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String tagCount(int count);

  /// No description provided for @noCustomTags.
  ///
  /// In zh, this message translates to:
  /// **'暂无自定义标签'**
  String get noCustomTags;

  /// No description provided for @inputTag.
  ///
  /// In zh, this message translates to:
  /// **'输入标签'**
  String get inputTag;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @ocrRecognition.
  ///
  /// In zh, this message translates to:
  /// **'OCR 识别'**
  String get ocrRecognition;

  /// No description provided for @ocrWordCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 词'**
  String ocrWordCount(int count);

  /// No description provided for @noOcrText.
  ///
  /// In zh, this message translates to:
  /// **'暂未识别到文字'**
  String get noOcrText;

  /// No description provided for @receiveShare.
  ///
  /// In zh, this message translates to:
  /// **'接收分享'**
  String get receiveShare;

  /// No description provided for @importingProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在导入 {processed}/{total} 张图片...'**
  String importingProgress(int processed, int total);

  /// No description provided for @deduplicating.
  ///
  /// In zh, this message translates to:
  /// **'SHA256 去重中'**
  String get deduplicating;

  /// No description provided for @importCompleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入完成'**
  String get importCompleteTitle;

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功: {count}'**
  String importSuccess(int count);

  /// No description provided for @importSkipped.
  ///
  /// In zh, this message translates to:
  /// **'跳过（已存在）: {count}'**
  String importSkipped(int count);

  /// No description provided for @importErrors.
  ///
  /// In zh, this message translates to:
  /// **'错误: {count}'**
  String importErrors(int count);

  /// No description provided for @viewGallery.
  ///
  /// In zh, this message translates to:
  /// **'查看图库'**
  String get viewGallery;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败: {error}'**
  String searchFailed(String error);

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索图片（语义/关键词）...'**
  String get searchHint;

  /// No description provided for @filterByColor.
  ///
  /// In zh, this message translates to:
  /// **'按颜色筛选'**
  String get filterByColor;

  /// No description provided for @clearFilter.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clearFilter;

  /// No description provided for @startSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词或选择颜色开始搜索'**
  String get startSearchHint;

  /// No description provided for @noImageData.
  ///
  /// In zh, this message translates to:
  /// **'暂无图片数据，请先导入图片'**
  String get noImageData;

  /// No description provided for @combinedSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'支持文字搜索 + 颜色筛选叠加使用'**
  String get combinedSearchHint;

  /// No description provided for @noMatchingImages.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的图片'**
  String get noMatchingImages;

  /// No description provided for @tryOtherKeywords.
  ///
  /// In zh, this message translates to:
  /// **'试试其他关键词或颜色'**
  String get tryOtherKeywords;

  /// No description provided for @foundResults.
  ///
  /// In zh, this message translates to:
  /// **'找到 {count} 个结果'**
  String foundResults(int count);

  /// No description provided for @searchLevelFull.
  ///
  /// In zh, this message translates to:
  /// **'L3 全功能'**
  String get searchLevelFull;

  /// No description provided for @searchLevelColorKeyword.
  ///
  /// In zh, this message translates to:
  /// **'L2 关键词+颜色'**
  String get searchLevelColorKeyword;

  /// No description provided for @searchLevelColorOnly.
  ///
  /// In zh, this message translates to:
  /// **'L1 仅颜色'**
  String get searchLevelColorOnly;

  /// No description provided for @searchLevelBrowse.
  ///
  /// In zh, this message translates to:
  /// **'L0 浏览'**
  String get searchLevelBrowse;

  /// No description provided for @customColor.
  ///
  /// In zh, this message translates to:
  /// **'自定义颜色'**
  String get customColor;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @colorRed.
  ///
  /// In zh, this message translates to:
  /// **'红'**
  String get colorRed;

  /// No description provided for @colorDeepOrange.
  ///
  /// In zh, this message translates to:
  /// **'深橙'**
  String get colorDeepOrange;

  /// No description provided for @colorOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙'**
  String get colorOrange;

  /// No description provided for @colorAmber.
  ///
  /// In zh, this message translates to:
  /// **'琥珀'**
  String get colorAmber;

  /// No description provided for @colorYellow.
  ///
  /// In zh, this message translates to:
  /// **'黄'**
  String get colorYellow;

  /// No description provided for @colorLime.
  ///
  /// In zh, this message translates to:
  /// **'柠绿'**
  String get colorLime;

  /// No description provided for @colorLightGreen.
  ///
  /// In zh, this message translates to:
  /// **'浅绿'**
  String get colorLightGreen;

  /// No description provided for @colorGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿'**
  String get colorGreen;

  /// No description provided for @colorCyan.
  ///
  /// In zh, this message translates to:
  /// **'青'**
  String get colorCyan;

  /// No description provided for @colorLightBlue.
  ///
  /// In zh, this message translates to:
  /// **'浅蓝'**
  String get colorLightBlue;

  /// No description provided for @colorBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝'**
  String get colorBlue;

  /// No description provided for @colorIndigo.
  ///
  /// In zh, this message translates to:
  /// **'靛蓝'**
  String get colorIndigo;

  /// No description provided for @colorDeepPurple.
  ///
  /// In zh, this message translates to:
  /// **'深紫'**
  String get colorDeepPurple;

  /// No description provided for @colorPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫'**
  String get colorPurple;

  /// No description provided for @colorPink.
  ///
  /// In zh, this message translates to:
  /// **'粉'**
  String get colorPink;

  /// No description provided for @colorBrown.
  ///
  /// In zh, this message translates to:
  /// **'棕'**
  String get colorBrown;

  /// No description provided for @colorGrey.
  ///
  /// In zh, this message translates to:
  /// **'灰'**
  String get colorGrey;

  /// No description provided for @colorBlueGrey.
  ///
  /// In zh, this message translates to:
  /// **'蓝灰'**
  String get colorBlueGrey;

  /// No description provided for @colorBlack.
  ///
  /// In zh, this message translates to:
  /// **'黑'**
  String get colorBlack;

  /// No description provided for @colorWhite.
  ///
  /// In zh, this message translates to:
  /// **'白'**
  String get colorWhite;

  /// No description provided for @confirmDeleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 张图片吗？\n图片文件和所有分析数据都会被移除。'**
  String confirmDeleteSelected(int count);

  /// No description provided for @deletedCountImages.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 张图片'**
  String deletedCountImages(int count);

  /// No description provided for @noAlbumsCreateFirst.
  ///
  /// In zh, this message translates to:
  /// **'还没有相册，请先创建'**
  String get noAlbumsCreateFirst;

  /// No description provided for @selectAlbum.
  ///
  /// In zh, this message translates to:
  /// **'选择相册'**
  String get selectAlbum;

  /// No description provided for @addedToAlbum.
  ///
  /// In zh, this message translates to:
  /// **'已将 {count} 张图片添加到「{albumName}」'**
  String addedToAlbum(int count, String albumName);

  /// No description provided for @newAlbum.
  ///
  /// In zh, this message translates to:
  /// **'新建相册'**
  String get newAlbum;

  /// No description provided for @albumName.
  ///
  /// In zh, this message translates to:
  /// **'相册名称'**
  String get albumName;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @releaseToImport.
  ///
  /// In zh, this message translates to:
  /// **'松开导入图片'**
  String get releaseToImport;

  /// No description provided for @allImages.
  ///
  /// In zh, this message translates to:
  /// **'全部图片'**
  String get allImages;

  /// No description provided for @selectedItems.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 项'**
  String selectedItems(int count);

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @addToAlbum.
  ///
  /// In zh, this message translates to:
  /// **'添加到相册'**
  String get addToAlbum;

  /// No description provided for @analyzingProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在分析{running}剩余 {total} 张…'**
  String analyzingProgress(String running, int total);

  /// No description provided for @analyzingRunning.
  ///
  /// In zh, this message translates to:
  /// **'({count} 进行中)'**
  String analyzingRunning(int count);

  /// No description provided for @loadFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String loadFailedWithError(String error);

  /// No description provided for @noMemesYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有任何 Meme'**
  String get noMemesYet;

  /// No description provided for @tapToImport.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角按钮导入图片'**
  String get tapToImport;

  /// No description provided for @scanFolder.
  ///
  /// In zh, this message translates to:
  /// **'扫描文件夹'**
  String get scanFolder;

  /// No description provided for @importImage.
  ///
  /// In zh, this message translates to:
  /// **'导入图片'**
  String get importImage;

  /// No description provided for @importFromClipboard.
  ///
  /// In zh, this message translates to:
  /// **'从剪贴板导入'**
  String get importFromClipboard;

  /// No description provided for @newAlbumShort.
  ///
  /// In zh, this message translates to:
  /// **'新建相册'**
  String get newAlbumShort;

  /// No description provided for @noImageFilesFound.
  ///
  /// In zh, this message translates to:
  /// **'未发现图片文件'**
  String get noImageFilesFound;

  /// No description provided for @clipboardEmpty.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板为空'**
  String get clipboardEmpty;

  /// No description provided for @cannotReadClipboardUri.
  ///
  /// In zh, this message translates to:
  /// **'无法读取剪贴板 URI'**
  String get cannotReadClipboardUri;

  /// No description provided for @downloadingFromClipboardUrl.
  ///
  /// In zh, this message translates to:
  /// **'正在从剪贴板 URL 下载图片...'**
  String get downloadingFromClipboardUrl;

  /// No description provided for @downloadFromUrlFailed.
  ///
  /// In zh, this message translates to:
  /// **'从 URL 下载图片失败'**
  String get downloadFromUrlFailed;

  /// No description provided for @downloadClipboardImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载剪贴板图片失败'**
  String get downloadClipboardImageFailed;

  /// No description provided for @clipboardNotValidPath.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板内容不是有效的文件路径'**
  String get clipboardNotValidPath;

  /// No description provided for @clipboardNotImage.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板文件不是图片格式'**
  String get clipboardNotImage;

  /// No description provided for @importResultTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入结果'**
  String get importResultTitle;

  /// No description provided for @existingFiles.
  ///
  /// In zh, this message translates to:
  /// **'已存在的文件:'**
  String get existingFiles;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @exportMemes.
  ///
  /// In zh, this message translates to:
  /// **'导出表情包'**
  String get exportMemes;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @exportFileName.
  ///
  /// In zh, this message translates to:
  /// **'文件名'**
  String get exportFileName;

  /// No description provided for @exporting.
  ///
  /// In zh, this message translates to:
  /// **'正在导出...'**
  String get exporting;

  /// No description provided for @exportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'导出成功: {path}'**
  String exportSuccess(String path);

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败: {error}'**
  String exportFailed(String error);

  /// No description provided for @importMemePack.
  ///
  /// In zh, this message translates to:
  /// **'导入表情包'**
  String get importMemePack;

  /// No description provided for @importMemePackResult.
  ///
  /// In zh, this message translates to:
  /// **'导入完成: 成功 {success}, 跳过 {skipped}, 失败 {errors}'**
  String importMemePackResult(int success, int skipped, int errors);

  /// No description provided for @importMemePackFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败: {error}'**
  String importMemePackFailed(String error);

  /// No description provided for @copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboard;

  /// No description provided for @shareMeme.
  ///
  /// In zh, this message translates to:
  /// **'分享表情包'**
  String get shareMeme;

  /// No description provided for @s3NotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'S3 未配置'**
  String get s3NotConfigured;

  /// No description provided for @cancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get cancelled;

  /// No description provided for @imageUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片上传失败: {filename}: {error}'**
  String imageUploadFailed(String filename, String error);

  /// No description provided for @syncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: {error}'**
  String syncFailed(String error);

  /// No description provided for @passwordIncorrect.
  ///
  /// In zh, this message translates to:
  /// **'密码错误'**
  String get passwordIncorrect;

  /// No description provided for @noBackupOnS3.
  ///
  /// In zh, this message translates to:
  /// **'S3 上没有找到备份数据'**
  String get noBackupOnS3;

  /// No description provided for @pleaseFullDownloadFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先执行全量下载'**
  String get pleaseFullDownloadFirst;

  /// No description provided for @incrementalSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'增量同步失败: {error}'**
  String incrementalSyncFailed(String error);

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @aiRecognition.
  ///
  /// In zh, this message translates to:
  /// **'AI 识别'**
  String get aiRecognition;

  /// No description provided for @noAiTags.
  ///
  /// In zh, this message translates to:
  /// **'暂无 AI 标签'**
  String get noAiTags;

  /// No description provided for @llmTagCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String llmTagCount(int count);

  /// No description provided for @descriptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get descriptionLabel;

  /// No description provided for @mmprojHint.
  ///
  /// In zh, this message translates to:
  /// **'如果你的模型支持图片输入（多模态），建议同时选择 mmproj 投影文件。\n\n不需要请点「跳过」'**
  String get mmprojHint;

  /// No description provided for @uriReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取 URI'**
  String get uriReadFailed;

  /// No description provided for @userStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'用户统计'**
  String get userStatsTitle;

  /// No description provided for @todayStats.
  ///
  /// In zh, this message translates to:
  /// **'今日统计'**
  String get todayStats;

  /// No description provided for @recent7DayTrend.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天趋势'**
  String get recent7DayTrend;

  /// No description provided for @totalSummary.
  ///
  /// In zh, this message translates to:
  /// **'全部汇总'**
  String get totalSummary;

  /// No description provided for @imported.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get imported;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copied;

  /// No description provided for @favorited.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorited;

  /// No description provided for @total.
  ///
  /// In zh, this message translates to:
  /// **'总计'**
  String get total;

  /// No description provided for @filter.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filter;

  /// No description provided for @tokenUsage.
  ///
  /// In zh, this message translates to:
  /// **'Token 用量'**
  String get tokenUsage;

  /// No description provided for @promptTokens.
  ///
  /// In zh, this message translates to:
  /// **'Prompt Token'**
  String get promptTokens;

  /// No description provided for @completionTokens.
  ///
  /// In zh, this message translates to:
  /// **'Completion Token'**
  String get completionTokens;

  /// No description provided for @totalTokens.
  ///
  /// In zh, this message translates to:
  /// **'总 Token'**
  String get totalTokens;

  /// No description provided for @day.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get day;

  /// No description provided for @last7Days.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天'**
  String get last7Days;

  /// No description provided for @last30Days.
  ///
  /// In zh, this message translates to:
  /// **'近 30 天'**
  String get last30Days;

  /// No description provided for @last365Days.
  ///
  /// In zh, this message translates to:
  /// **'近 365 天'**
  String get last365Days;

  /// No description provided for @heatmap.
  ///
  /// In zh, this message translates to:
  /// **'热度图'**
  String get heatmap;

  /// No description provided for @statsDateRange.
  ///
  /// In zh, this message translates to:
  /// **'统计范围'**
  String get statsDateRange;

  /// No description provided for @exportConfig.
  ///
  /// In zh, this message translates to:
  /// **'导出配置'**
  String get exportConfig;

  /// No description provided for @importConfig.
  ///
  /// In zh, this message translates to:
  /// **'导入配置'**
  String get importConfig;

  /// No description provided for @configExported.
  ///
  /// In zh, this message translates to:
  /// **'配置已导出'**
  String get configExported;

  /// No description provided for @configImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'配置导入成功'**
  String get configImportSuccess;

  /// No description provided for @configImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'配置导入失败: {error}'**
  String configImportFailed(String error);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
