import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Whether an MP4/MOV video is HDR, read from the file's own boxes: the colour
/// transfer function of the video sample entry (`colr`/`nclx`: 16 = PQ,
/// 18 = HLG) or a Dolby Vision configuration (`dvcC`, `dvvC`). The codec says
/// nothing (HEVC is often SDR), so neither the extension nor the codec is
/// used. Read with one to three small ranged GETs (the head, and the `moov`
/// box when it sits behind `mdat`); never the whole file.
class Mp4ColorInfo {
  const Mp4ColorInfo({this.transfer, this.dolbyVision = false});

  /// `transfer_characteristics` of the `colr`/`nclx` box, null when absent.
  final int? transfer;
  final bool dolbyVision;

  bool get hdr => transfer == 16 || transfer == 18 || dolbyVision;

  @override
  String toString() => 'Mp4ColorInfo(transfer: $transfer, dolbyVision: $dolbyVision)';
}

class Mp4Boxes {
  static int _u32(Uint8List b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  static String _type(Uint8List b, int o) => String.fromCharCodes(b.sublist(o + 4, o + 8));

  /// The size and header length of the box at [offset] in [bytes], or null when
  /// the header is incomplete. A size of 0 means "to the end" ([total]).
  static ({int size, int header, String type})? header(
    Uint8List bytes,
    int offset, {
    required int total,
  }) {
    if (offset + 8 > bytes.length) return null;
    var size = _u32(bytes, offset);
    var header = 8;
    final type = _type(bytes, offset);
    if (size == 1) {
      if (offset + 16 > bytes.length) return null;
      size = (_u32(bytes, offset + 8) << 32) | _u32(bytes, offset + 12);
      header = 16;
    } else if (size == 0) {
      size = total - offset;
    }
    if (size < header) return null;
    return (size: size, header: header, type: type);
  }

  static const _containers = {'moov', 'trak', 'mdia', 'minf', 'stbl'};
  static const _videoEntries = {
    'hvc1', 'hev1', 'dvh1', 'dvhe', 'avc1', 'avc3', 'av01', 'dav1', 'vp09', 'encv',
  };

  /// Colour information of the first video track in the `moov` box [moov]
  /// (the box including its 8-byte header), or null when it has none.
  static Mp4ColorInfo? colorOfMoov(Uint8List moov) {
    Mp4ColorInfo? found;
    void walk(int start, int end) {
      var offset = start;
      while (found == null && offset + 8 <= end) {
        final box = header(moov, offset, total: end);
        if (box == null || offset + box.size > end) return;
        final bodyStart = offset + box.header, bodyEnd = offset + box.size;
        if (_containers.contains(box.type)) {
          walk(bodyStart, bodyEnd);
        } else if (box.type == 'stsd') {
          // version/flags (4) + entry count (4), then the sample entries.
          var entry = bodyStart + 8;
          while (found == null && entry + 8 <= bodyEnd) {
            final e = header(moov, entry, total: bodyEnd);
            if (e == null || entry + e.size > bodyEnd) break;
            if (_videoEntries.contains(e.type)) {
              // VisualSampleEntry: 78 bytes of fields, then child boxes.
              found = _entryColor(moov, entry + e.header + 78, entry + e.size);
            }
            entry += e.size;
          }
        }
        offset += box.size;
      }
    }

    final top = header(moov, 0, total: moov.length);
    if (top == null || top.type != 'moov') return null;
    walk(top.header, moov.length);
    return found;
  }

  static Mp4ColorInfo _entryColor(Uint8List b, int start, int end) {
    int? transfer;
    var dolby = false;
    var offset = start;
    while (offset + 8 <= end) {
      final box = header(b, offset, total: end);
      if (box == null || offset + box.size > end) break;
      final body = offset + box.header;
      switch (box.type) {
        case 'colr':
          // colour_type 'nclx': primaries, transfer, matrix (u16 each), range.
          if (box.size >= box.header + 11 && String.fromCharCodes(b.sublist(body, body + 4)) == 'nclx') {
            transfer = (b[body + 6] << 8) | b[body + 7];
          }
        case 'dvcC' || 'dvvC' || 'dvwC':
          dolby = true;
      }
      offset += box.size;
    }
    return Mp4ColorInfo(transfer: transfer, dolbyVision: dolby);
  }
}

/// Reads [url]'s colour information with ranged GETs through [dio]. Returns
/// null when the file is not an MP4/MOV, the server ignores ranges, or the
/// boxes cannot be found cheaply: the caller then treats the video as SDR.
Future<Mp4ColorInfo?> probeMp4Color(
  Dio dio,
  Uri url, {
  CancelToken? cancel,
  int headBytes = 64 * 1024,
  int maxMoovBytes = 4 * 1024 * 1024,
}) async {
  Future<(Uint8List, int?)?> range(int start, int length) async {
    final response = await dio.getUri<ResponseBody>(
      url,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'range': 'bytes=$start-${start + length - 1}'},
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (s) => s == 206,
      ),
    );
    int? total;
    final contentRange = response.headers.value('content-range');
    final m = contentRange == null ? null : RegExp(r'/(\d+)$').firstMatch(contentRange);
    if (m != null) total = int.parse(m[1]!);
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.data!.stream) {
      builder.add(chunk);
      if (builder.length >= length) break;
    }
    return (builder.takeBytes(), total);
  }

  try {
    var offset = 0;
    var head = await range(0, headBytes);
    if (head == null) return null;
    final total = head.$2 ?? 0;
    var window = head.$1, windowStart = 0;
    for (var step = 0; step < 8; step++) {
      final box = Mp4Boxes.header(window, offset - windowStart, total: total);
      if (box == null) {
        // The next header is outside what was read: read it.
        if (total <= 0 || offset >= total) return null;
        final next = await range(offset, 4096);
        if (next == null) return null;
        window = next.$1;
        windowStart = offset;
        continue;
      }
      if (step == 0 && box.type != 'ftyp') return null;
      if (box.type == 'moov') {
        if (box.size > maxMoovBytes) return null;
        final local = offset - windowStart;
        if (local + box.size <= window.length) {
          return Mp4Boxes.colorOfMoov(Uint8List.sublistView(window, local, local + box.size));
        }
        final moov = await range(offset, box.size);
        if (moov == null || moov.$1.length < box.size) return null;
        return Mp4Boxes.colorOfMoov(moov.$1);
      }
      offset += box.size;
      if (total > 0 && offset >= total) return null;
      if (offset - windowStart + 16 > window.length) {
        final next = await range(offset, 4096);
        if (next == null) return null;
        window = next.$1;
        windowStart = offset;
      }
    }
  } on Object {
    return null;
  }
  return null;
}
