import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/services/s3_sync_service.dart';

void main() {
  group('S3SyncService.friendlyError', () {
    test('SocketException 网络错误 → 友好文案带重试说明', () {
      final s = S3SyncService.friendlyError(
        const SocketException(
          'Failed host lookup: s3-cn-south-1.qiniucs.com '
          '(OS Error: No address associated with hostname, errno = 7)',
        ),
      );
      expect(s, contains('网络连接失败'));
      expect(s, contains('已完成的同步'));
      expect(s.contains('再次点同步') || s.contains('重试可继续'), isTrue);
    });

    test('ClientException 字面错误（含 SocketException 字串）也能命中', () {
      final s = S3SyncService.friendlyError(
        Exception('ClientException with SocketException: Failed host lookup'),
      );
      expect(s, contains('网络连接失败'));
    });

    test('凭证类错误走另一分支', () {
      final s = S3SyncService.friendlyError(
        Exception('AccessDenied: bad credentials'),
      );
      expect(s, contains('S3 凭证'));
    });

    test('未知错误仍能回退到原始信息', () {
      final raw = Exception('some weird thing');
      final s = S3SyncService.friendlyError(raw);
      expect(s, contains('同步失败'));
      expect(s, contains('some weird thing'));
    });
  });
}