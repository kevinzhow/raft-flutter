import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_typing_store.dart';
import '../data/read_receipts.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_messages.dart';
import 'agent_metadata_projection.dart';
import 'sender_avatar_projection.dart';
import 'system_message_grouping.dart';
import 'timeline_boundary_change.dart';

typedef _ReadScope = ({String id, String channelId, String? parentId});
typedef _ReadFace = ({
  String id,
  String name,
  String? url,
  String? pixel,
  String? activity,
  bool working,
});
typedef _RowProgress = ({
  List<_ReadFace>? faces,
  List<(RaftAgentReadReason, String)>? status,
});

class AgentReadProgressPresentation {
  ReadReceipts? _receipts;
  AgentTypingStore? _typing;
  VoidCallback? _changed, _release;
  _ReadScope? _watch;
  int? _authority;
  final _rows = <String, _RowProgress>{};
  _ReadProgressWindow? _window;
  bool _active = false;

  void bind(
    WorkspaceController w, {
    required bool thread,
    required bool visible,
    required VoidCallback changed,
  }) {
    final scope = _scope(w, thread);
    final receipts = w.readReceipts;
    final authority = receipts.authorityEpoch;
    if (!identical(_receipts, receipts)) {
      dispose();
      _receipts = receipts;
      _changed = changed;
      receipts.addListener(changed);
    }
    if (visible && scope != null) receipts.ensureProgressFlag();
    final next = visible && receipts.progressEnabled ? scope : null;
    if (_watch == next && _authority == authority) return;
    _window = null;
    _release?.call();
    _watch = next;
    _authority = authority;
    _release = next == null ? null : receipts.watchProgress(next.id);
    _typing?.removeListener(changed);
    _typing = next == null ? null : AgentTypingStore.of(w.client);
    _typing?.addListener(changed);
  }

  _ReadScope? _scope(WorkspaceController w, bool thread) {
    final messages = w.messageDomain;
    final channel = thread ? messages.threadSourceChannel : w.channel;
    final scopeId = thread ? w.threadChannelId : channel?.id;
    final parentId = thread ? messages.threadParentMessageId : null;
    if (scopeId == null ||
        channel == null ||
        (thread && parentId == null) ||
        (!thread && channel.name == 'all') ||
        channel.type == 'dm' ||
        w.dms.any((row) => row.id == channel.id) ||
        w.client.serverId != w.server?.id ||
        w.sessionScope.revokedServers.contains(w.client.serverId) ||
        w.sessionScope.revokedChannels.contains(channel.id) ||
        w.sessionScope.revokedChannels.contains(scopeId) ||
        !w.can('viewChannel', resource: channel)) {
      return null;
    }
    return (id: scopeId, channelId: channel.id, parentId: parentId);
  }

