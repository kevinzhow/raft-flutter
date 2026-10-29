import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'indicators.dart';
import 'page_recipes.dart';
import 'popover_surface.dart';
import 'recipe_surface.dart';
import 'recipes/search.g.dart' as gen;
import 'recipes/recipe_runtime.dart' show RaftRecipeSet;
import 'recipes/search_entity.g.dart';
import 'dialog_card.dart';
import 'search_input.dart';
import 'search_result_surface.dart';
import 'kbd.dart';
import 'theme.dart';

/// Presentation of the Cmd/Ctrl+K quick switcher (Source SearchOverlay.tsx and
/// the overlay mode of MessageSearchPage.tsx). raft_ui owns the card, field,
/// rows, headings and key hints; the app owns data, ranking and navigation.
abstract final class RaftQuickSwitcherMetrics {
  static const maxWidth = 720.0, maxHeight = 680.0;
  static const rowGap = 6.0, headGap = 8.0, sectionGap = 12.0;
  static const leadingExtent = 32.0;

  /// Source searchOverlayCardStyle fallback: `width: min(720px, 92vw)`,
  /// `height: min(680px, 80vh)`, top `max(8vh + 16px, (100vh - height) / 2)`
  /// and never past the window bottom (24px margin). With a published search
  /// field, the panel starts at its top edge and is at least as wide as it.
  static Rect cardRect(Size viewport, {Rect? anchor}) {
    final width = math.max(
      anchor?.width ?? 0,
      math.min(maxWidth, viewport.width * .92),
    );
    final natural = math.min(maxHeight, viewport.height * .8);
    final top =
        anchor?.top ??
        math.max(viewport.height * .08 + 16, (viewport.height - natural) / 2);
    final height = math.max(0.0, math.min(natural, viewport.height - top - 24));
    return Rect.fromLTWH((viewport.width - width) / 2, top, width, height);
  }
}

/// Transparent material layer for the switcher route (no dim, no blur).
class RaftQuickSwitcherLayer extends StatelessWidget {
  const RaftQuickSwitcherLayer({super.key, required this.child});
  final Widget child;
  static const barrierColor = Color(0x00000000);
  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}

/// Fixed-size floating card: the field is the header, the body scrolls, the
/// footer states the keyboard contract in one quiet line.
class RaftQuickSwitcherFrame extends StatelessWidget {
  const RaftQuickSwitcherFrame({
    super.key,
    required this.field,
    required this.body,
    required this.selectLabel,
    required this.openLabel,
    required this.semanticLabel,
    this.filters,
  });
  final Widget field, body;

