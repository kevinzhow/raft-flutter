import 'dart:io';
import 'dart:typed_data';

import 'md4.dart';
import 'zsync_control.dart';

/// Where each block of the new file can be copied from in the file we already
/// have: [source] holds the byte offset of an identical block in the seed, or
/// -1 when the block has to be downloaded.
class ZsyncMatch {
  const ZsyncMatch(this.source, this.matchedBlocks);
  final Int64List source;
  final int matchedBlocks;
}

/// Finds the blocks of [control]'s target that already exist, at any byte
/// offset, in the file at [seedPath]: zsync's rolling-checksum search.
///
/// Synchronous and CPU-bound; run it in an isolate. [progress] receives the
/// scanned fraction (0..1) now and then.
ZsyncMatch matchSeed(
  String seedPath,
  ZsyncControl control, {
  void Function(double fraction)? progress,
}) {
  final file = File(seedPath).openSync();
  try {
    return _Matcher(file, control, progress).run();
  } finally {
    file.closeSync();
  }
}

class _Matcher {
  _Matcher(this._file, this._c, this._progress)
    : _bs = _c.blockSize,
      _cl = _c.checksumBytes,
      _mask = _c.weakMask,
      _fullBlocks = _c.length % _c.blockSize == 0
          ? _c.blockCount
          : _c.blockCount - 1;

  static const int _chunk = 8 << 20;

  final RandomAccessFile _file;
  final ZsyncControl _c;
  final void Function(double fraction)? _progress;
  final int _bs, _cl, _mask, _fullBlocks;
  final Md4 _md4 = Md4();

  late final int _seedLength = _file.lengthSync();
  late final Uint8List _buffer = Uint8List(_chunk + 2 * _bs);
  late final Uint8List _scratch = Uint8List(_bs);
  int _base = 0, _bufferLength = 0;

  late final int _seq = _c.sequenceMatches == 2 && _fullBlocks >= 2 ? 2 : 1;
  late final Int64List _source = Int64List(_c.blockCount)
    ..fillRange(0, _c.blockCount, -1);

  // Open-addressing table of block indexes (+1), keyed by the rsum of the
  // block (and of its successor when two matches in a row are required).
  late final int _tableBits = _bits(_fullBlocks * 2);
  late final Int32List _table = Int32List(1 << _tableBits);
  late final int _filterBits = (_tableBits + 6).clamp(16, 27);
  late final Uint8List _filter = Uint8List(1 << (_filterBits - 3));

  static int _bits(int n) {
    var bits = 4;
    while ((1 << bits) < n) {
      bits++;
    }
    return bits;
  }

  static int _hash(int first, int second) =>
      ((first * 0x9E3779B1) ^ (second * 0x85EBCA6B) ^ (first >>> 7)) &
      0xffffffff;

  ZsyncMatch run() {
    if (_fullBlocks == 0 || _seedLength < _seq * _bs) {
      return ZsyncMatch(_source, 0);
    }
    _index();
    _scan();
    final matched = _shareDuplicates();
    return ZsyncMatch(_source, matched);
  }

  int _second(int i) => _seq == 2 ? _c.weak[i + 1] : 0;

  void _index() {
    final last = _seq == 2 ? _fullBlocks - 1 : _fullBlocks;
    final cl = _cl;
    for (var i = 0; i < last; i++) {
      final first = _c.weak[i], second = _second(i);
      final hash = _hash(first, second);
      var slot = hash >>> (32 - _tableBits);
      var duplicate = false;
      while (_table[slot] != 0) {
        final other = _table[slot] - 1;
        if (_c.weak[other] == first && _second(other) == second) {
          var same = true;
          for (var k = 0; k < cl; k++) {
            if (_c.strong[other * cl + k] != _c.strong[i * cl + k]) {
              same = false;
              break;
            }
          }
          if (same) {
            duplicate = true;
            break;
          }
        }
        slot = (slot + 1) & ((1 << _tableBits) - 1);
      }
      if (duplicate) continue;
      _table[slot] = i + 1;
      final bit = hash >>> (32 - _filterBits);
      _filter[bit >> 3] |= 1 << (bit & 7);
    }
  }

  void _load(int at) {
    final want = (_seedLength - at) < _buffer.length
        ? _seedLength - at
        : _buffer.length;
    _file.setPositionSync(at);
    var read = 0;
    while (read < want) {
      final n = _file.readIntoSync(_buffer, read, want);
      if (n <= 0) break;
      read += n;
    }
    _base = at;
    _bufferLength = read;
  }

  /// Rolling-sum state of the two windows (see [_scan]).
  int _a1 = 0, _b1 = 0, _a2 = 0, _b2 = 0;

  void _initWindows(int rel) {
    var a = 0, b = 0;
    for (var i = 0; i < _bs; i++) {
      a += _buffer[rel + i];
      b += a;
    }
    _a1 = a & 0xffff;
    _b1 = b & 0xffff;
    if (_seq == 2) {
      a = 0;
      b = 0;
      for (var i = 0; i < _bs; i++) {
        a += _buffer[rel + _bs + i];
        b += a;
      }
      _a2 = a & 0xffff;
      _b2 = b & 0xffff;
    }
  }

