import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// Retains only the mounted API's numeric global total, never saved rows.
class SavedSidebarEntry extends StatefulWidget {
  const SavedSidebarEntry({
    super.key,
    required this.controller,
    required this.onTap,
  });
  final WorkspaceController controller;
  final VoidCallback onTap;
  @override
  State<SavedSidebarEntry> createState() => _SavedSidebarEntryState();
}

class _SavedSidebarEntryState extends State<SavedSidebarEntry> {
  WorkspaceController get w => widget.controller;
  int? count;
  int request = 0;
  int acceptedRevision = -1;
  String? scope;
  String get authority => jsonEncode([
    identityHashCode(w),
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.client.serverId,
    w.server?.id,
    w.server?.string('role'),
    for (final c in w.channels) [c.id, c.joined, c.json['channelCapabilities']],
  ]);
  @override
  void initState() {
    super.initState();
    w.addListener(changed);
    changed();
  }

  @override
  void didUpdateWidget(SavedSidebarEntry old) {
    super.didUpdateWidget(old);
    if (old.controller != w) {
      old.controller.removeListener(changed);
      w.addListener(changed);
      scope = null;
      changed();
    }
  }

  void changed() {
    if (!mounted) return;
    final next = authority;
    if (scope != next) {
      scope = next;
      count = null;
      ++request;
      acceptedRevision = -1;
    }
    if (acceptedRevision != w.savedRevision) {
      acceptedRevision = w.savedRevision;
      unawaited(load());
    }
    setState(() {});
  }

  Future<void> load() async {
    final captured = authority, ticket = ++request;
    if (w.client.user == null || w.server == null) return;
    try {
      final value = await w.query(
        '/channels/saved',
        query: {'limit': 1, 'offset': 0, 'sort': 'desc'},
      );
      if (!mounted || ticket != request || captured != authority) return;
      final total = value is Map
          ? value['globalTotal'] ?? value['total']
          : null;
      if (total is int && total >= 0 && total <= 9007199254740991) {
        setState(() => count = total);
      }
    } catch (_) {
      /* A transient failure does not imply an empty Saved list. */
    }
  }

  @override
  void dispose() {
    ++request;
    w.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftNavItem(
    label: raftText(context, 'Saved'),
    glyph: RaftGlyph.bookmark,
    role: RaftNavItemRole.saved,
    viewportHeight: MediaQuery.sizeOf(context).height,
    count: count,
    selected: w.section == 'saved',
    onTap: widget.onTap,
  );
}
