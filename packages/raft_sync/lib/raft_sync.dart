/// Receiver-visible message projections. Channel seq is sparse (server-wide
/// sequence); missing adjacent values do not imply a missing channel message.
library;

export 'src/core.dart';
export 'src/read_state.dart';
export 'src/reaction_viewer.dart';
export 'src/messages.dart';
export 'src/thread_replies.dart';
export 'src/notification_prefs.dart';

import 'src/messages.dart';

class MessageLedger {
  String? _serverId;
  int generation = 0;

  /// Bumped on every content change, so readers can cache derived views.
  int revision = 0;
  BigInt watermark = BigInt.zero;
  final Map<String, Map<String, Map<String, dynamic>>> _channels = {};
  final Map<String, List<Map<String, dynamic>>> _sorted = {};
  String? get serverId => _serverId;
  void switchServer(String? id) {
    if (_serverId == id) return;
    _serverId = id;
    generation++;
    revision++;
    watermark = BigInt.zero;
    _channels.clear();
    _sorted.clear();
  }

  List<Map<String, dynamic>> messages(String channelId) {
    final sorted = _sorted[channelId] ??= () {
      final list =
          (_channels[channelId]?.values.toList() ?? <Map<String, dynamic>>[]);
      final seqs = {for (final m in list) m: _seq(m)};
      list.sort((a, b) {
        final order = seqs[a]!.compareTo(seqs[b]!);
        return order != 0
            ? order
            : (a['id'] as String).compareTo(b['id'] as String);
      });
      return list;
    }();
    // Callers own the returned list; the cached order stays private.
    return List.of(sorted);
  }

  void _changed(String channelId) {
    revision++;
    _sorted.remove(channelId);
  }

  static BigInt _seq(Map<String, dynamic> m) =>
      BigInt.tryParse('${m['seq']}') ?? BigInt.zero;
  bool ingest(
    Iterable<Map<String, dynamic>> messages, {
    required int expectedGeneration,
  }) {
    if (expectedGeneration != generation || _serverId == null) return false;
    for (final message in messages) {
      final id = message['id'], channelId = message['channelId'];
      if (id is! String || channelId is! String) continue;
      final bucket = _channels[channelId] ??= {};
      bucket[id] = mergeMessageProjection(bucket[id], message);
      _changed(channelId);
      final seq = _seq(message);
      if (seq > watermark) watermark = seq;
    }
    return true;
  }

  /// Socket task/status updates are merge-only; they cannot create a message.
  bool ingestUpdate(
    Map<String, dynamic> message, {
    required int expectedGeneration,
  }) {
    if (expectedGeneration != generation || _serverId == null) return false;
    final id = message['id'], channelId = message['channelId'];
    if (id is! String ||
        channelId is! String ||
        _channels[channelId]?[id] == null) {
      return false;
    }
    _channels[channelId]![id] = mergeMessageProjection(
      _channels[channelId]![id],
      message,
    );
    _changed(channelId);
    return true;
  }

  void remove(String channelId, String messageId) {
    _channels[channelId]?.remove(messageId);
    _changed(channelId);
  }

  void revokeChannel(String id) {
    _channels.remove(id);
    _changed(id);
  }
}
