// Small Web-parity parts of the list pages (Search home, SelectionPopover,
// Tasks loading, Search load more) so the product pages compose them instead of
// restyling Material widgets.
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'components.dart' show RaftAvatar, RaftAvatarKind;
import 'control_typography.dart';
import 'design_primitives.dart';
import 'page_recipes.dart' show RaftSearchHomeRecipe;
import 'dialog_card.dart' show RaftRecipeButton;
import 'icons.dart';
import 'indicators.dart';
import 'list_items.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'system_inset.dart';
import 'theme.dart';

/// MessageSearchPage home heading: `mb-2 flex items-center justify-between
/// gap-3 px-1` over a SectionEyebrow with a 12px glyph (`gap-1.5`) and text
/// actions (`gap-3`).
class RaftSearchHomeHeading extends StatelessWidget {
  const RaftSearchHomeHeading({
    super.key,
    required this.label,
    required this.glyph,
    this.actions = const [],
  });
  final String label;
  final RaftGlyph glyph;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          RaftIcon(glyph, size: 12, color: t.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: RaftSectionEyebrow(raftText(context, label)),
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// `text-[11px] font-bold text-foreground-muted` (brutal black/45) text action
/// of the Search History heading.
class RaftSearchHomeAction extends StatelessWidget {
  const RaftSearchHomeAction({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      button: true,
      label: raftText(context, label),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: RaftHoverRegion(
          cursor: SystemMouseCursors.click,
          child: Text(
            raftText(context, label),
            style: TextStyle(
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w700,
              color: t.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// SelectionPopover header: `border-b px-3 py-2`, 10px bold
/// title and an optional Clear action.
class RaftSelectionPopoverHeader extends StatelessWidget {
  const RaftSelectionPopoverHeader({
    super.key,
    required this.title,
    this.onClear,
  });
  final String title;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = TextStyle(
      fontFamily: t.bodyFont,
      fontSize: 10,
      height: 16 / 10,
      fontWeight: FontWeight.w700,
      color: t.muted,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.colors['line-muted']!)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: style)),
          if (onClear != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Text(raftText(context, 'Clear'), style: style),
            ),
        ],
      ),
    );
  }
}

/// SelectionPopover search slot: `border-b px-2 py-2` around the field.
class RaftSelectionPopoverSearchSlot extends StatelessWidget {
  const RaftSelectionPopoverSearchSlot({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.colors['line-muted']!)),
      ),
      child: child,
    );
  }
}

/// TasksPanel loading: five `SkeletonRow` cards (`gap-2 rounded border p-3`,
/// lines w-1/2 and w-3/4) in the `p-4` viewport.
class RaftTaskLoadingList extends StatelessWidget {
  const RaftTaskLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // v1.21.23 TaskCardSkeleton: a Card (`rounded-container`, hairline) in the
    // `px-5 py-4` viewport; the pre-theme looks drew a 4px-radius muted box.
    return ListView(
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: raftScrollPadding(
        context,
        EdgeInsets.symmetric(
          horizontal:
              MediaQuery.sizeOf(context).width >=
                  RaftLayoutMetrics.desktopBreakpoint
              ? t.size('space.tasksViewportInline', fallback: 20)
              : 16,
          vertical: 16,
        ),
      ),
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 4 ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(
                  t.size('radius.taskLoadingCard', fallback: 10),
                ),
                border: Border.all(
                  color: t.colors['line-loading-card']!,
                  width: 1,
                ),
              ),
              child: const RaftSkeletonRow(lineFractions: [.5, .75]),
            ),
          ),
      ],
    );
  }
}

/// MessageSearchPage Load More: `flex justify-center py-4` around a
/// `Button size=sm outline`.
class RaftSearchLoadMore extends StatelessWidget {
  const RaftSearchLoadMore({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: RaftRecipeButton(
        label: raftText(context, 'Load More'),
        variant: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.sm,
        onPressed: onPressed,
      ),
    ),
  );
}

