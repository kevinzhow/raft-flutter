import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'indicators.dart';
import 'recipe_surface.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/search.g.dart' as gen;
import 'recipes/search_message.g.dart';
import 'recipes/search_thread.g.dart';
import 'search_result_surface.dart';
import 'theme.dart';
import 'flex_shrink_row.dart';
import 'raft/ui_tokens.dart';
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
      theme: t.recipeTheme,
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

/// `SearchSkeleton`: five placeholder cards (three meta bars, two text bars).
class RaftQuickSwitcherSkeleton extends StatelessWidget {
  const RaftQuickSwitcherSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final line = BorderSide(color: t.colors['line-muted']!, width: 1);
    Widget bar([double? width]) =>
        RaftSkeleton(variant: RaftSkeletonVariant.line, width: width);
    return Column(
      key: const Key('quick-switcher-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            decoration: BoxDecoration(
              color: t.card,
              border: Border.fromBorderSide(line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(spacing: 8, children: [bar(96), bar(80), bar(64)]),
                  const SizedBox(height: 8),
                  bar(),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: .8,
                    child: bar(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The search failure card: title, one line of advice and an optional action.
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
    final t = RaftTokens.of(context);
    return Container(
      key: const Key('quick-switcher-error'),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.colors['line-muted']!, width: 1),
        boxShadow: t.shadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: RaftTypography.body(
                t,
                size: 14,
                line: 20,
                weight: FontWeight.w700,
                color: t.strong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              RaftTextButton(
                label: actionLabel!,
                visualHeight: RaftMetrics.buttonSm,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
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
  });
  final String where, sender, time;
  final String? threadLabel;

  /// Warning badges (archived, beyond history), already localized.
  final List<String> warnings;
  final Widget? avatar;
  final Widget snippet;
  final bool selected, nested, first;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final plain = t.option('listGroup.frame', or: 'framed') == 'plain';
    final m = RaftSearchMessageRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
      selected: selected,
      nested: nested,
    );
    TextStyle meta(RaftSlotStyle slot) {
      final own = slot.textStyle(rt);
      return m.messageHeader
          .textStyle(rt)
          .merge(own)
          .copyWith(fontFamily: own.fontFamily ?? t.bodyFont);
    }

    return RaftSearchResultSurface(
      selected: selected,
      nested: nested,
      first: first,
      onPressed: onPressed,
      child: Column(
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
                              RaftFlexShrinkRow(
                                gap: 6,
                                truncating: true,
                                fixed: avatar != null ? const {0} : const {},
                                children: [
                                  ?avatar,
                                  Text(
                                    sender,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.scale(
                                      RaftTypeScale.callout,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            Text(
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
                                  RaftThreadIcon(
                                    size: 12,
                                    color: t.ui.foregroundHint,
                                  ),
                                  Text(
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
                        Text(
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
                            RaftThreadIcon(
                              size: 10,
                              color: meta(m.messageThreadMeta).color,
                            ),
                            Text(
                              threadLabel!,
                              style: meta(m.messageThreadMeta),
                            ),
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
              style: m.messageBody
                  .textStyle(rt)
                  .copyWith(fontFamily: t.bodyFont),
              child: snippet,
            ),
          ),
        ],
      ),
    );
  }

  /// Style of the highlighted snippet.
  static TextStyle snippetStyle(RaftTokens t) {
    if (t.option('listGroup.frame', or: 'framed') == 'plain')
      return t.scale(RaftTypeScale.callout, color: t.ui.foregroundMuted);
    final rt = t.recipeTokens;
    return RaftSearchMessageRecipe.resolve(
      theme: t.recipeTheme,
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
      theme: t.recipeTheme,
      states: t.recipeStates(extra: [if (selected) 'data-selected=true']),
      tokens: rt,
    );
    TextStyle text(RaftSlotStyle slot) => slot
        .textStyle(rt)
        .copyWith(fontFamily: slot.textStyle(rt).fontFamily ?? t.bodyFont);
    // `text-[11px] font-bold text-foreground-muted` (decision 0002: no caps).
    final metaStyle = RaftTypography.body(
      t,
      size: 11,
      line: 16,
      weight: FontWeight.w700,
      color: t.muted,
    ).copyWith(height: 1.5);
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
                          leading: RaftThreadIcon(size: 11, color: t.muted),
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
            style: RaftTypography.body(
              t,
              size: 14,
              line: 20,
              weight: FontWeight.w700,
              color: t.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: RaftTypography.body(
              t,
              size: 12,
              line: 16,
              color: t.muted.withValues(alpha: .7),
            ),
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
          theme: t.recipeTheme,
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
