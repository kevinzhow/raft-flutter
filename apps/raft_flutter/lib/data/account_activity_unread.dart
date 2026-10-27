import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'activity_attention.dart';
import 'source_activity_unread_store.dart';
import 'workspace_controller.dart';

/// Account lifetime, independent of which workspace the root is displaying.
/// Borrows a selected Activity projection; it never creates or starts one.
class AccountActivityUnread extends ChangeNotifier {
  AccountActivityUnread({this.refreshInterval = const Duration(seconds: 30)});

  final Duration refreshInterval;

  /// Native write retries follow accepted refreshes without dirtying consumers.
  final successfulRefresh = ValueNotifier<int>(0);
  RaftClient? _client;
  Object? _account, _workspaceAuthority;
  WorkspaceController? _workspace;
  SourceActivityUnreadStore? _activity;
  Set<String> _members = {}, _revoked = {};
  Map<String, int?> _counts = {};
  bool _known = false, _closed = false, _directoryKnown = false;
  Set<String>? _workspaceDirectory;
  bool _accountDirectoryRequired = false;
  int _revision = 0;
  Future<void>? _pending;
  Timer? _periodic, _debounce;
  StreamSubscription<RaftEvent>? _events;
  Interceptor? _reads;

  Object? _identity(RaftClient? client) =>
      client?.signedIn == true && client?.user?.id.isNotEmpty == true
      ? (client, client!.origin, client.user!.id)
      : null;

  Object? get authority => _identity(_client) == _account ? _account : null;
  String? get notificationAccount =>
      authority == null ? null : '${_client!.origin}\n${_client!.user!.id}';
  Set<String>? get memberIds => _known ? Set.unmodifiable(_members) : null;

  int? get total {
    if (_account == null ||
        _identity(_client) != _account ||
        !_known ||
        _accountDirectoryRequired && !_directoryKnown) {
      return null;
    }
    final id = _workspace?.server?.id;
    return knownActivityBadgeTotal(
      currentServerId: _members.contains(id) ? id : null,
      currentTotal: _activity?.totalUnreadCount,
      memberServerIds: _members,
      summary: _counts,
    );
  }

  Future<void> get settled async {
    while (_pending != null) {
      await _pending;
    }
  }

  void bindClient(RaftClient? next, {bool refreshNow = true}) {
    if (_closed) return;
    final key = _identity(next);
    if (key == _account && identical(next, _client)) return;
    _detachWorkspace();
    if (_reads != null) _client?.http.interceptors.remove(_reads);
    unawaited(_events?.cancel());
    _periodic?.cancel();
    _debounce?.cancel();
    _pending = null;
    ++_revision;
    _client = next;
    _account = key;
    _members = {};
    _counts = {};
    _revoked = {};
    _known = false;
    _directoryKnown = false;
    _accountDirectoryRequired = refreshNow;
    notifyListeners();
    if (key == null || next == null) return;
    _events = next.events.listen(_event);
    _reads = InterceptorsWrapper(
      onResponse: (response, handler) {
        final request = response.requestOptions;
        if (request.method == 'POST' &&
            (RegExp(r'^/channels/[^/]+/read(?:-all)?$')
                    .hasMatch(request.path) ||
                request.path == '/channels/inbox/read-all')) {
          _schedule();
        }
        handler.next(response);
      },
    );
    next.http.interceptors.add(_reads!);
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Account icon counts must reconcile while hidden; this timer requests no frames and is retired with the authenticated account.
    _periodic = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
    if (refreshNow) unawaited(refresh());
  }

  void bindWorkspace(WorkspaceController? next) {
    if (_closed || identical(next, _workspace)) return;
    _stash();
    ++_revision;
    _pending = null;
    _detachWorkspace();
    if (next != null && _identity(next.client) == _account) {
      _workspace = next;
      next.addListener(_workspaceChanged);
      next.foregroundChanges.addListener(_foregroundChanged);
      _workspaceChanged();
    } else {
      notifyListeners();
    }
  }

  void _stash() {
    final id = _workspace?.server?.id, count = _activity?.totalUnreadCount;
    if (id != null && _members.contains(id) && count != null) {
      _counts[id] = count;
    }
  }

  void _workspaceChanged() {
    final w = _workspace;
    if (_closed || w == null) return;
    if (_identity(w.client) != _account) {
      bindClient(w.client);
      return;
    }
    final activity = w.services.activityUnreadIfBound;
    if (!identical(activity, _activity)) {
      _activity?.removeListener(_activityChanged);
      _activity = activity?..addListener(_activityChanged);
    }
    final authority = (
      w.client.generation,
      w.server?.id,
      w.server?.string('role'),
    );
    final authorityChanged = authority != _workspaceAuthority;
    final inferred = {
      for (final server in w.servers) server.id,
      if (w.server != null) w.server!.id,
    }..removeAll(_revoked);
    final directoryChanged = !setEquals(inferred, _workspaceDirectory);
    _workspaceDirectory = inferred;
    final members = _directoryKnown ? {..._members} : inferred;
    final membershipChanged = !setEquals(members, _members);
    if (authorityChanged || membershipChanged || directoryChanged) {
      ++_revision;
      _pending = null;
      _workspaceAuthority = authority;
      _members = members;
      _counts.removeWhere((id, _) => !members.contains(id));
      _known = true;
      unawaited(refresh());
    }
    _activityChanged();
  }

