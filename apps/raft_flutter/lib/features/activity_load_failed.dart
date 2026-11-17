import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// ThreadsInbox `inbox-load-failed`: no rows and a failed load shows this,
/// never the empty state. A 503 `rw_unconfigured` says Activity is
/// unavailable instead ([unavailable]); Retry reloads from the first page.
/// `px-(--column-margin) py-3` around the banner.
const double _inset = 16;

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
    padding: const EdgeInsets.all(_inset),
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
