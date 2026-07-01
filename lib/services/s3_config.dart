/// S3 同步配置
class S3Config {
  final String endpoint;
  final String bucket;
  final String region;
  final String accessKey;
  final String secretKey;
  final bool useSsl;
  final bool pathStyle;
  final int connectTimeout;

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'bucket': bucket,
        'region': region,
        'accessKey': accessKey,
        'secretKey': secretKey,
        'useSsl': useSsl,
        'pathStyle': pathStyle,
        'connectTimeout': connectTimeout,
      };

  factory S3Config.fromJson(Map<String, dynamic> json) => S3Config(
        endpoint: json['endpoint'] as String? ?? '',
        bucket: json['bucket'] as String? ?? '',
        region: json['region'] as String? ?? 'us-east-1',
        accessKey: json['accessKey'] as String? ?? '',
        secretKey: json['secretKey'] as String? ?? '',
        useSsl: json['useSsl'] as bool? ?? true,
        pathStyle: json['pathStyle'] as bool? ?? true,
        connectTimeout: json['connectTimeout'] as int? ?? 30,
      );

  const S3Config({
    this.endpoint = '',
    this.bucket = '',
    this.region = 'us-east-1',
    this.accessKey = '',
    this.secretKey = '',
    this.useSsl = true,
    this.pathStyle = true,
    this.connectTimeout = 30,
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
    bool? pathStyle,
    int? connectTimeout,
  }) {
    return S3Config(
      endpoint: endpoint ?? this.endpoint,
      bucket: bucket ?? this.bucket,
      region: region ?? this.region,
      accessKey: accessKey ?? this.accessKey,
      secretKey: secretKey ?? this.secretKey,
      useSsl: useSsl ?? this.useSsl,
      pathStyle: pathStyle ?? this.pathStyle,
      connectTimeout: connectTimeout ?? this.connectTimeout,
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
