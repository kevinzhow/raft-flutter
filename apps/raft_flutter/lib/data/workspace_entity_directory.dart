import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

enum WorkspaceEntityKind { agents, computers, members }

/// An accepted entity belongs to the owning authenticated workspace projection.
/// Generation alone does not fence same-generation principal/role adoption.
@immutable
class WorkspaceEntityScope {
  const WorkspaceEntityScope({
    required this.origin,
    required this.principal,
    required this.serverId,
    required this.generation,
    required this.role,
    required this.capabilities,
  });
  final String origin, principal, serverId, role;
  final int generation;
  final Set<WorkspaceEntityKind> capabilities;
  bool allows(WorkspaceEntityKind kind) => capabilities.contains(kind);
  @override
  bool operator ==(Object other) =>
      other is WorkspaceEntityScope &&
      origin == other.origin &&
      principal == other.principal &&
      serverId == other.serverId &&
      generation == other.generation &&
      role == other.role &&
      setEquals(capabilities, other.capabilities);
  @override
  int get hashCode => Object.hash(
    origin,
    principal,
    serverId,
    generation,
    role,
    Object.hashAllUnordered(capabilities),
  );
}

@immutable
class WorkspaceEntityLoadState {
  const WorkspaceEntityLoadState({
    this.loading = false,
    this.loaded = false,
    this.error,
  });
  final bool loading, loaded;
  final Object? error;
}

/// Source agentDetailAvailability.ts:21–42, including deliberate public
/// channel/remote projections. An id-only route is never an entity snapshot.
bool canRenderWorkspaceAgent(Map<String, dynamic>? row, String? serverId) {
  if (row == null ||
      row['deletedAt'] != null ||
      row['id'] is! String ||
      row['name'] is! String ||
      row['status'] is! String) {
    return false;
  }
  final remote =
      row['serverId'] is String &&
      serverId != null &&
      row['serverId'] != serverId &&
      row.containsKey('displayName') &&
      (row['displayName'] == null || row['displayName'] is String) &&
      row.containsKey('avatarUrl') &&
      (row['avatarUrl'] == null || row['avatarUrl'] is String) &&
      ['active', 'inactive', 'stopped'].contains(row['status']);
  return remote ||
      row['profileProjection'] == 'channel_summary' ||
      (row['runtime'] is String && row['model'] is String);
}

bool canRenderWorkspaceComputer(Map<String, dynamic>? row) =>
    row != null &&
    row['id'] is String &&
    row['name'] is String &&
    row['status'] is String;

Map<String, dynamic> _copy(Map<String, dynamic> row) => {
  for (final entry in row.entries) entry.key: _copyValue(entry.value),
};
dynamic _copyValue(dynamic value) => value is Map
    ? _copy(Map<String, dynamic>.from(value))
    : value is List
    ? value.map(_copyValue).toList()
    : value;

/// Reads the record [WorkspaceEntityDirectory] last saved for [kind] under
/// the account/server of [scope] (null when nothing is on the device).
typedef WorkspaceEntityDeviceRead = Future<dynamic> Function(
  WorkspaceEntityScope scope,
  WorkspaceEntityKind kind,
);

/// Saves (or, for null, deletes) the record of [kind] under the
/// account/server of [scope].
typedef WorkspaceEntityDeviceWrite = void Function(
  WorkspaceEntityScope scope,
  WorkspaceEntityKind kind,
  Map<String, dynamic>? record,
);

/// Source store projection. Cold requests show a shell; refresh failures
/// preserve accepted rows and carry a separate error. Every response is
/// fenced by scope and request revision. Borrowed editors share this object.
///
/// With [readDevice]/[writeDevice] the accepted rows of each kind (agents
/// with their tombstones, members, computers) are also kept on the device,
/// one record per kind under (origin, principal, server), stamped with the
/// role they were accepted under. Each new scope paints that record before
/// any response ([restored]); it is never an authorization grant: it is only
/// adopted for a kind the scope allows, under the same role, while no fresher
/// facts were accepted, and it is always revalidated by the scope's own read.
/// A record for another role, or for a kind the scope no longer allows, is
/// deleted. Accepted reads and realtime patches are written back (debounced,
/// see [persistDelay]); a 401/403 deletes the kind.
class WorkspaceEntityDirectory extends ChangeNotifier {
  WorkspaceEntityDirectory({
    required WorkspaceEntityScope? Function() scope,
    required this.query,
    Stream<RaftEvent>? events,
    this.readDevice,
    this.writeDevice,
  }) : _readScope = scope {
    _subscription = events?.listen(_event);
  }
  final WorkspaceEntityScope? Function() _readScope;
  final Future<dynamic> Function(String path) query;
  final WorkspaceEntityDeviceRead? readDevice;
  final WorkspaceEntityDeviceWrite? writeDevice;

