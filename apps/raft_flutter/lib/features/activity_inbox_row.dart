// One Activity row (Web v1.24 `InboxRow.tsx`, `InboxRowDone.tsx`) on raft-ui's
// `RaftInboxItem`: the leading tile or face with its corner badge, the title
// rules, the excerpt, the marks, Mark as Done, and the row's accessible name.
// The page lends the data and the gestures through [ActivityRowHost].
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'activity_list_row.dart' show activityRowMarkedUnread;
import 'activity_row_host.dart';
import 'activity_row_label.dart';
import 'activity_row_time.dart';
import 'agent_lounge.dart' show loungeAgentName;
import 'sender_avatar_projection.dart';

/// Offers Done as a row semantics action on touch and a row button for pointer
/// input. `mention_action` rows have no Done action.
({List<Widget> actions, Map<String, VoidCallback> semanticActions})
activityRowDone(
  BuildContext context,
  ActivityRowHost host, {
  required String label,
  required bool offered,
}) {
  if (!offered) return (actions: const [], semanticActions: const {});
  void done() => host.action('done');
  if (RaftInteraction.of(context).touch || host.phoneTouch == true) {
    return (actions: const [], semanticActions: {label: done});
  }
  return (
    actions: [
      RaftInboxRowDone(
        semanticLabel: label,
        tooltip: raftText(context, 'Mark as Done'),
        onPressed: done,
      ),
    ],
    semanticActions: const {},
  );
}

/// Counts a pointer's clicks on the row (a second click upgrades to the
/// canonical page) and passes keyboard activation through as one.
class ActivityRowActivation extends StatefulWidget {
  const ActivityRowActivation({
    super.key,
    required this.host,
    required this.builder,
  });
  final ActivityRowHost host;
  final Widget Function(BuildContext context, VoidCallback onOpen) builder;

  @override
  State<ActivityRowActivation> createState() => _ActivityRowActivationState();
}

class _ActivityRowActivationState extends State<ActivityRowActivation> {
  Duration? _pendingTime, _lastTime;
  Offset? _pendingPosition, _lastPosition;
  int _clicks = 0;

  void _open() {
    final host = widget.host;
    if (!host.canonical) {
      _pendingPosition = null;
      host.open();
      return;
    }
    final pointer = _pendingPosition != null;
    final time = _pendingTime, position = _pendingPosition;
    final interval = time != null && _lastTime != null
        ? time - _lastTime!
        : null;
    final repeat =
        interval != null &&
        interval >= Duration.zero &&
        interval <= host.interval &&
        position != null &&
        _lastPosition != null &&
        (position - _lastPosition!).distance <= kDoubleTapSlop;
    _clicks = repeat ? _clicks + 1 : 1;
    _lastTime = time;
    _lastPosition = position;
    _pendingTime = null;
    _pendingPosition = null;
    host.activate(_clicks, cardHeight(context), pointer: pointer);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      if (event.kind == PointerDeviceKind.mouse &&
          event.buttons != kPrimaryMouseButton) {
        return;
      }
      _pendingTime = event.timeStamp;
      _pendingPosition = event.position;
    },
    onPointerCancel: (_) => _pendingPosition = null,
    child: widget.builder(context, _open),
  );
}

/// The gap between a title and the badge after it (`InboxItemHeading` gap-2).
const double _titleBadgeGap = 8;

/// ThreadsInbox `InboxRow` (`layout="list"`).
class ActivityInboxRow extends StatelessWidget {
  const ActivityInboxRow({super.key, required this.row, required this.host});
  final Map<String, dynamic> row;
  final ActivityRowHost host;

  bool get _thread => row['kind'] == 'thread';
  bool get _mention => row['kind'] == 'mention_action';

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

