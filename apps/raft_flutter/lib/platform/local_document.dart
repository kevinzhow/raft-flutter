import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// What the app can show of a downloaded original when the server declined to
/// build a preview (too large, unreadable, unsupported): the same document
/// shapes `RaftDocumentPreview` draws for a server preview.
enum LocalDocumentKind { markdown, csv, text }

/// The longest prefix of a file shown in the app. Everything below it is shown
/// whole (rendered lazily, a few screens at a time); a larger file shows its
/// first part with a notice and can be opened in full with another app.
///
/// 2 MiB: reading, decoding and splitting it takes ~10 ms in the background
/// isolate (see the measurements in the change description) and keeps the
/// decoded text, the line list and the lazily built blocks well below the
/// image memory a single photo already costs.
const localPreviewMaxBytes = 2 * 1024 * 1024;

/// Files at most this size are decoded on the calling isolate (a copy to a
/// background isolate costs more than the work).
const _inlineBytes = 256 * 1024;

/// CSV rows kept for the table (the file prefix holds at most this many).
const localCsvMaxRows = 20000;

/// The most columns shown (the server shows 12; the table scrolls sideways).
const localCsvMaxColumns = 50;

/// The kind the app renders itself for [metadata], or null (spreadsheets,
/// archives, office files, unknown types: another app opens those).
LocalDocumentKind? localDocumentKind(Map<String, dynamic> metadata) {
  final name = '${metadata['filename'] ?? ''}'.toLowerCase();
  final mime = '${metadata['mimeType'] ?? ''}'
      .toLowerCase()
      .split(';')
      .first
      .trim();
  bool ext(List<String> values) => values.any(name.endsWith);
  const spreadsheet = [
    '.xlsx',
    '.xls',
    '.xlt',
    '.xla',
    '.xlm',
    '.xlc',
    '.xlw',
    '.xlsm',
    '.ods',
  ];
  if (ext(spreadsheet) ||
      mime ==
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
    return null;
  }
  if (ext(['.md', '.markdown']) ||
      ['text/markdown', 'text/x-markdown'].contains(mime)) {
    return LocalDocumentKind.markdown;
  }
  if (ext(['.csv']) || ['text/csv', 'application/csv'].contains(mime)) {
    return LocalDocumentKind.csv;
  }
  return LocalDocumentKind.text;
}

/// The file holds no text the app can show (binary, not UTF-8, empty).
class LocalDocumentUnreadable implements Exception {
  const LocalDocumentUnreadable();
  @override
  String toString() => 'LocalDocumentUnreadable';
}

class LocalDocument {
  const LocalDocument({
    required this.data,
    required this.truncated,
    required this.shown,
    required this.totalBytes,
  });

  /// The `RaftDocumentPreview` data (`kind` text, markdown or csv).
  final Map<String, dynamic> data;

  /// Only the first part of the file is in [data].
  final bool truncated;

  /// Lines (text, markdown) or rows (csv) in [data].
  final int shown;
  final int totalBytes;
}

/// Reads [file] for display. Throws [LocalDocumentUnreadable] when it is not
/// UTF-8 text. Large files are decoded on a background isolate.
Future<LocalDocument> readLocalDocument(
  File file,
  LocalDocumentKind kind, {
  int maxBytes = localPreviewMaxBytes,
}) async {
  final length = await file.length();
  if (length <= _inlineBytes) {
    return _read(file.path, kind.index, maxBytes);
  }
  return Isolate.run(() => _read(file.path, kind.index, maxBytes));
}

