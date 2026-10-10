/// manifest 中单个实体的索引信息。
class ManifestEntry {
  final int updatedAt;
  final int? deletedAt;
  final String? hash; // 仅 meme：图片内容哈希
  final String? ext; // 仅 meme：图片扩展名（含点）

  const ManifestEntry({
    required this.updatedAt,
    this.deletedAt,
    this.hash,
    this.ext,
  });

  Map<String, dynamic> toJson() => {
        'updatedAt': updatedAt,
        if (deletedAt != null) 'deletedAt': deletedAt,
        if (hash != null) 'hash': hash,
        if (ext != null) 'ext': ext,
      };

  factory ManifestEntry.fromJson(Map<String, dynamic> j) => ManifestEntry(
        updatedAt: j['updatedAt'] as int,
        deletedAt: j['deletedAt'] as int?,
        hash: j['hash'] as String?,
        ext: j['ext'] as String?,
      );
}

/// 权威索引：一次 GET 即可算出全部差异。
class Manifest {
  static const currentSchema = 2;

  final int schema;
  final int generatedAt;
  final String lastWriter;
  final int clock;
  final Map<String, ManifestEntry> memes;
  final Map<String, ManifestEntry> albums;
  final int? userStatsUpdatedAt;

  const Manifest({
    required this.schema,
    required this.generatedAt,
    required this.lastWriter,
    required this.clock,
    required this.memes,
    required this.albums,
    this.userStatsUpdatedAt,
  });

  factory Manifest.empty() => const Manifest(
        schema: currentSchema,
        generatedAt: 0,
        lastWriter: '',
        clock: 0,
        memes: {},
        albums: {},
      );

  int maxUpdatedAt() {
    var max = 0;
    for (final e in memes.values) {
      if (e.updatedAt > max) max = e.updatedAt;
    }
    for (final e in albums.values) {
      if (e.updatedAt > max) max = e.updatedAt;
    }
    if ((userStatsUpdatedAt ?? 0) > max) max = userStatsUpdatedAt!;
    return max;
  }

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'generatedAt': generatedAt,
        'lastWriter': lastWriter,
        'clock': clock,
        'memes': memes.map((k, v) => MapEntry(k, v.toJson())),
        'albums': albums.map((k, v) => MapEntry(k, v.toJson())),
        if (userStatsUpdatedAt != null) 'userStatsUpdatedAt': userStatsUpdatedAt,
      };

  factory Manifest.fromJson(Map<String, dynamic> j) => Manifest(
        schema: j['schema'] as int? ?? 1,
        generatedAt: j['generatedAt'] as int? ?? 0,
        lastWriter: j['lastWriter'] as String? ?? '',
        clock: j['clock'] as int? ?? 0,
        memes: ((j['memes'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, ManifestEntry.fromJson(v as Map<String, dynamic>))),
        albums: ((j['albums'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, ManifestEntry.fromJson(v as Map<String, dynamic>))),
        userStatsUpdatedAt: j['userStatsUpdatedAt'] as int?,
      );
}
