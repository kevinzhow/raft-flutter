import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_updater/src/appimage/md4.dart';
import 'package:raft_updater/src/appimage/zsync_control.dart';
import 'package:raft_updater/src/appimage/zsync_matcher.dart';

import 'zsync_support.dart';

/// The gate runs package tests from `apps/raft_flutter`, a package's own
/// `flutter test` from the package directory: find the fixture from either.
Uint8List _deltaControl() => File(
  [
    'test/fixtures/delta_fixture_2048.zsync',
    'packages/raft_updater/test/fixtures/delta_fixture_2048.zsync',
    '../../packages/raft_updater/test/fixtures/delta_fixture_2048.zsync',
  ].firstWhere((path) => File(path).existsSync()),
).readAsBytesSync();

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('MD4 matches the RFC 1320 test suite', () {
    const vectors = {
      '': '31d6cfe0d16ae931b73c59d7e0c089c0',
      'a': 'bde52cb31de33e46245e05fbdbd6fb24',
      'abc': 'a448017aaf21d8525fc10ae87aa6729d',
      'message digest': 'd9130a8164549fe818874806e1c7014b',
      'abcdefghijklmnopqrstuvwxyz': 'd79e1c308aa5bbcdeea8ed63df412da9',
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789':
          '043f8582f241db351ce627e153e7f0e4',
      '12345678901234567890123456789012345678901234567890123456789012345678901234567890':
          'e33b4ddc9c38f2199c3e7b164fcc0536',
    };
    final md4 = Md4();
    vectors.forEach((text, expected) {
      final data = Uint8List.fromList(utf8.encode(text));
      expect(_hex(md4.digest(data, 0, data.length)), expected, reason: text);
    });
    // An offset inside a larger buffer.
    final data = Uint8List.fromList(utf8.encode('xxabcxx'));
    expect(_hex(md4.digest(data, 2, 3)), 'a448017aaf21d8525fc10ae87aa6729d');
  });

  group('control file', () {
    final real = _deltaControl();

    test('reads what zsyncmake 0.6.2 wrote', () {
      final control = ZsyncControl.parse(real);
      final pair = fixturePair();
      expect(control.length, pair.current.length);
      expect(control.blockSize, 2048);
      expect(
        (control.sequenceMatches, control.rsumBytes, control.checksumBytes),
        (2, 2, 4),
      );
      expect(control.blockCount, (pair.current.length + 2047) ~/ 2048);
      expect(control.url, 'new.bin');
      expect(
        control.blockLength(control.blockCount - 1),
        pair.current.length % 2048,
      );
    });

    test('a control file made here has the same bytes as the real one', () {
      // Proves rsum byte order, zero-padding of the last block and MD4 prefixes
      // against zsyncmake itself (the header's MTime line aside).
      final made = makeZsync(fixturePair().current, url: 'new.bin');
      expect(made.sublist(_tableStart(made)), real.sublist(_tableStart(real)));
    });

    test('rejects malformed, truncated and compressed control files', () {
      final cases = <String, Uint8List>{
        'no header': Uint8List.fromList(utf8.encode('zsync: 0.6.2\nLength: 1')),
        'truncated table': real.sublist(0, real.length - 3),
        'extra table bytes': Uint8List.fromList([...real, 1]),
        'compressed': makeZsync(
          prng(1, 5000),
          url: 'x',
          extra: {'Z-URL': 'x.gz'},
        ),
        'bad hash lengths': Uint8List.fromList(
          latin1.encode(latin1.decode(real).replaceFirst('2,2,4', '2,9,4')),
        ),
      };
      cases.forEach((name, bytes) {
        expect(
          () => ZsyncControl.parse(bytes),
          throwsFormatException,
          reason: name,
        );
      });
    });
  });

  group('seed matching', () {
    late Directory directory;
    setUp(() => directory = Directory.systemTemp.createTempSync('zsync-test'));
    tearDown(() => directory.deleteSync(recursive: true));

    /// Every block the matcher claims must really exist at that seed offset.
    int checkMatches(
      Uint8List seed,
      Uint8List target,
      ZsyncControl control,
      ZsyncMatch match,
    ) {
      var count = 0;
      for (var i = 0; i < control.blockCount; i++) {
        final at = match.source[i];
        if (at < 0) continue;
        count++;
        final length = control.blockLength(i);
        expect(
          seed.sublist(at, at + length),
          target.sublist(i * control.blockSize, i * control.blockSize + length),
          reason: 'block $i claimed at $at',
        );
      }
      return count;
    }

    ZsyncMatch run(Uint8List seed, ZsyncControl control) {
      final file = File('${directory.path}/seed')..writeAsBytesSync(seed);
      return matchSeed(file.path, control);
    }

    test('finds shifted blocks around an insertion and a replacement', () {
      final pair = fixturePair();
      final control = ZsyncControl.parse(_deltaControl());
      final watch = Stopwatch()..start();
      final match = run(pair.old, control);
      final matched = checkMatches(pair.old, pair.current, control, match);
      // 5000 + 3000 + 7000 + 1234 changed bytes touch at most ~12 blocks each
      // side; everything else (1.49 MB) must be reused.
      final unmatched = control.blockCount - matched;
      expect(
        unmatched,
        lessThan(25),
        reason: '$unmatched of ${control.blockCount} blocks',
      );
      expect(match.matchedBlocks, matched);
      printOnFailure('scan ${watch.elapsedMilliseconds} ms');
    });

    for (final variant in [
      (seq: 1, rsum: 2, checksum: 4, block: 1024),
      (seq: 1, rsum: 3, checksum: 5, block: 2048),
      (seq: 2, rsum: 4, checksum: 16, block: 4096),
      (seq: 2, rsum: 1, checksum: 8, block: 512),
    ]) {
      test(
        'hash lengths ${variant.seq},${variant.rsum},${variant.checksum} at ${variant.block}',
        () {
          final pair = fixturePair();
          final control = ZsyncControl.parse(
            makeZsync(
              pair.current,
              url: 'n',
              blockSize: variant.block,
              sequence: variant.seq,
              rsumBytes: variant.rsum,
              checksumBytes: variant.checksum,
            ),
          );
          final match = run(pair.old, control);
          final matched = checkMatches(pair.old, pair.current, control, match);
          // A one-byte weak sum only filters; the MD4 prefix still decides.
          expect(
            control.blockCount - matched,
            lessThan(control.blockCount * 0.05),
          );
        },
      );
    }

    test('an unrelated seed matches nothing and a seed equal to the target matches everything', () {
      final pair = fixturePair();
      final control = ZsyncControl.parse(makeZsync(pair.current, url: 'n'));
      expect(run(prng(5, 400000), control).matchedBlocks, 0);
      final whole = run(pair.current, control);
      // The short last block is always downloaded.
      expect(whole.matchedBlocks, control.blockCount - 1);
      expect(
        checkMatches(pair.current, pair.current, control, whole),
        control.blockCount - 1,
      );
    });

    test('identical blocks in the target share one source', () {
      final first = prng(3, 2048), second = prng(4, 2048);
      final target = concat([
        first,
        second,
        prng(8, 2048),
        first,
        second,
        prng(9, 2048),
      ]);
      final seed = concat([prng(11, 100), first, second, prng(12, 77)]);
      final control = ZsyncControl.parse(makeZsync(target, url: 'n'));
      final match = run(seed, control);
      expect(match.source.sublist(0, 6), [100, 2148, -1, 100, 2148, -1]);
      expect(match.matchedBlocks, 4);
    });

    test('seeds smaller than the window and empty seeds are safe', () {
      final control = ZsyncControl.parse(makeZsync(prng(1, 9000), url: 'n'));
      expect(run(Uint8List(0), control).matchedBlocks, 0);
      expect(run(prng(2, 3000), control).matchedBlocks, 0);
    });
  });
}

int _tableStart(Uint8List bytes) {
  for (var i = 0; i + 1 < bytes.length; i++) {
    if (bytes[i] == 10 && bytes[i + 1] == 10) return i + 2;
  }
  return 0;
}
