import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'activity_card_row.dart';
import 'activity_rollout_flags.dart';
import 'resource_view.dart' show activityRowTitle, activityThreadSubtitle;
import 'sender_avatar_projection.dart';

/// A heading over a row of the conversation list.
enum ActivityListSection { pinned, all }

/// Web `inboxPinnedConversation.ts` `isSidebarPinnedInboxItem`: whether an
/// Activity row's conversation is pinned in the sidebar. Channels pin by
/// channel id, DMs by their peer (agent or human); a thread is never pinned on
/// its own.
bool isSidebarPinnedActivityRow(
  Map<String, dynamic> row,
  List<Map<String, dynamic>> pinned,
  Iterable<RaftChannel> dms,
) {
  final kind = row['kind'];
  if (kind == 'thread' || pinned.isEmpty) return false;
  bool has(String type, Object? id) =>
      pinned.any((ref) => ref['kind'] == type && ref['id'] == id);
  final dm =
      kind == 'dm' || (kind == 'mention_action' && row['channelType'] == 'dm');
  if (!dm) return has('channel', row['channelId']);
  final peer = dms.where((c) => c.id == row['channelId']).firstOrNull;
  final peerId = peer?.json['peerId'];
  if (peer == null || peerId is! String || peerId.isEmpty) return false;
  return has(peer.json['peerType'] == 'agent' ? 'agent' : 'human', peerId);
}

/// With `activity_conversation_list_v0`, sidebar-pinned conversations float to
/// the top in their loaded order (Web `visibleItems`); every other row keeps
/// its place. Returns [rows] itself when the flag is off or nothing is pinned.
List<Map<String, dynamic>> activityPinnedFirst(
  WorkspaceController w,
  List<Map<String, dynamic>> rows,
) {
  if (rows.isEmpty ||
      ActivityRolloutFlags.peek(w)?.activityConversationList != true) {
    return rows;
  }
  final refs = [
    for (final ref in (w.sidebarOrder['pinned'] as List? ?? const []))
      if (ref is Map) Map<String, dynamic>.from(ref),
  ];
  final pinned = <Map<String, dynamic>>[], rest = <Map<String, dynamic>>[];
  for (final row in rows) {
    (isSidebarPinnedActivityRow(row, refs, w.dms) ? pinned : rest).add(row);
  }
  return pinned.isEmpty ? rows : [...pinned, ...rest];
}

/// The heading above the row at [index] of [rows] (already ordered by
/// [activityPinnedFirst]): "Pinned" over the first row when anything is
/// pinned, "All conversations" over the first row after the pinned ones.
ActivityListSection? activityListSectionAt(
  WorkspaceController w,
  List<Map<String, dynamic>> rows,
  int index,
) {
  if (index < 0 || index >= rows.length) return null;
  final refs = [
    for (final ref in (w.sidebarOrder['pinned'] as List? ?? const []))
      if (ref is Map) Map<String, dynamic>.from(ref),
  ];
  bool pinned(int i) => isSidebarPinnedActivityRow(rows[i], refs, w.dms);
  if (index == 0) return pinned(0) ? ActivityListSection.pinned : null;
  return !pinned(index) && pinned(index - 1) ? ActivityListSection.all : null;
}

/// ThreadsInbox `InboxRow` `layout="list"`.
class ActivityListRowView extends StatelessWidget {
  const ActivityListRowView({super.key, required this.row, required this.host});
  final Map<String, dynamic> row;
  final ActivityRowHost host;

  bool get _thread => row['kind'] == 'thread';
  bool get _mention => row['kind'] == 'mention_action';
  bool get _dm =>
      row['kind'] == 'dm' || (_mention && row['channelType'] == 'dm');

  RaftChannel? _dmChannel(WorkspaceController w) =>
      !_dm ? null : w.dms.where((c) => c.id == row['channelId']).firstOrNull;

