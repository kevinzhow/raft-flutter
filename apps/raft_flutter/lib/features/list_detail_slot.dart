// Web v1.24 MainLayout's content slot (SearchContentRoute, InboxContentRoute,
// activityRowFocus.ts): what a list opens shows in the detail area beside it
// on wide windows, never over the whole window; on a phone it is a page
// pushed over the list, its Back returning to it. The address names it, so
// it is in history, a reload restores it, the row stays selected, another
// row replaces it and leaving the list closes it. Beside the list its × and
// Escape close it and put focus back on the row it was opened from.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
import 'artifacts/artifact_content_slot.dart';
import 'artifacts/artifact_models.dart' show parseArtifactId;
import 'desktop_navigation_policy.dart';

/// Marks a list that has a detail slot (Activity, Search).
class ListDetailHost extends InheritedWidget {
  const ListDetailHost({super.key, required super.child});

  /// Whether what [context] opens goes to its list's detail slot.
  static bool hosts(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ListDetailHost>() != null;

  @override
  bool updateShouldNotify(ListDetailHost old) => false;
}

/// The query keys one detail slot owns; opening another clears them all.
const _slotKeys = [
  'open',
  'artifact',
  'msg',
  'thread',
  'profile',
  'legacyTask',
  'task',
  'taskMsg',
  'taskConversation',
  'version',
  'review',
];

/// Shows [slot] (its address keys) in the list's detail slot: beside the
/// list replacing what is open there, as every row does; on a phone
/// ([context] compact) a page pushed over the list.
void openListDetail(
  BuildContext context,
  WorkspaceController w,
  Map<String, String> slot,
) {
  final phone = RaftAdaptiveWorkspace.compactOf(context);
  w.closeThread(navigate: false);
  w.navigation.navigate(
    w.location.withQuery({for (final key in _slotKeys) key: null, ...slot}),
    kind: phone ? RaftNavigationKind.push : RaftNavigationKind.replace,
  );
  w.notifyListeners();
}

/// The slot of [target] when its kind is one this table shows: [close]
/// empties the slot (Back on a phone), then focus goes back to its row.
Widget? listDetailContent(
  WorkspaceController w,
  DesktopContentTarget target,
  VoidCallback close,
) {
  final ({String row, Widget Function(VoidCallback) slot})? entry =
      switch (target.kind) {
        DesktopContentKind.artifact => (
          row: artifactRowSlot(parseArtifactId(target.id) ?? target.id),
          slot: (closed) => ArtifactContentSlot(
            key: ValueKey('artifact-content-slot-${target.id}'),
            workspace: w,
            onClose: closed,
          ),
        ),
        _ => null,
      };
  if (entry == null) return null;
  return entry.slot(() {
    close();
    _focusRow(entry.row);
  });
}

/// The row key an Artifact's row registers ([ListDetailRow.slot]).
String artifactRowSlot(String artifactId) => 'artifact:$artifactId';

final _rows = <String, FocusNode>{};

/// Marks [child] as the row that opens [slot] (its row key), so closing
/// that slot puts focus back on the row's first control.
class ListDetailRow extends StatefulWidget {
  const ListDetailRow({super.key, required this.slot, required this.child});
  final String? slot;
  final Widget child;

  @override
  State<ListDetailRow> createState() => _ListDetailRowState();
}

class _ListDetailRowState extends State<ListDetailRow> {
  final node = FocusNode(
    debugLabel: 'list detail row',
    canRequestFocus: false,
    skipTraversal: true,
  );
  String? registered;

  void register() {
    final slot = widget.slot;
    if (registered == slot) return;
    if (_rows[registered] == node) _rows.remove(registered);
    registered = slot;
    if (slot != null) _rows[slot] = node;
  }

  @override
  void dispose() {
    if (_rows[registered] == node) _rows.remove(registered);
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    register();
    return Focus(focusNode: node, child: widget.child);
  }
}

/// After the slot has left the tree. No such row (a Search hit): nothing.
void _focusRow(String slot) =>
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _rows[slot];
      if (row == null || row.context == null) return;
      row.descendants
          .where((n) => n.canRequestFocus && !n.skipTraversal)
          .firstOrNull
          ?.requestFocus();
    });