/// SelectionPopover row leading slot (`size-5`): a 20px avatar, or the empty
/// reserved slot of the sentinel rows ("Assigned to me", "Unassigned").
class RaftSelectionPopoverAvatarSlot extends StatelessWidget {
  const RaftSelectionPopoverAvatarSlot({
    super.key,
    this.name,
    this.agent = false,
  });
  final String? name;
  final bool agent;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 20,
    child: name == null
        ? null
        : Center(
            child: RaftAvatar(
              name: name!,
              size: 20,
              kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
            ),
          ),
  );
}

/// Search home history tag (Web `MessageSearchPage` `search-history-tag`): an
/// outlined chip of a 12px clock, the query and a remove button that is
/// revealed on hover / focus (pointer) or while editing (touch).
///
/// The label takes the Android Chinese control profile
/// ([RaftControlTypography]) like every single-line control label, so the CJK
/// ink sits on the chip centre. The chip is [RaftSearchHomeRecipe.tagHeight]
/// at least; a taller line box grows it.
class RaftSearchHistoryTag extends StatefulWidget {
  const RaftSearchHistoryTag({
    super.key,
    required this.query,
    required this.touch,
    required this.editing,
    required this.onPressed,
    required this.onRemove,
  });
  final String query;

  /// Touch layout: the remove button exists only while [editing].
  final bool touch, editing;
  final VoidCallback onPressed, onRemove;

  @override
  State<RaftSearchHistoryTag> createState() => _RaftSearchHistoryTagState();
}

class _RaftSearchHistoryTagState extends State<RaftSearchHistoryTag> {
  bool hovering = false, focused = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchHomeRecipe(t);
    final reveal = widget.editing || hovering || focused;
    final showRemove = !widget.touch || widget.editing;
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: Focus(
        onFocusChange: (value) => setState(() => focused = value),
        child: Container(
          decoration: BoxDecoration(
            color: reveal ? t.colors['fill-muted'] : recipe.tagBackground,
            border: Border.all(color: reveal ? t.strong : recipe.tagBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: RaftControl(
                  semanticLabel: 'Search history: ${widget.query}',
                  shadow: false,
                  variant: RaftControlVariant.ghost,
                  visualHeight: RaftSearchHomeRecipe.tagHeight,
                  flexibleHeight: true,
                  padding: RaftSearchHomeRecipe.tagInset,
                  minimumTargetSize: RaftSearchHomeRecipe.tagHeight,
                  onPressed: widget.onPressed,
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RaftIcon(RaftGlyph.clock3, size: 12, color: t.muted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.query,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RaftControlTypography.of(
                              context,
                              recipe.historyLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showRemove)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IgnorePointer(
                    ignoring: !reveal,
                    child: Opacity(
                      opacity: reveal ? 1 : 0,
                      child: RaftIconButton(
                        glyph: RaftGlyph.x,
                        glyphSize: 12,
                        visualSize: 20,
                        tooltip: raftFormat(
                          context,
                          'Remove "{query}" from Search History',
                          {'query': widget.query},
                        ),
                        onPressed: widget.onRemove,
                      ),
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

/// MessageSearchPage's footer under the results: `flex flex-col items-center
/// gap-2 px-4 py-4` around the incomplete note and the paging button (or the
/// failed-page warning).
class RaftSearchFooter extends StatelessWidget {
  const RaftSearchFooter({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: children,
    ),
  );
}

/// `text-center text-caption text-foreground-hint`: the note that says how far
/// an incomplete search got.
class RaftSearchNote extends StatelessWidget {
  const RaftSearchNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: RaftTypography.body(
        t,
        size: 12,
        line: 16,
        color: t.colors['foreground-hint'] ?? t.muted,
      ),
    );
  }
}

/// An empty search state with room around it (`py-16`), and the failed-page
/// warning under it when the next page could not be read.
class RaftSearchEmptyFrame extends StatelessWidget {
  const RaftSearchEmptyFrame({super.key, required this.child, this.footer});
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        child,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: footer,
          ),
      ],
    ),
  );
}
