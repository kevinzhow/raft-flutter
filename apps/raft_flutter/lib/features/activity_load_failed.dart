import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// ThreadsInbox `inbox-load-failed`: no rows and a failed load shows this,
/// never the empty state. A 503 `rw_unconfigured` says Activity is
/// unavailable instead ([unavailable]); Retry reloads from the first page.
class ActivityLoadFailed extends StatelessWidget {
  const ActivityLoadFailed({
    super.key,
    required this.onRetry,
    this.unavailable = false,
  });

  final VoidCallback onRetry;
  final bool unavailable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: RaftErrorBanner(
      raftText(
        context,
        unavailable
            ? 'Activity is temporarily unavailable.'
            : "Couldn't load Activity.",
      ),
      onRetry: onRetry,
      retryLabel: 'Retry',
    ),
  );
}