  /// Version of the on-device record layout.
  static const deviceRecordVersion = 1;

  /// Window in which accepted reads and realtime patches are coalesced into
  /// one device write per kind.
  static const persistDelay = Duration(milliseconds: 500);
  WorkspaceEntityScope? _scope;
  final _rows = <WorkspaceEntityKind, Map<String, Map<String, dynamic>>>{};
  final _states = <WorkspaceEntityKind, WorkspaceEntityLoadState>{};
  final _pending = <WorkspaceEntityKind, Future<void>>{};
  final _activityVersions = <String, int>{};
  final _activity = <String, Map<String, dynamic>>{};
  final _tickets = <WorkspaceEntityKind, int>{};

  /// Authorized agent tombstones. They are not live entities (lookups and
  /// [rows] never return them) but still identify historical message senders.
  final _tombstones = <String, Map<String, dynamic>>{};

  /// Kinds that settled (accepted or failed) at least once in this scope.
  final _settled = <WorkspaceEntityKind>{};

  /// Kinds whose rows came from the device and await this scope's read.
  final _fromDevice = <WorkspaceEntityKind>{};

  /// Kinds the server refused (401/403) in this scope: never restored.
  final _denied = <WorkspaceEntityKind>{};

  /// Kinds read (at least started) from the server in this scope. A kind
  /// painted from the device is settled but still read once.
  final _requested = <WorkspaceEntityKind>{};
  final _persistDirty = <WorkspaceEntityKind>{};
  Timer? _persistTimer;
  Future<void> _restoring = Future.value();
  int _authorRevision = 0, _agentRevision = 0, _agentRequests = 0;
  int _computerRevision = 0;
  List<Map<String, dynamic>>? _authorAgents, _authorMembers;
  int _epoch = 0;
  bool _disposed = false;
  bool started = false;
  Timer? _refresh;
  final _dirty = <WorkspaceEntityKind>{}, _queued = <WorkspaceEntityKind>{};
  StreamSubscription<RaftEvent>? _subscription;

  /// Window in which catalog events (created/deleted/updated, machine
  /// transitions, member changes) are coalesced into one read per kind.
  static const reloadDelay = Duration(milliseconds: 150);

  /// Called by the owner on authority notification; lookup also fences itself.
  bool synchronize() {
    if (_disposed) return false;
    final next = _readScope();
    if (next == _scope) return false;
    _scope = next;
    ++_epoch;
    _pending.clear();
    _rows.clear();
    _states.clear();
    _activityVersions.clear();
    _activity.clear();
    _tombstones.clear();
    _settled.clear();
    _latestComputerVersion = null;
    _fromDevice.clear();
    _denied.clear();
    _requested.clear();
    // Unwritten changes belong to the previous scope, which may have been
    // revoked: they are dropped, never written under the new one.
    _persistTimer?.cancel();
    _persistTimer = null;
    _persistDirty.clear();
    _authorAgents = _authorMembers = null;
    _authorRevision++;
    _agentRevision++;
    _computerRevision++;
    _refresh?.cancel();
    _refresh = null;
    _dirty.clear();
    _queued.clear();
    _restoring = next == null ? Future.value() : _restore(next, _epoch);
    return true;
  }

  /// Completes once the device records of the current scope were read and,
  /// when still valid, painted. Server selection waits for it before its
  /// first workspace frame.
  Future<void> get restored {
    synchronize();
    return _restoring;
  }

  /// True while the rows of [kind] are the device copy and this scope's own
  /// read has not been accepted yet (they are being revalidated).
  bool fromDevice(WorkspaceEntityKind kind) {
    synchronize();
    return _fromDevice.contains(kind);
  }

