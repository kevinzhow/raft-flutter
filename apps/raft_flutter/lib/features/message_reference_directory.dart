import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'private_route_guard.dart';

/// A per-mount view over the workspace's shared, server-scoped author
/// directory ([WorkspaceEntityDirectory.authorAgents]/[authorMembers]).
///
/// The shared lists are preloaded at server selection and survive channel
/// switches, thread opens and capability refreshes. They are cleared only when
/// the server-level identity ([directoryAuthority]) changes. A revalidation
/// (agent events, reconnect, conflicts) keeps the accepted lists in place and
/// replaces them when the response is accepted; [loading] is true only while
/// the current identity has no settled data. Nothing is written to the
/// workspace cache.
class MessageReferenceDirectory extends ChangeNotifier {
  MessageReferenceDirectory(this.w) : store = w.entityDirectory {
    observed = directoryAuthority(w);
    store.addListener(storeChanged);
    w.addListener(changed);
    store.ensureAuthors();
    stamp = currentStamp;
  }
  final WorkspaceController w;
  final WorkspaceEntityDirectory store;
  bool ended = false;
  String? observed;
  Object? stamp;
  int referencesRevision = -1;
  List<RaftTextReference> cachedReferences = const [];

  /// The server-level authority the shared lists belong to.
  String? get scope => ended ? null : directoryAuthority(w);
  bool get loading => !ended && store.authorsLoading;

  /// Changes whenever an agents read starts / is accepted (or cleared).
  int get requestRevision => store.agentRequestRevision;
  int get acceptedRevision => store.agentRevision;

  /// Changes whenever either accepted list is replaced or cleared.
  int get revision => store.authorRevision;

  /// Authorized agents, including tombstones (they still identify historical
  /// senders and suppress their live activity/mention affordances).
  List<Map<String, dynamic>> get agents =>
      ended ? const [] : store.authorAgents;
  List<Map<String, dynamic>> get members =>
      ended ? const [] : store.authorMembers;

  List<RaftTextReference> get references {
    if (ended) return const [];
    final current = store.authorRevision;
    if (current != referencesRevision) {
      referencesRevision = current;
      cachedReferences = buildReferences(agents, members);
    }
    return cachedReferences;
  }

  Object get currentStamp => (
    directoryAuthority(w),
    store.authorRevision,
    store.agentRequestRevision,
    store.authorsLoading,
  );

  void storeChanged() {
    if (ended) return;
    final next = currentStamp;
    if (next == stamp) return;
    stamp = next;
    notifyListeners();
  }

  void changed() {
    if (ended) return;
    final next = directoryAuthority(w);
    if (observed == next) return;
    observed = next;
    store.ensureAuthors();
    stamp = currentStamp;
    notifyListeners();
  }

  /// Revalidate in place; the accepted lists stay visible until replaced.
  void refresh() {
    if (ended) return;
    store.revalidateAuthors();
    storeChanged();
  }

  static List<RaftTextReference> buildReferences(
    List<Map<String, dynamic>> agents,
    List<Map<String, dynamic>> members,
  ) {
    final result = <String, Map<String, RaftTextReference>>{};
    void add(String text, String href) {
      result.putIfAbsent(text, () => {})[href] = RaftTextReference(
        text: text,
        href: href,
      );
    }

    void read(List<Map<String, dynamic>> rows, String kind) {
      for (final row in rows) {
        if (kind == 'agent' && row['deletedAt'] != null) continue;
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
    }

    read(agents, 'agent');
    read(members, 'user');
    return List.unmodifiable([
      for (final targets in result.values)
        if (targets.length == 1) targets.values.single,
    ]);
  }

  @override
  void dispose() {
    ended = true;
    w.removeListener(changed);
    store.removeListener(storeChanged);
    cachedReferences = const [];
    super.dispose();
  }
}