  void update(
    WorkspaceController w,
    List<chat.Message> presented,
    RaftMessage Function(chat.Message) source,
    List<SystemGroupState?> Function() groups,
    TimelineBoundaryChange? Function(List<chat.Message>, List<chat.Message>)
    boundaryFrom, {
    required bool thread,
  }) {
    final scope = _scope(w, thread);
    final receipts = _receipts;
    final peers = scope == null || receipts?.progressEnabled != true
        ? null
        : receipts!.scope(scope.id)?.peers;
    final agents = {
      for (final peer in peers ?? const <PeerReadState>[])
        if (peer.peerKind == 'agent') peer.peerId: peer,
    };
    _active = agents.isNotEmpty;
    if (!_active ||
        scope == null ||
        (thread
            ? w.messageDomain.threadWindow?.hasNewer == true
            : w.messageDomain.state.hasNewer)) {
      _rows.clear();
      _window = null;
      return;
    }
    var window = _window;
    if (window == null || window.channelId != scope.id) {
      window = _window = _ReadProgressWindow(scope.id);
    }
    window.update(presented, source, groups(), boundaryFrom);
    final messages = window.messages;
    final ownId = w.client.user?.id;
    final recent = messages.reversed.take(30).where(_isChat);
    final own = recent
        .where(
          (row) =>
              row.senderId == ownId &&
              const {'human', 'user'}.contains(row.string('senderType')),
        )
        .firstOrNull;
    final working =
        _typing?.typingAgentIds(scope.channelId, scope.parentId) ??
        const <String>[];
    final relevant = <String>{
      ...working,
      for (final row in recent) ...[
        if (row.string('senderType') == 'agent') row.senderId,
        ..._mentions(row).map((mention) => mention['id']).whereType<String>(),
      ],
    }..retainAll(agents.keys.toSet());
    final directory = w.services.entityDirectory;
    final byId = {
      for (final row in directory.authorAgents)
        if (row['id'] case final String id) id: row,
    };
    final faces = <String, List<_ReadFace>>{};
    final byRead = <String, _ReadFace>{
      for (final id in relevant)
        id: _face(w, id, byId[id], recent, working.contains(id)),
    };
    for (final id in relevant) {
      final row = _frontier(messages, agents[id]!.maxReadSeq);
      if (row != null) {
        (faces[window.folded[row.id] ?? row.id] ??= []).add(byRead[id]!);
      }
    }
    final status = own == null
        ? null
        : _status(w, scope, own, messages, agents, byRead, working);
    final ids = {...faces.keys, if (status != null) own!.id};
    _rows.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      final next = (faces: faces[id], status: id == own?.id ? status : null);
      final previous = _rows[id];
      if (!listEquals(previous?.faces, next.faces) ||
          !listEquals(previous?.status, next.status)) {
        _rows[id] = next;
      }
    }
  }

  Object? revision(String id) => _active ? (_rows[id] ?? true) : null;

  Widget? faces(String id) {
    if (!_active) return null;
    final faces = _rows[id]?.faces ?? const [];
    return RaftMessageReadFaces(
      faces: [
        for (final face in faces)
          RaftReadFace(
            id: face.id,
            name: face.name,
            avatar: RaftAvatarContent(
              name: face.name,
              kind: RaftAvatarContentKind.agent,
              uploadedUrl: face.url,
              pixelKey: face.pixel,
            ),
            working: face.working,
            activity: face.activity,
          ),
      ],
    );
  }

  Widget system(String id, Widget child) {
    final trailing = faces(id);
    return trailing == null
        ? child
        : Builder(
            builder: (context) =>
                RaftSystemMessageGroup.containsExpandedRows(context)
                ? child
                : RaftMessageSystemTrailing(trailing: trailing, child: child),
          );
  }

  Widget? status(String id) {
    final entries = _rows[id]?.status;
    return entries == null
        ? null
        : RaftMessageReadStatus.agents(entries: entries);
  }

  void dispose() {
    final changed = _changed;
    if (changed != null) {
      _receipts?.removeListener(changed);
      _typing?.removeListener(changed);
    }
    _release?.call();
    _watch = null;
    _receipts = null;
    _typing = null;
    _changed = null;
    _release = null;
    _rows.clear();
    _window = null;
    _active = false;
  }
}

class _ReadProgressWindow {
  _ReadProgressWindow(this.channelId);

  final String channelId;
  List<chat.Message>? _previous;
  List<SystemGroupState?>? _previousGroups;
  final messages = <RaftMessage>[];
  final _positions = <String, int>{};
  final folded = <String, String>{};

  void update(
    List<chat.Message> presented,
    RaftMessage Function(chat.Message) source,
    List<SystemGroupState?> groups,
    TimelineBoundaryChange? Function(List<chat.Message>, List<chat.Message>)
    boundaryFrom,
  ) {
    final previous = _previous;
    if (!identical(previous, presented)) {
      final change = previous == null
          ? null
          : boundaryFrom(previous, presented);
      if (change == null || !extend(presented, source, change)) {
        messages
          ..clear()
          ..addAll(
            presented.map(source).where((row) => row.channelId == channelId),
          )
          ..sort(
            (left, right) => _timelineSeq(left).compareTo(_timelineSeq(right)),
          );
        _positions.clear();
        for (var index = 0; index < messages.length; index++) {
          _positions[messages[index].id] = index;
        }
      }
      _previous = presented;
    }
    if (!identical(_previousGroups, groups)) {
      folded.clear();
      for (var index = 0; index < groups.length; index++) {
        if (groups[index] case final SystemGroupSummary group) {
          for (final child in group.messageIndexes) {
            folded[source(presented[child]).id] = source(presented[index]).id;
          }
        }
      }
      _previousGroups = groups;
    }
  }

