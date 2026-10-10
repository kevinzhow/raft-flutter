import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// QR Code Model 2 encoder, a line-for-line port of the `uqr` package the Web
/// client uses (itself Nayuki's reference "QR Code generator library"):
/// numeric / alphanumeric / byte segment selection, error correction level
/// L by default without boosting, automatic mask choice by the standard
/// penalty score. Same input, same options -> the same module matrix as
/// `encode(url, { border: 1 })` in MobileDownloadQr.tsx.
class RaftQrMatrix {
  RaftQrMatrix._(this.size, this.modules, this.version, this.mask);

  /// Modules per side, border included.
  final int size;

  /// `modules[y][x]`, true = dark.
  final List<List<bool>> modules;
  final int version, mask;

  bool dark(int x, int y) => modules[y][x];

  factory RaftQrMatrix.encode(
    String text, {
    RaftQrEcc ecc = RaftQrEcc.low,
    int border = 1,
  }) {
    final qr = _encodeSegments(_makeSegments(text), ecc);
    final size = qr.size + border * 2;
    final rows = [
      for (var y = 0; y < size; y++)
        [
          for (var x = 0; x < size; x++)
            x >= border &&
                y >= border &&
                x < size - border &&
                y < size - border &&
                qr.modules[y - border][x - border],
        ],
    ];
    return RaftQrMatrix._(size, rows, qr.version, qr.mask);
  }
}

/// Error correction level: [ordinal, format bits].
enum RaftQrEcc {
  low(0, 1),
  medium(1, 0),
  quartile(2, 3),
  high(3, 2);

  const RaftQrEcc(this.ordinal, this.formatBits);
  final int ordinal, formatBits;
}

