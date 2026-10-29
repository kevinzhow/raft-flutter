// raft-ui `Card` (`card.recipe.ts`): the one card shell. A flat `layer-card`
// box with a `line-hairline` outline and the container radius. [RaftCard] is
// the plain shell (a panel of content, a dialog surface); [RaftCard.item] is the
// product's SurfaceListItem (the same card as a row that can be selected or
// hovered); `variant: option` is the selectable choice inside a form.

import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'dialog_card.dart' show raftRecipeThemeOf;
import 'design_primitives.dart' show RaftInteractive;
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/card.g.dart';
import 'recipes/recipe_router.dart' show resolveRecipeClasses;
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

export 'recipes/card.g.dart' show RaftCardRecipeVariant;

class RaftCard extends StatefulWidget {
  /// The card root with [padding] (default none).
  const RaftCard({
    super.key,
    required this.child,
    this.variant = RaftCardRecipeVariant.default_,
    this.padding,
    this.maxWidth,
    this.background,
    this.dialog = false,
    this.clip = false,
    this.transparentBorder = false,
    this.onTap,
    this.semanticLabel,
  }) : _item = false,
       selected = false,
       selectedBackground = null,
       interactive = null;

  /// Web `SurfaceListItem`: the card as a row with `px-4 py-3`, selectable
  /// ([selected]) and hovered when [interactive] (default: when [onTap]).
  const RaftCard.item({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.interactive,
    this.padding,
    this.background,
    this.selectedBackground,
  }) : _item = true,
       variant = RaftCardRecipeVariant.default_,
       maxWidth = null,
       dialog = false,
       clip = false,
       transparentBorder = false,
       semanticLabel = null;

  final Widget child;
  final RaftCardRecipeVariant variant;

  /// Content padding; null is none for the plain card, `px-4 py-3` for
  /// [RaftCard.item] and 12 for `variant: option`.
  final EdgeInsets? padding;
  final double? maxWidth;

  /// The card is a dialog's surface. Web draws every dialog on raft-ui's
  /// `DialogSurface` (`bg-layer-popover`); the legacy packs keep their frozen
  /// Card fill (`layer-panel`) through the dialog component role.
  /// An explicit [background] still wins.
  final bool dialog;

  /// Call-site `bg-*` override of the Card fill (on an item: of the unselected,
  /// unhovered surface, e.g. MachineAgentList `bg-layer-canvas-muted
  /// theme-brutal:bg-gray-100`).
  final Color? background;

  /// Item only: a call-site `bg-*` that also wins over the selected fill (the
  /// MachineAgentList bulk bar).
  final Color? selectedBackground;

  /// Call-site `overflow-hidden`: the content is clipped to the rounded box.
  final bool clip;

  /// Call-site `border-transparent`: the border keeps its width (and takes
  /// its layout space) but paints nothing.
  final bool transparentBorder;

  /// Item only: marks the row selected.
  final bool selected;

  /// Item only: hover affordance; defaults to `onTap != null`.
  final bool? interactive;

  /// Item and option: the tap.
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool _item;

  @override
  State<RaftCard> createState() => _RaftCardState();
}

class _RaftCardState extends State<RaftCard> {
  bool hovered = false;

  EdgeInsets get _padding =>
      widget.padding ??
      (widget._item
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
          : widget.variant == RaftCardRecipeVariant.option
          ? const EdgeInsets.all(12)
          : EdgeInsets.zero);

  @override
  Widget build(BuildContext context) => widget._item
      ? _buildItem(context)
      : widget.variant == RaftCardRecipeVariant.option
      ? _buildOption(context)
      : _buildPlain(context);

