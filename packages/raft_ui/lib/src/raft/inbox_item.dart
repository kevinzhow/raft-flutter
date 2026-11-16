// raft-ui `InboxItem` (0.95.3), compact density: the only one Web v1.24 mounts
// (InboxRow.tsx, ObjectInboxRow.tsx). A list cell: the row is a grid of
// leading tile, text and actions, its fill an 8px-inset rounded cell; one
// trigger covers it (the Tab stop and the semantics label); the actions are
// separate stops that fade in on hover or focus (always shown on touch).
//
// Reads the generated `inbox_item` / `inbox_item_skeleton` recipes. Left out
// on purpose (nothing Flutter mounts needs them): the selection checkbox
// slot, the `context`/`subtitle`/`message`/`metadata` slots, the trailing
// unread pixel (hidden in compact) and the roomy density.
import 'package:flutter/material.dart';
import 'package:raft_theme/recipes/inbox_item.g.dart' as raft;

import '../indicators.dart';
import '../interaction.dart';
import '../recipe_surface.dart';
import '../recipes/inbox_item_skeleton.g.dart';
import '../recipes/recipe_runtime.dart';
import '../design_primitives.dart';
import '../text_scaling.dart';
import '../theme.dart';
import 'button_color_transition.dart';

raft.RaftInboxItemRecipeStyle _resolve(
  BuildContext context, {
  bool hovered = false,
  bool pressed = false,
  bool selected = false,
}) {
  final t = RaftTokens.of(context);
  return raft.RaftInboxItemRecipe.resolve(
    density: raft.RaftInboxItemRecipeDensity.compact,
    reveal: raft.RaftInboxItemRecipeReveal.hover,
    states: t.recipeStates(
      hovered: hovered,
      pressed: pressed,
      responsive: true,
      pointerCoarse: RaftInteraction.of(context).touch,
      extra: [if (selected) 'data-active=true'],
    ),
    tokens: t.recipeTokens,
  );
}

/// One Activity list row. [leading] is the 36x36 tile (an icon tile or an
/// avatar), [leadingBadge] the 14x14 corner mark on it. [title], [body] and
/// [timestamp] take the recipe's text style; [timestamp] only shows while the
/// row is hovered or keyboard-focused (never on touch). [marks] are the small
/// hint-coloured status items after the body. [actions] fade in on hover and
/// focus, and are always shown on touch.
///
/// [semanticLabel] is the one name of the row (title, body and time in words);
/// the trigger carries it and [onOpen]. [onOpen] null or [disabled] makes the
/// row inert.
class RaftInboxItem extends StatefulWidget {
  const RaftInboxItem({
    super.key,
    required this.semanticLabel,
    required this.title,
    this.leading,
    this.leadingBadge,
    this.timestamp,
    this.body,
    this.marks = const [],
    this.actions = const [],
    this.selected = false,
    this.unread = false,
    this.disabled = false,
    this.onOpen,
    this.focusNode,
  });

  final String semanticLabel;
  final Widget title;
  final Widget? leading, leadingBadge, timestamp, body;
  final List<Widget> marks, actions;

  /// Web `data-active`: the row open in the detail pane.
  final bool selected;

  /// Web `data-unread`: the title is bold and foreground.
  final bool unread;
  final bool disabled;
  final VoidCallback? onOpen;
  final FocusNode? focusNode;

  @override
  State<RaftInboxItem> createState() => _RaftInboxItemState();
}

class _RaftInboxItemState extends State<RaftInboxItem> {
  bool _hovered = false, _focusWithin = false;

  bool get _enabled => !widget.disabled && widget.onOpen != null;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final touch = RaftInteraction.of(context).touch;
    final base = _resolve(context, selected: widget.selected);
    final hasLine = widget.body != null || widget.marks.isNotEmpty;
    final hasActions = widget.actions.isNotEmpty;
    final revealed =
        hasActions && (touch || _hovered || _focusWithin || widget.selected);
    final keyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final showTime =
        widget.timestamp != null &&
        !touch &&
        (_hovered || (_focusWithin && keyboard));
    // `--inbox-item-actions-room`: 40 with a mouse while revealed, 44 on touch.
    final room = !hasLine || !hasActions
        ? 0.0
        : touch
        ? 44.0
        : revealed
        ? 40.0
        : 0.0;
    final foreground = base.itemSender.color!.resolve(tokens);
    final muted = base.itemTitle.color!.resolve(tokens);
    final padding = base.item.padding;
    final minHeight = base.item.minHeight ?? 0;