// dart format off
const _eccCodewordsPerBlock = [
  [-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
  [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
  [-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
  [-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
];
const _numErrorCorrectionBlocks = [
  [-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
  [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
  [-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
  [-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81],
];
// dart format on
const _penaltyN1 = 3, _penaltyN2 = 3, _penaltyN3 = 40, _penaltyN4 = 10;
const _alphanumericCharset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ \$%*+-./:';
final _numeric = RegExp(r'^\d*$');
final _alphanumeric = RegExp(r'^[A-Z0-9 $%*+./:-]*$');

bool _bit(int x, int i) => ((x >> i) & 1) != 0;

void _appendBits(int value, int length, List<int> bits) {
  for (var i = length - 1; i >= 0; i--) {
    bits.add((value >> i) & 1);
  }
}

class _Segment {
  _Segment(this.mode, this.chars, this.data);

  /// [mode indicator, char count bits for versions 1-9, 10-26, 27-40].
  final List<int> mode;
  final int chars;
  final List<int> data;
}

const _modeNumeric = [1, 10, 12, 14];
const _modeAlphanumeric = [2, 9, 11, 13];
const _modeByte = [4, 8, 16, 16];

int _charCountBits(List<int> mode, int version) =>
    mode[(version + 7) ~/ 17 + 1];

List<_Segment> _makeSegments(String text) {
  if (text.isEmpty) return const [];
  if (_numeric.hasMatch(text)) {
    final bits = <int>[];
    for (var i = 0; i < text.length;) {
      final n = math.min(text.length - i, 3);
      _appendBits(int.parse(text.substring(i, i + n)), n * 3 + 1, bits);
      i += n;
    }
    return [_Segment(_modeNumeric, text.length, bits)];
  }
  if (_alphanumeric.hasMatch(text)) {
    final bits = <int>[];
    var i = 0;
    for (; i + 2 <= text.length; i += 2) {
      _appendBits(
        _alphanumericCharset.indexOf(text[i]) * 45 +
            _alphanumericCharset.indexOf(text[i + 1]),
        11,
        bits,
      );
    }
    if (i < text.length) {
      _appendBits(_alphanumericCharset.indexOf(text[i]), 6, bits);
    }
    return [_Segment(_modeAlphanumeric, text.length, bits)];
  }
  final bytes = utf8.encode(text);
  final bits = <int>[];
  for (final b in bytes) {
    _appendBits(b, 8, bits);
  }
  return [_Segment(_modeByte, bytes.length, bits)];
}

int _rawDataModules(int version) {
  var result = (16 * version + 128) * version + 64;
  if (version >= 2) {
    final align = version ~/ 7 + 2;
    result -= (25 * align - 10) * align - 55;
    if (version >= 7) result -= 36;
  }
  return result;
}

int _dataCodewords(int version, RaftQrEcc ecc) =>
    _rawDataModules(version) ~/ 8 -
    _eccCodewordsPerBlock[ecc.ordinal][version] *
        _numErrorCorrectionBlocks[ecc.ordinal][version];

int _rsMultiply(int x, int y) {
  var z = 0;
  for (var i = 7; i >= 0; i--) {
    z = ((z << 1) ^ ((z >> 7) * 0x11D)) & 0x1FF;
    z ^= ((y >> i) & 1) * x;
  }
  return z & 0xFF;
}

List<int> _rsDivisor(int degree) {
  final result = [for (var i = 0; i < degree - 1; i++) 0, 1];
  var root = 1;
  for (var i = 0; i < degree; i++) {
    for (var j = 0; j < result.length; j++) {
      result[j] = _rsMultiply(result[j], root);
      if (j + 1 < result.length) result[j] ^= result[j + 1];
    }
    root = _rsMultiply(root, 2);
  }
  return result;
}

List<int> _rsRemainder(List<int> data, List<int> divisor) {
  final result = [for (final _ in divisor) 0];
  for (final b in data) {
    final factor = b ^ result.removeAt(0);
    result.add(0);
    for (var i = 0; i < divisor.length; i++) {
      result[i] ^= _rsMultiply(divisor[i], factor);
    }
  }
  return result;
}

_Qr _encodeSegments(List<_Segment> segments, RaftQrEcc ecc) {
  late int version;
  for (version = 1; ; version++) {
    final capacity = _dataCodewords(version, ecc) * 8;
    var used = 0;
    var fits = true;
    for (final s in segments) {
      final count = _charCountBits(s.mode, version);
      if (s.chars >= 1 << count) fits = false;
      used += 4 + count + s.data.length;
    }
    if (fits && used <= capacity) break;
    if (version >= 40) throw ArgumentError('Data too long for a QR code');
  }
  final bits = <int>[];
  for (final s in segments) {
    _appendBits(s.mode[0], 4, bits);
    _appendBits(s.chars, _charCountBits(s.mode, version), bits);
    bits.addAll(s.data);
  }
  final capacity = _dataCodewords(version, ecc) * 8;
  _appendBits(0, math.min(4, capacity - bits.length), bits);
  _appendBits(0, (8 - bits.length % 8) % 8, bits);
  for (var pad = 0xEC; bits.length < capacity; pad ^= 0xEC ^ 0x11) {
    _appendBits(pad, 8, bits);
  }
  final codewords = List<int>.filled(bits.length ~/ 8, 0);
  for (var i = 0; i < bits.length; i++) {
    codewords[i >> 3] |= bits[i] << (7 - (i & 7));
  }
  return _Qr(version, ecc, codewords);
}

class _Qr {
  _Qr(this.version, this.ecc, List<int> data) : size = version * 4 + 17 {
    modules = [for (var i = 0; i < size; i++) List<bool>.filled(size, false)];
    function = [for (var i = 0; i < size; i++) List<bool>.filled(size, false)];
    _drawFunctionPatterns();
    _drawCodewords(_addEccAndInterleave(data));
    var best = 0, minPenalty = 1 << 30;
    for (var i = 0; i < 8; i++) {
      _applyMask(i);
      _drawFormatBits(i);
      final penalty = _penalty();
      if (penalty < minPenalty) {
        best = i;
        minPenalty = penalty;
      }
      _applyMask(i);
    }
    mask = best;
    _applyMask(best);
    _drawFormatBits(best);
  }

  final int version, size;
  final RaftQrEcc ecc;
  late final List<List<bool>> modules, function;
  late final int mask;

  void _set(int x, int y, bool dark) {
    modules[y][x] = dark;
    function[y][x] = true;
  }

  void _drawFunctionPatterns() {
    for (var i = 0; i < size; i++) {
      _set(6, i, i % 2 == 0);
      _set(i, 6, i % 2 == 0);
    }
    _drawFinder(3, 3);
    _drawFinder(size - 4, 3);
    _drawFinder(3, size - 4);
    final align = _alignmentPositions();
    final n = align.length;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (!(i == 0 && j == 0 ||
            i == 0 && j == n - 1 ||
            i == n - 1 && j == 0)) {
          for (var dy = -2; dy <= 2; dy++) {
            for (var dx = -2; dx <= 2; dx++) {
              _set(
                align[i] + dx,
                align[j] + dy,
                math.max(dx.abs(), dy.abs()) != 1,
              );
            }
          }
        }
      }
    }
    _drawFormatBits(0);
    _drawVersion();
  }

  void _drawFormatBits(int mask) {
    final data = ecc.formatBits << 3 | mask;
    var rem = data;
    for (var i = 0; i < 10; i++) {
      rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    }
    final bits = (data << 10 | rem) ^ 0x5412;
    for (var i = 0; i <= 5; i++) {
      _set(8, i, _bit(bits, i));
    }
    _set(8, 7, _bit(bits, 6));
    _set(8, 8, _bit(bits, 7));
    _set(7, 8, _bit(bits, 8));
    for (var i = 9; i < 15; i++) {
      _set(14 - i, 8, _bit(bits, i));
    }
    for (var i = 0; i < 8; i++) {
      _set(size - 1 - i, 8, _bit(bits, i));
    }
    for (var i = 8; i < 15; i++) {
      _set(8, size - 15 + i, _bit(bits, i));
    }
    _set(8, size - 8, true);
  }

  void _drawVersion() {
    if (version < 7) return;
    var rem = version;
    for (var i = 0; i < 12; i++) {
      rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
    }
    final bits = version << 12 | rem;
    for (var i = 0; i < 18; i++) {
      final dark = _bit(bits, i);
      final a = size - 11 + i % 3, b = i ~/ 3;
      _set(a, b, dark);
      _set(b, a, dark);
    }
  }

  void _drawFinder(int x, int y) {
    for (var dy = -4; dy <= 4; dy++) {
      for (var dx = -4; dx <= 4; dx++) {
        final dist = math.max(dx.abs(), dy.abs());
        final xx = x + dx, yy = y + dy;
        if (xx >= 0 && xx < size && yy >= 0 && yy < size) {
          _set(xx, yy, dist != 2 && dist != 4);
        }
      }
    }
  }

  List<int> _alignmentPositions() {
    if (version == 1) return const [];
    final n = version ~/ 7 + 2;
    final step = version == 32
        ? 26
        : ((version * 4 + 4) / (n * 2 - 2)).ceil() * 2;
    final result = [6];
    for (var pos = size - 7; result.length < n; pos -= step) {
      result.insert(1, pos);
    }
    return result;
  }

  List<int> _addEccAndInterleave(List<int> data) {
    final blocks = _numErrorCorrectionBlocks[ecc.ordinal][version];
    final eccLength = _eccCodewordsPerBlock[ecc.ordinal][version];
    final raw = _rawDataModules(version) ~/ 8;
    final shortBlocks = blocks - raw % blocks;
    final shortLength = raw ~/ blocks;
    final divisor = _rsDivisor(eccLength);
    final all = <List<int>>[];
    for (var i = 0, k = 0; i < blocks; i++) {
      final length = shortLength - eccLength + (i < shortBlocks ? 0 : 1);
      final block = data.sublist(k, k + length);
      k += length;
      final remainder = _rsRemainder(block, divisor);
      if (i < shortBlocks) block.add(0);
      all.add([...block, ...remainder]);
    }
    final result = <int>[];
    for (var i = 0; i < all.first.length; i++) {
      for (var j = 0; j < all.length; j++) {
        if (i != shortLength - eccLength || j >= shortBlocks) {
          result.add(all[j][i]);
        }
      }
    }
    return result;
  }

  void _drawCodewords(List<int> data) {
    var i = 0;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          final upward = ((right + 1) & 2) == 0;
          final y = upward ? size - 1 - vert : vert;
          if (!function[y][x] && i < data.length * 8) {
            modules[y][x] = _bit(data[i >> 3], 7 - (i & 7));
            i++;
          }
        }
      }
    }
  }

  void _applyMask(int mask) {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final invert = switch (mask) {
          0 => (x + y) % 2 == 0,
          1 => y % 2 == 0,
          2 => x % 3 == 0,
          3 => (x + y) % 3 == 0,
          4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
          5 => x * y % 2 + x * y % 3 == 0,
          6 => (x * y % 2 + x * y % 3) % 2 == 0,
          _ => ((x + y) % 2 + x * y % 3) % 2 == 0,
        };
        if (!function[y][x] && invert) modules[y][x] = !modules[y][x];
      }
    }
  }

  int _penalty() {
    var result = 0;
    for (var pass = 0; pass < 2; pass++) {
      for (var a = 0; a < size; a++) {
        var runColor = false;
        var run = 0;
        final history = [0, 0, 0, 0, 0, 0, 0];
        for (var b = 0; b < size; b++) {
          final color = pass == 0 ? modules[a][b] : modules[b][a];
          if (color == runColor) {
            run++;
            if (run == 5) {
              result += _penaltyN1;
            } else if (run > 5) {
              result++;
            }
          } else {
            _addHistory(run, history);
            if (!runColor) result += _countPatterns(history) * _penaltyN3;
            runColor = color;
            run = 1;
          }
        }
        result += _terminateAndCount(runColor, run, history) * _penaltyN3;
      }
    }
    for (var y = 0; y < size - 1; y++) {
      for (var x = 0; x < size - 1; x++) {
        final c = modules[y][x];
        if (c == modules[y][x + 1] &&
            c == modules[y + 1][x] &&
            c == modules[y + 1][x + 1]) {
          result += _penaltyN2;
        }
      }
    }
    var dark = 0;
    for (final row in modules) {
      for (final c in row) {
        if (c) dark++;
      }
    }
    final total = size * size;
    final k = ((dark * 20 - total * 10).abs() / total).ceil() - 1;
    return result + k * _penaltyN4;
  }

  int _countPatterns(List<int> h) {
    final n = h[1];
    final core = n > 0 && h[2] == n && h[3] == n * 3 && h[4] == n && h[5] == n;
    return (core && h[0] >= n * 4 && h[6] >= n ? 1 : 0) +
        (core && h[6] >= n * 4 && h[0] >= n ? 1 : 0);
  }

  int _terminateAndCount(bool color, int run, List<int> history) {
    if (color) {
      _addHistory(run, history);
      run = 0;
    }
    run += size;
    _addHistory(run, history);
    return _countPatterns(history);
  }

  void _addHistory(int run, List<int> history) {
    if (history[0] == 0) run += size;
    history
      ..removeLast()
      ..insert(0, run);
  }
}

/// Paints a [RaftQrMatrix] into its box, one module per `1/size` of the side
/// (the Web SVG `viewBox="0 0 size size"` with `shape-rendering: crispEdges`).
class RaftQrCodePainter extends CustomPainter {
  RaftQrCodePainter(this.matrix, this.color);
  final RaftQrMatrix matrix;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final module = size.width / matrix.size;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    // crispEdges: each module edge snaps to the device pixel grid.
    double snap(double v) => v.roundToDouble();
    for (var y = 0; y < matrix.size; y++) {
      for (var x = 0; x < matrix.size; x++) {
        if (!matrix.dark(x, y)) continue;
        canvas.drawRect(
          Rect.fromLTRB(
            snap(x * module),
            snap(y * module),
            snap((x + 1) * module),
            snap((y + 1) * module),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(RaftQrCodePainter old) =>
      old.matrix != matrix || old.color != color;
}
