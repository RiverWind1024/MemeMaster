/// S3 同步配置
class S3Config {
  final String endpoint;
  final String bucket;
  final String region;
  final String accessKey;
  final String secretKey;
  final bool useSsl;

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'bucket': bucket,
        'region': region,
        'accessKey': accessKey,
        'secretKey': secretKey,
        'useSsl': useSsl,
      };

  factory S3Config.fromJson(Map<String, dynamic> json) => S3Config(
        endpoint: json['endpoint'] as String? ?? '',
        bucket: json['bucket'] as String? ?? '',
        region: json['region'] as String? ?? 'us-east-1',
        accessKey: json['accessKey'] as String? ?? '',
        secretKey: json['secretKey'] as String? ?? '',
        useSsl: json['useSsl'] as bool? ?? true,
      );

  const S3Config({
    this.endpoint = '',
    this.bucket = '',
    this.region = 'us-east-1',
    this.accessKey = '',
    this.secretKey = '',
    this.useSsl = true,
  });

  bool get isValid =>
      endpoint.isNotEmpty &&
      bucket.isNotEmpty &&
      accessKey.isNotEmpty &&
      secretKey.isNotEmpty;

  S3Config copyWith({
    String? endpoint,
    String? bucket,
    String? region,
    String? accessKey,
    String? secretKey,
    bool? useSsl,
  }) {
    return S3Config(
      endpoint: endpoint ?? this.endpoint,
      bucket: bucket ?? this.bucket,
      region: region ?? this.region,
      accessKey: accessKey ?? this.accessKey,
      secretKey: secretKey ?? this.secretKey,
      useSsl: useSsl ?? this.useSsl,
    );
  }
}

/// S3 同步状态
enum S3SyncStatus {
  idle,
  uploading,
  downloading,
  error,
}

/// S3 同步进度
class S3SyncProgress {
  final S3SyncStatus status;
  final int completed;
  final int total;
  final String? errorMessage;

  const S3SyncProgress({
    this.status = S3SyncStatus.idle,
    this.completed = 0,
    this.total = 0,
    this.errorMessage,
  });

  double? get fraction =>
      total > 0 ? completed / total : null;
}
