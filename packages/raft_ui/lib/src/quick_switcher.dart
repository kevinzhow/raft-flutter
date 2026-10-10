import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'indicators.dart';
import 'page_recipes.dart';
import 'popover_surface.dart';
import 'recipe_surface.dart';
import 'recipes/kbd.g.dart';
import 'recipes/search_entity.g.dart';
import 'search_input.dart';
import 'search_result_surface.dart';
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
  /// and never past the window bottom (24px margin).
  static Rect cardRect(Size viewport) {
    final width = math.min(maxWidth, viewport.width * .92);
    final natural = math.min(maxHeight, viewport.height * .8);
    final top = math.max(
      viewport.height * .08 + 16,
      (viewport.height - natural) / 2,
    );
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

/// A key cap such as the arrows and Return of the footer and the row hint.
class RaftKeyCap extends StatelessWidget {
  const RaftKeyCap(this.glyph, {super.key});
  final String glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    return ExcludeSemantics(
      child: RaftRecipeBox(
        style: RaftKbdRecipe.resolve(theme: t.recipeTheme, tokens: rt).root,
        tokens: rt,
        child: Text(
          glyph,
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: t.muted,
          ),
        ),
      ),
    );
  }
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
  });
  final Widget field, body;
  final String selectLabel, openLabel, semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    final line = BorderSide(
      color: t.brutal ? t.strong : t.colors['line-muted']!,
      width: t.brutal ? 2 : 1,
    );
    final hint = recipe.metadata.copyWith(fontSize: 11);
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
              DecoratedBox(
                decoration: BoxDecoration(border: Border(bottom: line)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: field,
                ),
              ),
              Expanded(child: body),
              DecoratedBox(
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
                      const RaftKeyCap('↑'),
                      const RaftKeyCap('↓'),
                      Text(selectLabel, style: hint),
                      const SizedBox(width: 12),
                      const RaftKeyCap('↵'),
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
    return Row(
      spacing: 8,
      children: [
        RaftIcon(RaftGlyph.search, size: 16, color: t.muted),
        Expanded(
          child: RaftSearchInput(
            key: const Key('quick-switcher-input'),
            controller: controller,
            focusNode: focusNode,
            hint: hint,
            clearLabel: clearLabel,
            showEscape: true,
            onClear: onClear,
          ),
        ),
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
  Widget build(BuildContext context) => ListView(
    controller: controller,
    primary: false,
    padding: EdgeInsets.all(compact ? 12 : 16),
    children: children,
  );
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

/// A headed group of rows.
class RaftQuickSwitcherSection extends StatelessWidget {
  const RaftQuickSwitcherSection({
    super.key,
    required this.heading,
    required this.children,
    this.glyph,
  });
  final String heading;
  final RaftGlyph? glyph;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: RaftQuickSwitcherMetrics.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftQuickSwitcherMetrics.rowGap,
        children: [
          Padding(
            padding: RaftSearchHomeRecipe.headingInset,
            child: Row(
              spacing: 6,
              children: [
                if (glyph != null) RaftIcon(glyph!, size: 12, color: t.muted),
                Expanded(child: Text(heading, style: recipe.sectionTitle)),
              ],
            ),
          ),
          ...children,
        ],
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
      child: RaftIcon(glyph, size: 16),
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
  });
  final Widget leading;
  final String title, subtitle;
  final List<String> badges;
  final bool selected, returnHint;

  /// Shows the Return hint on every state (the "Search for" row).
  final bool alwaysHint;
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
                        style: recipe.entityTitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                        uppercase: true,
                      ),
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.metadata.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          if (alwaysHint || returnHint && selected) const RaftKeyCap('↵'),
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