  Widget _buildPlain(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final root = RaftCardRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: tokens,
    ).root;
    final fill =
        widget.background ?? (widget.dialog ? t.colors['layer-dialog'] : null);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth ?? double.infinity),
      child: RaftRecipeBox(
        style: root.withCssUsedBorderWidths(),
        tokens: tokens,
        width: double.infinity,
        padding: _padding,
        applyText: false,
        clip: widget.clip,
        decorationOverride: fill == null && !widget.transparentBorder
            ? null
            : (d) {
                final border = d.border;
                return d.copyWith(
                  color: fill ?? d.color,
                  border: widget.transparentBorder && border is Border
                      ? Border(
                          top: border.top.copyWith(color: Colors.transparent),
                          right: border.right.copyWith(
                            color: Colors.transparent,
                          ),
                          bottom: border.bottom.copyWith(
                            color: Colors.transparent,
                          ),
                          left: border.left.copyWith(color: Colors.transparent),
                        )
                      : border,
                );
              },
        child: DefaultTextStyle.merge(
          style: root.textStyle(tokens),
          child: widget.child,
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final interactive = widget.interactive ?? widget.onTap != null;
    final hover = interactive && hovered;
    if (t.option('surfaceItem.style', or: 'recipe') == 'raft') {
      final ui = t.ui;
      final base = widget.selected
          ? (widget.selectedBackground ?? ui['info-soft'])
          : (widget.background ?? ui.layerCard);
      // `hover:press-overlay`: the pressed wash laid over the resting fill.
      final fill = hover && !widget.selected
          ? Color.alphaBlend(ui.fillPressed, base)
          : base;
      final root = RaftCardRecipe.resolve(
        theme: t.recipeTheme,
        states: t.recipeStates(),
        tokens: rt,
      ).root;
      Widget raft = RaftRecipeBox(
        style: root.withCssUsedBorderWidths(),
        tokens: rt,
        width: double.infinity,
        padding: _padding,
        applyText: false,
        decorationOverride: (d) => d.copyWith(color: fill),
        child: widget.child,
      );
      if (interactive) {
        raft = RaftHoverRegion(
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(onTap: widget.onTap, child: raft),
        );
      }
      return Semantics(
        selected: widget.selected,
        button: widget.onTap != null,
        child: raft,
      );
    }
    var card = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    {
      // Raft set (a user pack that opts out of `surfaceItem.style: raft`): the
      // Card classes with the `raft` style's selected fill and hover wash.
      // Frozen looks: their Card classes plus the authored 0.5.52 list.
      final classes = t.recipeSet == RaftRecipeSet.raft
          ? [
              ...card.classes.where(
                (name) =>
                    !widget.selected ||
                    (name != 'bg-layer-card' && name != 'border-line-hairline'),
              ),
              if (widget.selected) ...['bg-info-soft', 'border-line-hairline'],
              if (interactive && !widget.selected) 'hover:press-overlay',
            ]
          : [
              ...card.classes.where(
                (name) =>
                    name != 'border-[0.5px]' &&
                    name != 'border-line-muted' &&
                    name != 'bg-layer-panel' &&
                    (!(widget.selected || hover) || name != 'shadow-raft-xs'),
              ),
              'border',
              widget.selected ? 'border-info' : 'border-line-muted',
              widget.selected ? 'bg-info-muted' : 'bg-layer-card',
              if (widget.selected) 'shadow-raft-sm',
              if (interactive && !widget.selected) ...[
                'hover:border-line-strong',
                'hover:shadow-raft-sm',
              ],
            ];
      card = resolveRecipeClasses(classes, t.recipeStates(hovered: hover), rt);
    }

    Widget item = RaftRecipeBox(
      style: card,
      tokens: rt,
      width: double.infinity,
      padding: _padding,
      clip: true,
      decorationOverride: widget.selected && widget.selectedBackground != null
          ? (d) => d.copyWith(color: widget.selectedBackground)
          : widget.background != null && !widget.selected
          ? (d) => d.copyWith(
              color: hover ? t.colors['layer-panel'] : widget.background,
            )
          : null,
      child: widget.child,
    );
    if (interactive) {
      item = RaftHoverRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(onTap: widget.onTap, child: item),
      );
    }
    return Semantics(
      selected: widget.selected,
      button: widget.onTap != null,
      child: item,
    );
  }

  /// Web ServerSelector option (`variant: option`): raft-ui `Card variant="option"` rendered as a
  /// `<button class="w-full text-left">`. The raft-ui option recipe itself has
  /// no hover, active or focus styles, so a touch client would show no response
  /// at all. This is the design-system interactive form of that card: the
  /// recipe box plus [RaftInteractive] states, with the same treatment the
  /// other interactive cards use (the [RaftCard.item] hover) and a pressed
  /// fill. The 48dp hit area comes from [RaftInteractive] on touch density.
  ///
  /// - hover: elegant `border-line-strong shadow-raft-sm`; the idle brutal card
  ///   already carries `shadow-brutal-sm`.
  /// - pressed: filled with the muted canvas (elegant) or the brutal cream;
  ///   brutal drops its shadow, like a pressed brutal button.
  /// - focus-visible: a 2px ring.
  Widget _buildOption(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    return RaftInteractive(
      onPressed: widget.onTap,
      semanticLabel: widget.semanticLabel,
      builder: (context, state) {
        final active = state.enabled && (state.hovered || state.pressed);
        final root = RaftCardRecipe.resolve(
          theme: t.recipeTheme,
          variant: RaftCardRecipeVariant.option,
          states: t.recipeStates(
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
            disabled: !state.enabled,
          ),
          tokens: rt,
        ).root;
        return RaftRecipeBox(
          style: root,
          tokens: rt,
          width: double.infinity,
          padding: _padding,
          decorationOverride: (base) {
            final pressed = state.enabled && state.pressed;
            return base.copyWith(
              color: pressed ? (t.colors['layer-canvas-muted']) : base.color,
              border: (active)
                  ? Border.all(color: t.colors['line-strong']!)
                  : base.border,
              boxShadow: [
                ...[...?base.boxShadow, if (active) ...t.shadows],
                if (state.focusVisible)
                  BoxShadow(
                    color: (t.ink).withValues(alpha: .8),
                    spreadRadius: 2,
                  ),
              ],
            );
          },
          child: widget.child,
        );
      },
    );
  }
}
