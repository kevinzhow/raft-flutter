import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import '../data/resource_row_reconcile.dart' show activityScopeId;

/// Remembers expand and collapse for one viewing of one chat.
///
/// The first time an agent message is shown, it follows the read cursor:
/// unread opens, and read stays closed. That choice stays while the reader
/// remains in the conversation, including after the cursor moves past the
/// message. A manual toggle replaces it. The next visit follows the cursor
/// again.
///
/// This hangs off the chat state instead of being one of its fields. The
/// structure audit counts every new instance field on that state.
final _sessions = Expando<AgentMessageCollapseSession>();

typedef _Visit = (RaftClient, int, String?, String?, String?);
typedef _Cursor = ({BigInt? maxReadSeq});
final _opening = Expando<({_Visit visit, _Cursor cursor})>();

_Visit _visit(WorkspaceController w, String? scope) => (
  w.client,
  w.client.generation,
  w.client.serverId,
  w.client.user?.id,
  scope,
);

_Cursor _cursor(WorkspaceController w, String? scope) => (
  maxReadSeq: scopeReadCursor(
    state: w.readState.state,
    serverId: w.client.serverId,
    principalId: w.client.user?.id,
    scopeId: scope,
  ),
);

/// Keep the display rule from before Activity's read-all request. History may
/// arrive after its receipt; this snapshot never changes the read ledger.
void captureActivityAgentCollapse(
  WorkspaceController w,
  String section,
  Map<String, dynamic> row,
) {
  if (section != 'activity') return;
  final scope = activityScopeId(row);
  if (scope == null) return;
  _opening[w] = (visit: _visit(w, scope), cursor: _cursor(w, scope));
}

/// The collapse memory for this mounted chat.
AgentMessageCollapseSession agentCollapseOf(Object chat) =>
    _sessions[chat] ??= AgentMessageCollapseSession();

/// Drops the memory when the chat state is disposed.
void releaseAgentCollapse(Object chat) {
  _sessions[chat] = null;
}

/// Binds this chat to the conversation its own message window presents.
/// The workspace may already point elsewhere while this page is leaving.
void bindAgentCollapse(
  Object chat,
  WorkspaceController workspace,
  String? scope,
) {
  final visit = _visit(workspace, scope);
  final opening = _opening[workspace];
  final captured = opening?.visit == visit ? opening : null;
  if (captured != null) _opening[workspace] = null;
  agentCollapseOf(chat).bind(
    visit,
    readAtOpen: captured?.cursor ?? _cursor(workspace, scope),
    newVisit: captured != null,
  );
}

/// Collapse setting for this row, and whether it starts open.
/// A thread's parent row keeps today's collapse and does not follow the
/// thread cursor. Turning collapse off remembers nothing.
({bool collapse, bool open}) agentMessageOpens(
  AgentMessageCollapseSession session,
  bool parent,
  bool agent,
  RaftMessage message,
  WorkspaceController workspace,
  String? scope,
) {
  final collapse = longMessagesCollapse(message.json, workspace.channel?.json);
  if (parent || !collapse) return (collapse: collapse, open: false);
  return (
    collapse: true,
    open: session.startsOpen(
      messageId: message.id,
      agent: agent,
      seq: message.seq,
      maxReadSeq: scopeReadCursor(
        state: workspace.readState.state,
        serverId: workspace.client.serverId,
        principalId: workspace.client.user?.id,
        scopeId: scope,
      ),
    ),
  );
}

class AgentMessageCollapseSession {
  Object? _scope;
  _Cursor? _readAtOpen;
  final _open = <String, bool>{};

  /// Clears remembered choices when [scope] changes. The same scope keeps
  /// them. Null is the gap between conversations.
  void bind(
    Object? scope, {
    ({BigInt? maxReadSeq})? readAtOpen,
    bool newVisit = false,
  }) {
    if (scope == _scope && !newVisit) return;
    _scope = scope;
    _readAtOpen = readAtOpen;
    _open.clear();
  }

  /// The choice already made for [messageId], or the cursor rule for an
  /// agent message. Other messages stay closed and are not remembered until
  /// the reader toggles one.
  ///
  /// A mounted visit uses its entry cursor, before opening marks messages
  /// read. Standalone callers can supply [maxReadSeq] per row. A null cursor
  /// is unread, matching the unread-count rule.
  bool startsOpen({
    required String messageId,
    required bool agent,
    required BigInt seq,
    required BigInt? maxReadSeq,
  }) {
    final remembered = _open[messageId];
    if (remembered != null) return remembered;
    if (!agent) return false;
    final cursor = _readAtOpen == null ? maxReadSeq : _readAtOpen!.maxReadSeq;
    final open = cursor == null || seq > cursor;
    _open[messageId] = open;
    return open;
  }

  /// The reader's own toggle. It wins over the cursor for this visit.
  void choose(String messageId, bool open) {
    _open[messageId] = open;
  }
}

/// Channel "Collapse long messages", on unless the channel turns it off.
/// Action cards and forwarded bundles stay out of the collapse (Web
/// `disabled={isActionCardMessage || forwardedBundle || !collapseLongMessages}`).
bool longMessagesCollapse(
  Map<String, dynamic> message,
  Map<String, dynamic>? channel,
) {
  final metadata = message['actionMetadata'];
  return (metadata is! Map ||
          (metadata['kind'] != 'action-card' &&
              metadata['kind'] != 'forwarded-bundle')) &&
      channel?['collapseLongMessages'] != false;
}

/// `maxReadSeq` from the accepted read fact the unread count uses.
/// Missing identity, or a missing fact, is null: not read yet.
BigInt? scopeReadCursor({
  required Map<String, dynamic>? Function(
    String server,
    String principal,
    String scope,
  )
  state,
  required String? serverId,
  required String? principalId,
  required String? scopeId,
}) {
  if (serverId == null || principalId == null || scopeId == null) return null;
  final seq = state(serverId, principalId, scopeId)?['maxReadSeq'];
  return seq is int ? BigInt.from(seq) : null;
}