  /// Filter chips under the field once there is something to filter.
  final Widget? filters;
  final String selectLabel, openLabel, semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    final line = BorderSide(color: t.colors['line-muted']!, width: 1);
    final hint = recipe.metadata.copyWith(fontSize: 11);
    final rt = t.recipeTokens;
    final shell = gen.RaftSearchRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      namesRoute: true,
      scopesRoute: true,
      label: semanticLabel,
      child: RaftPopoverSurface(
        child: ColoredBox(
          color: t.popover,
          child: Column(
            key: const Key('quick-switcher'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // `SearchShellRoot`: the frame fills header, chips and results.
              Expanded(
                child: DecoratedBox(
                  decoration: shell.frame.decoration(rt),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(border: Border(bottom: line)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: field,
                        ),
                      ),
                      ?filters,
                      Expanded(
                        child: DecoratedBox(
                          decoration: shell.viewport.decoration(rt),
                          child: body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(border: Border(top: line)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    key: const Key('quick-switcher-footer'),
                    spacing: 4,
                    children: [
                      const RaftKbd('↑'),
                      const RaftKbd('↓'),
                      Text(selectLabel, style: hint),
                      const SizedBox(width: 12),
                      const RaftKbd('↵'),
                      Text(openLabel, style: hint),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search glyph plus the shared search field.
class RaftQuickSwitcherField extends StatelessWidget {
  const RaftQuickSwitcherField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.clearLabel,
    required this.onClear,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint, clearLabel;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final search = RaftSearchInput(
      key: const Key('quick-switcher-input'),
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      clearLabel: clearLabel,
      showEscape: true,
      onClear: onClear,
    );
    // The Web's search field carries its own icon (an InputGroup addon).
    if (t.recipeSet == RaftRecipeSet.raft) return search;
    return Row(
      spacing: 8,
      children: [
        RaftIcon(RaftGlyph.search, size: 16, color: t.muted),
        Expanded(child: search),
      ],
    );
  }
}

/// Scrolling body. [head] rows (exact destination, "Search for") sit above
/// the [sections]; the recent list uses the tighter inset.
class RaftQuickSwitcherList extends StatelessWidget {
  const RaftQuickSwitcherList({
    super.key,
    required this.controller,
    required this.children,
    this.compact = false,
  });
  final ScrollController controller;
  final List<Widget> children;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final viewport = gen.RaftSearchRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).viewport;
    // `SearchShellViewport` padding plus the results wrapper (`p-3` for the
    // recent list, `p-4` for results).
    return ListView(
      controller: controller,
      primary: false,
      padding: viewport.padding.add(EdgeInsets.all(compact ? 12 : 16)),
      children: children,
    );
  }
}

/// Exact destination then the "Search for" row.
class RaftQuickSwitcherHead extends StatelessWidget {
  const RaftQuickSwitcherHead({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RaftQuickSwitcherMetrics.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftQuickSwitcherMetrics.headGap,
      children: children,
    ),
  );
}

/// A headed group of rows. With a [glyph] the heading is the Source
/// `SectionEyebrow` (recent conversations: `mb-2 flex items-center gap-1.5
/// px-1`); otherwise the search recipe's `SearchResultsSection` and
/// `SearchResultsSectionHeading` slots, like the Search page.
class RaftQuickSwitcherSection extends StatelessWidget {
  const RaftQuickSwitcherSection({
    super.key,
    required this.children,
    this.heading,
    this.glyph,
  });

  /// Null leaves the heading out (the card still paints).
  final String? heading;
  final RaftGlyph? glyph;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final slots = gen.RaftSearchRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    );
    final gap = slots.list.rowGap ?? RaftQuickSwitcherMetrics.rowGap;
    if (glyph != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: RaftSearchHomeRecipe.headingInset,
            child: Row(
              spacing: 6,
              children: [
                RaftIcon(glyph!, size: 12, color: t.muted),
                Expanded(child: RaftDialogSectionEyebrow(heading!)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: children,
          ),
        ],
      );
    }
    // The recipe box paints Chromium's shadow rule (outer shadows never show
    // through the translucent fill).
    return Padding(
      padding: slots.section.margin,
      child: RaftRecipeBox(
        style: slots.section,
        tokens: rt,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading != null)
              Padding(
                padding: slots.sectionHeading.padding,
                child: Text(
                  heading!,
                  style: slots.sectionHeading
                      .textStyle(rt)
                      .copyWith(fontFamily: t.bodyFont),
                ),
              ),
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

/// Rounded square carrying a glyph (channels, computers, "Search for").
class RaftQuickSwitcherIconBox extends StatelessWidget {
  const RaftQuickSwitcherIconBox(this.glyph, {super.key});
  final RaftGlyph glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    return Container(
      width: RaftQuickSwitcherMetrics.leadingExtent,
      height: RaftQuickSwitcherMetrics.leadingExtent,
      alignment: Alignment.center,
      decoration: RaftSearchEntityRecipe.resolve(
        theme: t.recipeTheme,
        tokens: rt,
      ).entityIcon.decoration(rt),
      child: RaftIcon(glyph, size: 14, color: t.colors['foreground-icon']),
    );
  }
}

/// Destination row: leading, title with badges, one-line subtitle and the
/// Return hint on the cursor row.
class RaftQuickSwitcherRow extends StatelessWidget {
  const RaftQuickSwitcherRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onPressed,
    this.badges = const [],
    this.returnHint = false,
    this.alwaysHint = false,
    this.boldTitle = true,
  });
  final Widget leading;
  final String title, subtitle;
  final List<String> badges;
  final bool selected, returnHint;

  /// Shows the Return hint on every state (the "Search for" row).
  final bool alwaysHint;

  /// Destination rows set their title `font-bold`; the action row keeps the
  /// recipe's title weight.
  final bool boldTitle;
  final VoidCallback onPressed;

  /// A badge label marked warning (archived) is passed as `!label`.
  static const warningPrefix = '!';
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    return RaftSearchResultSurface(
      entity: true,
      selected: selected,
      onPressed: onPressed,
      child: Row(
        spacing: 12,
        children: [
          SizedBox.square(
            dimension: RaftQuickSwitcherMetrics.leadingExtent,
            child: leading,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: boldTitle
                            ? recipe.entityTitle.copyWith(
                                fontWeight: FontWeight.w700,
                              )
                            : recipe.entityTitle,
                      ),
                    ),
                    for (final badge in badges)
                      RaftBadge(
                        label: badge.startsWith(warningPrefix)
                            ? badge.substring(1)
                            : badge,
                        appearance: RaftBadgeRecipeAppearance.soft,
                        variant: badge.startsWith(warningPrefix)
                            ? RaftBadgeRecipeVariant.warning
                            : RaftBadgeRecipeVariant.muted,
                      ),
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // `text-black/50` (Brutal), `text-foreground-muted/70`.
                  style: recipe.metadata.copyWith(
                    fontWeight: FontWeight.w400,
                    color: t.muted.withValues(alpha: .7),
                  ),
                ),
              ],
            ),
          ),
          if (alwaysHint || returnHint && selected) const RaftKbd('↵'),
        ],
      ),
    );
  }
}

