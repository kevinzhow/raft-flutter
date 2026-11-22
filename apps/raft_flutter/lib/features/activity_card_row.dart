import 'package:flutter/widgets.dart';

import 'activity_inbox_row.dart';
import 'activity_list_row.dart';
import 'activity_object_row.dart';
import 'activity_row_host.dart';
import 'activity_swipe_actions.dart';
import 'agent_lounge.dart' show loungeAgentName;
import 'message_task_actions.dart' show TaskV2ConversationsFlag;
import 'public_page_live.dart' show channelOnPublicPage;

export 'activity_row_host.dart' show ActivityRowHost, cardHeight;

/// One Activity row: an Artifact's (`kind: object`) or a conversation's, both
/// on raft-ui's `RaftInboxItem`. The card layout is gone (Web v1.24 has one
/// row).
class ActivityCardRow extends StatelessWidget {
  const ActivityCardRow({super.key, required this.row, required this.host});
  final Map<String, dynamic> row;
  final ActivityRowHost host;

  @override
  Widget build(BuildContext context) => row['kind'] == 'object'
      ? ActivityObjectRow(row: row, host: host)
      : ActivityInboxRow(row: row, host: host);
}

class ListedActivityCard extends StatefulWidget {
  const ListedActivityCard({
    super.key,
    required this.row,
    required this.host,
    required this.authority,
    this.swipe,
  });

  final Map<String, dynamic> row;
  final ActivityRowHost host;
  final String authority;
  final ActivitySwipeHooks? swipe;

  @override
  State<ListedActivityCard> createState() => _ListedActivityCardState();
}

class _ListedActivityCardState extends State<ListedActivityCard> {
  Object? _inputs;
  Widget? _card;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final host = widget.host;
    final workspace = host.controller;
    final swipe = widget.swipe;
    final thread = row['kind'] == 'thread';
    final conversation = row[thread ? 'parentChannelId' : 'channelId'];
    final dm = conversation == null
        ? null
        : workspace.dms
              .where((channel) => channel.id == conversation)
              .firstOrNull;
    final channel = conversation == null
        ? null
        : workspace.channels
                  .where((channel) => channel.id == conversation)
                  .firstOrNull ??
              dm;
    final inputs = (
      row,
      workspace,
      widget.authority,
      host.filter,
      host.interval,
      host.selected,
      host.located,
      host.canonical,
      host.pinnedHeight,
      host.agents,
      host.people,
      workspace.client.user,
      swipe?.open,
      swipe?.undo,
      channel,
      dm,
      channel?.loungeAgentId == null
          ? null
          : loungeAgentName(workspace, channel!),
      channel != null && channelOnPublicPage(workspace, channel),
      thread ? workspace.drafts[row['threadChannelId']] : null,
      host.taskV2 ?? TaskV2ConversationsFlag.of(workspace).enabled,
      row['kind'] != 'object' && activityRowMarkedUnread(workspace, row),
      swipe?.muted(row),
    );
    if (_inputs != inputs) {
      _inputs = inputs;
      final card = ActivityCardRow(row: row, host: host);
      _card = swipe == null
          ? card
          : ActivitySwipeRow(row: row, host: host, hooks: swipe, child: card);
    }
    return _card!;
  }
}
