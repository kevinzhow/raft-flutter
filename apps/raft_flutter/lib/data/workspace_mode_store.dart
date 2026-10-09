import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'search_memory.dart';
import 'workspace_controller.dart';

/// Mounted workspaceGridAvailability + workspaceGridNavigationStore contract.
/// DEV availability is separate from the default-false personal preference.
/// Release builds require the actual server feature evaluation. The native
/// preference adds API origin isolation to Source's per-user storage key.
class WorkspaceModeStore extends ChangeNotifier {
  WorkspaceModeStore(this.workspace, {SearchMemoryStorage? storage, bool? dev})
    : storage = storage ?? PreferencesSearchMemoryStorage(),
      dev = dev ?? kDebugMode {
    workspace.addListener(synchronize);
    events = workspace.client.events.listen((e) {
      if (e.name == 'server:updated') {
        flagScope = null;
        synchronize();
      }
    });
    synchronize();
  }
  final WorkspaceController workspace;
  final SearchMemoryStorage storage;
  final bool dev;
  late final StreamSubscription<RaftEvent> events;
  String? preferenceKey, flagScope;
  bool enabled = false, hydrated = false, resolved = false, available = false;
  bool ended = false;
  int preferenceRevision = 0, flagRevision = 0;
  Future<void> writes = Future.value();

  String get authority => jsonEncode([
    identityHashCode(workspace.client),
    workspace.client.origin,
    workspace.client.generation,
    workspace.client.user?.id,
    workspace.server?.id,
    workspace.server?.string('role'),
  ]);
  bool get showCard => hydrated && resolved && available;
  bool active(double width) => width >= 1024 && showCard && enabled;

  void synchronize() {
    if (ended) return;
    final w = workspace;
    final key = w.client.user == null
        ? null
        : 'raft:workspace-grid-mode:${jsonEncode([w.client.origin, w.client.user!.id])}';
    if (key != preferenceKey) {
      preferenceKey = key;
      enabled = false;
      hydrated = false;
      final request = ++preferenceRevision;
      if (key != null) unawaited(hydrate(key, request));
    }
    final scope = authority;
    if (scope == flagScope) return;
    flagScope = scope;
    resolved = dev;
    available = dev;
    final request = ++flagRevision;
    notifyListeners();
    if (!dev && w.server != null && w.client.user != null) {
      unawaited(evaluate(scope, request, w.server!.id));
    }
  }

  Future<void> hydrate(String key, int request) async {
    String? raw;
    try {
      raw = await storage.read(key);
    } catch (_) {
      /* optional device store */
    }
    if (ended || preferenceKey != key || request != preferenceRevision) return;
    try {
      final data = raw == null ? null : jsonDecode(raw);
      enabled = data is Map && data['enabled'] == true;
    } catch (_) {
      enabled = false;
    }
    hydrated = true;
    notifyListeners();
  }

  Future<void> evaluate(String scope, int request, String server) async {
    try {
      final result = await workspace.client.post(
        '/feature-flags/evaluate',
        data: {
          'keys': ['chat_grid_layout_v0'],
          'serverId': server,
          'platform': 'web',
        },
      );
      if (ended ||
          scope != authority ||
          flagScope != scope ||
          request != flagRevision) {
        return;
      }
      final values = result is Map ? result['evaluations'] : null;
      final row = values is List
          ? values
                .whereType<Map>()
                .where((v) => v['key'] == 'chat_grid_layout_v0')
                .firstOrNull
          : null;
      resolved = row != null && row['enabled'] is bool;
      available = resolved && row!['enabled'] == true;
      notifyListeners();
    } catch (_) {
      /* unknown and unavailable never enable an experimental route */
    }
  }

  bool setEnabled(bool value, {required String capturedAuthority}) {
    if (ended ||
        capturedAuthority != authority ||
        !showCard ||
        preferenceKey == null) {
      return false;
    }
    enabled = value;
    final key = preferenceKey!;
    writes = writes.catchError((Object _) {}).then((_) async {
      try {
        await storage.write(key, jsonEncode({'enabled': value}));
      } catch (_) {
        /* best effort */
      }
    });
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    ended = true;
    ++preferenceRevision;
    ++flagRevision;
    workspace.removeListener(synchronize);
    events.cancel();
    super.dispose();
  }
}
