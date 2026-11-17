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

  // Web: `<Banner status="warning" role="alert">` with `<TriangleAlert>`, a
  // description and a `size="md" variant="default"` Retry; the banner is as
  // tall as its content at the top of the list (347x88 desktop).
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topStart,
    child: Padding(
      padding: const EdgeInsets.all(_inset),
      child: RaftBanner(
        status: RaftBannerRecipeStatus.warning,
        glyph: RaftGlyph.triangleAlert,
        description: raftText(
          context,
          unavailable
              ? 'Activity is temporarily unavailable.'
              : "Couldn't load Activity.",
        ),
        action: RaftButton(
          label: raftText(context, 'Retry'),
          uiVariant: RaftButtonVariant.standard,
          uiSize: RaftButtonSize.md,
          onPressed: onRetry,
        ),
      ),
    ),
  );
}
