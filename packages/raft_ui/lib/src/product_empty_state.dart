import 'package:flutter/material.dart';

import 'panel_layout.dart' show RaftCssText;
import 'recipe_surface.dart';
import 'recipes/empty_state.g.dart';
import 'system_inset.dart' show raftScrollPadding;
import 'design_primitives.dart' show RaftTypography;
import 'theme.dart';

/// Web `components/ui/EmptyState` (raft-ui `EmptyState` / `EmptyStateIcon` /
/// `EmptyStateContent` / `EmptyStateTitle` / `EmptyStateDescription`),
/// painted from the generated `emptyState` recipe: elegant shows a small
/// rounded `bg-fill-muted` icon tile and a `text-sm font-medium` title,
/// brutal a bare 36px icon and a muted `text-lg font-semibold` title. The
/// recipe's `[&_svg]:size-*` wins over the call site's icon size attribute.
///
/// [icon] receives the recipe icon size and colour. The widget fills the
/// space it is given and centres its content (`flex flex-1 flex-col
/// items-center justify-center`).
class RaftProductEmptyState extends StatelessWidget {
  const RaftProductEmptyState({
    super.key,
    required this.title,
    required this.icon,
    this.description,
    this.action,
  });

  final String title;
  final String? description;
  final Widget? action;
  final Widget Function(BuildContext context, double size, Color color) icon;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // raft-ui 0.7.0 EmptyState: a bare 36px `text-foreground-hint` icon, a
    // `text-headline font-bold text-foreground-muted` title and a callout
    // description (`px-6 py-12`, content `max-w-sm gap-2`); the pre-theme looks
    // keep the recipe of a57b9dab (emptyState.look).
    if (t.option('emptyState.look', or: 'plain') == 'plain') {
      final base = DefaultTextStyle.of(context).style;
      final contentMax = t.size('size.emptyContentMax', fallback: 384);
      final descriptionMax = t.size('size.emptyDescriptionMax', fallback: 300);
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.size('space.emptyInline', fallback: 24),
            vertical: t.size('space.emptyBlock', fallback: 48),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: contentMax > 0 ? contentMax : double.infinity,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: const ValueKey('empty-state-icon'),
                  child: icon(
                    context,
                    t.size('size.emptyGlyph', fallback: 36),
                    t.colors['foreground-hint']!,
                  ),
                ),
                SizedBox(height: t.size('space.emptyIconAfter', fallback: 16)),
                RaftCssText(
                  title,
                  key: const ValueKey('empty-state-title'),
                  textAlign: TextAlign.center,
                  style: RaftTypography.body(
                    t,
                    size: t.size('type.emptyTitle.size', fallback: 17),
                    line: t.size('type.emptyTitle.line', fallback: 22),
                    weight: FontWeight.w700,
                    color: t.colors['foreground-muted'],
                  ).copyWith(fontFamily: base.fontFamily),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: descriptionMax > 0
                          ? descriptionMax
                          : double.infinity,
                    ),
                    child: RaftCssText(
                      description!,
                      textAlign: TextAlign.center,
                      style: RaftTypography.body(
                        t,
                        size: t.size('type.emptyBody.size', fallback: 14),
                        line: t.size('type.emptyBody.line', fallback: 20),
                        color: t.colors['foreground-hint'],
                      ).copyWith(fontFamily: base.fontFamily),
                    ),
                  ),
                ],
                if (action != null)
                  Padding(
                    padding: EdgeInsets.only(
                      top: t.size('space.emptyActionBefore', fallback: 20),
                    ),
                    child: action,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final rt = t.recipeTokens;
    final recipe = RaftEmptyStateRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    );
    final base = DefaultTextStyle.of(context).style;
    final iconSlot = recipe.icon;
    final svg = iconSlot.target('& svg') ?? iconSlot.target('[&_svg]');
    final iconColor =
        iconSlot.textStyle(rt).color ?? t.colors['foreground-placeholder']!;
    final iconSize = svg?.width ?? (18.0);
    final content = recipe.content;
    return Center(
      child: Padding(
        padding: recipe.root.padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: content.maxWidth ?? 384),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The icon is a sibling of the content slot (not inside it), so
              // the recipe's `mb-4` applies; `gap-2` only spaces title/text.
              RaftRecipeBox(
                key: const ValueKey('empty-state-icon'),
                style: iconSlot,
                tokens: rt,
                applyText: false,
                child: icon(context, iconSize, iconColor),
              ),
              SizedBox(height: iconSlot.margin.bottom),
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: content.rowGap ?? 8,
                children: [
                  RaftCssText(
                    title,
                    key: const ValueKey('empty-state-title'),
                    textAlign: TextAlign.center,
                    style: recipe.title.text(rt, base: base),
                  ),
                  if (description != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 275),
                      child: RaftCssText(
                        description!,
                        textAlign: TextAlign.center,
                        style: recipe.description.text(rt, base: base),
                      ),
                    ),
                ],
              ),
              if (action != null)
                Padding(
                  padding: EdgeInsets.only(top: recipe.actions.margin.top),
                  child: action,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [RaftProductEmptyState] filling a board surface (`bg-layer-sidebar`, brutal
/// `bg-layer-panel`) with the `p-4` page inset plus the system inset, as the
/// Tasks panel shows it for a channel with no task at all.
class RaftProductEmptyPanel extends StatelessWidget {
  const RaftProductEmptyPanel({
    super.key,
    required this.title,
    required this.icon,
    this.description,
    this.action,
  });

  final String title;
  final String? description;
  final Widget? action;
  final Widget Function(BuildContext context, double size, Color color) icon;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      // TasksPanelViewport `dark:bg-transparent`: Elegant dark shows the
      // mounted card surface.
      color: (t.dark ? Colors.transparent : t.sidebar),
      child: Padding(
        padding: raftScrollPadding(context, const EdgeInsets.all(16)),
        child: SizedBox.expand(
          child: RaftProductEmptyState(
            title: title,
            description: description,
            action: action,
            icon: icon,
          ),
        ),
      ),
    );
  }
}
