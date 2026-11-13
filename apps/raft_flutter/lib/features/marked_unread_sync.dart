import 'dart:async';

import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';

/// Feeds the marked-unread flags ([ConversationReadRepository.marks]) from
/// live `read_state:updated` / `read_state:updated_bulk` frames (Web
/// `normalizeReadStateScope` keeps `markedUnread` only when it is `true`;
/// absent means not marked). The session's ledger (raft_sync) orders the
/// read points; the flags keep their own version order, so this listener does
/// not depend on running after it.
///
/// One owner per presentation, created by the first surface that paints the
/// flag (sidebar rows, Activity rows); served snapshots fill in anything a
/// frame delivered before that.
class MarkedUnreadSync {
  MarkedUnreadSync._(this.w) {
    _events = w.client.events.listen(_event);
    w.services.disposeWithSession(dispose);
  }

  static final _owners = Expando<MarkedUnreadSync>();

  static MarkedUnreadSync of(WorkspaceController w) =>
      _owners[w] ??= MarkedUnreadSync._(w);

  final WorkspaceController w;
  StreamSubscription<RaftEvent>? _events;

  void _event(RaftEvent event) {
    if (event.name != 'read_state:updated' &&
        event.name != 'read_state:updated_bulk') {
      return;
    }
    final payload = event.payload;
    if (payload is! Map || payload['serverId'] != w.client.serverId) return;
    final scopes = event.name.endsWith('_bulk') ? payload['scopes'] : [payload];
    if (scopes is! List) return;
    for (final scope in scopes) {
      if (scope is! Map) continue;
      final id = scope['scopeId'], version = scope['readStateVersion'];
      if (id is! String || id.isEmpty || version is! int || version < 0) {
        continue;
      }
      w.conversationReads.acceptMark(
        id,
        version,
        scope['markedUnread'] == true,
      );
    }
  }

  void dispose() {
    unawaited(_events?.cancel());
    _events = null;
  }
}
