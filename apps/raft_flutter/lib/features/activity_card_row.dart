import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'activity_list_row.dart';
import 'resource_view.dart'
    show activityRowTitle, activityTaskLabel, activityThreadSubtitle;

/// What one Activity row needs from the page that lists it: the page's own
/// reads and actions, handed over as values and callbacks (the row is drawn
/// here, the data and the gestures stay with the page).
class ActivityRowHost {
  const ActivityRowHost({
    required this.controller,
    required this.filter,
    required this.interval,
    required this.selected,
    required this.canonical,
    required this.popupOpen,
    required this.savedView,
    required this.listLayout,
    required this.open,
    required this.activate,
    required this.menu,
    required this.action,
    required this.relativeTime,
    required this.stableSender,
    required this.directorySenderLabel,
    required this.agents,
    required this.people,
    this.pinnedHeight,
    this.section,
    this.separator = false,
  });
  final WorkspaceController controller;

  /// The view the row is listed in (`all`, `unread`, `mentions`, `done`, ...).
  final String filter;

  /// Double-click window: the host platform's, or the one captured while the
  /// row's gesture was pinned.
  final Duration interval;

  /// A gesture in flight pins the row to the height it had when it started.
  final double? pinnedHeight;
  final bool selected, popupOpen, savedView, listLayout;

  /// A second click upgrades to the canonical page (Activity master/detail).
  final bool canonical;
  final VoidCallback open;
  final void Function(int detail, double? height, {bool pointer}) activate;
  final ValueChanged<Offset> menu;

  /// `done`, `undone`.
  final void Function(String action) action;
  final String Function(dynamic value) relativeTime;
  final String Function(String key, String Function() build) stableSender;
  final String Function(dynamic id, dynamic type) directorySenderLabel;
  final List<Map<String, dynamic>> agents, people;

  /// The directory row of one agent, when known.
  Map<String, dynamic>? agentFor(String id) =>
      agents.where((a) => a['id'] == id).firstOrNull;

  /// List layout: the heading above this row, and whether a hairline sits
  /// between it and the row above.
  final ActivityListSection? section;
  final bool separator;
}

double? cardHeight(BuildContext context) =>
    (context.findRenderObject() as RenderBox?)?.size.height;

/// One Activity row. A card (ThreadsInbox `InboxRow`, card layout), or one
/// avatar row per conversation with `activity_conversation_list_v0`.
class ActivityCardRow extends StatelessWidget {
  const ActivityCardRow({super.key, required this.row, required this.host});
  final Map<String, dynamic> row;
  final ActivityRowHost host;

