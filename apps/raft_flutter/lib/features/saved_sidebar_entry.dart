import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// Server-scoped Saved total shared by every mounted Saved entry of one
/// workspace. It retains only the mounted API's numeric global total, never
/// saved rows. The total is cleared only by a server-level identity change
/// (principal, server, generation, role); save receipts and channel
/// membership/capability changes revalidate it in place.
class SavedCountStore extends ChangeNotifier {
  SavedCountStore._(this.w);
  static final _stores = Expando<SavedCountStore>('saved count');
  static SavedCountStore of(WorkspaceController w) =>
      _stores[w] ??= SavedCountStore._(w);

  final WorkspaceController w;
  int? count;
  int _request = 0, _acceptedRevision = -1;
  String? _scope, _channels;

  String get authority => jsonEncode([
    identityHashCode(w),
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.client.serverId,
    w.server?.id,
    w.server?.string('role'),
  ]);
  String get _channelAuthority => jsonEncode([
    for (final c in w.channels) [c.id, c.joined, c.json['channelCapabilities']],
  ]);

  /// Adopts the current authority; callers rebuild themselves afterwards.
  void sync() {
    final next = authority;
    if (_scope != next) {
      _scope = next;
      count = null;
      ++_request;
      _acceptedRevision = -1;
      _channels = null;
    }
    var reload = false;
    if (_acceptedRevision != w.savedRevision) {
      _acceptedRevision = w.savedRevision;
      reload = true;
    }
    final channels = _channelAuthority;
    if (_channels != channels) {
      reload |= _channels != null;
      _channels = channels;
    }
    if (reload) unawaited(_load());
  }

  Future<void> _load() async {
    final captured = authority, ticket = ++_request;
    if (w.client.user == null || w.server == null) return;
    try {
      final value = await w.query(
        '/channels/saved',
        query: {'limit': 1, 'offset': 0, 'sort': 'desc'},
      );
      if (ticket != _request || captured != authority) return;
      final total = value is Map
          ? value['globalTotal'] ?? value['total']
          : null;
      if (total is int && total >= 0 && total <= 9007199254740991) {
        count = total;
        notifyListeners();
      }
    } catch (_) {
      /* A transient failure does not imply an empty Saved list. */
    }
  }
}

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
  late SavedCountStore saved;

  @override
  void initState() {
    super.initState();
    bind();
  }

  void bind() {
    saved = SavedCountStore.of(w)..addListener(rebuild);
    w.addListener(changed);
    saved.sync();
  }

  void unbind(WorkspaceController controller) {
    controller.removeListener(changed);
    saved.removeListener(rebuild);
  }

  @override
  void didUpdateWidget(SavedSidebarEntry old) {
    super.didUpdateWidget(old);
    if (old.controller != w) {
      unbind(old.controller);
      bind();
    }
  }

  void rebuild() {
    if (mounted) setState(() {});
  }

  void changed() {
    if (!mounted) return;
    saved.sync();
    setState(() {});
  }

  @override
  void dispose() {
    unbind(w);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftNavItem(
    label: raftText(context, 'Saved'),
    glyph: RaftGlyph.bookmark,
    role: RaftNavItemRole.saved,
    viewportHeight: MediaQuery.sizeOf(context).height,
    count: saved.count,
    selected: w.section == 'saved',
    onTap: widget.onTap,
  );
}
