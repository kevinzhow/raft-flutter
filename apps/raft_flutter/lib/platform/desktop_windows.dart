import 'dart:async';
import 'dart:math' as math;

import 'package:raft_client/raft_client.dart';

import '../data/workspace_cache.dart';
import 'desktop_drafts.dart';

/// The existing live window was focused; no workspace selection occurred.
class DesktopWindowAlreadyOpen implements Exception {
  const DesktopWindowAlreadyOpen();
}

/// Window-local service. The native adapter is deliberately absent in tests
/// and SDK previews. No coordinator credentials belong in a window route.
abstract interface class DesktopWindows {
  bool get isChild;
  String? get origin;
  Uri? get initialLocation;
  String? get navigationNamespace;
  String? get startupServerId;
  SharedSessionAuthority? get sessionAuthority;
  WorkspaceCache? get draftCache;
  void bind(
    RaftClient? client,
    String? serverId, {
    Future<void> Function()? onLogout,
    WorkspaceCache? cache,
    Future<bool> Function()? prepareClose,
    void Function()? cancelClose,
  });
  Future<void> retireDrafts();
  Future<void> selectServer(String serverId);
  Future<bool> prepareExit();
  void cancelClose();
  Future<void> openServer(RaftRecord server);
  Future<void> frameReady();
  Future<void> dispose();
}

abstract interface class DesktopWindowPeer {
  String get id;
  Future<void> focus();
  Future<void> close();
  Future<bool> prepareClose();
  Future<void> cancelClose();
  Future<void> publish(SharedSessionSnapshot? snapshot);
}

typedef DesktopWindowFactory = Future<DesktopWindowPeer> Function(
  String binding,
  RaftRecord server,
  DesktopSessionBroker broker,
);

/// Sole session owner, living in the primary engine. Window bindings are
/// minted before creation; every native pair is bound to this login epoch.
class DesktopSessionBroker implements DesktopWindows {
  DesktopSessionBroker({
    required this.createWindow,
    required this.focusPrimary,
    this.releaseNative,
  });
  final DesktopWindowFactory createWindow;
  final Future<void> Function() focusPrimary;
  final Future<void> Function()? releaseNative;
  final Map<String, _WindowBinding> _windows = {};
  final Map<String, Future<void>> _opening = {};
  RaftClient? _client;
  String? _principal, _server;
  int? _authentication;
  int _epoch = 0, _revision = 0, _credentialRevision = 0;
  final _entropy = math.Random.secure();
  StreamSubscription<RaftEvent>? _events;
  bool _disposed = false;
  Future<void>? _ending;
  int? _endingEpoch;
  Future<void> Function()? _onLogout;
  DesktopDraftOwner _drafts = DesktopDraftOwner();
  Future<bool> Function()? _prepareClose;
  Future<void> _retiredDrafts = Future.value();
  @override
  WorkspaceCache? get draftCache => null;

  @override
  bool get isChild => false;
  @override
  String? get origin => null;
  @override
  Uri? get initialLocation => null;
  @override
  String? get navigationNamespace => null;
  @override
  String? get startupServerId => null;
  @override
  SharedSessionAuthority? get sessionAuthority => null;

  @override
  void bind(
    RaftClient? client,
    String? serverId, {
    Future<void> Function()? onLogout,
    WorkspaceCache? cache,
    Future<bool> Function()? prepareClose,
    void Function()? cancelClose,
  }) {
    if (_disposed) return;
    _server = serverId;
    _prepareClose = prepareClose;
    if (identical(client, _client) &&
        client?.user?.id == _principal &&
        client?.authenticationGeneration == _authentication) {
      _onLogout = onLogout;
      _drafts.cache = cache;
      return;
    }
    _revoke();
    if (client == null || client.user == null || !client.signedIn) return;
    _drafts = DesktopDraftOwner()..cache = cache;
    _client = client;
    _onLogout = onLogout;
    _principal = client.user!.id;
    _authentication = client.authenticationGeneration;
    _events = client.events.listen((event) {
      if (!identical(client, _client)) return;
      if (event.name == 'session:ended' || client.user?.id != _principal) {
        _revoke();
      } else if (event.name == 'session:credentials-updated' ||
          event.name == 'account:updated') {
        _revision++;
        if (event.name == 'session:credentials-updated') _credentialRevision++;
        for (final entry in _windows.entries.toList()) {
          unawaited(_publish(entry.key, entry.value));
        }
      } else if (event.name == 'server:membership-removed') {
        final payload = event.payload;
        final id = payload is Map ? payload['serverId'] : null;
        if (id is String) _drafts.revokeServer(client.origin, _principal!, id);
        for (final entry in _windows.entries.toList()) {
          if (entry.value.server == id) remove(entry.key);
        }
      }
    });
  }

