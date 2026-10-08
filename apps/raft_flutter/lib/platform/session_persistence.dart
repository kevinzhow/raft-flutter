import 'package:raft_client/raft_client.dart';

/// Serializes session persistence across separately constructed auth clients.
/// A superseded candidate cannot overwrite the selected client's session.
class SessionPersistence implements SessionStore {
  SessionPersistence(this.delegate);
  final SessionStore delegate;
  Future<void> _writes = Future<void>.value();

  SessionStore guarded(bool Function() current) =>
      _GuardedSessionStore(this, current);

  @override
  Future<Session?> read(String origin) async {
    await _writes.catchError((Object _) {});
    return delegate.read(origin);
  }

  @override
  Future<void> write(String origin, Session? session) =>
      writeIf(origin, session, () => true);

  Future<void> writeIf(
    String origin,
    Session? session,
    bool Function() current,
  ) {
    final next = _writes.catchError((Object _) {}).then((_) async {
      if (current()) await delegate.write(origin, session);
    });
    _writes = next;
    return next;
  }
}

class _GuardedSessionStore implements SessionStore {
  _GuardedSessionStore(this.persistence, this.current);
  final SessionPersistence persistence;
  final bool Function() current;
  @override
  Future<Session?> read(String origin) => persistence.read(origin);
  @override
  Future<void> write(String origin, Session? session) =>
      persistence.writeIf(origin, session, current);
}
