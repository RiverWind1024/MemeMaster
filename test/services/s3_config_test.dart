import 'package:flutter_test/flutter_test.dart';
import 'package:meme_helper/services/s3_config.dart';

void main() {
  group('S3Config', () {
    test('default config is invalid', () {
      const config = S3Config();
      expect(config.isValid, isFalse);
    });

    test('valid when all fields set', () {
      const config = S3Config(
        endpoint: 's3.amazonaws.com',
        bucket: 'my-bucket',
        accessKey: 'AKID',
        secretKey: 'secret',
      );
      expect(config.isValid, isTrue);
    });

    test('invalid when endpoint is empty', () {
      const config = S3Config(
        endpoint: '',
        bucket: 'my-bucket',
        accessKey: 'AKID',
        secretKey: 'secret',
      );
      expect(config.isValid, isFalse);
    });

    test('invalid when bucket is empty', () {
      const config = S3Config(
        endpoint: 's3.amazonaws.com',
        bucket: '',
        accessKey: 'AKID',
        secretKey: 'secret',
      );
      expect(config.isValid, isFalse);
    });

    test('copyWith overrides specific fields', () {
      const config = S3Config(
        endpoint: 'old.com',
        bucket: 'bucket',
        accessKey: 'AKID',
        secretKey: 'secret',
      );
      final updated = config.copyWith(endpoint: 'new.com');
      expect(updated.endpoint, 'new.com');
      expect(updated.bucket, 'bucket');
    });

    test('copyWith preserves other fields', () {
      const config = S3Config(
        endpoint: 's3.amazonaws.com',
        bucket: 'bucket',
        region: 'us-east-1',
        accessKey: 'AKID',
        secretKey: 'secret',
      );
      final updated = config.copyWith(region: 'eu-west-1');
      expect(updated.region, 'eu-west-1');
      expect(updated.accessKey, 'AKID');
      expect(updated.secretKey, 'secret');
    });
  });

  group('S3SyncProgress', () {
    test('fraction is null when total is 0', () {
      const progress = S3SyncProgress();
      expect(progress.fraction, isNull);
    });

    test('fraction is 0 when completed is 0', () {
      const progress = S3SyncProgress(completed: 0, total: 10);
      expect(progress.fraction, 0.0);
    });

    test('fraction is 0.5 when half done', () {
      const progress = S3SyncProgress(completed: 5, total: 10);
      expect(progress.fraction, 0.5);
    });

    test('fraction is 1.0 when complete', () {
      const progress = S3SyncProgress(completed: 10, total: 10);
      expect(progress.fraction, 1.0);
    });
  });
}
