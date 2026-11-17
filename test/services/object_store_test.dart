import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/services/object_store.dart';

void main() {
  group('InMemoryObjectStore', () {
    test('putBytes/getBytes 往返', () async {
      final s = InMemoryObjectStore();
      await s.putBytes('a/b.json', Uint8List.fromList(utf8.encode('hi')));
      expect(await s.exists('a/b.json'), isTrue);
      expect(utf8.decode((await s.getBytes('a/b.json'))!), 'hi');
    });

    test('getBytes 不存在返回 null', () async {
      final s = InMemoryObjectStore();
      expect(await s.getBytes('nope'), isNull);
    });

    test('list 按前缀过滤', () async {
      final s = InMemoryObjectStore();
      await s.putBytes('memes/1.json', Uint8List(1));
      await s.putBytes('memes/2.json', Uint8List(1));
      await s.putBytes('albums/1.json', Uint8List(1));
      expect((await s.list('memes/'))..sort(),
          ['memes/1.json', 'memes/2.json']);
    });

    test('listWithSizes 返回 key 到字节长度的映射', () async {
      final s = InMemoryObjectStore();
      await s.putBytes('memes/1.json', Uint8List(3));
      await s.putBytes('memes/2.json', Uint8List(5));
      await s.putBytes('albums/1.json', Uint8List(1));
      expect(await s.listWithSizes('memes/'),
          {'memes/1.json': 3, 'memes/2.json': 5});
    });

    test('delete 幂等', () async {
      final s = InMemoryObjectStore();
      await s.putBytes('k', Uint8List(1));
      await s.delete('k');
      await s.delete('k');
      expect(await s.exists('k'), isFalse);
    });

    test('uploadFile/downloadToFile 往返', () async {
      final dir = await Directory.systemTemp.createTemp('os_test_');
      final src = File('${dir.path}/src.bin')..writeAsBytesSync([1, 2, 3]);
      final dst = '${dir.path}/dst.bin';
      final s = InMemoryObjectStore();
      await s.uploadFile('blob/x', src.path);
      await s.downloadToFile('blob/x', dst);
      expect(File(dst).readAsBytesSync(), [1, 2, 3]);
      await dir.delete(recursive: true);
    });
  });
}
