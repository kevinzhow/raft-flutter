import 'dart:convert';

/// Receiver-private reaction state. Counts remain on the public message;
/// this ledger records only the current principal's choices.
class ReactionViewerLedger {
  final Map<String, Map<String, dynamic>> _snapshots = {};
  Set<String>? reacted(String messageId) {
    final value = _snapshots[messageId];
    return value == null ? null : Set<String>.from(value['reactedEmojis']);
  }

  String accept(dynamic payload, {required String serverId}) {
    if (payload is! Map || payload['serverId'] != serverId ||
        payload['messageId'] is! String || (payload['messageId'] as String).isEmpty ||
        payload['viewerVersion'] is! int || payload['viewerVersion'] < 0 ||
        payload['viewerVersion'] > 9007199254740991 ||
        payload['reactedEmojis'] is! List ||
        (payload['reactedEmojis'] as List).any((e) => e is! String || e.isEmpty)) {
      return 'corrupt';
    }
    final emojis = Set<String>.from(payload['reactedEmojis']).toList()..sort();
    final id = payload['messageId'] as String, old = _snapshots[id];
    if (old != null) {
      if (payload['viewerVersion'] < old['viewerVersion']) return 'stale';
      if (payload['viewerVersion'] == old['viewerVersion']) {
        return jsonEncode(emojis) == jsonEncode(old['reactedEmojis']) ? 'duplicate' : 'conflict';
      }
    }
    _snapshots[id] = {'viewerVersion': payload['viewerVersion'], 'reactedEmojis': emojis};
    return 'accepted';
  }
  void reset() => _snapshots.clear();
  void remove(String messageId) => _snapshots.remove(messageId);
}
