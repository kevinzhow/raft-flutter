import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A valid [width] x [height] 8-bit grey PNG (a left-to-right ramp, so a crop
/// of it is recognisable), small enough to decode instantly in a test.
Uint8List solidPng(int width, int height) {
  final rows = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rows.addByte(0);
    for (var x = 0; x < width; x++) {
      rows.addByte(40 + (x * 180 ~/ width));
    }
  }
  final out = BytesBuilder()..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    out
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(_crc32(body)));
  }

  chunk('IHDR', [..._u32(width), ..._u32(height), 8, 0, 0, 0, 0]);
  chunk('IDAT', zlib.encode(rows.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 255,
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
