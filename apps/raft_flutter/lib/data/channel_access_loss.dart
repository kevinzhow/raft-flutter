// Channels this person can no longer read (Web store/channelAccessLoss.ts at
// v1.24.0-source.1), per signed-in person and server:
//
// - lost: removed from a private or shared channel while it was open. Marked
//   only by an answer about that channel; the open channel stops asking
//   GET /messages/sync for it (the heartbeat would ask forever) and the shell
//   shows "You're no longer in this channel" (WP-SHELL, `layout.main`).
// - unavailable: a link opened a conversation `GET /channels/:id` refused.
//
// [clear] drops both when the channel comes back (`channel:updated` with
// `joined`, a sync `scope` added) or a check answers it can be read.
import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

class ChannelAccessLoss extends ChangeNotifier {
  ChannelAccessLoss._(this.client);
  final RaftClient client;

  static final _of = Expando<ChannelAccessLoss>('channel access loss');

  /// The marks of [client]'s signed-in person on its current server.
  static ChannelAccessLoss of(RaftClient client) =>
      _of[client] ??= ChannelAccessLoss._(client);

  /// The server's answers that mean "this channel, for this person"
  /// (routes/channelAccessDenial.ts, `GET /channels/:id`). They carry no
  /// code, so the body tells them from every other 403/404.
  static const denials = {
    403: {'Access denied', 'You do not have access to this channel'},
    404: {'Channel not found or not visible', 'Channel not found'},
  };

  static bool isDenial(Object error) =>
      error is RaftApiException &&
      error.structured &&
      error.code == null &&
      (denials[error.status]?.contains(error.message) ?? false);

  String? _scope;
  final _lost = <String>{};
  final _unavailable = <String>{};

  void _synchronize() {
    final scope = '${client.origin}|${client.user?.id}|${client.serverId}';
    if (_scope == scope) return;
    _scope = scope;
    _lost.clear();
    _unavailable.clear();
  }

  bool isLost(String? channelId) {
    _synchronize();
    return channelId != null && _lost.contains(channelId);
  }

  bool isUnavailable(String? channelId) {
    _synchronize();
    return channelId != null && _unavailable.contains(channelId);
  }

  /// A read about [channelId] failed: mark it lost when the answer says so.
  void noteReadError(String? channelId, Object error) {
    _synchronize();
    if (channelId == null || !isDenial(error) || !_lost.add(channelId)) return;
    notifyListeners();
  }

  /// Opening [channelId] answered: null when it could be read, else the
  /// error. Only a denial marks it; any other answer clears an earlier mark.
  void noteOpenResult(String channelId, Object? error) {
    _synchronize();
    final changed = error != null && isDenial(error)
        ? _unavailable.add(channelId)
        : _unavailable.remove(channelId);
    if (changed) notifyListeners();
  }

  void clear(String channelId) {
    _synchronize();
    final a = _lost.remove(channelId), b = _unavailable.remove(channelId);
    if (a || b) notifyListeners();
  }

  /// A sync `scope` change for one channel. Removed is a membership change,
  /// not always lost access (a public channel stays readable), so the
  /// channel is read once and marked only if that read is refused.
  Future<void> applyScopeChange(String channelId, String op) async {
    if (op == 'added') return clear(channelId);
    try {
      await client.get('/channels/${Uri.encodeComponent(channelId)}');
      clear(channelId);
    } catch (error) {
      noteReadError(channelId, error);
    }
  }
}
