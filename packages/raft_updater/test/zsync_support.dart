import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:raft_updater/src/appimage/md4.dart';

/// xorshift32 byte stream; `tool`-side fixture generation uses the same one:
///
/// ```python
/// def prng(seed, n):
///     out = bytearray(n); x = seed
///     for i in range(n):
///         x ^= (x << 13) & 0xffffffff; x ^= x >> 17; x ^= (x << 5) & 0xffffffff
///         out[i] = x & 0xff
///     return bytes(out)
/// ```
Uint8List prng(int seed, int length) {
  final out = Uint8List(length);
  var x = seed;
  for (var i = 0; i < length; i++) {
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    out[i] = x & 0xff;
  }
  return out;
}

Uint8List concat(List<List<int>> parts) =>
    Uint8List.fromList([for (final part in parts) ...part]);

/// The pair `delta_fixture_*.zsync` was generated from (`zsyncmake -b 2048`).
({Uint8List old, Uint8List current}) fixturePair() {
  const size = 1500000;
  final old = prng(12345, size);
  final current = concat([
    old.sublist(0, size ~/ 4),
    prng(777, 5000),
    old.sublist(size ~/ 4, size ~/ 2),
    prng(999, 3000),
    old.sublist(size ~/ 2 + 7000),
    prng(4242, 1234),
  ]);
  return (old: old, current: current);
}

/// A `.zsync` control file for [data] like zsyncmake writes, with chosen hash
/// lengths so every parser/matcher variant can be exercised.
Uint8List makeZsync(
  Uint8List data, {
  required String url,
  int blockSize = 2048,
  int sequence = 2,
  int rsumBytes = 2,
  int checksumBytes = 4,
  Map<String, String> extra = const {},
}) {
  final blocks = (data.length + blockSize - 1) ~/ blockSize;
  final header = StringBuffer()
    ..write('zsync: 0.6.2\nFilename: $url\nBlocksize: $blockSize\n')
    ..write('Length: ${data.length}\n')
    ..write('Hash-Lengths: $sequence,$rsumBytes,$checksumBytes\nURL: $url\n')
    ..write('SHA-1: ${sha1.convert(data)}\n');
  extra.forEach((key, value) => header.write('$key: $value\n'));
  header.write('\n');
  final out = BytesBuilder()..add(utf8.encode(header.toString()));
  final md4 = Md4();
  for (var i = 0; i < blocks; i++) {
    final block = Uint8List(blockSize);
    final end = (i + 1) * blockSize > data.length
        ? data.length
        : (i + 1) * blockSize;
    block.setRange(0, end - i * blockSize, data, i * blockSize);
    var a = 0, b = 0;
    for (final byte in block) {
      a += byte;
      b += a;
    }
    final rsum = ((a & 0xffff) << 16) | (b & 0xffff);
    for (var k = rsumBytes - 1; k >= 0; k--) {
      out.addByte((rsum >> (8 * k)) & 0xff);
    }
    out.add(md4.digest(block, 0, blockSize).sublist(0, checksumBytes));
  }
  return out.toBytes();
}
