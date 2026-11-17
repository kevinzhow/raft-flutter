import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/history_paywall.dart';
import 'src/inline_thread_surface.dart';

const _rows = [
  RaftHiddenMessagePreview(
    id: 'a',
    author: 'Mina',
    timestamp: 'Oct 2, 10:14',
    text: 'The migration plan is ready for review',
  ),
  RaftHiddenMessagePreview(
    id: 'b',
    author: 'Dev',
    timestamp: 'Oct 3, 09:02',
    text: 'Sent an attachment',
  ),
];

@RaftPreviews(
  'History paywall: start of a Free conversation',
  size: Size(520, 520),
)
Widget historyPaywallStartPreview() => const _Frame(
  RaftHistoryPaywall(
    title: '12 earlier messages are older than 30 days',
    description: 'Free shows only the last 30 days. On Pro, all history can be read and searched.',
    upgradeLabel: 'Upgrade to Pro',
    onUpgrade: _noop,
    glimpse: _rows,
    recentDividerLabel: 'Last 30 days',
  ),
);

@RaftPreviews('History paywall: every message hidden', size: Size(520, 360))
Widget historyPaywallAllHiddenPreview() => const _Frame(
  RaftHistoryPaywall(
    title: 'All 3 messages in this channel are older than 30 days',
    description: 'Free shows only the last 30 days. On Pro, all history can be read and searched.',
    upgradeLabel: 'Upgrade to Pro',
    onUpgrade: _noop,
    glimpse: _rows,
    noRecentLabel: 'No new messages in the last 30 days',
  ),
);

@RaftPreviews('History paywall: target behind the window', size: Size(520, 640))
Widget historyPaywallTargetPreview() => _Frame(
  RaftHistoryPaywall(
    title: "This thread's first message is older than 30 days",
    description: 'It was sent on October 3; only its start shows here. Free shows only the last 30 days; on Pro you can read it and all history.',
    upgradeLabel: 'Upgrade to Pro',
    onUpgrade: _noop,
    before: [_rows.first],
    target: _rows.last,
    after: [_rows.first],
    targetReplies: const RaftHiddenTargetReplies(
      summary: '4 replies',
      semanticLabel: 'Open 4 replies',
      onOpen: _noop,
      reply: RaftInlineReply(
        id: 'r',
        author: 'Mina',
        preview: 'Shipped it',
        senderType: 'user',
        timestamp: 'Nov 1, 11:00',
      ),
    ),
  ),
);

void _noop() {}

class _Frame extends StatelessWidget {
  const _Frame(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
