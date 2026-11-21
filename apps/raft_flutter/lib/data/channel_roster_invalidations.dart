import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

/// Invalidation pulse for open roster consumers of a single client.
/// Consumers unregister when they unmount. The client owns the signal's
/// lifetime, including when a presentation borrows the same client.
class ChannelRosterInvalidations implements ValueListenable<(int, String?)> {
  ChannelRosterInvalidations._(this._client);

  static final _owners = Expando<ChannelRosterInvalidations>();
  static ChannelRosterInvalidations of(RaftClient client) =>
      _owners[client] ??= ChannelRosterInvalidations._(client);

  final RaftClient _client;
  final _listeners = <VoidCallback>{};
  (int, String?) _value = (0, null);

  @override
  (int, String?) get value => _value;

  void invalidate(String channelId) {
    _client.invalidateChannelRosterReads(channelId);
    _value = (_value.$1 + 1, channelId);
    for (final listener in _listeners.toList()) {
      if (_listeners.contains(listener)) listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}
