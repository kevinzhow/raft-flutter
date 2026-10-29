// Which staging folders "Clear cache" may remove: the ones the step 3 sweep
// knows (cache_staging.dart), in the staging directory and in the legacy
// temporary directory, only when nothing is using them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/cache_staging.dart';

void touch(String path, Duration age) {
  final t = DateTime.now().subtract(age);
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}'
      '${two(t.minute)}.${two(t.second)}';
  expect(Process.runSync('touch', ['-t', stamp, path]).exitCode, 0);
}

void main() {
  late Directory root, staging, legacy;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-staging-clear');
    staging = await Directory(p.join(root.path, 'staging')).create();
    legacy = await Directory(p.join(root.path, 'temp')).create();
  });
  tearDown(() => root.delete(recursive: true));

  Directory folder(
    Directory parent,
    String name, {
    Duration old = const Duration(hours: 1),
  }) {
    final directory = Directory(p.join(parent.path, name))
      ..createSync(recursive: true);
    final file = File(p.join(directory.path, 'f.bin'))..writeAsBytesSync([1]);
    touch(file.path, old);
    touch(directory.path, old);
    return directory;
  }

  Future<int> clear() =>
      clearStaging(staging: staging, legacyTemporary: legacy);

  test('removes idle staging in both places and nothing else', () async {
    final gone = [
      folder(staging, 'raft-previews/preview-a'),
      folder(staging, 'raft-share/share-b'),
      folder(staging, 'raft-attachment-1'),
      folder(legacy, 'raft-export-2'),
      folder(legacy, 'raft-gallery-3'),
      folder(legacy, 'raft-previews/preview-old'),
    ];
    final kept = [
      folder(legacy, 'raft-incoming/session'),
      folder(staging, 'raft-incoming/session'),
      folder(legacy, 'raft-attachments/v2/abc'),
      folder(legacy, 'flutter_tool_thing'),
    ];
    expect(await clear(), 6);
    for (final directory in gone) {
      expect(directory.existsSync(), isFalse, reason: directory.path);
    }
    for (final directory in kept) {
      expect(directory.existsSync(), isTrue, reason: directory.path);
    }
  });

  test('keeps a held folder until its owner lets go', () async {
    final leased = folder(staging, 'raft-previews/preview-leased');
    final release = holdStaging(leased.path);
    final second = holdStaging(leased.path);
    expect(await clear(), 0);
    release();
    expect(await clear(), 0, reason: 'a second holder');
    second();
    expect(await clear(), 1);
    expect(leased.existsSync(), isFalse);
  });

  test('keeps a folder written within the fresh window', () async {
    final running = folder(
      staging,
      'raft-export-now',
      old: const Duration(minutes: 1),
    );
    expect(await clear(), 0);
    expect(running.existsSync(), isTrue);
    touch(running.path, const Duration(minutes: 10));
    touch(p.join(running.path, 'f.bin'), const Duration(minutes: 10));
    expect(await clear(), 1);
  });

  test('a missing directory is not an error', () async {
    expect(
      await clearStaging(
        staging: Directory(p.join(root.path, 'nope')),
        legacyTemporary: Directory(p.join(root.path, 'nope2')),
      ),
      0,
    );
  });
}