  Widget? _peerFace(
    BuildContext context,
    WorkspaceController w,
    RaftChannel? dm,
  ) {
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
        if (!agent) {'userId': peerId, 'avatarUrl': dm.json['peerAvatarUrl']},
      ],
      carriedAvatarUrl: dm.json['peerAvatarUrl'] is String
          ? dm.json['peerAvatarUrl'] as String
          : null,
    );
    return _slot(context, name, avatar, RaftAvatarSlotContext.panelHeader);
  }

  /// The channel's kind icon (`ChannelIcon`): # for a channel, a lock for a
  /// private one, a branch for a joint one.
  static RaftGlyph channelGlyph(String? type) => switch (type) {
    'private' => RaftGlyph.lock,
    'joint' => RaftGlyph.gitBranch,
    _ => RaftGlyph.hash,
  };

  /// Web `ConversationAvatar`: the leading tile or face, and its corner badge.
  (Widget, Widget?) _leading(
    BuildContext context,
    WorkspaceController w,
    ActivityRowFacts f,
  ) {
    final kind = f.titleKind;
    final tile = kind == 'task' || kind == 'thread';
    final threadGlyph = kind == 'task' ? RaftGlyph.listTodo : RaftGlyph.thread;
    Widget badgeOf(RaftGlyph glyph) => RaftIcon(glyph, size: 10);
    final lounge = f.loungeAgentId;
    if (lounge != null && kind != 'dm' && f.threadDmChannel == null) {
      final channel = f.rowChannel;
      final name = channel == null ? '' : loungeAgentName(w, channel);
      final lounged = badgeOf(RaftGlyph.users);
      if (!tile) {
        final agent = host.agentFor(lounge);
        final avatar = projectSenderAvatar(
          origin: w.client.origin,
          senderId: lounge,
          senderType: 'agent',
          agents: [?agent],
          members: const [],
        );
        return (
          _slot(context, name, avatar, RaftAvatarSlotContext.panelHeader),
          lounged,
        );
      }
      return (RaftIconTile(glyph: threadGlyph), lounged);
    }
    if (tile && f.threadDmChannel != null) {
      return (
        _peerFace(context, w, f.threadDmChannel) ??
            RaftIconTile(glyph: threadGlyph),
        badgeOf(threadGlyph),
      );
    }
    if (kind == 'dm' && f.dmChannel != null) {
      return (_peerFace(context, w, f.dmChannel)!, null);
    }
    if (tile) {
      return (
        RaftIconTile(glyph: threadGlyph),
        badgeOf(channelGlyph('${row['parentChannelType'] ?? ''}')),
      );
    }
    return (
      RaftIconTile(
        glyph: kind == 'dm'
            ? RaftGlyph.atSign
            : channelGlyph('${row['channelType'] ?? ''}'),
      ),
      null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = host.controller;
    final t = RaftTokens.of(context);
    final marked = !_mention && activityRowMarkedUnread(w, row);
    final f = ActivityRowFacts.of(
      context,
      row,
      lookups: ActivityRowLookups(
        controller: w,
        agents: host.agents,
        people: host.people,
        directorySenderLabel: host.directorySenderLabel,
        stableSender: host.stableSender,
        taskV2: host.taskV2,
      ),
      filter: host.filter,
      marked: marked,
    );
    final statusWord = f.taskStatus == null
        ? null
        : raftText(context, raftTaskStatusLabel(f.taskStatus!));
    final hint = t.colors['foreground-placeholder'];
    final (leading, badge) = _leading(context, w, f);
    final done = activityRowDone(
      context,
      host,
      label: f.doneLabel,
      offered: !_mention,
    );

    // The sender's face before their name; a DM or a DM thread leads with the
    // peer's face, so it skips it.
    final senderFace =
        f.isSystemSender ||
            f.titleKind == 'dm' ||
            f.threadDmChannel != null ||
            f.senderLabel == null
        ? null
        : f.senderType == 'agent' || f.senderType == 'user'
        ? _slot(
            context,
            f.senderLabel!,
            projectSenderAvatar(
              origin: w.client.origin,
              senderId: f.senderId,
              senderType: f.senderType,
              agents: host.agents,
              members: host.people,
              currentUser: w.client.user?.json,
            ),
            RaftAvatarSlotContext.compactList,
          )
        : null;

    return ActivityRowTimeBuilder(
      at: _thread
          ? row['lastActivityAt']
          : _mention
          ? row['createdAt']
          : row['lastMessageAt'] ?? row['lastActivityAt'],
      user: w.client.user?.json,
      builder: (context, time) {
        final titleText = Text(
          f.title,
          key: const ValueKey('conversation-card-primary'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: f.titleMuted
              ? DefaultTextStyle.of(context).style.copyWith(color: hint)
              : null,
        );
        final badges = [
          if (f.appBadge != null) _AppBadge(app: f.appBadge!, botName: f.title),
          if (f.legacyTaskNumber != null && f.taskStatus != null)
            RaftListRowTaskBadge(
              key: const ValueKey('conversation-card-task-badge'),
              status: RaftTaskStatus(status: f.taskStatus!),
              label: f.legacyTaskNumber!,
            ),
        ];
        final body = Text.rich(
          key: const ValueKey('conversation-card-body'),
          TextSpan(
            style: f.strong
                ? DefaultTextStyle.of(context).style.copyWith(color: t.strong)
                : null,
            children: [
              if (f.threadPrefix != null)
                f.threadPrefixHidden
                    ? WidgetSpan(
                        child: Semantics(
                          label: f.threadPrefix,
                          child: const SizedBox.shrink(),
                        ),
                      )
                    : TextSpan(text: '${f.threadPrefix} '),
              if (!f.peerSpoke && senderFace != null && f.senderLabel != null)
                RaftListRowSender.face(senderFace),
              if (!f.peerSpoke && f.senderLabel != null)
                f.hasPreview
                    ? RaftListRowSender.name(context, f.senderLabel!)
                    : TextSpan(
                        text: f.senderLabel,
                        style: RaftListRowSender.name(context, '').style,
                      ),
              if (f.hasPreview)
                TextSpan(
                  text: f.preview,
                  style: f.previewRetracted
                      ? DefaultTextStyle.of(context).style.copyWith(color: hint)
                      : null,
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        final statusLabel = statusWord;
        final marks = <Widget>[
          if (f.statusInMarks && f.taskStatus != null && statusLabel != null)
            KeyedSubtree(
              key: const ValueKey('conversation-card-task-badge'),
              child: RaftInboxItemStatus(
                status: raftTaskStatusOf(f.taskStatus!),
                label: statusLabel,
              ),
            ),
          if (f.draft)
            Semantics(
              label: raftText(context, 'Thread has an unsent draft'),
              child: RaftIcon(
                RaftGlyph.pencil,
                key: const ValueKey('inbox-thread-draft-badge'),
                size: 12,
                color: hint,
              ),
            ),
          // The sidebar's yellow @ sticker: a mention reads the same here.
          if (f.mentionBadge)
            RaftSidebarMentionMarker(
              key: const ValueKey('inbox-mention-badge'),
              label: raftText(context, 'Mentioned you'),
            ),
          if (f.muted)
            RaftIcon(
              RaftGlyph.bellOff,
              size: 14,
              color: hint,
              key: const ValueKey('conversation-card-muted'),
            )
          else if (f.unreadCount > 0)
            KeyedSubtree(
              key: const ValueKey('conversation-card-new-badge'),
              child: RaftSidebarUnreadCount(count: f.unreadCount),
            )
          else if (f.marked)
            KeyedSubtree(
              key: const ValueKey('conversation-card-marked-unread'),
              child: RaftSidebarQuietNewDot(
                label: raftText(context, 'Marked as unread'),
              ),
            ),
        ];
        return ActivityRowActivation(
          host: host,
          builder: (context, onOpen) => RaftInboxItem(
            key: _thread
                ? ValueKey('activity-thread-${row['threadChannelId']}')
                : ValueKey(
                    'activity-${row['kind']}-${row['channelId'] ?? row['messageId']}',
                  ),
            semanticLabel: f.semanticLabel(
              context,
              timeWords: time?.words,
              statusWord: statusWord,
            ),
            leading: leading,
            leadingBadge: badge,
            title: badges.isEmpty
                ? titleText
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: _titleBadgeGap,
                    children: [
                      Flexible(child: titleText),
                      ...badges,
                    ],
                  ),
            timestamp: time == null
                ? null
                : Text(
                    time.shown,
                    key: const ValueKey('conversation-card-timestamp'),
                  ),
            timestampAtRest: time != null && !time.older,
            timestampTooltip: time?.words,
            body:
                f.hasPreview || f.senderLabel != null || f.threadPrefix != null
                ? body
                : null,
            marks: marks,
            actions: done.actions,
            semanticActions: done.semanticActions,
            selected: host.selected,
            unread: f.strong,
            located: host.located,
            onOpen: onOpen,
            onLongPress: host.onLongPress ?? host.menu,
            onSecondaryTap: host.onSecondaryTap ?? host.menu,
          ),
        );
      },
    );
  }
}

/// Web `AppBadge`: "App" (the plain badge), "App · {app}" when the DM's name
/// is not the app's, with "Created by the {app} app" as its tooltip.
class _AppBadge extends StatelessWidget {
  const _AppBadge({required this.app, required this.botName});
  final String app, botName;

  @override
  Widget build(BuildContext context) {
    final plain = raftText(context, 'App');
    final badge = RaftBadge(
      key: const ValueKey('app-bot-badge'),
      label: app.isEmpty || app == botName
          ? plain
          : raftFormat(context, 'App · {app}', {'app': app}),
      appearance: RaftBadgeRecipeAppearance.soft,
      variant: RaftBadgeRecipeVariant.muted,
    );
    if (app.isEmpty) return badge;
    return RaftTooltip(
      message: raftFormat(context, 'Created by the {app} app', {'app': app}),
      child: badge,
    );
  }
}
