// S3 同步使用的对象键与本地状态键约定（v2 协议）。
//
// 集中定义，避免引擎、统计/清理服务与 DAO 各自硬编码字符串导致漂移。

/// manifest（权威索引）对象键。
const String kManifestKey = 'sync/manifest.json';

/// 单个 meme 的同步 json 前缀。
const String kMemePrefix = 'sync/memes/';

/// 单个相册的同步 json 前缀。
const String kAlbumPrefix = 'sync/albums/';

/// 图片内容寻址 blob 前缀。
const String kBlobPrefix = 'blobs/';

/// 用户统计对象键。
const String kUserStatsKey = 'sync/user_stats.json';

/// 本地逻辑时钟在 SyncStateTable 中的 key。
const String kSyncClockKey = 'sync_clock';

/// 本地用户统计变更时间在 SyncStateTable 中的 key。
const String kUserStatsClockKey = 'user_stats_updated_at';

/// 本机 deviceId 在 S3SecretStore 中的 key。
const String kDeviceIdKey = 'device_id';

/// 迁移前的 v1 遗留对象（文件）键。
///
/// 只要其中任意一个仍存在，说明该 bucket 尚未完成 v1 → v2 迁移。
const List<String> kLegacyObjectKeys = [
  'snapshot-v1.json',
  'data/memes.json',
  'data/albums.json',
];

/// 迁移前的 v1 遗留对象前缀。
const List<String> kLegacyPrefixes = [
  'data/memes/',
  'memes/',
];