  @override
  Widget build(BuildContext context) {
    if (host.listLayout && !host.savedView) {
      return ActivityListRowView(row: row, host: host);
    }
    final w = host.controller, filter = host.filter;
    final recipe = RaftConversationCardRecipe(RaftTokens.of(context));
    final thread = row['kind'] == 'thread';
    final dm = row['kind'] == 'dm' || row['channelType'] == 'dm';
    final unread = (row['unreadCount'] as num? ?? 0).toInt();
    final title = thread
        ? '${row['parentMessagePreview'] ?? ''}'
        : activityRowTitle(row, w.dms);
    final senderType =
        row[thread ? 'latestActivitySenderType' : 'lastMessageSenderType'];
    final senderId =
        row[thread ? 'latestActivitySenderId' : 'lastMessageSenderId'];
    final sender = senderType == 'system' || senderId == 'system'
        ? raftText(context, 'System')
        : '${row[thread ? 'latestActivitySenderName' : 'lastMessageSenderName'] ?? host.stableSender('activity:$senderType:$senderId', () => host.directorySenderLabel(senderId, senderType))}';
    final preview =
        '${thread ? row['latestActivityPreview'] ?? '' : row['lastMessagePreview'] ?? row['messagePreview'] ?? ''}';
    return Builder(
      builder: (cardContext) => ConstrainedBox(
        constraints: host.pinnedHeight == null
            ? const BoxConstraints()
            : BoxConstraints(minHeight: host.pinnedHeight!),
        child: RaftConversationCard(
          key: thread
              ? ValueKey('activity-thread-${row['threadChannelId']}')
              : ValueKey(
                  'activity-${row['kind']}-${row['channelId'] ?? row['messageId']}',
                ),
          selected: host.selected,
          onOpen: host.open,
          onActivate: !host.canonical
              ? null
              : (detail) => host.activate(detail, cardHeight(cardContext)),
          onPointerActivate: !host.canonical
              ? null
              : (detail) => host.activate(
                  detail,
                  cardHeight(cardContext),
                  pointer: true,
                ),
          doubleClickInterval: host.interval,
          onContextMenu: host.menu,
          popupOpen: host.popupOpen,
          actions: host.savedView
              ? null
              : row['kind'] == 'mention_action'
              ? null
              // ThreadsInbox row action: ghost icon-sm Check 14 (RotateCcw 14 to
              // restore). Follow/unfollow is only in the context menu.
              : RaftIconButton(
                  glyph: filter == 'done'
                      ? RaftGlyph.rotateCcw
                      : RaftGlyph.check,
                  visualSize: 28,
                  minimumTargetSize: 28,
                  tooltip: filter == 'done'
                      ? 'Restore conversation'
                      : 'Mark conversation done',
                  onPressed: () =>
                      host.action(filter == 'done' ? 'undone' : 'done'),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thread)
                Padding(
                  // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                  padding: const EdgeInsets.only(bottom: 2),
                  child: RaftCssText(
                    activityThreadSubtitle(row, [...w.channels, ...w.dms]),
                    style: recipe.metadata.copyWith(
                      // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                      fontSize: 11,
                      // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                      height: 12 / 11,
                      color: recipe.titleIconColor,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RaftCssText.rich(
                      TextSpan(
                        children: [
                          // ThreadsInbox's icon is inline, not a separate flex
                          // column: wrapped title lines return to the row's edge.
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: Transform.translate(
                              offset: const Offset(0, 2),
                              child: Padding(
                                // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                                padding: const EdgeInsets.only(right: 6),
                                child: thread
                                    ? RaftThreadIcon(
                                        size: 13,
                                        color: recipe.titleIconColor,
                                      )
                                    : dm
                                    ? RaftDirectMessageIcon(
                                        size: 13,
                                        color: recipe.titleIconColor,
                                      )
                                    : RaftIcon(
                                        RaftGlyph.hash,
                                        size: 13,
                                        color: recipe.titleIconColor,
                                      ),
                              ),
                            ),
                          ),
                          TextSpan(text: title),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: recipe.titleStyle(unread > 0),
                    ),
                  ),
                  // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                  const SizedBox(width: 8),
                  RaftConversationTimestamp(
                    child: RaftCssText(
                      host.relativeTime(
                        row['lastActivityAt'] ?? row['lastMessageAt'],
                      ),
                      style: recipe.timestamp,
                    ),
                  ),
                ],
              ),
              // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
              const SizedBox(height: 2),
              RaftCssText.rich(
                TextSpan(
                  children: [
                    if (sender.isNotEmpty)
                      TextSpan(
                        text: '$sender: ',
                        style: recipe.body.copyWith(
                          color: recipe.senderColor,
                          // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    TextSpan(text: preview),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: recipe.body.copyWith(
                  color: recipe.titleColor(unread > 0),
                ),
              ),
              // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
              const SizedBox(height: 4),
              ConstrainedBox(
                // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                constraints: const BoxConstraints(minHeight: 20),
                child: Wrap(
                  // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                  spacing: 6,
                  // ds-allow: moved unchanged from resource_view.dart; the count there dropped by the same.
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (row['taskNumber'] != null &&
                        row['taskStatus'] is String) ...[
                      RaftTaskStatus(status: row['taskStatus']),
                      if (thread)
                        RaftCssText(
                          activityTaskLabel(row),
                          style: recipe.metadata,
                        ),
                    ],
                    if (thread)
                      RaftResourceBadge(
                        label:
                            '${row['replyCount'] ?? 0} ${raftText(context, 'replies')}',
                        appearance: RaftBadgeRecipeAppearance.outline,
                        variant: RaftBadgeRecipeVariant.muted,
                      ),
                    if (thread && row['isFollowing'] == false)
                      RaftResourceBadge(
                        label: raftText(context, 'Unfollowed'),
                        appearance: RaftBadgeRecipeAppearance.outline,
                        variant: RaftBadgeRecipeVariant.muted,
                      ),
                    // shouldShowMentionBadge: mention with unread messages.
                    if (row['hasMention'] == true && unread > 0)
                      RaftResourceBadge(
                        label: raftText(context, 'you'),
                        glyph: RaftGlyph.atSign,
                        variant: RaftBadgeRecipeVariant.primary,
                      ),
                    if (unread > 0)
                      RaftResourceBadge(
                        label: '$unread ${raftText(context, 'new')}',
                        variant: RaftBadgeRecipeVariant.accent,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
