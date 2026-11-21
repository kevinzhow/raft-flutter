import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart' show RaftTokens;

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

  /// The wrapper keeps its inset at every width. raft-ui 0.5.36 dropped the
  /// brutal row's `mx-3` and set the row insets to 8 (7 + 1 border; 6 + 2
  /// brutal), so the Web itself lands the avatar on 20 next to the header
  /// buttons on a phone. This replaces the owner decision of 2026-10-12, which
  /// removed the wrapper inset on phones to reach the same 20.
  ///
  /// [desktop]: the Raft look in a window of 768 or more with a fine pointer
  /// (`RaftTokens.desktop`): the wrapper is `--page-inset - 8` = 8 there, so
  /// the avatar sits on 16 (composerHost.ts).
  EdgeInsets messageInsetFor(double viewportWidth, {bool desktop = false}) =>
      desktop && viewportWidth >= 768
      ? const EdgeInsets.symmetric(horizontal: 8)
      : messageInset;

  /// [messageInsetFor] for the window and input of [context].
  EdgeInsets messageInsetOf(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return messageInsetFor(tokens.viewportWidth ?? 0, desktop: tokens.desktop);
  }

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
    bool reserveSentinels = true,
  }) => [
    ...header,
    if (reserveSentinels)
      SliverToBoxAdapter(child: SizedBox(height: sentinelExtent)),
    history,
    forward,
    if (reserveSentinels)
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

/// Timeline footer plus optional loading-newer content. When the channel
/// composer follows, its top inset completes the Web timeline section gap.
class RaftTimelineFooter extends StatelessWidget {
  const RaftTimelineFooter({
    super.key,
    this.loadingNewer,
    this.aboveComposer = false,
  });
  final Widget? loadingNewer;
  final bool aboveComposer;
  @override
  Widget build(BuildContext context) {
    const recipe = RaftTimelineCompositionRecipe();
    return Padding(
      // The trailing scroll sentinel already occupies one pixel of the
      // measured 12px Web end space above the composer.
      padding: aboveComposer
          ? recipe.footerInset.copyWith(
              bottom: recipe.footerInset.bottom - recipe.sentinelExtent,
            )
          : recipe.footerInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loadingNewer != null) loadingNewer!,
          if (!aboveComposer) SizedBox(height: recipe.footerTailExtent),
        ],
      ),
    );
  }
}
