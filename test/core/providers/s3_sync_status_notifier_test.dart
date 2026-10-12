import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/features/gallery/gallery_provider.dart';
import 'package:mememaster/services/s3_config.dart';

void main() {
  group('s3SyncStatusNotifier', () {
    test('启动同步会把状态置为 uploading/idle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(s3SyncStatusProvider.notifier);

      final completer = Completer<void>();
      final stream = Stream<S3SyncProgress>.multi((controller) async {
        controller.add(const S3SyncProgress(
            status: S3SyncStatus.uploading, completed: 0, total: 1));
        await completer.future;
        controller.add(const S3SyncProgress(
            status: S3SyncStatus.idle,
            completed: 1,
            total: 1,
            summary: '完成'));
        await controller.close();
      });

      expect(container.read(s3SyncStatusProvider).status, S3SyncStatus.idle);
      final started = await notifier.start(() => stream);
      expect(started, isTrue);

      // yield 已被 awaitFuture 处理：state 应已变 uploading。
      await Future<void>.delayed(Duration.zero);
      expect(container.read(s3SyncStatusProvider).status,
          S3SyncStatus.uploading);

      // 收尾
      completer.complete();
      // 等待内部 cleanup 完成
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(s3SyncStatusProvider).status, S3SyncStatus.idle);
      expect(container.read(s3SyncStatusProvider).summary, '完成');
    });

    test('连续两次 start 第二次返回 false，互斥', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(s3SyncStatusProvider.notifier);

      // 第一条 stream 故意不结束（用来证明第二次被拒绝）。
      final firstCtrl = StreamController<S3SyncProgress>();
      final started1 = await notifier.start(() => firstCtrl.stream);
      expect(started1, isTrue);

      // 第二次启动：用同一种 stream factory。
      final secondCtrl = StreamController<S3SyncProgress>();
      final started2 = await notifier.start(() => secondCtrl.stream);
      expect(started2, isFalse, reason: '第一次同步还在跑，第二次应被拒绝');

      // 收尾：关掉第一个 stream 让内部 cleanup 跑。
      firstCtrl.add(const S3SyncProgress(status: S3SyncStatus.idle));
      await firstCtrl.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 现在第二次应能启动。
      final started3 = await notifier.start(() => secondCtrl.stream);
      expect(started3, isTrue);
      secondCtrl.add(const S3SyncProgress(status: S3SyncStatus.idle));
      await secondCtrl.close();
    });

    test('stream onError 时进入 error 态，且 inFlight 被释放', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(s3SyncStatusProvider.notifier);

      // ignore: unused_local_variable
      final _ = notifier.start(() => Stream<S3SyncProgress>.fromFutures([
            Future.error(StateError('boom')),
          ]));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(s3SyncStatusProvider).status, S3SyncStatus.error);
      expect(container.read(s3SyncStatusProvider).errorMessage,
          contains('boom'));

      // 同步已结束，第二次能启动。
      final ctrl = StreamController<S3SyncProgress>();
      final started = await notifier.start(() => ctrl.stream);
      expect(started, isTrue);
      ctrl.add(const S3SyncProgress(status: S3SyncStatus.idle));
      await ctrl.close();
    });
  });
}