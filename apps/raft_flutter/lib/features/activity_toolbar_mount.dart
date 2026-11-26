// Source: packages/web/src/features/thread/ThreadsInbox.tsx:521-596 at v1.24.0.
// The Activity toolbar: raft_ui's filter bar (Filter menu, the chip, Mark all
// read) mounted for the page. On a phone it is the scroller's first child and
// pins; on desktop it sits above the scroller.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/activity_filter_choice.dart';

Widget activityFilterBar(
  BuildContext context, {
  required ActivityFilterChoice choice,
  required ValueChanged<ActivityFilterChoice> onChoice,
  required bool showMarkAllRead,
  required VoidCallback onMarkAllRead,
}) => RaftActivityFilterBar(
  choice: RaftActivityFilterChoice.values.byName(choice.name),
  onChoice: (next) => onChoice(ActivityFilterChoice.parse(next.name)),
  showMarkAllRead: showMarkAllRead,
  onMarkAllRead: onMarkAllRead,
  labels: RaftActivityFilterLabels(
    filter: raftText(context, 'Filter'),
    menu: raftText(context, 'Filter inbox'),
    clear: raftText(context, 'Clear filter'),
    markAllRead: raftText(context, 'Mark all read'),
    markAllReadTooltip: raftText(context, 'Mark all as read'),
    choices: {
      RaftActivityFilterChoice.all: raftText(context, 'All'),
      RaftActivityFilterChoice.unread: raftText(context, 'Unread'),
      RaftActivityFilterChoice.mentions: raftText(context, 'Mentions'),
      RaftActivityFilterChoice.pinned: raftText(context, 'Pinned'),
      RaftActivityFilterChoice.saved: raftTextKeyed(
        context,
        'Saved',
        'thread.filter.saved',
      ),
      RaftActivityFilterChoice.artifacts: raftText(context, 'Artifacts'),
    },
  ),
);
