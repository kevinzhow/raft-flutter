import 'dart:convert';

/// Persisted rows are a bounded accepted tail/history window, never an
/// authorization grant or a permalink window. Authorization is checked by the
/// controller before hydration; origin/principal/workspace are database keys.
const messageWindowLimit = 500;

String messageWindowAuthority(String? role, Map<String, dynamic> channel) =>
    jsonEncode([
      role,
      channel['id'],
      channel['type'],
      channel['joined'],
      channel['channelCapabilities'],
    ]);

List<Map<String, dynamic>> acceptedWindowRows(dynamic value, String id) {
  if (value is! List || value.length > messageWindowLimit) return const [];
  final result = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final raw in value) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['channelId'] != id ||
        BigInt.tryParse('${raw['seq']}') == null ||
        !ids.add(raw['id'])) {
      return const [];
    }
    result.add(Map<String, dynamic>.from(raw));
  }
  return result;
}

/// The refreshed first page is authoritative over its own range. Preserve only
/// already accepted older history, so deleted rows inside the refreshed page do
/// not survive by union and a stale context cannot extend the live window.
Set<String> reconcileTailWindow(
  Iterable<Map<String, dynamic>> retained,
  Iterable<Map<String, dynamic>> page,
) {
  final fresh = page.toList();
  if (fresh.isEmpty) return {};
  final first = fresh
      .map((row) => BigInt.tryParse('${row['seq']}'))
      .whereType<BigInt>()
      .fold<BigInt?>(null, (a, b) => a == null || b < a ? b : a);
  return {
    if (first != null)
      for (final row in retained)
        if (BigInt.tryParse('${row['seq']}') case final seq?)
          if (seq < first) row['id'] as String,
    for (final row in fresh) row['id'] as String,
  };
}