  Future<void> _restore(WorkspaceEntityScope scope, int epoch) async {
    final read = readDevice, write = writeDevice;
    if (read == null) return;
    await Future.wait([
      for (final kind in WorkspaceEntityKind.values)
        if (scope.allows(kind))
          _restoreKind(scope, epoch, kind, read)
        else if (write != null)
          // A permission downgrade retires what the old role saved.
          Future.sync(() => write(scope, kind, null)),
    ]);
  }

  Future<void> _restoreKind(
    WorkspaceEntityScope scope,
    int epoch,
    WorkspaceEntityKind kind,
    WorkspaceEntityDeviceRead read,
  ) async {
    dynamic value;
    try {
      value = await read(scope, kind);
    } catch (_) {
      return;
    }
    if (value == null || !_accepts(scope, epoch)) return;
    final record = _deviceRecord(scope, kind, value);
    if (record == null) {
      // Another role (or an unknown layout) never paints; it is retired.
      writeDevice?.call(scope, kind, null);
      return;
    }
    // Fresher facts of this scope (an accepted read, or a refusal) win.
    if (_rows.containsKey(kind) || _denied.contains(kind)) return;
    _rows[kind] = record.$1;
    if (kind == WorkspaceEntityKind.agents) {
      _tombstones
        ..clear()
        ..addAll(record.$2);
    }
    if (kind == WorkspaceEntityKind.computers) {
      final latest = value['latestComputerVersion'];
      _latestComputerVersion = latest is String ? latest : null;
    }
    _fromDevice.add(kind);
    _settled.add(kind);
    _states[kind] = WorkspaceEntityLoadState(
      loading: _pending.containsKey(kind),
      loaded: true,
      error: _states[kind]?.error,
    );
    _authorsChanged(kind);
    notifyListeners();
  }

  (Map<String, Map<String, dynamic>>, Map<String, Map<String, dynamic>>)?
  _deviceRecord(
    WorkspaceEntityScope scope,
    WorkspaceEntityKind kind,
    dynamic value,
  ) {
    if (value is! Map ||
        value['version'] != deviceRecordVersion ||
        value['kind'] != kind.name ||
        value['role'] != scope.role ||
        value['rows'] is! List) {
      return null;
    }
    final rows = <String, Map<String, dynamic>>{};
    for (final item in value['rows'] as List) {
      if (item is! Map) return null;
      final row = _copy(Map<String, dynamic>.from(item));
      final id = _id(kind, row);
      if (id == null ||
          (kind == WorkspaceEntityKind.agents && row['deletedAt'] != null)) {
        return null;
      }
      rows[id] = row;
    }
    final tombstones = <String, Map<String, dynamic>>{};
    if (kind == WorkspaceEntityKind.agents && value['tombstones'] is List) {
      for (final item in value['tombstones'] as List) {
        if (item is! Map) return null;
        final row = _copy(Map<String, dynamic>.from(item));
        final id = row['id'];
        if (id is! String || id.isEmpty || row['deletedAt'] == null) {
          return null;
        }
        tombstones[id] = row;
      }
    }
    return (rows, tombstones);
  }

  /// Schedules a device write of [kind]'s current rows (or its deletion when
  /// the scope holds none).
  void _persist(WorkspaceEntityKind kind) {
    if (_disposed || writeDevice == null || _scope == null) return;
    _persistDirty.add(kind);
    _persistTimer ??= Timer(persistDelay, flushDevice);
  }

  /// Writes every scheduled change now (the owner calls this before it
  /// flushes or closes its device cache).
  void flushDevice() {
    _persistTimer?.cancel();
    _persistTimer = null;
    final write = writeDevice, scope = _scope;
    final kinds = Set.of(_persistDirty);
    _persistDirty.clear();
    if (_disposed || write == null || scope == null) return;
    if (scope != _readScope()) return;
    for (final kind in kinds) {
      if (!scope.allows(kind)) continue;
      final rows = _rows[kind];
      write(
        scope,
        kind,
        rows == null
            ? null
            : {
                'version': deviceRecordVersion,
                'kind': kind.name,
                'role': scope.role,
                'rows': [for (final row in rows.values) _copy(row)],
                if (kind == WorkspaceEntityKind.agents)
                  'tombstones': [
                    for (final row in _tombstones.values) _copy(row),
                  ],
                if (kind == WorkspaceEntityKind.computers)
                  'latestComputerVersion': _latestComputerVersion,
              },
      );
    }
  }