  Widget? _peerFace(BuildContext context, WorkspaceController w) {
    final dm = _dmChannel(w);
    if (dm == null) return null;
    final agent = dm.json['peerType'] == 'agent';
    final peerId = '${dm.json['peerId'] ?? ''}';
    final name = dm.string('peerDisplayName', dm.string('peerName', dm.name));
    final avatar = projectSenderAvatar(
      origin: w.client.origin,
      senderId: peerId,
      senderType: agent ? 'agent' : 'user',
      agents: [
        if (agent) {...?host.agentFor(peerId), 'id': peerId},
      ],
      members: [
        if (!agent)
          {
            'userId': peerId,
            'avatarUrl': dm.json['peerAvatarUrl'],
            'gravatarHash': dm.json['peerGravatarHash'],
          },
      ],
      carriedAvatarUrl: dm.json['peerAvatarUrl'] is String
          ? dm.json['peerAvatarUrl'] as String
          : null,
      requestSize: 36,
    );
    return _slot(context, name, avatar, RaftAvatarSlotContext.panelHeader);
  }

  Widget _slot(
    BuildContext context,
    String name,
    SenderAvatarProjection avatar,
    RaftAvatarSlotContext slot,
  ) => RaftAvatarSlot(
    name: name,
    slot: slot,
    agent: avatar.kind == 'agent',
    avatarUrl: avatar.uploadedUrl,
    content: RaftAvatarContent(
      name: name,
      kind: switch (avatar.kind) {
        'agent' => RaftAvatarContentKind.agent,
        'app' => RaftAvatarContentKind.app,
        _ => RaftAvatarContentKind.human,
      },
      pixelKey: avatar.pixelKey,
      uploadedUrl: avatar.uploadedUrl,
      gravatarUrl: avatar.gravatarUrl,
      fallback: avatar.kind == 'human'
          ? Center(
              child: RaftIcon(
                RaftGlyph.user,
                size: slot.size * .6,
                color: RaftTokens.of(context).muted,
              ),
            )
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final w = host.controller, filter = host.filter;
    final unread = (row['unreadCount'] as num? ?? 0).toInt();
    final mutedId = _thread ? row['parentChannelId'] : row['channelId'];
    final muted = [
      ...w.channels,
      ...w.dms,
    ].any((c) => c.id == mutedId && c.flag('activityMuted'));
    final strong = unread > 0 && !muted;
    final senderType = _mention
        ? 'system'
        : row[_thread ? 'latestActivitySenderType' : 'lastMessageSenderType'];
    final senderId = _mention
        ? ''
        : row[_thread ? 'latestActivitySenderId' : 'lastMessageSenderId'];
    final system = senderType == 'system' || senderId == 'system';
    final sender = system
        ? raftText(context, 'System')
        : '${row[_thread ? 'latestActivitySenderName' : 'lastMessageSenderName'] ?? host.stableSender('activity:$senderType:$senderId', () => host.directorySenderLabel(senderId, senderType))}';
    final preview =
        '${_thread ? row['latestActivityPreview'] ?? '' : row['lastMessagePreview'] ?? row['messagePreview'] ?? ''}';
    final dmChannel = _dmChannel(w);
    // A DM already leads with the peer's face: the peer's own lines need no
    // sender in front of them.
    final peerSpoke = dmChannel != null && senderId == dmChannel.json['peerId'];
    final title = _thread
        ? '${row['parentMessagePreview'] ?? ''}'
        : activityRowTitle(row, w.dms);
    final senderFace = system || _dm || sender.isEmpty
        ? null
        : senderType == 'agent' || senderType == 'user'
        ? _slot(
            context,
            sender,
            projectSenderAvatar(
              origin: w.client.origin,
              senderId: '$senderId',
              senderType: '$senderType',
              agents: host.agents,
              members: host.people,
              currentUser: w.client.user?.json,
              requestSize: 20,
            ),
            RaftAvatarSlotContext.compactList,
          )
        : null;
    final draft =
        _thread &&
        (w.drafts['${row['threadChannelId']}'] ?? '').trim().isNotEmpty;
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (host.section case final section?)
          RaftActivityListSection(
            label: raftText(
              context,
              section == ActivityListSection.pinned
                  ? 'Pinned'
                  : 'All conversations',
            ),
            pinned: section == ActivityListSection.pinned,
            first: section == ActivityListSection.pinned,
          ),
        RaftConversationListRow(
          key: _thread
              ? ValueKey('activity-thread-${row['threadChannelId']}')
              : ValueKey(
                  'activity-${row['kind']}-${row['channelId'] ?? row['messageId']}',
                ),
          strong: strong,
          selected: host.selected,
          popupOpen: host.popupOpen,
          separator: host.separator,
          onOpen: host.open,
          onActivate: !host.canonical
              ? null
              : (detail) => host.activate(detail, cardHeight(context)),
          onPointerActivate: !host.canonical
              ? null
              : (detail) =>
                    host.activate(detail, cardHeight(context), pointer: true),
          doubleClickInterval: host.interval,
          onContextMenu: host.menu,
          leading: RaftConversationAvatarTile(
            kind: _thread
                ? RaftConversationAvatarKind.thread
                : _dm
                ? RaftConversationAvatarKind.dm
                : RaftConversationAvatarKind.channel,
            face: _peerFace(context, w),
          ),
          title: Text(
            title,
            key: const ValueKey('conversation-card-primary'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          titleTrailing: [
            if (row['taskNumber'] != null && row['taskStatus'] is String)
              RaftListRowTaskBadge(
                key: const ValueKey('conversation-card-task-badge'),
                status: RaftTaskStatus(status: row['taskStatus']),
                label: '#${row['taskNumber']}',
              ),
          ],
          timestamp: Text(
            host.relativeTime(row['lastActivityAt'] ?? row['lastMessageAt']),
            key: const ValueKey('conversation-card-timestamp'),
          ),
          body: Text.rich(
            key: const ValueKey('conversation-card-body'),
            TextSpan(
              children: [
                if (_thread)
                  TextSpan(
                    text: raftFormat(context, '{channel} ·', {
                      'channel': activityThreadSubtitle(row, [
                        ...w.channels,
                        ...w.dms,
                      ]),
                    }),
                  ),
                if (_thread) const TextSpan(text: ' '),
                if (!peerSpoke && senderFace != null)
                  RaftListRowSender.face(senderFace),
                if (!peerSpoke && sender.isNotEmpty)
                  RaftListRowSender.name(context, sender),
                TextSpan(text: preview),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bodyTrailing: [
            if (draft)
              RaftIcon(
                RaftGlyph.pencil,
                size: 12,
                color: t.colors['foreground-placeholder'],
              ),
            // The sidebar's yellow @ sticker: a mention reads the same here.
            if (row['hasMention'] == true && unread > 0 && filter != 'mentions')
              RaftSidebarMentionMarker(
                label: raftText(context, 'Mentioned you'),
              ),
            if (muted)
              RaftIcon(
                RaftGlyph.bellOff,
                size: 14,
                color: t.colors['foreground-placeholder'],
                key: const ValueKey('conversation-card-muted'),
              )
            else if (unread > 0)
              KeyedSubtree(
                key: const ValueKey('conversation-card-new-badge'),
                child: RaftSidebarUnreadCount(count: unread),
              ),
          ],
          action: row['kind'] == 'mention_action'
              ? null
              : RaftIconButton(
                  key: const ValueKey('inbox-row-done'),
                  glyph: filter == 'done'
                      ? RaftGlyph.rotateCcw
                      : RaftGlyph.check,
                  variant: RaftControlVariant.outline,
                  visualSize: 32,
                  minimumTargetSize: 32,
                  tooltip: filter == 'done'
                      ? 'Restore conversation'
                      : 'Mark conversation done',
                  onPressed: () =>
                      host.action(filter == 'done' ? 'undone' : 'done'),
                ),
        ),
      ],
    );
  }
}
