// raft-ui 0.95.3 `Card` parts (`card.recipe.ts` slots): header grid, title, description, leading, trailing,
// content, footer. Each part reads its slot of the generated card recipe (padding, border, type, gaps) for the
// variant of the enclosing [RaftCard] (see [RaftCardScope]), with the desktop `md:pointer-fine` rules.
import 'package:flutter/material.dart';

import 'recipe_surface.dart';
import 'recipes/card.g.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// The variant of the [RaftCard] a part sits in; parts outside a card use the default variant.
class RaftCardScope extends InheritedWidget {
  const RaftCardScope({super.key, required this.variant, required super.child});

  final RaftCardRecipeVariant variant;

  static RaftCardRecipeVariant of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftCardScope>()?.variant ??
      RaftCardRecipeVariant.default_;

  @override
  bool updateShouldNotify(RaftCardScope old) => variant != old.variant;
}

({RaftCardRecipeStyle slots, RaftRecipeTokens tokens}) _resolve(
  BuildContext context,
) {
  final t = RaftTokens.of(context);
  final tokens = t.recipeTokens;
  return (
    slots: RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      variant: RaftCardScope.of(context),
      states: t.recipeStates(responsive: true),
      tokens: tokens,
    ),
    tokens: tokens,
  );
}

/// `CardHeader`: the grid of [leading] (spans both rows), [title], [description] and [trailing] (on the title
/// row, vertically centred). [aboveContent] is `has-[+[data-slot=card-content]]:pb-0`.
class RaftCardSectionHeader extends StatelessWidget {
  const RaftCardSectionHeader({
    super.key,
    this.leading,
    this.title,
    this.description,
    this.trailing,
    this.aboveContent = false,
  });

  final RaftCardLeading? leading;
  final RaftCardTitle? title;
  final RaftCardDescription? description;
  final RaftCardTrailing? trailing;
  final bool aboveContent;

  @override
  Widget build(BuildContext context) {
    final r = _resolve(context);
    final slot = r.slots.header;
    final padding = slot.padding;
    final colGap = slot.columnGap ?? 0;
    final rowGap = slot.rowGap ?? 0;
    final titleRow = [
      if (title != null) Expanded(child: title!) else const Spacer(),
      if (trailing != null) ...[SizedBox(width: colGap), trailing!],
    ];
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null || trailing != null)
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: titleRow),
        if (description != null) ...[
          if (title != null || trailing != null) SizedBox(height: rowGap),
          description!,
        ],
      ],
    );
    return RaftRecipeBox(
      style: slot,
      tokens: r.tokens,
      width: double.infinity,
      padding: aboveContent ? padding.copyWith(bottom: 0) : padding,
      applyText: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, SizedBox(width: colGap)],
          Expanded(child: text),
        ],
      ),
    );
  }
}

/// `CardTitle`: `text-card-title font-card-title` (16 / 600 / 24 touch, 14 / 22 on desktop; `callout`
/// semibold in the option variant).
class RaftCardTitle extends StatelessWidget {
  const RaftCardTitle(this.title, {super.key, this.maxLines, this.overflow});

  final Widget title;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final r = _resolve(context);
    return DefaultTextStyle.merge(
      style: r.slots.title.text(r.tokens, base: DefaultTextStyle.of(context).style),
      maxLines: maxLines,
      overflow: overflow,
      child: title,
    );
  }
}

/// `CardDescription`: `text-callout text-foreground-muted` (`footnote` in the option variant).
class RaftCardDescription extends StatelessWidget {
  const RaftCardDescription(this.description, {super.key});

  final Widget description;

  @override
  Widget build(BuildContext context) {
    final r = _resolve(context);
    return DefaultTextStyle.merge(
      style: r.slots.description.text(
        r.tokens,
        base: DefaultTextStyle.of(context).style,
      ),
      child: description,
    );
  }
}

/// `CardLeading`: an icon or avatar before the title, at least one title line tall, top-aligned.
class RaftCardLeading extends StatelessWidget {
  const RaftCardLeading(this.leading, {super.key});

  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final r = _resolve(context);
    final slot = r.slots.leading;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: slot.minHeight ?? 0),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        alignment: Alignment.centerLeft,
        child: leading,
      ),
    );
  }
}

/// `CardTrailing`: an action on the title row, centred on it and pushed to the end.
class RaftCardTrailing extends StatelessWidget {
  const RaftCardTrailing(this.trailing, {super.key});

  final Widget trailing;

  @override
  Widget build(BuildContext context) => trailing;
}

/// `CardContent`: `p-4` (`px-3 pb-3` in the option variant).
class RaftCardContent extends StatelessWidget {
  const RaftCardContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = _resolve(context);
    return RaftRecipeBox(
      style: r.slots.content,
      tokens: r.tokens,
      width: double.infinity,
      applyText: false,
      child: child,
    );
  }
}

/// `CardFooter`: `border-t border-line-hairline px-4 py-3`, one nowrap row at `gap-2` of `text-caption
/// text-foreground-hint`.
class RaftCardFooter extends StatelessWidget {
  const RaftCardFooter({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = _resolve(context);
    final slot = r.slots.footer;
    final gap = slot.columnGap ?? 0;
    final color = slot.color?.resolve(r.tokens);
    return RaftRecipeBox(
      style: slot,
      tokens: r.tokens,
      width: double.infinity,
      child: IconTheme.merge(
        data: IconThemeData(size: 14, color: color),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Flexible(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}
