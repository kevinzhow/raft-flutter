part of 'client.dart';

/// Trusted in-process desktop engines share one credential owner. Children
/// retain normal HTTP/socket/stream transports but never rotate or persist.
abstract interface class SharedSessionAuthority {
  Stream<SharedSessionSnapshot?> get changes;
  Future<SharedSessionSnapshot?> read();
  Future<SharedSessionSnapshot> refresh(int revision);
  Future<void> end(SessionEndReason reason);
  Future<SharedSessionSnapshot> synchronizeUser();
}

/// Memory-only credential handoff. Never serialize into URLs, arguments,
/// diagnostics or storage. Epoch binds a window to one accepted login.
class SharedSessionSnapshot {
  const SharedSessionSnapshot({
    required this.origin,
    required this.epoch,
    required this.revision,
    this.credentialRevision = 0,
    required this.session,
  });
  final String origin, epoch;
  final int revision, credentialRevision;
  final Session session;
  String? get principal => session.cachedUser?['id'] as String?;
}

extension SharedClientSession on RaftClient {
  /// Read only by the primary desktop broker over a paired native channel.
  Session? get sessionForSharing => _closed ? null : _session;

  /// Ends the primary session with the same revocation policy as its own
  /// transport. A rejected credential is never an explicit logout POST.
  Future<void> endSharedSession(SessionEndReason reason) =>
      reason == SessionEndReason.userRequested
      ? logout(reason: reason)
      : _endSession(reason, null);

  Future<bool> _restoreSharedSession(
    bool cachedFirst,
    void Function(bool)? onLocalSession,
  ) async {
    if (_sharedRevoked) return false;
    final authentication = ++_authenticationGeneration;
    _generation++;
    lastEndReason = null;
    final snapshot = await sharedSessionAuthority!.read();
    if (_closed || authentication != _authenticationGeneration) return false;
    if (snapshot == null || !_acceptSharedSession(snapshot)) return false;
    final cached = cachedFirst && user != null;
    onLocalSession?.call(cached);
    if (cached) {
      _sessionValidated = _validateRestoredSession(authentication);
      return true;
    }
    await _validateRestoredSession(authentication);
    return signedIn;
  }

  bool _acceptSharedSession(SharedSessionSnapshot? next) {
    if (_closed || _sharedRevoked) return false;
    if (next == null) {
      _retireSharedSession();
      return false;
    }
    final previous = _sharedSnapshot;
    if (next.origin != origin ||
        next.principal == null ||
        previous != null &&
            (previous.epoch != next.epoch ||
                previous.principal != next.principal)) {
      _retireSharedSession();
      return false;
    }
    if (previous != null && next.revision < previous.revision) return false;
    _sharedSnapshot = next;
    _session = next.session;
    final record = RaftRecord(
      Map<String, dynamic>.from(next.session.cachedUser!),
    );
    final changed =
        user != null && jsonEncode(user!.json) != jsonEncode(record.json);
    user = record;
    _socket?.auth = _authenticateSocket;
    if (changed) _emit(const RaftEvent('account:updated', null));
    return true;
  }

  Future<void> _ensureSharedSession() async {
    if (_sharedRevoked || _closed) throw const RaftApiException.staleScope();
    try {
      final snapshot = await sharedSessionAuthority!.read();
      if (snapshot == null || !_acceptSharedSession(snapshot)) {
        throw const RaftApiException.staleScope();
      }
    } catch (_) {
      _retireSharedSession();
      rethrow;
    }
  }

  Future<void> _refreshSharedSession() async {
    final before = _sharedSnapshot;
    if (_closed || _session == null || before == null) {
      throw const RaftApiException.staleScope();
    }
    final next = await sharedSessionAuthority!.refresh(
      before.credentialRevision,
    );
    if (_closed ||
        _sharedRevoked ||
        _session == null ||
        _sharedSnapshot?.epoch != before.epoch) {
      throw const RaftApiException.staleScope();
    }
    if (next.revision < _sharedSnapshot!.revision) return;
    if (!_acceptSharedSession(next)) throw const RaftApiException.staleScope();
  }

  void _retireSharedSession() {
    _sharedRevoked = true;
    if (_session == null && user == null) return;
    _session = null;
    user = null;
    serverId = null;
    _authenticationGeneration++;
    _generation++;
    _socket?.dispose();
    _socket = null;
    _authRetry?.cancel();
    _recoveryTimer?.cancel();
    _emit(const RaftEvent('session:ended', null));
  }
}
