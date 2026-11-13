// Source: packages/web/src/components/layout/StaleCountsNotice.tsx at
// v1.24.0-source.1 (task #164), placed as SidebarTopBar.tsx and
// features/thread/ThreadsInbox.tsx place it.

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/rw_freshness.dart';
import '../data/workspace_controller.dart';

/// One notice under a panel head while the counts it shows may be out of
/// date: the last known values stay, unchanged, and this says so once.
/// Waiting is not a problem, so it is an `info` PanelNotice led by a spinner;
/// RisingWave not configured (503 `rw_unconfigured`) will not catch up on its
/// own, so the same strip says the reads are temporarily unavailable, as a
/// `warning` led by a triangle. It goes away silently on a clean answer.
class StaleCountsNotice extends StatefulWidget {
  const StaleCountsNotice({
    super.key,
    required this.controller,
    required this.surfaces,
    required this.message,
    required this.unavailableMessage,
  });

  /// Home's bar on a phone and the Chat sidebar head on a desktop: the unread
  /// counts, the followed threads and the other servers' dots.
  const StaleCountsNotice.sidebar(this.controller, {super.key})
    : surfaces = const [
        RwSurface.unread,
        RwSurface.followed,
        RwSurface.summary,
      ],
      message = "Unread counts may be out of date. They'll update on their own when Raft catches up.",
      unavailableMessage = 'Unread counts are temporarily unavailable.';

  /// Under the Activity head.
  const StaleCountsNotice.activity(this.controller, {super.key})
    : surfaces = const [RwSurface.inbox],
      message = "Activity may be out of date. It'll update on its own when Raft catches up.",
      unavailableMessage = 'Activity is temporarily unavailable.';

  final WorkspaceController controller;
  final List<RwSurface> surfaces;
  final String message, unavailableMessage;

  @override
  State<StaleCountsNotice> createState() => _StaleCountsNoticeState();
}

class _StaleCountsNoticeState extends State<StaleCountsNotice> {
  late RwFreshnessStore store = RwFreshnessStore.of(widget.controller)..watch();

  @override
  void didUpdateWidget(StaleCountsNotice old) {
    super.didUpdateWidget(old);
    if (identical(old.controller, widget.controller)) return;
    store.unwatch();
    store = RwFreshnessStore.of(widget.controller)..watch();
  }

  @override
  void dispose() {
    store.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = widget.surfaces;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.outOfDate(surfaces)) return const SizedBox.shrink();
        final unconfigured = store.unconfigured(surfaces);
        final text = raftText(
          context,
          unconfigured ? widget.unavailableMessage : widget.message,
        );
        return Semantics(
          liveRegion: true,
          child: RaftPanelNotice(
            key: ValueKey(
              surfaces.contains(RwSurface.inbox)
                  ? 'activity-stale-notice'
                  : 'sidebar-stale-notice',
            ),
            status: unconfigured
                ? RaftPanelNoticeRecipeStatus.warning
                : RaftPanelNoticeRecipeStatus.info,
            leading: unconfigured
                ? const RaftIcon(RaftGlyph.triangleAlert, size: 16)
                : const RaftSpinner(size: 16),
            content: (context, style) => Text(text, style: style),
          ),
        );
      },
    );
  }
}
