import 'package:flutter/material.dart';

import 'banner.dart';
import 'icons.dart';
import 'indicators.dart';
import 'interaction.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/avatar.dart';
import 'raft/button.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/search.g.dart' as gen;
import 'recipes/search_message.g.dart';
import 'recipes/search_thread.g.dart';
import 'search_result_surface.dart';
import 'surface_background_scope.dart';
import 'theme.dart';
import 'flex_shrink_row.dart';
import 'tokens/tokens.dart';

/// Filter chips laid out like MessageSearchPage's `flex flex-wrap items-center
/// gap-2` row; the Search page and the quick switcher both use it.
class RaftSearchFilterWrap extends StatelessWidget {
  const RaftSearchFilterWrap({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}

/// `SearchShellFilters` strip of the overlay (`px-3 py-2`): the recipe's
/// border and background with the overlay's own padding.
class RaftQuickSwitcherFilterRow extends StatelessWidget {
  const RaftQuickSwitcherFilterRow({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final slot = gen.RaftSearchRecipe.resolve(
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).filtersRow;
    return RaftRecipeBox(
      key: const Key('quick-switcher-filters'),
      style: slot,
      tokens: t.recipeTokens,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

/// `SearchSkeleton`: five `SearchMessageResult` rows matching Web `SearchSkeleton.tsx`.
class RaftQuickSwitcherSkeleton extends StatelessWidget {
  const RaftQuickSwitcherSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final compact = RaftInteraction.of(context).touch;
    final avatarSize = RaftAvatarSize.sm.extent;
    final leftInset = compact ? 20.0 : 16.0;
    Widget bar({double? width, double height = 10}) => RaftSkeleton(
      variant: RaftSkeletonVariant.line,
      width: width,
      height: height,
      fromRecipe: true,
    );
    Widget row() => Stack(
      children: [
        Positioned(
          left: leftInset,
          top: 12,
          child: RaftSkeleton(
            variant: RaftSkeletonVariant.block,
            width: avatarSize,
            height: avatarSize,
            fromRecipe: true,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            leftInset + 39,
            compact ? 12 : 8,
            leftInset,
            compact ? 12 : 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: compact ? 20 : 24,
                child: Padding(
                  padding: compact
                      ? const EdgeInsets.only(top: 6)
                      : EdgeInsets.zero,
                  child: Row(
                    crossAxisAlignment: compact
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    spacing: 6,
                    children: [
                      bar(width: 96),
                      bar(width: 80),
                      const Spacer(),
                      bar(width: 48),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 20,
                child: Padding(
                  padding: compact
                      ? const EdgeInsets.only(top: 6)
                      : EdgeInsets.zero,
                  child: Align(
                    alignment: compact
                        ? Alignment.topLeft
                        : Alignment.centerLeft,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: .8,
                      child: bar(),
                    ),
                  ),
                ),
              ),
              if (compact)
                SizedBox(
                  height: 20,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: FractionallySizedBox(
                        alignment: Alignment.topLeft,
                        widthFactor: .5,
                        child: bar(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return Padding(
      key: const Key('quick-switcher-skeleton'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [for (var i = 0; i < 5; i++) row()],
      ),
    );
  }
}

/// The search failure banner: warning status, title, body and an optional outline action.
class RaftQuickSwitcherErrorCard extends StatelessWidget {
  const RaftQuickSwitcherErrorCard({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });
  final String title, body;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final banner = RaftBanner(
      key: const Key('quick-switcher-error'),
      status: RaftBannerRecipeStatus.warning,
      live: false,
      glyph: RaftGlyph.triangleAlert,
      title: title,
      description: body,
      action: actionLabel == null
          ? null
          : RaftButton(
              label: actionLabel!,
              uiVariant: RaftButtonVariant.outline,
              uiSize: RaftButtonSize.md,
              onPressed: onAction,
            ),
    );
    if (RaftSurfaceBackgroundScope.of(context) != null) return banner;
    return RaftSurfaceBackgroundScope(
      color: RaftTokens.of(context).ui.layerCanvas,
      child: banner,
    );
  }
}

/// A message hit (`renderMessageHit`): source, thread marker, badges, sender
/// with avatar and time over the highlighted snippet.
class RaftQuickSwitcherHit extends StatelessWidget {
  const RaftQuickSwitcherHit({
    super.key,
    required this.where,
    required this.snippet,
    required this.selected,
    required this.onPressed,
    this.threadLabel,
    this.warnings = const [],
    this.avatar,
    this.sender = '',
    this.time = '',
    this.nested = false,
    this.first = false,
    this.pageLayout = false,
  });
  final String where, sender, time;
  final String? threadLabel;

  /// Warning badges (archived, beyond history), already localized.
  final List<String> warnings;
  final Widget? avatar;
  final Widget snippet;
  final bool selected, nested, first, pageLayout;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final plain = t.option('listGroup.frame', or: 'framed') == 'plain';
    final m = RaftSearchMessageRecipe.resolve(
      states: t.recipeStates(),
      tokens: rt,
    );
    TextStyle meta(RaftSlotStyle slot) {
      final own = slot.textStyle(rt);
      return m.messageHeader
          .textStyle(rt)
          .merge(own)
          .copyWith(fontFamily: own.fontFamily ?? t.bodyFont);
    }

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Nested hits drop the header padding and keep `mb-1`
          // (`group-data-[nested=true]` variants).
          padding: plain
              ? const EdgeInsets.only(bottom: 2)
              : nested
              ? const EdgeInsets.only(bottom: 4)
              : m.messageHeader.padding.add(
                  EdgeInsets.only(bottom: m.messageHeader.margin.bottom),
                ),
          child: plain
              ? Row(
                  children: [
                    Expanded(
                      child: RaftFlexShrinkRow(
                        gap: 6,
                        truncating: true,
                        children: [
                          if (sender.isNotEmpty)
                            RaftCssText(
                              sender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.scale(
                                RaftTypeScale.callout,
                                weight: FontWeight.w700,
                              ),
                            ),
                          RaftCssText(
                            where,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.scale(
                              RaftTypeScale.monoMeta,
                              mono: true,
                              color: t.ui.foregroundHint,
                            ),
                          ),
                          if (threadLabel != null)
                            RaftFlexShrinkRow(
                              gap: 4,
                              truncating: true,
                              fixed: const {0},
                              children: [
                                RaftThreadIcon.search(
                                  color: t.ui.foregroundHint,
                                ),
                                RaftCssText(
                                  threadLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.scale(
                                    RaftTypeScale.monoMeta,
                                    mono: true,
                                    color: t.ui.foregroundHint,
                                  ),
                                ),
                              ],
                            ),
                          for (final warning in warnings)
                            RaftBadge(
                              label: warning,
                              appearance: RaftBadgeRecipeAppearance.soft,
                              variant: RaftBadgeRecipeVariant.warning,
                            ),
                        ],
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      RaftCssText(
                        time,
                        style: t.scale(
                          RaftTypeScale.monoMeta,
                          mono: true,
                          color: t.ui.foregroundHint,
                        ),
                      ),
                    ],
                  ],
                )
              : Wrap(
                  spacing: m.messageHeader.columnGap ?? 8,
                  runSpacing: m.messageHeader.rowGap ?? 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(where, style: meta(m.messageMeta)),
                    if (threadLabel != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: m.messageThreadMeta.columnGap ?? 0,
                        children: [
                          RaftThreadIcon.search(
                            color: meta(m.messageThreadMeta).color ?? t.muted,
                          ),
                          Text(threadLabel!, style: meta(m.messageThreadMeta)),
                        ],
                      ),
                    for (final warning in warnings)
                      RaftBadge(
                        label: warning,
                        appearance: RaftBadgeRecipeAppearance.soft,
                        variant: RaftBadgeRecipeVariant.warning,
                      ),
                    if (sender.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: m.messageSender.columnGap ?? 4,
                        children: [
                          ?avatar,
                          Flexible(
                            child: Text(
                              sender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: meta(m.messageSender),
                            ),
                          ),
                        ],
                      ),
                    if (time.isNotEmpty)
                      Text(time, style: meta(m.messageTimestamp)),
                  ],
                ),
        ),
        Padding(
          padding: plain || nested ? EdgeInsets.zero : m.messageBody.padding,
          child: DefaultTextStyle.merge(
            style: m.messageBody.textStyle(rt).copyWith(fontFamily: t.bodyFont),
            child: snippet,
          ),
        ),
      ],
    );
    return RaftSearchResultSurface(
      pageLayout: pageLayout,
      selected: selected,
      nested: nested,
      first: first,
      onPressed: onPressed,
      child: plain && avatar != null
          ? Row(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar!,
                Expanded(child: textColumn),
              ],
            )
          : textColumn,
    );
  }

  /// Style of the highlighted snippet.
  static TextStyle snippetStyle(RaftTokens t, {bool selected = false}) {
    if (t.option('listGroup.frame', or: 'framed') == 'plain') {
      final ink = t.ui.foregroundMuted;
      final fill = t.ui['brand-soft'];
      final alpha = (ink.a * 255).round() / 255;
      int channel(double fg, double bg) =>
          (fg * 255 * alpha).round() + (bg * 255 * (1 - alpha)).round();
      return t.scale(
        RaftTypeScale.callout,
        color: selected && fill.a == 1
            ? fill.withValues(
                red: channel(ink.r, fill.r) / 255,
                green: channel(ink.g, fill.g) / 255,
                blue: channel(ink.b, fill.b) / 255,
              )
            : ink,
      );
    }
    final rt = t.recipeTokens;
    return RaftSearchMessageRecipe.resolve(
      states: t.recipeStates(),
      tokens: rt,
    ).messageBody.textStyle(rt).copyWith(fontFamily: t.bodyFont);
  }
}

/// A thread's hits under one card (`SearchThreadResult`): marker badge,
/// source, hit count and time over the thread title, then the nested hits.
class RaftQuickSwitcherThreadGroup extends StatelessWidget {
  const RaftQuickSwitcherThreadGroup({
    super.key,
    required this.badge,
    required this.where,
    required this.hits,
    required this.time,
    required this.title,
    required this.children,
    this.selected = false,
  });
  final String badge, where, hits, time, title;
  final bool selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final g = RaftSearchThreadRecipe.resolve(
      states: t.recipeStates(extra: [if (selected) 'data-selected=true']),
      tokens: rt,
    );
    TextStyle text(RaftSlotStyle slot) => slot
        .textStyle(rt)
        .copyWith(fontFamily: slot.textStyle(rt).fontFamily ?? t.bodyFont);
    // `text-[11px] font-bold text-foreground-muted` (decision 0002: no caps).
    final metaStyle = t.scale(
      RaftTypeScale.label,
      weight: FontWeight.w700,
      color: t.ui.foregroundMuted,
    );
    return RaftRecipeBox(
      key: const Key('quick-switcher-thread-group'),
      style: g.thread.withCssUsedBorderWidths(),
      tokens: rt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftRecipeBox(
            style: g.threadHeader,
            tokens: rt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 20.5),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RaftBadge(
                          label: badge,
                          appearance: RaftBadgeRecipeAppearance.outline,
                          leading: RaftThreadIcon.search(color: t.muted),
                        ),
                        Text(where, style: metaStyle.merge(text(g.threadMeta))),
                        Text(hits, style: metaStyle),
                        Text(
                          time,
                          style: metaStyle.merge(text(g.threadTimestamp)),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(title, style: text(g.threadTitle)),
              ],
            ),
          ),
          RaftRecipeBox(
            style: g.threadMessages.withCssUsedBorderWidths(),
            tokens: rt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// `centeredEmptyState`: the faint search glyph over a title and a hint.
class RaftQuickSwitcherEmpty extends StatelessWidget {
  const RaftQuickSwitcherEmpty({
    super.key,
    required this.title,
    required this.detail,
    this.iconSize = 32,
  });
  final String title, detail;

  /// The overlay's glyph is 32; the full results page uses 48.
  final double iconSize;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftIcon(
            RaftGlyph.search,
            size: iconSize,
            color: t.muted.withValues(alpha: .3),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.scale(
              RaftTypeScale.callout,
              weight: FontWeight.w700,
              color: t.ui.foregroundMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundHint),
          ),
        ],
      ),
    );
  }
}

/// `ENTITY_RESULTS_SCROLL_CLASS` (`-m-1.5 max-h-[24rem] overflow-y-auto p-1.5`):
/// the destination list scrolls inside a 24rem box whose scroll port reaches
/// 6px past the rows, so a selection ring is not clipped.
class RaftQuickSwitcherEntityScroll extends StatelessWidget {
  const RaftQuickSwitcherEntityScroll({super.key, required this.children});
  final List<Widget> children;
  static const _bleed = 6.0, _maxHeight = 384.0;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final gap =
        gen.RaftSearchRecipe.resolve(
          states: t.recipeStates(),
          tokens: t.recipeTokens,
        ).list.rowGap ??
        6;
    return ClipRect(
      clipper: const _BleedClipper(_bleed),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxHeight - 2 * _bleed),
        child: ListView(
          key: const Key('quick-switcher-entities'),
          shrinkWrap: true,
          primary: false,
          clipBehavior: Clip.none,
          padding: EdgeInsets.zero,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}

class _BleedClipper extends CustomClipper<Rect> {
  const _BleedClipper(this.bleed);
  final double bleed;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height).inflate(bleed);
  @override
  bool shouldReclip(_BleedClipper old) => old.bleed != bleed;
}