  // Message-author directory: one server-scoped projection shared by every
  // mounted chat, thread, activity and saved surface. It is cleared only when
  // the server-level identity (principal, server, generation, role or
  // capabilities) changes. Revalidation keeps the accepted lists in place.

  /// Agents, including authorized tombstones, as immutable rows.
  List<Map<String, dynamic>> get authorAgents {
    synchronize();
    if (_disposed || _scope?.allows(WorkspaceEntityKind.agents) != true) {
      return const [];
    }
    return _authorAgents ??= List.unmodifiable([
      for (final row in [
        ...?_rows[WorkspaceEntityKind.agents]?.values,
        ..._tombstones.values,
      ])
        Map<String, dynamic>.unmodifiable(_copy(row)),
    ]);
  }

  List<Map<String, dynamic>> get authorMembers {
    synchronize();
    if (_disposed || _scope?.allows(WorkspaceEntityKind.members) != true) {
      return const [];
    }
    return _authorMembers ??= List.unmodifiable([
      for (final row
          in _rows[WorkspaceEntityKind.members]?.values ??
              const <Map<String, dynamic>>[])
        Map<String, dynamic>.unmodifiable(_copy(row)),
    ]);
  }

  /// Changes whenever [authorAgents] or [authorMembers] is replaced/cleared.
  int get authorRevision {
    synchronize();
    return _authorRevision;
  }

  /// Changes whenever [authorAgents] is replaced or cleared.
  int get agentRevision {
    synchronize();
    return _agentRevision;
  }

  /// Changes whenever an agents request starts.
  int get agentRequestRevision => _agentRequests;

  /// Changes whenever a computer row is accepted, patched (status,
  /// capabilities) or cleared. Agent presence patches never change it.
  int get computerRevision {
    synchronize();
    return _computerRevision;
  }

  /// True only while the current scope has no settled author data yet. A
  /// revalidation of accepted lists never reports loading.
  bool get authorsLoading {
    synchronize();
    final scope = _scope;
    if (_disposed || scope == null) return false;
    return [
      WorkspaceEntityKind.agents,
      WorkspaceEntityKind.members,
    ].any((kind) => scope.allows(kind) && !_settled.contains(kind));
  }

  /// Starts the author lists once per scope; accepted or in-flight lists are
  /// reused by every surface.
  void ensureAuthors() =>
      ensure(const [WorkspaceEntityKind.agents, WorkspaceEntityKind.members]);

  /// Starts each kind that has not settled (or was only painted from the
  /// device) in this scope. Accepted or in-flight lists are reused, so a
  /// revisited surface renders its rows at the first frame without a request. [retryFailed] also re-reads a kind whose
  /// last read failed (a surface the user explicitly opens again).
  void ensure(Iterable<WorkspaceEntityKind> kinds, {bool retryFailed = false}) {
    synchronize();
    for (final kind in kinds) {
      if (_pending.containsKey(kind)) continue;
      if (!_settled.contains(kind) ||
          !_requested.contains(kind) ||
          (retryFailed && _states[kind]?.error != null)) {
        unawaited(refresh(kind));
      }
    }
  }

  /// True once [kind] was accepted or failed in the current scope. A
  /// revalidation of a settled kind never makes it unsettled again.
  bool settled(WorkspaceEntityKind kind) {
    synchronize();
    return _settled.contains(kind);
  }

  /// True when [id] is an authorized deleted agent (a tombstone).
  bool agentDeleted(String id) {
    synchronize();
    return !_disposed &&
        _scope?.allows(WorkspaceEntityKind.agents) == true &&
        _tombstones.containsKey(id);
  }

  /// Supersedes any in-flight author read (reconnect/conflict reconcile). The
  /// previous lists stay visible until the replacement is accepted.
  void revalidateAuthors() {
    for (final kind in [
      WorkspaceEntityKind.agents,
      WorkspaceEntityKind.members,
    ]) {
      unawaited(refresh(kind, force: true));
    }
  }

