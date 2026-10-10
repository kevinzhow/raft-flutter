import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Mounted MessageTimeline defaults to top (Thread); ChatPanel selects bottom.
enum RaftTimelineSparseAnchor { top, bottom }

/// Uses the actual mounted host, not channel.type: ChatPanel can render a
/// thread channel too, while ordinary ThreadPanel has its own reply rules.
enum RaftTimelineHost { chatPanel, threadPanel }

/// Source MessageTimeline min-height:100% column geometry, independent of color.
@immutable
class RaftTimelineCompositionRecipe {
  const RaftTimelineCompositionRecipe();
  RaftTimelineSparseAnchor anchorFor(RaftTimelineHost host) =>
      host == RaftTimelineHost.chatPanel
      ? RaftTimelineSparseAnchor.bottom
      : RaftTimelineSparseAnchor.top;
  // Thread retains timezone/day grouping but never emits reply DateDivider.
  bool emitsDayDivider(RaftTimelineHost host) =>
      host == RaftTimelineHost.chatPanel;
  // ChatPanel/ThreadPanel ordinary MessageItem wrappers; date/header/parent
  // have separate composition and must not receive this inset twice.
  EdgeInsets get messageInset => const EdgeInsets.symmetric(horizontal: 12);
  double get sentinelExtent => 1;
  EdgeInsets get channelHeaderInset =>
      const EdgeInsets.only(left: 12, right: 12, top: 12);
  EdgeInsets get footerInset =>
      const EdgeInsets.only(left: 12, right: 12, bottom: 12);
  double get footerTailExtent => 12;

  /// The same column for a two-sided timeline whose scroll view centers on
  /// [forward] (`CustomScrollView.center`): [header] (top to bottom), the
  /// leading sentinel, [history] (rows before the center, laid out upward),
  /// [forward] (the center and newer rows), the trailing sentinel and
  /// [footer]. Everything above [forward] grows away from the center, so
  /// history and header changes never move the rows below them.
  List<Widget> centeredSlivers({
    List<Widget> header = const [],
    required Widget history,
    required Widget forward,
    Widget? footer,
  }) => [
    ...header,
    SliverToBoxAdapter(child: SizedBox(height: sentinelExtent)),
    history,
    forward,
    SliverToBoxAdapter(child: SizedBox(height: sentinelExtent)),
    if (footer != null) SliverToBoxAdapter(child: footer),
  ];

  double leadingSpace({
    required RaftTimelineSparseAnchor anchor,
    required double viewportExtent,
    required double precedingExtent,
    required double tailExtent,
  }) => anchor == RaftTimelineSparseAnchor.top
      ? 0
      : math.max(0, viewportExtent - precedingExtent - tailExtent);
}

/// Natural source footer: optional loading-newer block, h-3 tail and pb-3.
/// The composer/OS inset live outside the scroller and must not be added again.
class RaftTimelineFooter extends StatelessWidget {
  const RaftTimelineFooter({super.key, this.loadingNewer});
  final Widget? loadingNewer;
  @override
  Widget build(BuildContext context) {
    const recipe = RaftTimelineCompositionRecipe();
    return Padding(
      padding: recipe.footerInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loadingNewer != null) loadingNewer!,
          SizedBox(height: recipe.footerTailExtent),
        ],
      ),
    );
  }
}