  void _scan() {
    final bs = _bs, seq = _seq, mask = _mask, span = _seq * _bs;
    final tableMask = (1 << _tableBits) - 1;
    final cl = _cl;
    var x = 0;
    var reports = 0;
    while (x + span <= _seedLength) {
      _load(x);
      if (_bufferLength < span) break;
      var rel = 0;
      _initWindows(0);
      var a1 = _a1, b1 = _b1, a2 = _a2, b2 = _b2;
      final buffer = _buffer;
      var reload = false;
      while (true) {
        final first = ((a1 << 16) | b1) & mask;
        final second = seq == 2 ? ((a2 << 16) | b2) & mask : 0;
        final hash = _hash(first, second);
        final bit = hash >>> (32 - _filterBits);
        if ((_filter[bit >> 3] & (1 << (bit & 7))) != 0) {
          var slot = hash >>> (32 - _tableBits);
          var next = -1;
          while (_table[slot] != 0) {
            final i = _table[slot] - 1;
            if (_c.weak[i] == first && _second(i) == second) {
              final digest = _md4.digest(buffer, rel, bs);
              var same = true;
              for (var k = 0; k < cl; k++) {
                if (digest[k] != _c.strong[i * cl + k]) {
                  same = false;
                  break;
                }
              }
              if (same) {
                next = _claim(i, x);
                break;
              }
            }
            slot = (slot + 1) & tableMask;
          }
          if (next >= 0) {
            x = next;
            reload = true;
            break;
          }
        }
        if (x + span >= _seedLength) {
          x = _seedLength;
          break;
        }
        if (rel + span >= _bufferLength) {
          x += 1;
          reload = true;
          break;
        }
        final out = buffer[rel], into = buffer[rel + bs];
        a1 = (a1 - out + into) & 0xffff;
        b1 = (b1 - bs * out + a1) & 0xffff;
        if (seq == 2) {
          final out2 = into, into2 = buffer[rel + span];
          a2 = (a2 - out2 + into2) & 0xffff;
          b2 = (b2 - bs * out2 + a2) & 0xffff;
        }
        rel++;
        x++;
      }
      if (!reload) break;
      if ((++reports & 7) == 0) _progress?.call(x / _seedLength);
    }
    _progress?.call(1);
  }

  /// Block [i] equals the seed at [at]; take it and every following block that
  /// also matches in place. Returns the seed offset after the last one.
  int _claim(int i, int at) {
    if (_source[i] < 0) _source[i] = at;
    var block = i + 1, position = at + _bs;
    while (block < _fullBlocks && position + _bs <= _seedLength) {
      final data = _window(position);
      var a = 0, b = 0;
      for (var k = 0; k < _bs; k++) {
        a += data.$1[data.$2 + k];
        b += a;
      }
      final rsum = (((a & 0xffff) << 16) | (b & 0xffff)) & _mask;
      if (rsum != _c.weak[block]) break;
      final digest = _md4.digest(data.$1, data.$2, _bs);
      var same = true;
      for (var k = 0; k < _cl; k++) {
        if (digest[k] != _c.strong[block * _cl + k]) {
          same = false;
          break;
        }
      }
      if (!same) break;
      if (_source[block] < 0) _source[block] = position;
      block++;
      position += _bs;
    }
    return position;
  }

  (Uint8List, int) _window(int position) {
    final rel = position - _base;
    if (rel >= 0 && rel + _bs <= _bufferLength) return (_buffer, rel);
    _file.setPositionSync(position);
    var read = 0;
    while (read < _bs) {
      final n = _file.readIntoSync(_scratch, read, _bs);
      if (n <= 0) break;
      read += n;
    }
    return (_scratch, 0);
  }

  /// Identical blocks elsewhere in the new file share one source; returns the
  /// number of blocks with a source.
  int _shareDuplicates() {
    final byContent = <int, List<int>>{};
    int key(int i) {
      final at = i * _cl;
      var tail = 0;
      for (var k = 0; k < _cl && k < 4; k++) {
        tail = (tail << 8) | _c.strong[at + k];
      }
      return (_c.weak[i] << 32) | tail;
    }

    bool same(int i, int j) {
      if (_c.weak[i] != _c.weak[j]) return false;
      for (var k = 0; k < _cl; k++) {
        if (_c.strong[i * _cl + k] != _c.strong[j * _cl + k]) return false;
      }
      return true;
    }

    for (var i = 0; i < _fullBlocks; i++) {
      if (_source[i] >= 0) byContent.putIfAbsent(key(i), () => []).add(i);
    }
    var matched = 0;
    for (var i = 0; i < _fullBlocks; i++) {
      if (_source[i] < 0) {
        for (final j in byContent[key(i)] ?? const <int>[]) {
          if (same(i, j)) {
            _source[i] = _source[j];
            break;
          }
        }
      }
      if (_source[i] >= 0) matched++;
    }
    return matched;
  }
}