  void _authorsChanged(WorkspaceEntityKind kind) {
    if (kind == WorkspaceEntityKind.computers) {
      _computerRevision++;
    } else if (kind == WorkspaceEntityKind.agents) {
      _authorAgents = null;
      _agentRevision++;
      _authorRevision++;
    } else if (kind == WorkspaceEntityKind.members) {
      _authorMembers = null;
      _authorRevision++;
    }
  }

  Map<String, dynamic>? _lookup(WorkspaceEntityKind kind, String id) {
    synchronize();
    if (_disposed || _scope?.allows(kind) != true) return null;
    final row = _rows[kind]?[id];
    return row == null ? null : _copy(row);
  }

  Map<String, dynamic>? agent(String id) =>
      _lookup(WorkspaceEntityKind.agents, id);
  Map<String, dynamic>? computer(String id) =>
      _lookup(WorkspaceEntityKind.computers, id);

  /// Latest published Computer version from the machines read
  /// (`{machines, latestComputerVersion}`, Web machineStore.ts:280); the
  /// Computers rail and detail compare each row against it.
  String? get latestComputerVersion {
    synchronize();
    return _scope?.allows(WorkspaceEntityKind.computers) == true
        ? _latestComputerVersion
        : null;
  }

  String? _latestComputerVersion;
  Map<String, dynamic>? member(String userId) =>
      _lookup(WorkspaceEntityKind.members, userId);
  List<Map<String, dynamic>> rows(WorkspaceEntityKind kind) {
    synchronize();
    if (_disposed || _scope?.allows(kind) != true) return [];
    return [
      for (final row in _rows[kind]?.values ?? <Map<String, dynamic>>[])
        _copy(row),
    ];
  }

  WorkspaceEntityLoadState state(WorkspaceEntityKind kind) {
    synchronize();
    return _states[kind] ?? const WorkspaceEntityLoadState();
  }

  Future<void> preload() async {
    started = true;
    synchronize();
    await Future.wait([
      for (final kind in WorkspaceEntityKind.values) refresh(kind),
    ]);
  }