  SharedSessionSnapshot snapshot(String binding) {
    final entry = _windows[binding], client = _client;
    if (_disposed ||
        entry == null ||
        entry.epoch != _epoch ||
        client?.user?.id != _principal ||
        client?.authenticationGeneration != _authentication ||
        client?.sessionForSharing == null) {
      throw const RaftApiException.staleScope();
    }
    return SharedSessionSnapshot(
      origin: client!.origin,
      epoch: '$_epoch',
      revision: _revision,
      credentialRevision: _credentialRevision,
      session: client.sessionForSharing!,
    );
  }

  void _draftAuthority(
    String binding,
    String origin,
    String principal,
    String server,
  ) {
    final current = snapshot(binding);
    if (current.origin != origin ||
        current.principal != principal ||
        _windows[binding]?.server != server) {
      throw const RaftApiException.staleScope();
    }
  }

  Future<dynamic> readDraft(
    String binding,
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async {
    final owner = _drafts, epoch = _epoch;
    _draftAuthority(binding, origin, principal, server);
    return owner.read(
      origin,
      principal,
      server,
      kind,
      id,
      () => epoch == _epoch && _windows.containsKey(binding),
    );
  }

  Future<void> writeDraft(
    String binding,
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    final owner = _drafts, epoch = _epoch;
    _draftAuthority(binding, origin, principal, server);
    await owner.write(
      origin,
      principal,
      server,
      kind,
      id,
      value,
      () => epoch == _epoch && _windows.containsKey(binding),
    );
  }

  @override
  Future<void> selectServer(String serverId) async {}

  @override
  Future<void> retireDrafts() =>
      Future.wait([_retiredDrafts, _drafts.retire()]);

  @override
  void cancelClose() {}

  @override
  Future<bool> prepareExit() async {
    var accepted = false;
    try {
      for (final entry in _windows.values.toList()) {
        if (await entry.peer?.prepareClose() != true) return false;
      }
      if (await _prepareClose?.call() != true) return false;
      await _drafts.settled;
      return accepted = true;
    } finally {
      if (!accepted) {
        for (final entry in _windows.values.toList()) {
          try {
            await entry.peer?.cancelClose();
          } catch (_) {
            /* Retired engine. */
          }
        }
      }
    }
  }

  Future<SharedSessionSnapshot> refresh(String binding, int revision) async {
    final before = snapshot(binding), client = _client!;
    // A slower window retries with the already rotated record, without
    // spending another single-use refresh token.
    if (revision >= before.credentialRevision) await client.refresh();
    return snapshot(binding);
  }

  Future<void> end(String binding, SessionEndReason reason) {
    final existing = _ending;
    if (existing != null && _endingEpoch == _epoch) return existing;
    snapshot(binding);
    final client = _client!, logout = _onLogout;
    _endingEpoch = _epoch;
    // Root owns cache retirement and keeps the primary transport alive until
    // explicit revocation settles. Involuntary rejection never sends logout.
    late final Future<void> ending;
    ending =
        (reason == SessionEndReason.userRequested && logout != null
                ? logout()
                : client.endSharedSession(reason))
            .whenComplete(() {
              if (identical(_ending, ending)) _ending = null;
            });
    return _ending = ending;
  }

  Future<SharedSessionSnapshot> synchronizeUser(String binding) async {
    snapshot(binding);
    await _client!.reloadUser();
    return snapshot(binding);
  }

  Future<void> bindServer(String binding, String? serverId) async {
    final before = snapshot(binding), entry = _windows[binding]!;
    final sequence = ++entry.sequence;
    if (serverId == null) {
      entry.server = null;
      return;
    }
    final servers = await _client!.accountServers();
    if (snapshot(binding).epoch != before.epoch ||
        sequence != entry.sequence ||
        !servers.any((server) => server.id == serverId)) {
      throw const RaftApiException.staleScope();
    }
    for (final other in _windows.values) {
      if (!identical(entry, other) && other.server == serverId) {
        final peer = other.peer;
        if (peer == null) throw const RaftApiException.staleScope();
        await peer.focus();
        throw const DesktopWindowAlreadyOpen();
      }
    }
    entry.server = serverId;
  }

  @override
  Future<void> openServer(RaftRecord server) => _openShared(server, () => true);

  Future<void> openFromWindow(String binding, RaftRecord server) {
    snapshot(binding);
    final requester = _windows[binding]!;
    return _openShared(server, () => identical(_windows[binding], requester));
  }

  Future<void> _openShared(RaftRecord server, bool Function() requested) =>
      _opening.putIfAbsent(
        server.id,
        () => _open(server.id, requested).whenComplete(() {
          _opening.remove(server.id);
        }),
      );

  Future<void> _open(String serverId, bool Function() requested) async {
    final client = _client, epoch = _epoch;
    if (client == null || (!_current(client, epoch) || !requested())) {
      throw const RaftApiException.staleScope();
    }
    if (!_drafts.available) {
      throw const RaftApiException(
        'Desktop windows need the local draft database. Restart Raft and try again.',
      );
    }
    final servers = await client.accountServers();
    if ((!_current(client, epoch) || !requested())) {
      throw const RaftApiException.staleScope();
    }
    final candidates = servers.where((server) => server.id == serverId);
    if (candidates.isEmpty) throw const RaftApiException.staleScope();
    if (_server == serverId) {
      await focusPrimary();
      return;
    }
    for (final entry in _windows.entries.toList()) {
      if (entry.value.server != serverId || entry.value.peer == null) continue;
      try {
        await entry.value.peer?.focus();
        return;
      } catch (_) {
        remove(entry.key);
      }
    }
    final nonce = List.generate(
      4,
      (_) => _entropy.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    final binding = '${_epoch}_$nonce';
    final entry = _WindowBinding(epoch, serverId);
    _windows[binding] = entry;
    try {
      final peer = await createWindow(binding, candidates.first, this);
      if ((!_current(client, epoch) || !requested()) ||
          !identical(_windows[binding], entry)) {
        await peer.close();
        throw const RaftApiException.staleScope();
      }
      entry.peer = peer;
      final latest = await client.accountServers();
      if ((!_current(client, epoch) || !requested()) ||
          !identical(_windows[binding], entry) ||
          !latest.any((s) => s.id == serverId)) {
        remove(binding);
        throw const RaftApiException.staleScope();
      }
      await peer.focus();
    } catch (_) {
      remove(binding);
      rethrow;
    }
  }

  bool _current(RaftClient client, int epoch) =>
      !_disposed &&
      identical(client, _client) &&
      epoch == _epoch &&
      client.authenticationGeneration == _authentication &&
      client.user?.id == _principal &&
      client.signedIn;

  Future<void> _publish(String binding, _WindowBinding entry) async {
    try {
      await entry.peer?.publish(snapshot(binding));
    } catch (_) {
      remove(binding);
    }
  }

  void remove(String binding) {
    final entry = _windows.remove(binding);
    if (entry?.peer case final peer?) {
      unawaited(peer.publish(null).catchError((Object _) {}));
      unawaited(peer.close().catchError((Object _) {}));
    }
  }

  void removeClosed(Set<String> liveIds) {
    for (final entry in _windows.entries.toList()) {
      final peer = entry.value.peer;
      if (peer != null && !liveIds.contains(peer.id)) remove(entry.key);
    }
  }

  void _revoke() {
    _retiredDrafts = Future.wait([_retiredDrafts, _drafts.retire()]);
    _epoch++;
    _revision = _credentialRevision = 0;
    _client = null;
    _onLogout = null;
    _principal = null;
    _authentication = null;
    unawaited(_events?.cancel());
    _events = null;
    for (final binding in _windows.keys.toList()) {
      remove(binding);
    }
  }

  @override
  Future<void> frameReady() async {}

  @override
  Future<void> dispose() async {
    _disposed = true;
    _revoke();
    await releaseNative?.call();
  }
}

class _WindowBinding {
  _WindowBinding(this.epoch, this.server);
  final int epoch;
  String? server;
  DesktopWindowPeer? peer;
  int sequence = 0;
}
