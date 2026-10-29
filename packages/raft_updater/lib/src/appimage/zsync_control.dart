import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// A `.zsync` control file (zsync 0.6.x format, written by `zsyncmake`): a
/// text header, a blank line, then for every block of the target file its
/// rolling checksum (the last [rsumBytes] bytes of the big-endian 32-bit
/// rsum) and the first [checksumBytes] bytes of its MD4.
@immutable
class ZsyncControl {
  const ZsyncControl._({
    required this.fileName,
    required this.url,
    required this.length,
    required this.blockSize,
    required this.sequenceMatches,
    required this.rsumBytes,
    required this.checksumBytes,
    required this.sha1,
    required this.blockCount,
    required this.weak,
    required this.strong,
  });

  final String fileName;

  /// The `URL:` header: the target file, relative to the control file's URL or
  /// absolute.
  final String url;

  /// Size of the file the control file describes.
  final int length;
  final int blockSize;

  /// Hash-Lengths: how many consecutive blocks must match their rsum before
  /// a candidate is verified (1 or 2), rsum bytes per block (1-4) and MD4
  /// bytes per block (1-16).
  final int sequenceMatches, rsumBytes, checksumBytes;

  /// Lowercase hex SHA-1 of the whole target file.
  final String sha1;
  final int blockCount;

  /// The stored rsum of every block (low [rsumBytes] bytes of `a << 16 | b`).
  final Uint32List weak;

  /// The stored MD4 prefixes, [checksumBytes] per block, back to back.
  final Uint8List strong;

  /// Parses [bytes]; throws [FormatException] naming the problem otherwise.
  static ZsyncControl parse(Uint8List bytes) {
    var end = -1;
    for (var i = 0; i + 1 < bytes.length && i < 16384; i++) {
      if (bytes[i] == 10 && bytes[i + 1] == 10) {
        end = i;
        break;
      }
    }
    if (end < 0) throw const FormatException('The .zsync file has no header.');
    final fields = <String, String>{};
    for (final line in utf8.decode(bytes.sublist(0, end)).split('\n')) {
      final colon = line.indexOf(': ');
      if (colon > 0) {
        fields[line.substring(0, colon)] = line.substring(colon + 2);
      }
    }
    if (fields.containsKey('Z-URL') || fields.containsKey('Z-Map2')) {
      throw const FormatException(
        'Compressed .zsync targets are not supported.',
      );
    }
    final length = int.tryParse(fields['Length'] ?? '');
    final blockSize = int.tryParse(fields['Blocksize'] ?? '');
    final lengths = (fields['Hash-Lengths'] ?? '')
        .split(',')
        .map(int.tryParse)
        .toList();
    final sha1 = (fields['SHA-1'] ?? '').toLowerCase();
    final url = fields['URL'];
    if (length == null ||
        length <= 0 ||
        blockSize == null ||
        blockSize < 512 ||
        blockSize & (blockSize - 1) != 0 ||
        lengths.length != 3 ||
        lengths.contains(null) ||
        url == null ||
        url.isEmpty ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(sha1)) {
      throw const FormatException('The .zsync header is incomplete.');
    }
    final sequence = lengths[0]!, rsum = lengths[1]!, checksum = lengths[2]!;
    if (sequence < 1 ||
        sequence > 2 ||
        rsum < 1 ||
        rsum > 4 ||
        checksum < 1 ||
        checksum > 16) {
      throw const FormatException('The .zsync hash lengths are unsupported.');
    }
    final blocks = (length + blockSize - 1) ~/ blockSize;
    final rowBytes = rsum + checksum;
    final tableStart = end + 2;
    if (bytes.length - tableStart != blocks * rowBytes) {
      throw const FormatException('The .zsync block table has the wrong size.');
    }
    final weak = Uint32List(blocks);
    final strong = Uint8List(blocks * checksum);
    for (var i = 0; i < blocks; i++) {
      final row = tableStart + i * rowBytes;
      var value = 0;
      for (var j = 0; j < rsum; j++) {
        value = (value << 8) | bytes[row + j];
      }
      weak[i] = value;
      strong.setRange(i * checksum, (i + 1) * checksum, bytes, row + rsum);
    }
    return ZsyncControl._(
      fileName: fields['Filename'] ?? '',
      url: url,
      length: length,
      blockSize: blockSize,
      sequenceMatches: sequence,
      rsumBytes: rsum,
      checksumBytes: checksum,
      sha1: sha1,
      blockCount: blocks,
      weak: weak,
      strong: strong,
    );
  }

  /// Mask applied to a computed 32-bit rsum before comparing it with [weak].
  int get weakMask => rsumBytes == 4 ? 0xffffffff : (1 << (8 * rsumBytes)) - 1;

  /// Bytes of block [index] in the target (the last block may be shorter).
  int blockLength(int index) =>
      index == blockCount - 1 ? length - index * blockSize : blockSize;
}