  Future<void> refresh(WorkspaceEntityKind kind, {bool force = false}) {
    started = true;
    synchronize();
    final scope = _scope;
    if (_disposed || scope == null || !scope.allows(kind)) {
      return Future.value();
    }
    final existing = _pending[kind];
    if (existing != null && !force) return existing;
    final epoch = _epoch;
    _requested.add(kind);
    final ticket = _tickets[kind] = (_tickets[kind] ?? 0) + 1;
    if (kind == WorkspaceEntityKind.agents) _agentRequests++;
    bool current() => _accepts(scope, epoch) && _tickets[kind] == ticket;
    final versions = Map<String, int>.of(_activityVersions);
    _states[kind] = WorkspaceEntityLoadState(
      loading: true,
      loaded: _states[kind]?.loaded == true,
    );
    // Defer notification: a mounted panel can start loading in initState while
    // the workspace is building. Its first frame reads state synchronously.
    scheduleMicrotask(() {
      if (_accepts(scope, epoch)) notifyListeners();
    });
    late final Future<void> pending;
    pending = (() async {
      try {
        final value = await Future.sync(
          () => query(switch (kind) {
            WorkspaceEntityKind.agents => '/agents',
            WorkspaceEntityKind.computers =>
              '/servers/${scope.serverId}/machines',
            WorkspaceEntityKind.members => '/servers/${scope.serverId}/members',
          }),
        );
        if (!current()) return;
        final raw = kind == WorkspaceEntityKind.computers && value is Map
            ? value['machines']
            : value;
        if (raw is! List || raw.any((row) => row is! Map)) {
          throw const FormatException(
            'Invalid workspace entity directory response.',
          );
        }
        final accepted = <String, Map<String, dynamic>>{};
        final tombstones = <String, Map<String, dynamic>>{};
        for (final item in raw) {
          final row = Map<String, dynamic>.from(item as Map);
          if (kind == WorkspaceEntityKind.agents && row['deletedAt'] != null) {
            final id = row['id'];
            if (id is String && id.isNotEmpty) tombstones[id] = _copy(row);
            continue;
          }
          final id = _id(kind, row);
          if (id == null) {
            throw const FormatException('Invalid workspace entity record.');
          }
          if (kind == WorkspaceEntityKind.agents &&
              (_activityVersions[id] ?? 0) > (versions[id] ?? 0)) {
            row.addAll(_activity[id] ?? {});
          }
          // agent:seen is monotonic across an older list snapshot.
          final seen = _rows[kind]?[id]?['lastSeenAt'];
          if (kind == WorkspaceEntityKind.agents &&
              seen is String &&
              (row['lastSeenAt'] is! String ||
                  (DateTime.tryParse(seen)?.isAfter(
                        DateTime.tryParse(row['lastSeenAt'] as String) ??
                            DateTime(0),
                      ) ??
                      false))) {
            row['lastSeenAt'] = seen;
          }
          accepted[id] = _copy(row);
        }
        _rows[kind] = accepted;
        if (kind == WorkspaceEntityKind.computers) {
          final latest = value is Map ? value['latestComputerVersion'] : null;
          _latestComputerVersion = latest is String ? latest : null;
        }
        if (kind == WorkspaceEntityKind.agents) {
          _tombstones
            ..clear()
            ..addAll(tombstones);
        }
        _states[kind] = const WorkspaceEntityLoadState(loaded: true);
        _settled.add(kind);
        _fromDevice.remove(kind);
        _authorsChanged(kind);
        _persist(kind);
      } catch (error) {
        if (!current()) return;
        if (error is RaftApiException && [401, 403].contains(error.status)) {
          _rows.remove(kind);
          if (kind == WorkspaceEntityKind.agents) _tombstones.clear();
          _fromDevice.remove(kind);
          _denied.add(kind);
          _authorsChanged(kind);
          _persist(kind);
        }
        _states[kind] = WorkspaceEntityLoadState(
          loaded: _rows[kind]?.isNotEmpty == true,
          error: error,
        );
        _settled.add(kind);
      } finally {
        if (current() && identical(_pending[kind], pending)) {
          _pending.remove(kind);
          notifyListeners();
        }
      }
    })();
    _pending[kind] = pending;
    return pending;
  }

  bool _accepts(WorkspaceEntityScope scope, int epoch) =>
      !_disposed && epoch == _epoch && scope == _scope && scope == _readScope();
  String? _id(WorkspaceEntityKind kind, Map<String, dynamic> row) {
    final id = row[kind == WorkspaceEntityKind.members ? 'userId' : 'id'];
    return id is String && id.isNotEmpty && row['name'] is String ? id : null;
  }

