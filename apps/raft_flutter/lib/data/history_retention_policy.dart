/// Resolves sidebar pin identities to actual conversation IDs, including DMs.
Set<String> historyPinnedChannels(
  Map<String, dynamic> preferences,
  Iterable<Map<String, dynamic>> conversations,
) {
  final channels = conversations.toList();
  return {
    for (final pin
        in (preferences['pinned'] as List? ?? const []).whereType<Map>())
      if (pin['kind'] == 'channel' && pin['id'] is String)
        pin['id'] as String
      else
        for (final row in channels)
          if (row['type'] == 'dm' &&
              row['peerId'] == pin['id'] &&
              (pin['kind'] == 'agent'
                  ? row['peerType'] == 'agent'
                  : pin['kind'] == 'human' && row['peerType'] != 'agent'))
            row['id'] as String,
  };
}
