Set<String> composerDeliveryWarningReasons(Object? raw) => {
  if (raw is List)
    for (final row in raw.whereType<Map>())
      if (row['targetType'] == 'agent' &&
          row['targetId'] is String &&
          (row['targetId'] as String).isNotEmpty &&
          row['reason'] is String)
        row['reason'] as String,
};
