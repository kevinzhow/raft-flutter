// The server's shared model-label catalog (Web store/modelLabelCatalogStore.ts,
// task #700): the names each Computer's daemon reported for its runtimes'
// models. Every display surface resolves a model's name from this one copy
// first, and falls back to the bundled table (agent_metadata_catalog.dart)
// only while a Computer has not reported, so a model the server names itself
// is never shown as a bare id.
//
// Loaded when something first asks and again after a server switch, never on
// a timer: a Computer's model list almost never changes.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/workspace_controller.dart';
import 'agent_metadata_catalog.dart' show sourceRuntimeModelLabels;
import 'agent_metadata_projection.dart';

/// Fetch window: a loaded catalog is not read again before this passes.
const modelLabelCatalogCache = Duration(minutes: 5);

/// A failed load backs off before the next attempt, so render-time asks cannot
/// hammer the endpoint.
const modelLabelCatalogRetry = Duration(seconds: 60);

/// machine id -> runtime id -> model id -> label.
typedef ModelLabelMap = Map<String, Map<String, Map<String, String>>>;

/// The catalog the server sent, or null when the payload is not one. A
/// malformed payload never replaces a good catalog (Web
/// isServerModelLabelCatalog).
ModelLabelMap? parseModelLabelCatalog(Object? value) {
  final machines = value is Map ? value['machines'] : null;
  if (machines is! Map) return null;
  final parsed = <String, Map<String, Map<String, String>>>{};
  for (final MapEntry(key: machineId, value: machine) in machines.entries) {
    final runtimes = machine is Map ? machine['runtimes'] : null;
    if (machineId is! String || runtimes is! Map) return null;
    final byRuntime = <String, Map<String, String>>{};
    for (final MapEntry(key: runtimeId, value: runtime) in runtimes.entries) {
      if (runtimeId is! String) continue;
      final models = runtime is Map ? runtime['models'] : null;
      byRuntime[runtimeId] = {
        if (models is List)
          for (final model in models)
            if (model is Map &&
                model['id'] is String &&
                model['label'] is String)
              model['id'] as String: model['label'] as String,
      };
    }
    parsed[machineId] = byRuntime;
  }
  return parsed;
}

/// One catalog per workspace session. Notifies when a catalog is accepted.
/// A plain listener list, not a [ChangeNotifier]: the store lives and dies
/// with the session that owns it and has no lifecycle of its own to dispose.
class ModelLabelCatalogStore implements Listenable {
  ModelLabelCatalogStore(this.w, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    w.addListener(_workspaceChanged);
    _scope = _currentScope;
  }

  /// The store of a workspace session.
  factory ModelLabelCatalogStore.of(WorkspaceController w) =>
      _stores[w] ??= ModelLabelCatalogStore(w);
  static final _stores = Expando<ModelLabelCatalogStore>();

  final WorkspaceController w;
  final DateTime Function() _clock;
  bool _disposed = false;

  AgentPresentationScope get _currentScope => (
    origin: w.client.origin,
    principal: w.client.user?.id ?? '',
    server: w.server?.id ?? '',
    authorityRevision: w.client.generation,
  );

  AgentPresentationScope? _scope;
  ModelLabelMap? _machines;
  DateTime? _fetchedAt, _attemptedAt;
  Future<void>? _inflight;

  /// The accepted catalog of the current scope as the presentation layer's
  /// value, or null before one arrived (or after the scope changed).
  AgentModelLabelCatalog? get catalog {
    final machines = _machines;
    return machines == null || _scope != _currentScope
        ? null
        : AgentModelLabelCatalog(scope: _scope!, machines: machines);
  }

  /// The label the server's catalog gives [modelId] on [machineId]'s runtime.
  String? label(String? machineId, String? runtimeId, String? modelId) {
    if (machineId == null || runtimeId == null || modelId == null) return null;
    if (_scope != _currentScope) return null;
    return _machines?[machineId]?[runtimeId]?[modelId];
  }

  void _workspaceChanged() {
    if (_disposed || _scope == _currentScope) return;
    // A server switch, account change or sign-out retires what was accepted.
    final had = _machines != null;
    _scope = _currentScope;
    _machines = null;
    _fetchedAt = _attemptedAt = null;
    _inflight = null;
    AgentModelLabelRegistry.forget(this);
    if (had) notifyListeners();
  }

  /// Reads the catalog unless a fresh one is held, a read is running, or a
  /// failed one is still backing off. [force] skips the window and the
  /// back-off (after a live detect).
  void load({bool force = false}) {
    if (_disposed) return;
    final server = w.server?.id;
    if (server == null) return;
    final now = _clock();
    final fetched = _fetchedAt, attempted = _attemptedAt;
    if (!force &&
        fetched != null &&
        now.difference(fetched) < modelLabelCatalogCache) {
      return;
    }
    if (_inflight != null) return;
    if (!force &&
        fetched == null &&
        attempted != null &&
        now.difference(attempted) < modelLabelCatalogRetry) {
      return;
    }
    _attemptedAt = now;
    final scope = _currentScope;
    late final Future<void> request;
    request = _read(scope).whenComplete(() {
      if (identical(_inflight, request)) _inflight = null;
    });
    _inflight = request;
  }

  Future<void> _read(AgentPresentationScope scope) async {
    try {
      final value = await w.query(
        '/servers/${scope.server}/model-label-catalog',
      );
      // A failed or foreign answer keeps the display on the bundled labels
      // (and a previous good catalog).
      final machines = parseModelLabelCatalog(value);
      if (_disposed || machines == null || scope != _currentScope) return;
      _scope = scope;
      _machines = machines;
      _fetchedAt = _clock();
      AgentModelLabelRegistry.accept(this, catalog!);
      notifyListeners();
    } catch (_) {
      // Display keeps the bundled fallback labels.
    }
  }

  final _listeners = <VoidCallback>{};
  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void dispose() {
    _disposed = true;
    w.removeListener(_workspaceChanged);
    AgentModelLabelRegistry.forget(this);
    _listeners.clear();
  }
}

/// A model's display name: the server's catalog for that Computer's runtime,
/// else the bundled table, else the id itself (Web agentModelName / profile
/// card chain). Reading never starts a load; callers [ModelLabelCatalogStore.load]
/// when their surface opens.
String modelDisplayLabel(
  WorkspaceController w, {
  required String? machineId,
  required String runtime,
  required String model,
}) =>
    ModelLabelCatalogStore.of(w).label(machineId, runtime, model) ??
    sourceRuntimeModelLabels[runtime]?[model] ??
    model;
