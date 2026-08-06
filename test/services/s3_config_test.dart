import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/services/s3_config.dart';

void main() {
  group('S3Config', () {
    test('默认构造函数设置正确的默认值', () {
      const config = S3Config();
      expect(config.endpoint, '');
      expect(config.bucket, '');
      expect(config.region, 'us-east-1');
      expect(config.accessKey, '');
      expect(config.secretKey, '');
      expect(config.useSsl, true);
      expect(config.pathStyle, true);
      expect(config.connectTimeout, 30);
    });

    test('构造函数接受自定义值', () {
      const config = S3Config(
        endpoint: 'https://minio.example.com',
        bucket: 'my-bucket',
        region: 'eu-west-1',
        accessKey: 'AKIAIOSFODNN7EXAMPLE',
        secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        useSsl: false,
        pathStyle: false,
        connectTimeout: 60,
      );
      expect(config.endpoint, 'https://minio.example.com');
      expect(config.bucket, 'my-bucket');
      expect(config.region, 'eu-west-1');
      expect(config.accessKey, 'AKIAIOSFODNN7EXAMPLE');
      expect(config.secretKey, 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY');
      expect(config.useSsl, false);
      expect(config.pathStyle, false);
      expect(config.connectTimeout, 60);
    });

    group('isValid', () {
      test('所有必填字段都有值时返回 true', () {
        const config = S3Config(
          endpoint: 'https://s3.amazonaws.com',
          bucket: 'my-bucket',
          accessKey: 'AKIAIOSFODNN7EXAMPLE',
          secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        );
        expect(config.isValid, isTrue);
      });

      test('endpoint 为空时返回 false', () {
        const config = S3Config(
          endpoint: '',
          bucket: 'my-bucket',
          accessKey: 'key',
          secretKey: 'secret',
        );
        expect(config.isValid, isFalse);
      });

      test('bucket 为空时返回 false', () {
        const config = S3Config(
          endpoint: 'https://s3.amazonaws.com',
          bucket: '',
          accessKey: 'key',
          secretKey: 'secret',
        );
        expect(config.isValid, isFalse);
      });

      test('accessKey 为空时返回 false', () {
        const config = S3Config(
          endpoint: 'https://s3.amazonaws.com',
          bucket: 'my-bucket',
          accessKey: '',
          secretKey: 'secret',
        );
        expect(config.isValid, isFalse);
      });

      test('secretKey 为空时返回 false', () {
        const config = S3Config(
          endpoint: 'https://s3.amazonaws.com',
          bucket: 'my-bucket',
          accessKey: 'key',
          secretKey: '',
        );
        expect(config.isValid, isFalse);
      });
    });

    group('copyWith', () {
      test('复制所有字段', () {
        const original = S3Config(
          endpoint: 'https://old.com',
          bucket: 'old-bucket',
          region: 'us-east-1',
          accessKey: 'old-key',
          secretKey: 'old-secret',
          useSsl: true,
          pathStyle: true,
          connectTimeout: 30,
        );
        final copied = original.copyWith(
          endpoint: 'https://new.com',
          bucket: 'new-bucket',
        );
        expect(copied.endpoint, 'https://new.com');
        expect(copied.bucket, 'new-bucket');
        expect(copied.region, 'us-east-1');
        expect(copied.accessKey, 'old-key');
        expect(copied.secretKey, 'old-secret');
        expect(copied.useSsl, true);
        expect(copied.pathStyle, true);
        expect(copied.connectTimeout, 30);
      });

      test('保留未指定的字段', () {
        const original = S3Config(
          endpoint: 'https://s3.amazonaws.com',
          bucket: 'my-bucket',
          region: 'eu-west-1',
          accessKey: 'key',
          secretKey: 'secret',
          useSsl: false,
          pathStyle: false,
          connectTimeout: 120,
        );
        final copied = original.copyWith();
        expect(copied.endpoint, 'https://s3.amazonaws.com');
        expect(copied.bucket, 'my-bucket');
        expect(copied.region, 'eu-west-1');
        expect(copied.useSsl, false);
        expect(copied.pathStyle, false);
        expect(copied.connectTimeout, 120);
      });
    });

    group('JSON 序列化', () {
      test('toJson 包含所有字段', () {
        const config = S3Config(
          endpoint: 'https://s3.amazonaws.com',
          bucket: 'my-bucket',
          region: 'eu-west-1',
          accessKey: 'key',
          secretKey: 'secret',
          useSsl: false,
          pathStyle: false,
          connectTimeout: 60,
        );
        final json = config.toJson();
        expect(json['endpoint'], 'https://s3.amazonaws.com');
        expect(json['bucket'], 'my-bucket');
        expect(json['region'], 'eu-west-1');
        expect(json['accessKey'], 'key');
        expect(json['secretKey'], 'secret');
        expect(json['useSsl'], false);
        expect(json['pathStyle'], false);
        expect(json['connectTimeout'], 60);
      });

      test('fromJson 正确反序列化', () {
        final json = {
          'endpoint': 'https://minio.local',
          'bucket': 'test-bucket',
          'region': 'ap-south-1',
          'accessKey': 'access-key',
          'secretKey': 'secret-key',
          'useSsl': false,
          'pathStyle': true,
          'connectTimeout': 45,
        };
        final config = S3Config.fromJson(json);
        expect(config.endpoint, 'https://minio.local');
        expect(config.bucket, 'test-bucket');
        expect(config.region, 'ap-south-1');
        expect(config.accessKey, 'access-key');
        expect(config.secretKey, 'secret-key');
        expect(config.useSsl, false);
        expect(config.pathStyle, true);
        expect(config.connectTimeout, 45);
      });

      test('fromJson 处理缺失字段使用默认值', () {
        final json = <String, dynamic>{};
        final config = S3Config.fromJson(json);
        expect(config.endpoint, '');
        expect(config.bucket, '');
        expect(config.region, 'us-east-1');
        expect(config.accessKey, '');
        expect(config.secretKey, '');
        expect(config.useSsl, true);
        expect(config.pathStyle, true);
        expect(config.connectTimeout, 30);
      });

      test('toJson + fromJson 往返保持不变', () {
        const original = S3Config(
          endpoint: 'https://s3.amazonaws.com',
          bucket: 'my-bucket',
          region: 'eu-west-1',
          accessKey: 'key',
          secretKey: 'secret',
          useSsl: false,
          pathStyle: false,
          connectTimeout: 60,
        );
        final restored = S3Config.fromJson(original.toJson());
        expect(restored.endpoint, original.endpoint);
        expect(restored.bucket, original.bucket);
        expect(restored.region, original.region);
        expect(restored.accessKey, original.accessKey);
        expect(restored.secretKey, original.secretKey);
        expect(restored.useSsl, original.useSsl);
        expect(restored.pathStyle, original.pathStyle);
        expect(restored.connectTimeout, original.connectTimeout);
      });
    });
  });

  group('S3SyncProgress', () {
    test('默认构造函数', () {
      const progress = S3SyncProgress();
      expect(progress.status, S3SyncStatus.idle);
      expect(progress.completed, 0);
      expect(progress.total, 0);
      expect(progress.errorMessage, isNull);
    });

    test('构造函数接受所有参数', () {
      const progress = S3SyncProgress(
        status: S3SyncStatus.error,
        completed: 5,
        total: 10,
        errorMessage: 'Connection failed',
      );
      expect(progress.status, S3SyncStatus.error);
      expect(progress.completed, 5);
      expect(progress.total, 10);
      expect(progress.errorMessage, 'Connection failed');
    });

    group('fraction', () {
      test('total 为 0 时返回 null', () {
        const progress = S3SyncProgress(completed: 5, total: 0);
        expect(progress.fraction, isNull);
      });

      test('正常计算分数', () {
        const progress = S3SyncProgress(completed: 5, total: 10);
        expect(progress.fraction, 0.5);
      });

      test('完成时返回 1.0', () {
        const progress = S3SyncProgress(completed: 10, total: 10);
        expect(progress.fraction, 1.0);
      });

      test('未开始时返回 0.0', () {
        const progress = S3SyncProgress(completed: 0, total: 10);
        expect(progress.fraction, 0.0);
      });
    });
  });

  group('S3SyncStatus', () {
    test('包含所有预期状态', () {
      expect(S3SyncStatus.values, contains(S3SyncStatus.idle));
      expect(S3SyncStatus.values, contains(S3SyncStatus.uploading));
      expect(S3SyncStatus.values, contains(S3SyncStatus.downloading));
      expect(S3SyncStatus.values, contains(S3SyncStatus.error));
    });
  });
}