  bool extend(
    List<chat.Message> presented,
    RaftMessage Function(chat.Message) source,
    TimelineBoundaryChange change,
  ) {
    if (change.before != 0) return false;
    final edits = <(int, RaftMessage)>[];
    for (final index in change.edits) {
      final next = source(presented[index]);
      final previous = _positions[next.id];
      if ((previous != null) != (next.channelId == channelId)) return false;
      if (previous == null) continue;
      if (_timelineSeq(messages[previous]) != _timelineSeq(next)) return false;
      edits.add((previous, next));
    }
    final newer = <RaftMessage>[];
    var seq = messages.isEmpty ? 0 : _timelineSeq(messages.last);
    for (
      var index = presented.length - change.after;
      index < presented.length;
      index++
    ) {
      final row = source(presented[index]);
      if (row.channelId != channelId) continue;
      final next = _timelineSeq(row);
      if (next <= seq) return false;
      seq = next;
      newer.add(row);
    }
    for (final (index, row) in edits) {
      messages[index] = row;
    }
    for (final row in newer) {
      _positions[row.id] = messages.length;
      messages.add(row);
    }
    return true;
  }
}

int _sequence(RaftMessage row) => int.tryParse(row.string('seq')) ?? 0;
int _timelineSeq(RaftMessage row) =>
    _sequence(row) > 0 ? _sequence(row) : 9007199254740992;
bool _isChat(RaftMessage row) => row.string('messageType') != 'system';
Iterable<Map> _mentions(RaftMessage message) =>
    (message.json['mentions'] as List? ?? const []).whereType<Map>().where(
      (mention) => mention['type'] == 'agent',
    );

RaftMessage? _frontier(List<RaftMessage> messages, int seq) {
  var start = 0, end = messages.length;
  while (start < end) {
    final midpoint = (start + end) ~/ 2;
    if (_timelineSeq(messages[midpoint]) <= seq) {
      start = midpoint + 1;
    } else {
      end = midpoint;
    }
  }
  if (start == 0) return null;
  final row = messages[start - 1];
  return _sequence(row) > 0 ? row : null;
}

_ReadFace _face(
  WorkspaceController w,
  String id,
  Map<String, dynamic>? agent,
  Iterable<RaftMessage> recent,
  bool working,
) {
  final message = recent
      .where((row) => row.senderId == id && row.string('senderType') == 'agent')
      .firstOrNull;
  final mention = recent
      .expand(_mentions)
      .where((item) => item['id'] == id)
      .firstOrNull;
  final name = [
    agent?['displayName'],
    agent?['name'],
    message?.json['senderDisplayName'],
    mention?['displayName'],
    message?.json['senderName'],
    mention?['name'],
  ].whereType<String>().where((value) => value.isNotEmpty).firstOrNull;
  final avatar = projectSenderAvatar(
    origin: w.client.origin,
    senderId: id,
    senderType: 'agent',
    carriedAvatarUrl: message?.string('senderAvatarUrl'),
    agents: agent == null ? const [] : [agent],
    members: const [],
  );
  final activity = working
      ? w.services.entityDirectory.agentPresence(id)
      : null;
  return (
    id: id,
    name: name ?? '',
    url: avatar.uploadedUrl,
    pixel: avatar.pixelKey,
    activity: activity == null
        ? null
        : agentActivityText(
            activity.activity ?? 'working',
            activity.detail,
            activity.detailKind,
          ),
    working: working,
  );
}

List<(RaftAgentReadReason, String)>? _status(
  WorkspaceController w,
  _ReadScope scope,
  RaftMessage own,
  List<RaftMessage> messages,
  Map<String, PeerReadState> agents,
  Map<String, _ReadFace> relevant,
  List<String> working,
) {
  final seq = _sequence(own);
  if (seq <= 0 ||
      WorkspaceMessages.isPendingSend(own) ||
      _mentions(own).any((mention) => agents.containsKey(mention['id']))) {
    return null;
  }
  final summary = w.messageDomain.threadSummaries[own.id];
  final reached = {
    ...working,
    if (scope.parentId == null) ...[
      ...AgentTypingStore.of(w.client).typingAgentIds(scope.channelId, own.id),
      if (summary is Map && summary['participantIds'] is List)
        ...(summary['participantIds'] as List).whereType<String>(),
    ],
    for (final row in messages.skip(messages.indexOf(own) + 1))
      if (_isChat(row) && row.string('senderType') == 'agent') row.senderId,
  };
  final stopped = <(RaftAgentReadReason, String)>[];
  final muted = <(RaftAgentReadReason, String)>[];
  for (final face in relevant.values) {
    final peer = agents[face.id]!;
    if (reached.contains(face.id) || peer.maxReadSeq >= seq) continue;
    if (peer.stoppedFollowing) {
      stopped.add((RaftAgentReadReason.stoppedFollowing, face.name));
    } else if (peer.mutedChannel) {
      muted.add((RaftAgentReadReason.muted, face.name));
    }
  }
  return stopped.isEmpty && muted.isEmpty ? null : [...stopped, ...muted];
}