  void _event(RaftEvent event) {
    synchronize();
    final scope = _scope;
    if (_disposed || scope == null) return;
    final payload = event.payload is Map
        ? Map<String, dynamic>.from(event.payload as Map)
        : const <String, dynamic>{};
    final agents = scope.allows(WorkspaceEntityKind.agents);
    final computers = scope.allows(WorkspaceEntityKind.computers);
    switch (event.name) {
      // Source socketBridge agentActivity -> agentStore.updateActivity.
      case 'agent:activity' when agents:
        final id = payload['agentId'];
        if (id is! String) return;
        final patch = <String, dynamic>{
          if (payload['activity'] is String) 'activity': payload['activity'],
          if (payload['detail'] is String) 'activityDetail': payload['detail'],
        };
        _activityVersions[id] = (_activityVersions[id] ?? 0) + 1;
        _activity[id] = patch;
        // A heartbeat repeating the accepted activity changes nothing.
        final row = _rows[WorkspaceEntityKind.agents]?[id];
        if (row == null ||
            patch.entries.every((entry) => row[entry.key] == entry.value)) {
          return;
        }
        row.addAll(patch);
        _persist(WorkspaceEntityKind.agents);
        notifyListeners();
      // Source agentStore.applyAgentSeen: monotonic, no request.
      case 'agent:seen' when agents:
        final id = payload['agentId'], seen = payload['lastSeenAt'];
        if (id is! String || seen is! String) return;
        _patchAgent(id, (row) {
          final next = DateTime.tryParse(seen);
          final current = row['lastSeenAt'] is String
              ? DateTime.tryParse(row['lastSeenAt'] as String)
              : null;
          if (next == null || (current != null && !next.isAfter(current))) {
            return false;
          }
          row['lastSeenAt'] = seen;
          return true;
        });
      // Source agentStore.updateAgentSession: identity-preserving no-op when
      // the session is unchanged, no request.
      case 'agent:session' when agents:
        final id = payload['agentId'], session = payload['sessionId'];
        if (id is! String ||
            !payload.containsKey('sessionId') ||
            (session != null && session is! String)) {
          return;
        }
        _patchAgent(id, (row) {
          if (row.containsKey('sessionId') && row['sessionId'] == session) {
            return false;
          }
          row['sessionId'] = session;
          return true;
        });
      // Source agent:created/deleted -> loadAgents; agent:updated ->
      // reloadAgentsAfterServerChange. Only the agent list is re-read; the
      // pushed row (or tombstone) is visible before that read lands.
      case 'agent:created' when agents:
        final row = payload['agent'];
        if (row is Map) {
          final value = Map<String, dynamic>.from(row);
          final id = _id(WorkspaceEntityKind.agents, value);
          final accepted = _rows[WorkspaceEntityKind.agents];
          if (id != null &&
              value['deletedAt'] == null &&
              accepted != null &&
              !accepted.containsKey(id)) {
            accepted[id] = _copy(value);
            _authorsChanged(WorkspaceEntityKind.agents);
            _persist(WorkspaceEntityKind.agents);
            notifyListeners();
          }
        }
        _scheduleReload(const {WorkspaceEntityKind.agents});
      case 'agent:deleted' when agents:
        final id = payload['agentId'] ?? payload['id'];
        if (id is! String) {
          _scheduleReload(const {WorkspaceEntityKind.agents});
          return;
        }
        final row = _rows[WorkspaceEntityKind.agents]?.remove(id);
        if (row != null) {
          _tombstones[id] = {
            ...row,
            'deletedAt': DateTime.now().toUtc().toIso8601String(),
          };
          _authorsChanged(WorkspaceEntityKind.agents);
          _persist(WorkspaceEntityKind.agents);
          notifyListeners();
        }
        _scheduleReload(const {WorkspaceEntityKind.agents});
      case 'agent:updated' when agents:
        _scheduleReload(const {WorkspaceEntityKind.agents});
      // Source machineEvents applyStatus: statusVersion-gated patch. A stale or
      // duplicate frame is a no-op; an accepted transition (or an unknown
      // machine coming online) asks for the machines-and-agents recovery read.
      case 'machine:status' when computers:
        final id = payload['machineId'], status = payload['status'];
        if (id is! String || status is! String) return;
        final version = payload['statusVersion'];
        final row = _rows[WorkspaceEntityKind.computers]?[id];
        if (row == null) {
          if (status == 'online') {
            _scheduleReload(const {
              WorkspaceEntityKind.computers,
              WorkspaceEntityKind.agents,
            });
          }
          return;
        }
        final current = row['statusVersion'];
        if (version is int && current is int && version < current) return;
        if (row['status'] == status &&
            (version is! int || version == current)) {
          return;
        }
        row['status'] = status;
        if (version is int) row['statusVersion'] = version;
        _computerRevision++;
        _persist(WorkspaceEntityKind.computers);
        notifyListeners();
        _scheduleReload(const {
          WorkspaceEntityKind.computers,
          WorkspaceEntityKind.agents,
        });
      // Source machineEvents applyCapabilities: patch only.
      case 'machine:capabilities' when computers:
        final id = payload['machineId'];
        if (id is! String) return;
        final row = _rows[WorkspaceEntityKind.computers]?[id];
        if (row == null) return;
        final patch = <String, dynamic>{
          if (payload['runtimes'] is List)
            'runtimes': List<dynamic>.from(payload['runtimes'] as List),
          for (final key in const [
            'runtimeVersions',
            'hostname',
            'os',
            'daemonVersion',
            'computerVersion',
          ])
            if (payload.containsKey(key)) key: _copyValue(payload[key]),
        };
        if (patch.entries.every(
          (entry) => _sameValue(row[entry.key], entry.value),
        )) {
          return;
        }
        row.addAll(patch);
        _computerRevision++;
        _persist(WorkspaceEntityKind.computers);
        notifyListeners();
      // Source machine:updated / machine:upgrade-request / successful restart:
      // re-read the machine list only.
      case 'machine:updated' ||
              'machine:upgrade-request' ||
              'machine:created' ||
              'machine:deleted'
          when computers:
        _scheduleReload(const {WorkspaceEntityKind.computers});
      case 'computer:restart:done' when computers:
        if (payload['ok'] == true) {
          _scheduleReload(const {WorkspaceEntityKind.computers});
        }
      // Source refreshMembersForServer: re-read members of the current server.
      case 'server:member-added' ||
              'server:member:left' ||
              'server:member-removed' ||
              'server:member-updated'
          when scope.allows(WorkspaceEntityKind.members):
        final server = payload['serverId'];
        if (server is String && server != scope.serverId) return;
        _scheduleReload(const {WorkspaceEntityKind.members});
      // Source loadConnectSnapshotSet re-reads machines on (re)connect. Agents
      // are revalidated by the author directory's own reconnect path.
      case 'connected' when computers:
        if (_settled.contains(WorkspaceEntityKind.computers)) {
          _scheduleReload(const {WorkspaceEntityKind.computers});
        }
    }
  }

