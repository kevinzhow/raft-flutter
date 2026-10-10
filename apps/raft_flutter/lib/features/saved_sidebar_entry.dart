import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// Server-scoped Saved state shared by every mounted Saved entry, message
/// menu and Saved page of one workspace: the numeric global total and the
/// ids known to be saved (Source savedStore `total` + `savedIds`). It
/// retains no saved rows. It is cleared only by a server-level identity
/// change (principal, server, generation, role); save receipts and channel
/// membership/capability changes revalidate the total in place.
///
/// Saving and unsaving are optimistic like Source savedStore: the id set
/// and the total move before the request, and a failure puts both back.
class SavedCountStore extends ChangeNotifier {
  SavedCountStore._(this.w);
  static final _stores = Expando<SavedCountStore>('saved count');
  static SavedCountStore of(WorkspaceController w) =>
      _stores[w] ??= SavedCountStore._(w);

  final WorkspaceController w;
  int? count;
  int _request = 0, _acceptedRevision = -1;
  String? _scope, _channels;
  Object? _identity;
  final _ids = <String>{};
  final _tickets = <String, int>{};
  int _ticket = 0;

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

  /// Drops everything learned under an earlier identity. Called per message
  /// row, so it compares fields instead of encoding [authority].
  void _adopt() {
    final next = (
      w.client.origin,
      w.client.generation,
      w.client.user?.id,
      w.client.serverId,
      w.server?.id,
      w.server?.string('role'),
    );
    if (_identity == next) return;
    _identity = next;
    _scope = authority;
    count = null;
    ++_request;
    _acceptedRevision = -1;
    _channels = null;
    _ids.clear();
    _tickets.clear();
  }

  /// Whether [messageId] is known to be saved (Source `isSaved`).
  bool isSaved(String messageId) {
    _adopt();
    return _ids.contains(messageId);
  }

  /// Message ids a loaded Saved result discloses (Source `loadSaved` adds
  /// every entry to `savedIds`).
  void know(Iterable<String> messageIds) {
    _adopt();
    final before = _ids.length;
    _ids.addAll(messageIds);
    if (_ids.length != before) notifyListeners();
  }

  /// Source `saveMessage` / `unsaveMessage`: the saved state and the badge
  /// change before the request; a failure restores both and rethrows.
  Future<void> setSaved(String messageId, bool saved) async {
    _adopt();
    final scope = _scope, was = _ids.contains(messageId);
    final delta = was == saved ? 0 : (saved ? 1 : -1);
    final ticket = _tickets[messageId] = ++_ticket;
    saved ? _ids.add(messageId) : _ids.remove(messageId);
    _move(delta);
    notifyListeners();
    // Message rows read the saved state through the workspace listener.
    w.notifyListeners();
    try {
      await w.command(
        saved ? 'POST' : 'DELETE',
        saved ? '/channels/saved' : '/channels/saved/$messageId',
        data: saved ? {'messageId': messageId} : null,
      );
    } catch (_) {
      if (_scope == authority) {
        if (_tickets[messageId] == ticket) {
          was ? _ids.add(messageId) : _ids.remove(messageId);
        }
        _move(-delta);
        notifyListeners();
        w.notifyListeners();
      }
      rethrow;
    } finally {
      if (_scope == scope && _tickets[messageId] == ticket) {
        _tickets.remove(messageId);
      }
    }
  }

  /// Moves the badge by [delta] and retires any total read still in flight,
  /// whose answer predates this change.
  void _move(int delta) {
    if (delta == 0 || count == null) return;
    count = (count! + delta).clamp(0, 9007199254740991);
    ++_request;
  }

  /// Adopts the current authority; callers rebuild themselves afterwards.
  void sync() {
    _adopt();
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
