import 'dart:async';
import 'dart:math' as math;

import 'package:raft_client/raft_client.dart';

import '../data/workspace_cache.dart';
import 'desktop_drafts.dart';
import 'desktop_cache_scope.dart';

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
    this.createCache,
    this.observeWindows,
  });
  final DesktopWindowFactory createWindow;
  final Future<void> Function() focusPrimary;
  final Future<void> Function()? releaseNative;
  final Future<DesktopOwnedCache> Function()? createCache;
  final Future<Set<String>> Function()? observeWindows;
  final _closingCaches = <String, DesktopOwnedCache>{};
  final cleanupOutcomes = <String, String>{};
  final _failedCaches = <String, DesktopOwnedCache>{};
  final _closingIds = <String>{}, _confirmedRemoved = <String>{};
  final _cacheRemovals = <String, Completer<void>>{};
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
  _DesktopExitAttempt? _exit;
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

  Future<Map<String, String>> cacheLease(String binding) async {
    snapshot(binding);
    final entry = _windows[binding]!;
    final creator = createCache;
    if (creator == null) {
      throw StateError('Desktop cache owner is unavailable.');
    }
    final cache = await (entry.cache ??= creator());
    try {
      snapshot(binding);
      if (!identical(_windows[binding], entry)) {
        throw const RaftApiException.staleScope();
      }
    } catch (_) {
      if (!entry.cacheExposed) {
        cleanupOutcomes[binding] = await cache.remove()
            ? 'removed'
            : cache.outcome;
      } else {
        _failedCaches[binding] = cache;
        cleanupOutcomes[binding] = 'retired_lease_retained';
      }
      rethrow;
    }
    entry.cacheExposed = true;
    return cache.descriptor;
  }

  Future<void> _cleanup(String id, DesktopOwnedCache cache) async {
    if (!await cache.remove()) _failedCaches[id] = cache;
    cleanupOutcomes[id] = cache.outcome;
    _closingIds.remove(id);
    _confirmedRemoved.remove(id);
    _cacheRemovals.remove(id)?.complete();
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
  void cancelClose() {
    final attempt = _exit;
    if (attempt == null || attempt.cancelled) return;
    attempt.cancelled = true;
    if (attempt.result.isCompleted) unawaited(_cancelExit(attempt));
  }

  @override
  Future<bool> prepareExit() {
    final existing = _exit;
    if (existing != null) {
      return existing.cancelled ? Future.value(false) : existing.result.future;
    }
    final attempt = _exit = _DesktopExitAttempt();
    unawaited(
      _prepareExit(attempt).then<void>((accepted) async {
        if (accepted && attempt.cancelled) {
          await _cancelExit(attempt);
          accepted = false;
        }
        attempt.result.complete(accepted);
      }, onError: attempt.result.completeError),
    );
    return attempt.result.future;
  }

  Future<void> _cancelExit(_DesktopExitAttempt attempt) async {
    for (final peer in attempt.peers) {
      try {
        await peer.cancelClose();
      } catch (_) {
        /* Retired engine. */
      }
    }
    if (identical(_exit, attempt)) _exit = null;
  }

  Future<bool> _prepareExit(_DesktopExitAttempt attempt) async {
    final client = _client, epoch = _epoch;
    bool current() =>
        identical(_exit, attempt) &&
        !attempt.cancelled &&
        !_disposed &&
        epoch == _epoch &&
        (client == null || _current(client, epoch));
    final entries = _windows.values.toList();
    var accepted = false;
    try {
      // A native create already in flight has no save/veto endpoint yet.
      if (entries.any((entry) => entry.peer == null)) return false;
      attempt.peers.addAll(entries.map((entry) => entry.peer).nonNulls);
      final prepared = await Future.wait(
        attempt.peers.map((peer) => peer.prepareClose()),
      );
      if (!current() || prepared.any((accepted) => !accepted)) return false;
      if (await _prepareClose?.call() != true || !current()) return false;
      await _drafts.settled;
      if (!current()) return false;
      if (createCache != null) {
        final retiring = <Future<void>>[];
        for (final entry in _windows.entries.toList()) {
          final peer = entry.value.peer;
          if (peer == null || entry.value.cache == null) continue;
          final done = _cacheRemovals.putIfAbsent(
            peer.id,
            () => Completer<void>(),
          );
          retiring.add(done.future);
          remove(entry.key);
        }
        await Future.wait(retiring).timeout(const Duration(seconds: 10));
      }
      return accepted = current();
    } finally {
      // Success stays sealed until the host exits or explicitly cancels.
      if (!accepted) await _cancelExit(attempt);
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

  Future<void> _openShared(RaftRecord server, bool Function() requested) {
    if (_exit != null) return Future.error(const RaftApiException.staleScope());
    return _opening.putIfAbsent(
      server.id,
      () => _open(server.id, requested).whenComplete(() {
        _opening.remove(server.id);
      }),
    );
  }

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
    if (_exit != null || (!_current(client, epoch) || !requested())) {
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
      entry.peer = peer;
      if ((!_current(client, epoch) || !requested()) ||
          !identical(_windows[binding], entry)) {
        if (identical(_windows[binding], entry)) {
          remove(binding);
        } else {
          if (entry.cache case final cache?) _trackClosingCache(peer.id, cache);
          _failedCaches.remove(binding);
          await _closeAndObserve(peer);
        }
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

  void _cacheCreationFailed(String id) {
    cleanupOutcomes[id] = 'creation_failed_retained';
    _closingIds.remove(id);
    _confirmedRemoved.remove(id);
    _cacheRemovals.remove(id)?.complete();
  }

  void _trackClosingCache(String id, Future<DesktopOwnedCache> pending) {
    _cacheRemovals.putIfAbsent(id, () => Completer<void>());
    _closingIds.add(id);
    unawaited(
      pending.then<void>((owned) async {
        if (_confirmedRemoved.contains(id)) {
          await _cleanup(id, owned);
        } else {
          _closingCaches[id] = owned;
        }
      }, onError: (Object _, StackTrace _) => _cacheCreationFailed(id)),
    );
  }

  Future<void> _closeAndObserve(DesktopWindowPeer peer) async {
    try {
      await peer.close();
      if (observeWindows != null) removeClosed(await observeWindows!());
    } catch (_) {
      /* Unconfirmed native removal retains its exact cache lease. */
    }
  }

  void remove(String binding) {
    final entry = _windows.remove(binding);
    if (entry == null) return;
    final peer = entry.peer, cache = entry.cache;
    if (peer == null && cache != null) {
      unawaited(
        cache.then<void>((owned) {
          _failedCaches[binding] = owned;
          cleanupOutcomes[binding] = 'creation_failed_retained';
        }, onError: (Object _, StackTrace _) => _cacheCreationFailed(binding)),
      );
    }
    if (peer != null) {
      if (cache != null) _trackClosingCache(peer.id, cache);
      unawaited(peer.publish(null).catchError((Object _) {}));
      unawaited(_closeAndObserve(peer));
    }
  }

  void removeClosed(Set<String> liveIds) {
    cleanupClosedCaches(liveIds);
    for (final entry in _windows.entries.toList()) {
      final peer = entry.value.peer;
      if (peer != null && !liveIds.contains(peer.id)) {
        final cache = entry.value.cache;
        _windows.remove(entry.key);
        if (cache != null) {
          unawaited(
            cache.then<void>(
              (owned) => _cleanup(peer.id, owned),
              onError: (Object _, StackTrace _) =>
                  _cacheCreationFailed(peer.id),
            ),
          );
        }
      }
    }
  }

  void cleanupClosedCaches(Set<String> liveIds) {
    for (final id in _closingIds) {
      if (!liveIds.contains(id)) _confirmedRemoved.add(id);
    }
    for (final entry in _closingCaches.entries.toList()) {
      if (liveIds.contains(entry.key)) continue;
      _closingCaches.remove(entry.key);
      unawaited(_cleanup(entry.key, entry.value));
    }
  }

  void _revoke() {
    _exit?.cancelled = true;
    _exit = null;
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

class _DesktopExitAttempt {
  final result = Completer<bool>();
  final peers = <DesktopWindowPeer>[];
  bool cancelled = false;
}

class _WindowBinding {
  _WindowBinding(this.epoch, this.server);
  final int epoch;
  String? server;
  DesktopWindowPeer? peer;
  int sequence = 0;
  Future<DesktopOwnedCache>? cache;
  bool cacheExposed = false;
}
