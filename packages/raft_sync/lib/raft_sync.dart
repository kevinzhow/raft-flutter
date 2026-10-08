/// Receiver-visible message projections. Channel seq is sparse (server-wide
/// sequence); missing adjacent values do not imply a missing channel message.
library;

export 'src/core.dart';
export 'src/read_state.dart';
export 'src/reaction_viewer.dart';
export 'src/messages.dart';

import 'src/messages.dart';

class MessageLedger {
  String? _serverId;
  int generation = 0;
  BigInt watermark = BigInt.zero;
  final Map<String, Map<String, Map<String, dynamic>>> _channels = {};
  String? get serverId => _serverId;
  void switchServer(String? id) {
    if (_serverId == id) return;
    _serverId = id;
    generation++;
    watermark = BigInt.zero;
    _channels.clear();
  }

  List<Map<String, dynamic>> messages(String channelId) {
    final list =
        (_channels[channelId]?.values.toList() ?? <Map<String, dynamic>>[]);
    list.sort((a, b) {
      final order = _seq(a).compareTo(_seq(b));
      return order != 0
          ? order
          : (a['id'] as String).compareTo(b['id'] as String);
    });
    return list;
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
    return true;
  }

  void remove(String channelId, String messageId) =>
      _channels[channelId]?.remove(messageId);
  void revokeChannel(String id) => _channels.remove(id);
}
