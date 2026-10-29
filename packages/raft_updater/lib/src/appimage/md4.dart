import 'dart:typed_data';

/// MD4 (RFC 1320), the per-block strong checksum of the zsync format.
///
/// It only identifies unchanged blocks while merging a delta; the integrity of
/// the result is checked with SHA-1 (zsync) and SHA-256 (release manifest).
/// Digests are produced with a reusable instance to avoid allocating per block.
class Md4 {
  Md4() : _words = Uint32List(16), _tail = Uint8List(128);

  final Uint32List _words;
  final Uint8List _tail;
  int _a = 0, _b = 0, _c = 0, _d = 0;

  /// The 16-byte digest of `data[start, start + length)`.
  Uint8List digest(Uint8List data, int start, int length) {
    _a = 0x67452301;
    _b = 0xefcdab89;
    _c = 0x98badcfe;
    _d = 0x10325476;
    final whole = length ~/ 64;
    for (var block = 0; block < whole; block++) {
      _process(data, start + block * 64);
    }
    final rest = length - whole * 64;
    _tail.fillRange(0, _tail.length, 0);
    _tail.setRange(0, rest, data, start + whole * 64);
    _tail[rest] = 0x80;
    final padded = rest < 56 ? 64 : 128;
    final bits = length * 8;
    for (var i = 0; i < 8; i++) {
      _tail[padded - 8 + i] = (bits >> (8 * i)) & 0xff;
    }
    for (var offset = 0; offset < padded; offset += 64) {
      _process(_tail, offset);
    }
    final out = Uint8List(16);
    final view = ByteData.sublistView(out);
    view.setUint32(0, _a, Endian.little);
    view.setUint32(4, _b, Endian.little);
    view.setUint32(8, _c, Endian.little);
    view.setUint32(12, _d, Endian.little);
    return out;
  }

  static const int _m = 0xffffffff;

  static int _rol(int x, int s) => ((x << s) | (x >>> (32 - s))) & _m;

  void _process(Uint8List data, int at) {
    final x = _words;
    for (var i = 0; i < 16; i++) {
      final j = at + i * 4;
      x[i] =
          data[j] |
          (data[j + 1] << 8) |
          (data[j + 2] << 16) |
          (data[j + 3] << 24);
    }
    var a = _a, b = _b, c = _c, d = _d;
    // Round 1: F = (b & c) | (~b & d)
    for (var i = 0; i < 16; i += 4) {
      a = _rol((a + (((b & c) | (~b & d)) & _m) + x[i]) & _m, 3);
      d = _rol((d + (((a & b) | (~a & c)) & _m) + x[i + 1]) & _m, 7);
      c = _rol((c + (((d & a) | (~d & b)) & _m) + x[i + 2]) & _m, 11);
      b = _rol((b + (((c & d) | (~c & a)) & _m) + x[i + 3]) & _m, 19);
    }
    // Round 2: G = majority, +0x5a827999
    for (var i = 0; i < 4; i++) {
      a = _rol(
        (a + (((b & c) | (b & d) | (c & d))) + x[i] + 0x5a827999) & _m,
        3,
      );
      d = _rol(
        (d + (((a & b) | (a & c) | (b & c))) + x[i + 4] + 0x5a827999) & _m,
        5,
      );
      c = _rol(
        (c + (((d & a) | (d & b) | (a & b))) + x[i + 8] + 0x5a827999) & _m,
        9,
      );
      b = _rol(
        (b + (((c & d) | (c & a) | (d & a))) + x[i + 12] + 0x5a827999) & _m,
        13,
      );
    }
    // Round 3: H = parity, +0x6ed9eba1
    const order = [0, 2, 1, 3];
    for (var k = 0; k < 4; k++) {
      final i = order[k];
      a = _rol((a + (b ^ c ^ d) + x[i] + 0x6ed9eba1) & _m, 3);
      d = _rol((d + (a ^ b ^ c) + x[i + 8] + 0x6ed9eba1) & _m, 9);
      c = _rol((c + (d ^ a ^ b) + x[i + 4] + 0x6ed9eba1) & _m, 11);
      b = _rol((b + (c ^ d ^ a) + x[i + 12] + 0x6ed9eba1) & _m, 15);
    }
    _a = (_a + a) & _m;
    _b = (_b + b) & _m;
    _c = (_c + c) & _m;
    _d = (_d + d) & _m;
  }
}