    Widget content(RaftInteractionState state) {
      final style = _resolve(
        context,
        hovered: state.hovered && _enabled && !touch && !widget.selected,
        pressed: state.pressed && _enabled && !widget.selected,
        selected: widget.selected,
      );
      final titleStyle = style.itemTitle
          .text(tokens, base: DefaultTextStyle.of(context).style)
          .copyWith(
            color: widget.unread ? foreground : muted,
            fontWeight: widget.unread ? FontWeight.w700 : null,
          );
      final bodyStyle = style.itemBody.text(
        tokens,
        base: DefaultTextStyle.of(context).style,
      );
      final timeStyle = style.itemTimestamp.text(
        tokens,
        base: DefaultTextStyle.of(context).style,
      );
      final headingHeight = style.itemTitle.lineHeightPx ?? 22;
      final lineHeight = style.itemLine.height ?? 22;
      final cell = style.item.before!;
      final inset = cell.length('left') ?? 8;
      final insetEnd = cell.length('right') ?? 8;
      final radius = cell.borderRadius;
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Stack(
          children: [
            Positioned(
              key: const ValueKey('inbox-item-fill'),
              left: inset,
              right: insetEnd,
              top: 0,
              bottom: 0,
              child: RaftButtonColorTransition(
                style: cell,
                tokens: tokens,
                builder: (context, style) => RaftRecipeBox(
                  style: style,
                  tokens: tokens,
                  applyText: false,
                  applyOpacity: false,
                  applyTransform: false,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (state.focusVisible)
              Positioned(
                key: const ValueKey('inbox-item-focus-ring'),
                left: inset,
                right: insetEnd,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: foreground,
                        width: t.border * 2,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: style.item.columnGap ?? 12,
                children: [
                  if (widget.leading != null)
                    _Leading(
                      style: style,
                      tokens: tokens,
                      badge: widget.leadingBadge,
                      child: widget.leading!,
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: room),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftScaled.lineBox(
                            context,
                            height: headingHeight,
                            child: Row(
                              spacing: style.itemHeading.columnGap ?? 8,
                              children: [
                                Expanded(
                                  child: DefaultTextStyle(
                                    style: titleStyle,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    child: widget.title,
                                  ),
                                ),
                                if (showTime)
                                  DefaultTextStyle(
                                    key: const ValueKey('inbox-item-timestamp'),
                                    style: timeStyle,
                                    maxLines: 1,
                                    softWrap: false,
                                    child: widget.timestamp!,
                                  ),
                              ],
                            ),
                          ),
                          if (hasLine)
                            RaftScaled.lineBox(
                              context,
                              height: lineHeight,
                              child: Row(
                                spacing: style.itemLine.columnGap ?? 8,
                                children: [
                                  Expanded(
                                    child: DefaultTextStyle(
                                      style: bodyStyle,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      child: widget.body ?? const SizedBox(),
                                    ),
                                  ),
                                  if (widget.marks.isNotEmpty)
                                    DefaultTextStyle(
                                      style: timeStyle.copyWith(
                                        fontFamily: bodyStyle.fontFamily,
                                      ),
                                      child: IconTheme.merge(
                                        data: IconThemeData(
                                          color: style.itemMarks.color?.resolve(
                                            tokens,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          spacing:
                                              style.itemMarks.columnGap ?? 6,
                                          children: widget.marks,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final actionStyle = base.itemActions;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : actionStyle.transitionDuration ?? Duration.zero;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (_focusWithin != focused) setState(() => _focusWithin = focused);
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          children: [
            RaftInteractive(
              key: const ValueKey('inbox-item-open'),
              onPressed: _enabled ? widget.onOpen : null,
              focusNode: widget.focusNode,
              semanticLabel: widget.semanticLabel,
              selected: widget.selected,
              expandTouchTarget: false,
              builder: (context, state) =>
                  ExcludeSemantics(child: content(state)),
            ),
            if (hasActions)
              Positioned.directional(
                textDirection: Directionality.of(context),
                end: padding.right,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: revealed ? 1 : 0,
                    duration: duration,
                    child: IgnorePointer(
                      key: const ValueKey('inbox-item-actions'),
                      ignoring: !revealed,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: actionStyle.columnGap ?? 2,
                        children: widget.actions,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.style,
    required this.tokens,
    required this.child,
    this.badge,
  });
  final raft.RaftInboxItemRecipeStyle style;
  final RaftTokenResolver tokens;
  final Widget child;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final slot = style.itemLeading;
    final badgeSlot = style.itemLeadingBadge;
    final ring = badgeSlot.length('outline-width') ?? 2;
    final badgeCorner =
        (badgeSlot.length('border-top-left-radius') ?? 3) + ring;
    return SizedBox(
      key: const ValueKey('inbox-item-leading'),
      width: slot.width ?? 36,
      height: slot.height ?? 36,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Center(child: child),
          if (badge != null)
            Positioned(
              key: const ValueKey('inbox-item-leading-badge'),
              right: (badgeSlot.length('right') ?? -2) - ring,
              bottom: (badgeSlot.length('bottom') ?? -2) - ring,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: badgeSlot.outlineColor?.resolve(tokens),
                  borderRadius: BorderRadius.circular(badgeCorner),
                ),
                child: Padding(
                  padding: EdgeInsets.all(ring),
                  child: RaftRecipeBox(
                    style: badgeSlot,
                    tokens: tokens,
                    width: badgeSlot.width,
                    height: badgeSlot.height,
                    alignment: Alignment.center,
                    applyText: false,
                    child: IconTheme.merge(
                      data: const IconThemeData(size: 10),
                      child: badge!,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `InboxItemListGroup` (+ `InboxItemListHeading`): a heading over the rows of
/// a group with the list's 2px gap; consecutive groups are 6px apart.
class RaftInboxItemListGroup extends StatelessWidget {
  const RaftInboxItemListGroup({
    super.key,
    required this.heading,
    required this.children,
    this.first = false,
  });
  final String heading;
  final List<Widget> children;

  /// `first:mt-0`: the first group of a list has no top margin.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final style = _resolve(context);
    final tokens = RaftTokens.of(context).recipeTokens;
    final group = style.itemListGroup;
    final head = style.itemListHeading;
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : group.margin.top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: group.rowGap ?? 2,
        children: [
          Padding(
            key: const ValueKey('inbox-item-list-heading'),
            padding:
                head.padding.copyWith(bottom: head.padding.bottom) +
                EdgeInsets.only(bottom: head.margin.bottom),
            child: Text(
              heading,
              style: head.text(
                tokens,
                base: DefaultTextStyle.of(context).style,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// `InboxItemSkeleton` (compact, leading, line): a disabled row of bars with
/// the loaded row's padding and line heights, so nothing moves when the
/// content arrives. [index] picks the bar widths (`nth-3n`).
class RaftInboxItemSkeleton extends StatelessWidget {
  const RaftInboxItemSkeleton({super.key, this.index = 0});
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final style = _resolve(context);
    final skeleton = RaftInboxItemSkeletonRecipe.resolve(
      states: t.recipeStates(
        responsive: true,
        pointerCoarse: RaftInteraction.of(context).touch,
      ),
      tokens: tokens,
    );
    final (title, body) = switch (index % 3) {
      1 => (.45, .70),
      2 => (.55, .75),
      _ => (.60, .80),
    };
    final base = DefaultTextStyle.of(context).style;
    final headingHeight = style.itemTitle.lineHeightPx ?? 22;
    final lineHeight = style.itemLine.height ?? 22;
    final bar = skeleton.bar.length('height');
    final defaultLineFont = t.typeSlot('callout').fontSize;
    Widget line(double fraction, TextStyle text) => LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: constraints.maxWidth * fraction,
          height: RaftScaled.extent(
            context,
            bar ?? 10.5,
            fontSize: text.fontSize ?? defaultLineFont,
          ),
          child: const RaftSkeleton(
            variant: RaftSkeletonVariant.line,
            fromRecipe: true,
          ),
        ),
      ),
    );
    final minHeight = style.item.minHeight ?? 0;
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: style.item.padding,
          child: Row(
            spacing: style.item.columnGap ?? 12,
            children: [
              SizedBox(
                width: style.itemLeading.width ?? 36,
                height: style.itemLeading.height ?? 36,
                child: Center(
                  child: SizedBox(
                    width: skeleton.leading.width ?? 35,
                    height: skeleton.leading.height ?? 35,
                    child: const RaftSkeleton(
                      variant: RaftSkeletonVariant.block,
                      fromRecipe: true,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: RaftScaled.extent(context, headingHeight),
                      child: line(title, base),
                    ),
                    SizedBox(
                      height: RaftScaled.extent(context, lineHeight),
                      child: line(body, base),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
