import 'dart:typed_data';

import 'zsync_control.dart';

/// A half-open byte range `[start, end)` of the new file.
class ByteRange {
  const ByteRange(this.start, this.end);
  final int start, end;
  int get length => end - start;

  @override
  String toString() => '[$start, $end)';
}

/// Copy [length] bytes from [seedOffset] of the old file to [targetOffset] of
/// the new one.
class SeedCopy {
  const SeedCopy(this.targetOffset, this.seedOffset, this.length);
  final int targetOffset, seedOffset, length;
}

/// What to reuse and what to fetch to turn the old file into the new one.
class ZsyncPlan {
  ZsyncPlan._(this.control, this.downloads, this.copies);

  /// [gap] merges two missing ranges closer than that many bytes into one
  /// request: the few reused bytes in between cost less than another round
  /// trip, and the response overwrites them with identical data.
  factory ZsyncPlan.build(
    ZsyncControl control,
    Int64List source, {
    int gap = 64 * 1024,
  }) {
    final size = control.blockSize;
    final missing = <ByteRange>[];
    for (var i = 0; i < control.blockCount; i++) {
      if (source[i] >= 0) continue;
      final start = i * size;
      final end = start + control.blockLength(i);
      if (missing.isNotEmpty && missing.last.end == start) {
        missing[missing.length - 1] = ByteRange(missing.last.start, end);
      } else {
        missing.add(ByteRange(start, end));
      }
    }
    final merged = <ByteRange>[];
    for (final range in missing) {
      if (merged.isNotEmpty && range.start - merged.last.end <= gap) {
        merged[merged.length - 1] = ByteRange(merged.last.start, range.end);
      } else {
        merged.add(range);
      }
    }
    final copies = <SeedCopy>[];
    var cursor = 0; // index into merged
    for (var i = 0; i < control.blockCount; i++) {
      final start = i * size;
      while (cursor < merged.length && merged[cursor].end <= start) {
        cursor++;
      }
      if (source[i] < 0 ||
          (cursor < merged.length && merged[cursor].start <= start)) {
        continue;
      }
      final length = control.blockLength(i);
      final last = copies.isEmpty ? null : copies.last;
      if (last != null &&
          last.targetOffset + last.length == start &&
          last.seedOffset + last.length == source[i]) {
        copies[copies.length - 1] = SeedCopy(
          last.targetOffset,
          last.seedOffset,
          last.length + length,
        );
      } else {
        copies.add(SeedCopy(start, source[i], length));
      }
    }
    return ZsyncPlan._(control, merged, copies);
  }

  final ZsyncControl control;

  /// Ranges to request, ascending.
  final List<ByteRange> downloads;

  /// Reused data, ascending; never overlaps a download.
  final List<SeedCopy> copies;

  int get downloadBytes =>
      downloads.fold(0, (sum, range) => sum + range.length);
  int get reusedBytes => copies.fold(0, (sum, copy) => sum + copy.length);

  /// [downloads] cut into pieces of at most [piece] bytes, so a few large
  /// ranges can still be fetched in parallel.
  List<ByteRange> pieces(int piece) => [
    for (final range in downloads)
      for (var at = range.start; at < range.end; at += piece)
        ByteRange(at, at + piece < range.end ? at + piece : range.end),
  ];
}