  void _patchAgent(String id, bool Function(Map<String, dynamic> row) patch) {
    final row = _rows[WorkspaceEntityKind.agents]?[id];
    if (row != null && patch(row)) {
      _persist(WorkspaceEntityKind.agents);
      notifyListeners();
    }
  }

  static bool _sameValue(dynamic a, dynamic b) {
    if (a is List && b is List) {
      return a.length == b.length &&
          [for (var i = 0; i < a.length; i++) i]
              .every((i) => _sameValue(a[i], b[i]));
    }
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every(
            (key) => b.containsKey(key) && _sameValue(a[key], b[key]),
          );
    }
    return a == b;
  }

  /// Coalesces a burst of catalog events into one read per affected kind.
  /// Nothing is read before the directory has been started by a surface.
  void _scheduleReload(Set<WorkspaceEntityKind> kinds) {
    if (!started) return;
    _dirty.addAll(kinds);
    _refresh ??= Timer(reloadDelay, () {
      _refresh = null;
      if (_disposed) return;
      final dirty = Set.of(_dirty);
      _dirty.clear();
      dirty.forEach(_reloadAfterChange);
    });
  }

  /// Source reloadAgentsAfterServerChange: a read already in flight may have
  /// been answered before the change, so wait for it and read once more.
  /// Several changes during the same wait share that one extra read.
  void _reloadAfterChange(WorkspaceEntityKind kind) {
    final pending = _pending[kind];
    if (pending == null) {
      unawaited(refresh(kind));
      return;
    }
    if (!_queued.add(kind)) return;
    final epoch = _epoch;
    void again() {
      if (_disposed || epoch != _epoch) return;
      _queued.remove(kind);
      unawaited(refresh(kind));
    }

    unawaited(pending.then((_) => again(), onError: (_) => again()));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    _rows.clear();
    _tombstones.clear();
    _authorAgents = _authorMembers = null;
    _pending.clear();
    _refresh?.cancel();
    _dirty.clear();
    _queued.clear();
    // Unflushed device writes are dropped: the owner flushes before closing.
    _persistTimer?.cancel();
    _persistDirty.clear();
    _subscription?.cancel();
    super.dispose();
  }
}

/// Follows one facet of a [WorkspaceEntityDirectory] (for example the
/// identity lists through [WorkspaceEntityDirectory.authorRevision]) and
/// notifies only when [select] returns a different value. Presence patches
/// (agent:activity/seen/session) then never reach a surface that does not
/// render them.
class WorkspaceEntitySelection extends ChangeNotifier {
  WorkspaceEntitySelection(this.directory, this.select)
    : _value = select(directory) {
    directory.addListener(_changed);
  }
  final WorkspaceEntityDirectory directory;
  final Object? Function(WorkspaceEntityDirectory directory) select;
  Object? _value;
  bool _disposed = false;

  void _changed() {
    if (_disposed) return;
    final next = select(directory);
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    directory.removeListener(_changed);
    super.dispose();
  }
}