  void _activityChanged() {
    _stash();
    notifyListeners();
  }

  void _foregroundChanged() {
    if (_workspace?.foreground == true) unawaited(refresh());
  }

  void _event(RaftEvent event) {
    if (_identity(_client) != _account || event.name == 'session:ended') {
      bindClient(null);
      return;
    }
    final payload = event.payload;
    if (event.name == 'server:membership-removed' &&
        payload is Map &&
        (payload['userId'] == null || payload['userId'] == _client?.user?.id)) {
      final id = payload['serverId'];
      if (id is String) {
        ++_revision;
        _pending = null;
        _revoked.add(id);
        _members.remove(id);
        _counts.remove(id);
        notifyListeners();
      }
    }
    if (const {
      'rooms:joined',
      'message:new',
      'notification:push',
      'message:deleted',
      'thread:updated',
      'dm:new',
      'scope_read:updated',
      'notification_prefs:updated',
      'server:membership-removed',
      'server:member-updated',
    }.contains(event.name)) {
      _schedule();
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _debounce = null;
      unawaited(refresh());
    });
  }

  Future<void> refresh() {
    if (_closed || _account == null) return Future.value();
    final pending = _pending;
    if (pending != null) return pending;
    final read = _pending = _refresh();
    unawaited(
      read.whenComplete(() {
        if (identical(_pending, read)) _pending = null;
      }),
    );
    return read;
  }

  Future<void> _refresh() async {
    final client = _client!, account = _account, revision = _revision;
    bool current() =>
        !_closed &&
        revision == _revision &&
        account == _account &&
        _identity(client) == account;
    void acceptMembers(Set<String> members) {
      final changed = !_known || !setEquals(members, _members);
      _members = members;
      _counts.removeWhere((id, _) => !members.contains(id));
      _revoked = {};
      _known = _directoryKnown = true;
      if (changed) notifyListeners();
    }

    try {
      var members = {..._members};
      final counts = activitySummaryCounts(await client.accountUnreadSummary());
      if (!current()) return;
      final selected = _workspace?.server?.id;
      final selectedKnown = _activity?.totalUnreadCount != null;
      final omitted =
          counts != null &&
          members.any(
            (id) =>
                !counts.containsKey(id) && !(id == selected && selectedKnown),
          );
      if (_accountDirectoryRequired ||
          _workspace == null ||
          _revoked.isNotEmpty ||
          omitted) {
        // Read after the summary: an old row cannot reintroduce a membership
        // the current authoritative account directory has already removed.
        members = {
          for (final server in await client.accountServers()) server.id,
        };
        if (!current()) return;
        acceptMembers(members);
        if (!current()) return;
      }
      if (counts == null) return;
      final previous = _counts;
      _counts = {for (final id in members) id: counts[id] ?? previous[id]};
      _known = true;
      _stash();
      if (!mapEquals(previous, _counts)) notifyListeners();
      if (current() && total != null) successfulRefresh.value++;
    } catch (_) {
      // Accepted values survive failed or unknown member counts.
    }
  }

  void _detachWorkspace() {
    _workspace?.removeListener(_workspaceChanged);
    _workspace?.foregroundChanges.removeListener(_foregroundChanged);
    _activity?.removeListener(_activityChanged);
    _workspace = null;
    _activity = null;
    _workspaceAuthority = null;
    _workspaceDirectory = null;
  }

  @override
  void dispose() {
    if (_closed) return;
    bindClient(null);
    _closed = true;
    successfulRefresh.dispose();
    super.dispose();
  }
}

/// A headless delivery cannot replace a known global badge with a subtotal.
/// null keeps the OS's existing badge when the account summary is unavailable.
Future<int?> backgroundActivityBadge(
  RaftClient client, {
  int? selectedTotal,
}) async {
  try {
    final counts = activitySummaryCounts(await client.accountUnreadSummary());
    if (counts == null) return null;
    // The pre-inbox membership snapshot cannot authorize a later badge.
    final ids = {for (final server in await client.accountServers()) server.id};
    return knownActivityBadgeTotal(
      currentServerId: client.serverId,
      currentTotal: selectedTotal,
      memberServerIds: ids,
      summary: counts,
    );
  } catch (_) {
    return null;
  }
}
