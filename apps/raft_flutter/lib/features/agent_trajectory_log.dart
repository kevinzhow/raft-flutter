import 'dart:convert';

/// Mounted Source agentActivityEvents.ts: hydrate:trajectory-log merges with
/// an already admitted live window. This owns no disk, HTTP or ambient status.
List<Map<String, dynamic>> mergeAgentTrajectoryLog(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> incoming,
) {
  if (incoming.isEmpty) return existing;
  final merged = [...existing];
  bool identity(Map<String, dynamic> row) =>
      ['serverSeq', 'launchId', 'clientSeq', 'probeId'].any(row.containsKey);
  String entryKey(Map<String, dynamic> row) {
    final entry = Map<String, dynamic>.from(row['entry'] as Map);
    final keys = entry.keys.toList()..sort();
    return jsonEncode({for (final key in keys) key: entry[key]});
  }

  String visible(Map<String, dynamic> row) =>
      '${row['timestamp']}:${entryKey(row)}';
  String exact(Map<String, dynamic> row) => jsonEncode([
    row['timestamp'],
    row['serverSeq'] ?? 'na',
    row['launchId'] ?? '',
    row['clientSeq'] ?? '',
    row['probeId'] ?? '',
    entryKey(row),
  ]);
  for (final row in incoming) {
    if (merged.any((old) => exact(old) == exact(row))) continue;
    final duplicate = merged.indexWhere(
      (old) =>
          visible(old) == visible(row) &&
          ((old['entry'] as Map)['producerFactId'] is String ||
              !identity(old) ||
              !identity(row)),
    );
    if (duplicate >= 0) {
      if (!identity(merged[duplicate]) && identity(row)) {
        merged[duplicate] = row;
      }
    } else {
      merged.add(row);
    }
  }
  // JS sort is stable. Preserve insertion order for equal timestamp/sequence.
  final indexed = merged.indexed.toList()
    ..sort((a, b) {
      final time = (a.$2['timestamp'] as num).compareTo(
        b.$2['timestamp'] as num,
      );
      if (time != 0) return time;
      final seq = ((a.$2['serverSeq'] as num?) ?? -1).compareTo(
        (b.$2['serverSeq'] as num?) ?? -1,
      );
      return seq != 0 ? seq : a.$1.compareTo(b.$1);
    });
  return [
    for (final row in indexed.skip(
      indexed.length > 500 ? indexed.length - 500 : 0,
    ))
      row.$2,
  ];
}

List<Map<String, dynamic>> admittedAgentTrajectoryRows(dynamic value) => [
  if (value is List)
    for (final row in value.whereType<Map>())
      if (row['timestamp'] is num &&
          (row['timestamp'] as num).isFinite &&
          row['entry'] is Map &&
          row.keys.every((key) => key is String) &&
          (row['entry'] as Map).keys.every((key) => key is String) &&
          ['serverSeq', 'clientSeq'].every(
            (key) =>
                row[key] == null ||
                (row[key] is num && (row[key] as num).isFinite),
          ) &&
          [
            'launchId',
            'probeId',
          ].every((key) => row[key] == null || row[key] is String))
        Map<String, dynamic>.from(row),
];