LocalDocument _read(String path, int kindIndex, int maxBytes) {
  final kind = LocalDocumentKind.values[kindIndex];
  final handle = File(path).openSync();
  final Uint8List bytes;
  final int total;
  try {
    total = handle.lengthSync();
    bytes = handle.readSync(total < maxBytes ? total : maxBytes);
  } finally {
    handle.closeSync();
  }
  var end = bytes.length;
  final truncated = total > bytes.length;
  if (truncated) {
    // Cut after a whole line, so no line (or character) is split.
    final floor = end > 65536 ? end - 65536 : 0;
    for (var i = end - 1; i >= floor; i--) {
      if (bytes[i] == 0x0a) {
        end = i + 1;
        break;
      }
    }
  }
  final prefix = Uint8List.sublistView(bytes, 0, end);
  if (_binary(prefix)) throw const LocalDocumentUnreadable();
  final String text;
  try {
    text = const Utf8Decoder(allowMalformed: false).convert(prefix);
  } on FormatException {
    // A prefix cut inside a character would only fail at its very end.
    throw const LocalDocumentUnreadable();
  }
  final clean = text.startsWith('﻿') ? text.substring(1) : text;
  if (clean.trim().isEmpty) throw const LocalDocumentUnreadable();
  switch (kind) {
    case LocalDocumentKind.text:
      return LocalDocument(
        data: {'kind': 'text', 'text': clean},
        truncated: truncated,
        shown: _lineCount(clean),
        totalBytes: total,
      );
    case LocalDocumentKind.markdown:
      return LocalDocument(
        data: {'kind': 'markdown', 'markdown': clean.trim()},
        truncated: truncated,
        shown: _lineCount(clean),
        totalBytes: total,
      );
    case LocalDocumentKind.csv:
      return _csv(clean, truncated, total);
  }
}

int _lineCount(String text) {
  var lines = 1;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0a) lines++;
  }
  // A closing newline does not start a line.
  return text.endsWith('\n') ? lines - 1 : lines;
}

/// NUL bytes and the OLE header of a legacy workbook: not text (the server
/// rejects the same).
bool _binary(Uint8List bytes) {
  const ole = [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1];
  if (bytes.length >= ole.length) {
    var same = true;
    for (var i = 0; i < ole.length; i++) {
      if (bytes[i] != ole[i]) {
        same = false;
        break;
      }
    }
    if (same) return true;
  }
  final probe = bytes.length < 8192 ? bytes.length : 8192;
  for (var i = 0; i < probe; i++) {
    final b = bytes[i];
    if (b == 0 || (b < 0x09) || (b > 0x0d && b < 0x20 && b != 0x1b)) {
      return true;
    }
  }
  return false;
}

String _delimiter(String text) {
  final newline = text.indexOf('\n');
  final first = newline < 0 ? text : text.substring(0, newline);
  var best = ',', most = -1;
  for (final candidate in const [',', '\t', ';']) {
    final count = candidate.allMatches(first).length;
    if (count > most) {
      best = candidate;
      most = count;
    }
  }
  return best;
}

/// The server's own CSV rules (quotes, doubled quotes, blank rows skipped).
List<List<String>> parseCsv(String text, {int? maxRows}) {
  final delimiter = _delimiter(text);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false, any = false;
  void endRow() {
    row.add(field.toString());
    field.clear();
    if (row.any((cell) => cell.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
    any = false;
  }

  for (var i = 0; i < text.length; i++) {
    if (maxRows != null && rows.length >= maxRows) break;
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        field.write(c);
      }
      continue;
    }
    if (c == '"') {
      quoted = true;
      any = true;
    } else if (c == delimiter) {
      row.add(field.toString());
      field.clear();
      any = true;
    } else if (c == '\n') {
      endRow();
    } else if (c != '\r') {
      field.write(c);
      any = true;
    }
  }
  if (any || field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

LocalDocument _csv(String text, bool truncated, int total) {
  final parsed = parseCsv(text, maxRows: localCsvMaxRows + 1);
  if (parsed.isEmpty) throw const LocalDocumentUnreadable();
  final capped = parsed.length > localCsvMaxRows;
  final columns = parsed.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  List<String> clip(List<String> r) =>
      r.length > localCsvMaxColumns ? r.sublist(0, localCsvMaxColumns) : r;
  final rows = [for (final r in parsed.skip(1).take(localCsvMaxRows)) clip(r)];
  return LocalDocument(
    data: {
      'kind': 'csv',
      'headers': clip(parsed.first),
      'rows': rows,
      'rowCount': rows.length,
      'columnCount': columns,
    },
    truncated: truncated || capped,
    shown: rows.length,
    totalBytes: total,
  );
}
