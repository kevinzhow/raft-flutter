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

/// Memory-only Source store projection. Cold requests show a shell; refresh
/// failures preserve accepted rows and carry a separate error. Every response
/// is fenced by scope and request revision. Borrowed editors share this object.
class WorkspaceEntityDirectory extends ChangeNotifier {
  WorkspaceEntityDirectory({
    required WorkspaceEntityScope? Function() scope,
    required this.query,
    Stream<RaftEvent>? events,
  }) : _readScope = scope {
    _subscription = events?.listen(_event);
  }
  final WorkspaceEntityScope? Function() _readScope;
  final Future<dynamic> Function(String path) query;
  WorkspaceEntityScope? _scope;
  final _rows = <WorkspaceEntityKind, Map<String, Map<String, dynamic>>>{};
  final _states = <WorkspaceEntityKind, WorkspaceEntityLoadState>{};
  final _pending = <WorkspaceEntityKind, Future<void>>{};
  final _activityVersions = <String, int>{};
  final _activity = <String, Map<String, dynamic>>{};
  int _epoch = 0;
  bool _disposed = false;
  bool started = false;
  Timer? _refresh;
  StreamSubscription<RaftEvent>? _subscription;

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
    _refresh?.cancel();
    return true;
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

  Future<void> refresh(WorkspaceEntityKind kind) {
    started = true;
    synchronize();
    final scope = _scope;
    if (_disposed || scope == null || !scope.allows(kind)) {
      return Future.value();
    }
    final existing = _pending[kind];
    if (existing != null) return existing;
    final epoch = _epoch;
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
        if (!_accepts(scope, epoch)) return;
        final raw = kind == WorkspaceEntityKind.computers && value is Map
            ? value['machines']
            : value;
        if (raw is! List || raw.any((row) => row is! Map)) {
          throw const FormatException(
            'Invalid workspace entity directory response.',
          );
        }
        final accepted = <String, Map<String, dynamic>>{};
        for (final item in raw) {
          final row = Map<String, dynamic>.from(item as Map);
          if (kind == WorkspaceEntityKind.agents && row['deletedAt'] != null) {
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
          accepted[id] = _copy(row);
        }
        _rows[kind] = accepted;
        _states[kind] = const WorkspaceEntityLoadState(loaded: true);
      } catch (error) {
        if (!_accepts(scope, epoch)) return;
        if (error is RaftApiException && [401, 403].contains(error.status)) {
          _rows.remove(kind);
        }
        _states[kind] = WorkspaceEntityLoadState(
          loaded: _rows[kind]?.isNotEmpty == true,
          error: error,
        );
      } finally {
        if (_accepts(scope, epoch) && identical(_pending[kind], pending)) {
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
    if (_disposed || _scope == null) return;
    if (event.name == 'agent:activity' && event.payload is Map) {
      final payload = event.payload as Map;
      final id = payload['agentId'];
      if (id is String && _scope!.allows(WorkspaceEntityKind.agents)) {
        final patch = <String, dynamic>{
          if (payload['activity'] is String) 'activity': payload['activity'],
          if (payload['detail'] is String) 'activityDetail': payload['detail'],
        };
        _activityVersions[id] = (_activityVersions[id] ?? 0) + 1;
        _activity[id] = patch;
        _rows[WorkspaceEntityKind.agents]?[id]?.addAll(patch);
        notifyListeners();
      }
      return;
    }
    if (started &&
        (event.name.startsWith('agent:') ||
            event.name.startsWith('machine:') ||
            event.name.startsWith('server:member'))) {
      _refresh?.cancel();
      _refresh = Timer(const Duration(milliseconds: 150), () {
        if (!_disposed) unawaited(preload());
      });
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    _rows.clear();
    _pending.clear();
    _refresh?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
