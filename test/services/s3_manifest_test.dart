import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/services/s3_manifest.dart';

void main() {
  test('Manifest JSON 往返', () {
    final m = Manifest(
      schema: Manifest.currentSchema,
      generatedAt: 100,
      lastWriter: 'devA',
      clock: 100,
      memes: {
        'm1': ManifestEntry(updatedAt: 100, deletedAt: null, hash: 'h1', ext: '.jpg'),
        'm2': ManifestEntry(updatedAt: 50, deletedAt: 60, hash: null, ext: null),
      },
      albums: {'a1': ManifestEntry(updatedAt: 10)},
      userStatsUpdatedAt: 80,
    );
    final m2 = Manifest.fromJson(m.toJson());
    expect(m2.schema, 2);
    expect(m2.memes['m1']!.hash, 'h1');
    expect(m2.memes['m2']!.deletedAt, 60);
    expect(m2.albums['a1']!.updatedAt, 10);
    expect(m2.userStatsUpdatedAt, 80);
    expect(m2.maxUpdatedAt(), 100);
  });

  test('空 manifest 的 maxUpdatedAt 为 0', () {
    final m = Manifest.empty();
    expect(m.maxUpdatedAt(), 0);
  });
}