/// "Search for" row: always carries the Return hint.
class RaftQuickSwitcherActionRow extends StatelessWidget {
  const RaftQuickSwitcherActionRow({
    super.key,
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onPressed,
  });
  final RaftGlyph glyph;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => RaftQuickSwitcherRow(
    leading: RaftQuickSwitcherIconBox(glyph),
    title: title,
    subtitle: subtitle,
    selected: selected,
    alwaysHint: true,
    boldTitle: false,
    onPressed: onPressed,
  );
}

/// Compact message hit: where, who, when, and the highlighted snippet.
class RaftQuickSwitcherMessageRow extends StatelessWidget {
  const RaftQuickSwitcherMessageRow({
    super.key,
    required this.where,
    required this.snippet,
    required this.selected,
    required this.onPressed,
    this.thread,
    this.sender = '',
    this.time = '',
  });
  final String where, sender, time;
  final String? thread;
  final Widget snippet;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    return RaftSearchResultSurface(
      selected: selected,
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: recipe.messageHeaderInset,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(where, style: recipe.metadata),
                if (thread != null) Text(thread!, style: recipe.metadata),
                if (sender.isNotEmpty) Text(sender, style: recipe.sender),
                if (time.isNotEmpty) Text(time, style: recipe.timestamp),
              ],
            ),
          ),
          Padding(padding: recipe.messageBodyInset, child: snippet),
        ],
      ),
    );
  }
}

/// Style of the highlighted snippet inside [RaftQuickSwitcherMessageRow].
TextStyle raftQuickSwitcherSnippetStyle(RaftTokens t) =>
    RaftSearchRecipe(t, mobile: false).snippet;

/// "Searching…" placeholder under the Messages heading.
class RaftQuickSwitcherStatus extends StatelessWidget {
  const RaftQuickSwitcherStatus(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Text(
      label,
      style: RaftSearchRecipe(RaftTokens.of(context), mobile: false).metadata,
    ),
  );
}

/// Centered "no results" block that keeps the "Search for" row reachable.
class RaftQuickSwitcherNoResults extends StatelessWidget {
  const RaftQuickSwitcherNoResults({
    super.key,
    required this.title,
    required this.detail,
  });
  final String title, detail;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        spacing: 4,
        children: [
          RaftIcon(RaftGlyph.search, size: 32, color: t.muted),
          Text(
            title,
            textAlign: TextAlign.center,
            style: recipe.entityTitle.copyWith(color: t.muted),
          ),
          Text(detail, textAlign: TextAlign.center, style: recipe.metadata),
        ],
      ),
    );
  }
}
