import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A client-computed summary of a complete authorized range. Body fields are
/// included because deployed message pages have no universal edit version;
/// content, deletion, reaction and reply metadata can change without new seq.
class HistoryRangeDigest {
  HistoryRangeDigest(Iterable<Map<String, dynamic>> values) {
    final rows = values.toList()
      ..sort(
        (a, b) =>
            BigInt.parse('${a['seq']}').compareTo(BigInt.parse('${b['seq']}')),
      );
    count = rows.length;
    last = rows.isEmpty ? null : ('${rows.last['seq']}', '${rows.last['id']}');
    versions = sha256
        .convert(utf8.encode(jsonEncode(_canonical(rows))))
        .toString();
  }
  late final int count;
  late final (String, String)? last;
  late final String versions;
  bool matches(HistoryRangeDigest other) =>
      count == other.count && last == other.last && versions == other.versions;

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}
