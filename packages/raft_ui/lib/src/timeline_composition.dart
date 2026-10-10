import 'dart:math' as math;

import 'package:flutter/rendering.dart';
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

  double leadingSpace({
    required RaftTimelineSparseAnchor anchor,
    required double viewportExtent,
    required double precedingExtent,
    required double tailExtent,
  }) => anchor == RaftTimelineSparseAnchor.top
      ? 0
      : math.max(0, viewportExtent - precedingExtent - tailExtent);
}

/// Keeps header before the source flex-grow spacer. Messages, the bottom
/// sentinel and the natural footer form its tail; Thread gets no spacer.
///
/// The host must supply the EXISTING animated-list sliver, retaining its key,
/// observer, controller and cache. This is not a replacement message list.
class RaftTimelineCompositionSliver extends StatelessWidget {
  const RaftTimelineCompositionSliver({
    super.key,
    this.anchor = RaftTimelineSparseAnchor.top,
    this.header,
    required this.messagesSliver,
    this.footer,
    this.reversed = false,
  });
  final RaftTimelineSparseAnchor anchor;
  final Widget? header;
  final Widget messagesSliver;
  final Widget? footer;

  /// The host scroll view is reversed (newest message at scroll offset 0).
  /// Slivers grow upward, so the visual order is listed bottom-first and a
  /// short timeline sits at the bottom without a measured spacer; the host
  /// keeps its top content at the top with a fill-remaining sliver.
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    const recipe = RaftTimelineCompositionRecipe();
    if (reversed) {
      return SliverMainAxisGroup(
        slivers: [
          if (footer != null) SliverToBoxAdapter(child: footer),
          SliverToBoxAdapter(child: SizedBox(height: recipe.sentinelExtent)),
          messagesSliver,
          SliverToBoxAdapter(child: SizedBox(height: recipe.sentinelExtent)),
          if (header != null) SliverToBoxAdapter(child: header),
        ],
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverToBoxAdapter(child: SizedBox(height: recipe.sentinelExtent)),
        RaftSparseTimelineSliver(
          anchor: anchor,
          sliver: SliverMainAxisGroup(
            slivers: [
              messagesSliver,
              SliverToBoxAdapter(
                child: SizedBox(height: recipe.sentinelExtent),
              ),
              if (footer != null) SliverToBoxAdapter(child: footer),
            ],
          ),
        ),
      ],
    );
  }
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

/// Source bottom anchoring is layout, not scroll-to-max (which is zero for
/// sparse content). Measures the tail in the SAME layout and inserts only its
/// actual spare viewport extent. No post-frame measurements, timers or state.
class RaftSparseTimelineSliver extends SingleChildRenderObjectWidget {
  const RaftSparseTimelineSliver({
    super.key,
    this.anchor = RaftTimelineSparseAnchor.top,
    required Widget sliver,
  }) : super(child: sliver);
  final RaftTimelineSparseAnchor anchor;
  @override
  RenderRaftSparseTimelineSliver createRenderObject(BuildContext context) =>
      RenderRaftSparseTimelineSliver(anchor: anchor);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderRaftSparseTimelineSliver renderObject,
  ) => renderObject.anchor = anchor;
}

class RenderRaftSparseTimelineSliver extends RenderSliverEdgeInsetsPadding {
  RenderRaftSparseTimelineSliver({required RaftTimelineSparseAnchor anchor})
    : _anchor = anchor;
  RaftTimelineSparseAnchor _anchor;
  EdgeInsets _resolved = EdgeInsets.zero;
  double get leadingExtent => _resolved.top;
  RaftTimelineSparseAnchor get anchor => _anchor;
  set anchor(RaftTimelineSparseAnchor value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  @override
  EdgeInsets get resolvedPadding => _resolved;

  @override
  void performLayout() {
    assert(constraints.axisDirection == AxisDirection.down);
    assert(constraints.growthDirection == GrowthDirection.forward);
    // First natural layout is exact for a sparse tail. For a long/lazy list
    // its extent already exceeds the remaining viewport, so no spacer exists.
    _resolved = EdgeInsets.zero;
    super.performLayout();
    if (_anchor == RaftTimelineSparseAnchor.top ||
        child == null ||
        geometry?.scrollOffsetCorrection != null) {
      return;
    }
    const recipe = RaftTimelineCompositionRecipe();
    final spare = recipe.leadingSpace(
      anchor: _anchor,
      viewportExtent: constraints.viewportMainAxisExtent,
      precedingExtent: constraints.precedingScrollExtent,
      tailExtent: child!.geometry!.scrollExtent,
    );
    if (spare == 0) return;
    _resolved = EdgeInsets.only(top: spare);
    // Bounded second layout delegates paint/hit/semantics offsets and scroll
    // corrections to Flutter's real sliver-padding implementation.
    super.performLayout();
  }
}
