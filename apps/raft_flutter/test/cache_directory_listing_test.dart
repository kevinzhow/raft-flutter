import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/data/cache_directory_listing.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-cache-listing');
  });
  tearDown(() => root.delete(recursive: true));

  for (final style in ['native', 'mixed separators', 'extended Windows']) {
    test(
      '$style keeps caller paths and entry types for long descendants',
      () async {
        final first = 'with spaces-测试-${'a' * 110}';
        final second = 'nested-${'b' * 110}';
        final leaf = await Directory(p.join(root.path, first, second))
            .create(recursive: true);
        await File(p.join(leaf.path, 'payload.bin')).writeAsBytes([1, 2, 3]);
        final input = switch (style) {
          'mixed separators' => Directory(root.path.replaceAll(r'\', '/')),
          'extended Windows' => Directory(r'\\?\' + root.path),
          _ => root,
        };
        final expected = {
          p.join(input.path, first),
          p.join(input.path, first, second),
          p.join(input.path, first, second, 'payload.bin'),
        };
        for (final entries in [
          await listCacheDirectory(input, recursive: true).toList(),
          listCacheDirectorySync(input, recursive: true).toList(),
        ]) {
          expect(entries.map((e) => e.path).toSet(), expected);
          expect(entries.whereType<Directory>(), hasLength(2));
          final file = entries.whereType<File>().single;
          expect(await file.readAsBytes(), [1, 2, 3]);
        }
        expect(
          (await listCacheDirectory(input).toList()).single.path,
          p.join(input.path, first),
        );
        expect(
          listCacheDirectorySync(input).single.path,
          p.join(input.path, first),
        );
      },
      skip: style == 'extended Windows' && !Platform.isWindows,
    );
  }

  test('a missing directory still reports its filesystem error', () async {
    final missing = Directory(p.join(root.path, 'missing'));
    await expectLater(
      listCacheDirectory(missing).toList(),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      () => listCacheDirectorySync(missing).toList(),
      throwsA(isA<FileSystemException>()),
    );
  });
}
