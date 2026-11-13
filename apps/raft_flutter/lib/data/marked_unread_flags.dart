// Source: packages/web/src/store/markedUnreadStore.ts and the mark handling of
// store/readStateSync.ts (`consumeReadStateUpdate`, `upgradeMarkAtSameVersion`,
// `consumeReadStateSnapshot`) at v1.24.0-source.1.

/// Conversations "manually marked unread": Mark as Unread on a conversation
/// whose messages after the read point are all the person's own. The server
/// cannot rewind the read point into anything it counts, so it marks the
/// scope instead; the sidebar and Activity show it unread with a dot and no
/// number, and counts never include it.
///
/// One flag per conversation (a thread's own channel id, else the channel's),
/// shared by the sidebar and Activity, ordered by read-state version like the
/// Web ledger: a newer version replaces the flag, the same version can only
/// add the mark (every change of the flag moves the version, so a carrier
/// that says "marked" at v outranks one that omits it at v). A read write of
/// the conversation from here clears it at once; its newer read state
/// confirms it.
class MarkedUnreadFlags {
  final Map<String, ({int version, bool marked})> _states = {};
  Set<String> _marked = const {};

  /// The marked conversations (a new set after every change).
  Set<String> get marked => _marked;

  bool contains(String? scopeId) =>
      scopeId != null && _marked.contains(scopeId);

  /// Folds one versioned read-state fact for [scopeId]. Returns whether the
  /// shown flag changed.
  bool accept(String scopeId, int version, bool markedUnread) {
    final held = _states[scopeId];
    if (held != null && version < held.version) return false;
    if (held != null && version == held.version) {
      if (!markedUnread || held.marked) return false;
      _states[scopeId] = (version: version, marked: true);
      return _set(scopeId, true);
    }
    _states[scopeId] = (version: version, marked: markedUnread);
    return _set(scopeId, markedUnread);
  }

  /// Folds a served read-state union (`readState` of `/channels/unread` or an
  /// inbox row): `present` carries the flag, `absent` (no cursor row) clears
  /// it. Anything else is ignored.
  bool acceptFrontier(String scopeId, Object? frontier) {
    if (frontier is! Map) return false;
    if (frontier['kind'] == 'absent') {
      _states.remove(scopeId);
      return _set(scopeId, false);
    }
    final version = frontier['readStateVersion'];
    if (frontier['kind'] != 'present' || version is! int || version < 0) {
      return false;
    }
    return accept(scopeId, version, frontier['markedUnread'] == true);
  }

  /// A read write of [scopeId] is going out from here: its mark is read.
  bool clearForRead(String scopeId) {
    final held = _states[scopeId];
    if (held != null) _states[scopeId] = (version: held.version, marked: false);
    return _set(scopeId, false);
  }

  /// Mark all read is going out from here: every mark is read.
  bool clearAllForRead() {
    if (_marked.isEmpty) return false;
    for (final id in _marked) {
      final held = _states[id];
      if (held != null) _states[id] = (version: held.version, marked: false);
    }
    _marked = const {};
    return true;
  }

  /// A new identity (server switch, sign-out).
  void reset() {
    _states.clear();
    _marked = const {};
  }

  bool _set(String scopeId, bool marked) {
    if (_marked.contains(scopeId) == marked) return false;
    _marked = marked ? {..._marked, scopeId} : ({..._marked}..remove(scopeId));
    return true;
  }
}
