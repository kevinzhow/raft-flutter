import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'resource_snapshot_cache.dart';

/// Attach, detach, revalidation, and release for one workspace page.
///
/// [onSessionEvent] runs only while that page is detached and the identity
/// still matches. The page classifies its own events.
abstract class ServerPageWindow implements ServerPageSlot {
  ServerPageWindow({
    required this.client,
    required this.events,
    required this.snapshot,
    required this.serverId,
    required this.identity,
  });

  final Object client;
  final Stream<RaftEvent> events;
  @override
  PageSnapshot snapshot;
  String? Function() serverId;
  String Function() identity;
  @override
  bool needsRevalidate = false;
  @override
  int attached = 0;
  StreamSubscription<RaftEvent>? _events;
  var _disposed = false;

  bool get disposed => _disposed;
  bool get sameIdentity => identity() == snapshot.identity;

  /// Copies session bindings. Does not change [attached].
  void adoptWindow(ServerPageWindow fresh) {
    snapshot = fresh.snapshot;
    serverId = fresh.serverId;
    identity = fresh.identity;
    needsRevalidate = false;
  }

  @override
  void attach() {
    attached++;
    _events?.cancel();
    _events = null;
  }

  @override
  void detach() {
    if (attached == 0) return;
    attached--;
    if (attached == 0) ensureListening();
  }

  void ensureListening() {
    if (_disposed || attached != 0 || _events != null) return;
    _events = events.listen(_guard);
  }

  void dispose() {
    _disposed = true;
    _events?.cancel();
    _events = null;
    attached = 0;
  }

  void onSessionEvent(RaftEvent event);

  void _guard(RaftEvent event) {
    if (_disposed || attached != 0 || !sameIdentity) return;
    onSessionEvent(event);
  }

  bool otherServer(Object? payload) {
    if (payload is! Map) return false;
    final id = payload['serverId'];
    return id is String && id != serverId();
  }
}

/// Reuses the page at [key] when [fresh] has the same account and client.
T holdServerPage<T extends ServerPageWindow>(
  ResourceSnapshotCache cache,
  String key,
  T fresh, {
  void Function(T window)? bind,
  void Function(T window)? release,
}) {
  final current = cache.serverPage(key);
  if (current is T &&
      current.snapshot.identity == fresh.snapshot.identity &&
      identical(current.client, fresh.client)) {
    current.adoptWindow(fresh);
    bind?.call(current);
    return current;
  }
  cache.keepServerPage(key, fresh, () {
    release?.call(fresh);
    fresh.dispose();
  });
  bind?.call(fresh);
  fresh.ensureListening();
  return fresh;
}

/// Borrows [key] and drops that snapshot slot. Rejected windows are released.
S? takeServerPage<S extends PageSnapshot>(
  ResourceSnapshotCache cache,
  String key,
  String identity, {
  bool Function(S snapshot)? accept,
}) {
  cache.remove(key);
  final window = cache.serverPage(key);
  final snapshot = window?.snapshot;
  if (snapshot is S &&
      snapshot.identity == identity &&
      (accept == null || accept(snapshot))) {
    window!.attach();
    window.needsRevalidate = false;
    return snapshot;
  }
  if (window != null) cache.dropServerPage(key);
  return null;
}
