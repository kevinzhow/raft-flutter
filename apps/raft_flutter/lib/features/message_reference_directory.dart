import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

/// A transient directory owned by one mounted chat. It is cleared immediately
/// on authority changes and never written to the workspace cache.
class MessageReferenceDirectory extends ChangeNotifier {
  MessageReferenceDirectory(this.w) {
    w.addListener(changed);
    changed();
  }
  final WorkspaceController w;
  String? scope;
  bool ended = false;
  List<RaftTextReference> references = [];
  void changed() {
    final next = workspaceAuthority(w);
    if (scope == next) return;
    scope = next;
    references = [];
    notifyListeners();
    load(next);
  }

  Future<void> load(String authority) async {
    final result = <String, Map<String, RaftTextReference>>{};
    void add(String text, String href) {
      result.putIfAbsent(text, () => {})[href] = RaftTextReference(
        text: text,
        href: href,
      );
    }

    Future<void> read(String path, String key, String kind) async {
      try {
        final out = await w.query(path),
            rows = out is List ? out : out[key] ?? [];
        for (final row in (rows as List).whereType<Map>()) {
          final name = row['name'],
              id = kind == 'user' ? row['userId'] ?? row['id'] : row['id'];
          if (name is! String || name.isEmpty || id is! String) continue;
          final href = Uri(
            scheme: 'raft-ref',
            host: 'mention',
            pathSegments: [kind, id],
          ).toString();
          add('@$name', href);
          add('@$name~${kind == 'user' ? 'human' : 'agent'}', href);
        }
      } catch (_) {
        /* An unavailable directory leaves unknown handles literal. */
      }
    }

    if (w.can('viewAgents')) await read('/agents', 'agents', 'agent');
    if (ended || scope != authority || workspaceAuthority(w) != authority) {
      return;
    }
    if (w.can('viewMembers') && w.server != null) {
      await read('/servers/${w.server!.id}/members', 'members', 'user');
    }
    if (ended || scope != authority || workspaceAuthority(w) != authority) {
      return;
    }
    references = [
      for (final targets in result.values)
        if (targets.length == 1) targets.values.single,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    ended = true;
    w.removeListener(changed);
    references = [];
    super.dispose();
  }
}
