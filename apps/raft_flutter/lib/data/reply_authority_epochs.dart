import 'dart:convert';

/// Revision tokens for reply summaries and their accepted message windows.
/// The caller supplies its live identity; no client or controller is retained.
final class ReplyAuthorityEpochs {
  /// Fail-closed fallback for an authority event without a channel id.
  int _all = 0;

  /// Only the affected channel's token changes on its membership event.
  final Map<String, int> _channels = {};

  String token(String identity, String? channelId) =>
      jsonEncode([identity, _all, channelId, _channels[channelId] ?? 0]);

  void invalidateChannel(String id) {
    _channels[id] = (_channels[id] ?? 0) + 1;
  }

  void invalidateAll() {
    _all++;
  }
}
