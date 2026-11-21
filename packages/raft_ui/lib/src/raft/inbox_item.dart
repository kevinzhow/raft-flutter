// raft-ui `InboxItem` (0.95.3), compact density: the only one Web v1.24 mounts
// (InboxRow.tsx, ObjectInboxRow.tsx). A list cell: the row is a grid of
// leading tile, text and actions, its fill an 8px-inset rounded cell; one
// trigger covers it (the Tab stop and the semantics label); the actions are
// separate stops that fade in on hover or focus (always shown on touch).
//
// Reads the generated `inbox_item` / `inbox_item_skeleton` recipes. Left out
// on purpose (nothing Flutter mounts needs them): the selection checkbox
// slot, the `context`/`message` slots, the trailing
// unread pixel (hidden in compact) and the roomy density.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:raft_theme/recipes/inbox_item.g.dart' as raft;

import '../indicators.dart';
import '../interaction.dart';
import '../mounted_task_chip.dart';
import '../panel_layout.dart' show raftCssBaseline;
import '../task_status_badge.dart';
import '../tooltip.dart' show RaftTooltip;
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
  bool popupOpen = false,
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
      extra: [
        if (selected) 'data-active=true',
        if (popupOpen) 'data-popup-open',
      ],
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
    this.subtitle,
    this.metadata,
    this.marks = const [],
    this.actions = const [],
    this.selected = false,
    this.popupOpen = false,
    this.unread = false,
    this.disabled = false,
    this.onOpen,
    this.focusNode,
    this.timestampAtRest = false,
    this.timestampTrailing = false,
    this.timestampTooltip,
    this.located = false,
    this.onLongPress,
    this.onSecondaryTap,
    this.semanticActions = const {},
  });

  final String semanticLabel;
  final Widget title;
  final Widget? leading, leadingBadge, timestamp, body, metadata;

  /// The recipe's caption below the heading, separate from the activity body.
  final Widget? subtitle;
  final List<Widget> marks, actions;

  /// Web `data-active`: the row open in the detail pane.
  final bool selected;

  /// The row owns the current popup. Keep its cell fill and actions visible.
  final bool popupOpen;

  /// Web `data-unread`: the title is bold and foreground.
  final bool unread;
  final bool disabled;
  final VoidCallback? onOpen;
  final FocusNode? focusNode;

  /// `ActivityRowTime`: a row under a day old shows its short time ("now",
  /// "3m", "2h") at rest, on touch too; only an older row's clock is revealed
  /// by hover or keyboard focus (never on touch). `true` is the former.
  final bool timestampAtRest;

  /// Draw the timestamp in InboxItemTrailing, centered beside the content.
  final bool timestampTrailing;

  /// The time in words ("Today at 5:20 PM"), a [RaftTooltip] on the shown
  /// timestamp. Mouse only.
  final String? timestampTooltip;

  /// Web `data-located` (`useLocated`): the row a jump landed on is washed
  /// `info-soft`, held 1.2 s and faded out by 2 s. The caller clears it after
  /// [raftLocatedDuration]; the fade is the component's.
  final bool located;

  /// Press-and-hold (touch) and right click (mouse), with the global position
  /// the row menu opens at.
  final ValueChanged<Offset>? onLongPress, onSecondaryTap;

  /// Screen-reader-only actions on the row's trigger, by label (Web's phone
  /// Done: a visually hidden button for assistive technology). Each is a
  /// `CustomSemanticsAction`; nothing is drawn.
  final Map<String, VoidCallback> semanticActions;

  @override
  State<RaftInboxItem> createState() => _RaftInboxItemState();
}

/// raft-ui `LOCATED_MS`.
const Duration raftLocatedDuration = Duration(milliseconds: 2000);

/// The open triggers of mounted rows: Up and Down move between these.
final Expando<bool> _rowTriggers = Expando<bool>('RaftInboxItem trigger');

class _InboxRowWidth extends InheritedWidget {
  const _InboxRowWidth({required this.width, required super.child});
  final double width;
  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InboxRowWidth>()?.width;
  @override
  bool updateShouldNotify(_InboxRowWidth old) => old.width != width;
}

class _RaftInboxItemState extends State<RaftInboxItem>
    with SingleTickerProviderStateMixin {
  bool _hovered = false, _focusWithin = false;
  final FocusNode _ownedTrigger = FocusNode(debugLabel: 'inbox-item-open');
  Offset _lastPointer = Offset.zero;
  late final AnimationController _located = AnimationController(
    vsync: this,
    duration: raftLocatedDuration,
  );

  FocusNode get _trigger => widget.focusNode ?? _ownedTrigger;

  @override
  void initState() {
    super.initState();
    _rowTriggers[_trigger] = true;
    if (widget.located) _located.forward();
  }

  @override
  void didUpdateWidget(RaftInboxItem old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      _rowTriggers[old.focusNode ?? _ownedTrigger] = null;
      _rowTriggers[_trigger] = true;
    }
    if (widget.located && !old.located) {
      _located.forward(from: 0);
    } else if (!widget.located && old.located) {
      _located.value = 1;
    }
  }

  @override
  void dispose() {
    _rowTriggers[_trigger] = null;
    _located.dispose();
    _ownedTrigger.dispose();
    super.dispose();
  }

  /// Up and Down on a row's trigger focus the previous or next row's, across
  /// day groups (Web `moveRowFocus`): plain keys only, never the actions.
  KeyEventResult _moveRow(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final rows = [
      for (final n in FocusScope.of(context).traversalDescendants)
        if (_rowTriggers[n] == true) n,
    ];
    final next =
        rows.indexOf(_trigger) + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
    if (next >= 0 && next < rows.length) {
      final target = rows[next];
      target.requestFocus();
      final targetContext = target.context;
      if (targetContext != null) {
        Scrollable.ensureVisible(targetContext);
      }
    }
    return KeyEventResult.handled;
  }

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
        hasActions &&
        (touch ||
            _hovered ||
            _focusWithin ||
            widget.selected ||
            widget.popupOpen);
    final keyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final showTime =
        widget.timestamp != null &&
        (widget.timestampAtRest ||
            (!touch && (_hovered || (_focusWithin && keyboard))));
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
        popupOpen: widget.popupOpen && _enabled && !widget.selected,
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
      final timestamp = showTime
          ? RaftTooltip(
              message: widget.timestampTooltip ?? '',
              enabled: !touch && widget.timestampTooltip != null,
              child: DefaultTextStyle(
                key: const ValueKey('inbox-item-timestamp'),
                style: timeStyle,
                maxLines: 1,
                softWrap: false,
                child: widget.timestamp!,
              ),
            )
          : null;
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
            if (widget.located || _located.isAnimating)
              Positioned(
                key: const ValueKey('inbox-item-located'),
                left: inset,
                right: insetEnd,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _located,
                    builder: (context, _) {
                      // Held to 1.2 s, then faded out by 2 s.
                      final fade = MediaQuery.disableAnimationsOf(context)
                          ? (_located.value < .6 ? 1.0 : 0.0)
                          : (1 - (_located.value - .6) / .4).clamp(0.0, 1.0);
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          color: t.colors['info-soft']!.withValues(
                            alpha: t.colors['info-soft']!.a * fade,
                          ),
                        ),
                      );
                    },
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
                                if (!widget.timestampTrailing) ?timestamp,
                              ],
                            ),
                          ),
                          if (widget.subtitle case final subtitle?)
                            Padding(
                              padding: style.itemSubtitle.margin,
                              child: RaftRecipeBox(
                                style: style.itemSubtitle,
                                tokens: tokens,
                                child: subtitle,
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
                          if (widget.metadata case final metadata?)
                            Padding(
                              padding: style.itemMetadata.margin,
                              child: RaftRecipeBox(
                                style: style.itemMetadata,
                                tokens: tokens,
                                growWithText: true,
                                child: metadata,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.timestampTrailing) ?timestamp,
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
    Widget trigger = RaftInteractive(
      key: const ValueKey('inbox-item-open'),
      onPressed: _enabled ? widget.onOpen : null,
      focusNode: _trigger,
      semanticLabel: widget.semanticLabel,
      selected: widget.selected,
      expandTouchTarget: false,
      semanticContainer: widget.semanticActions.isEmpty ? null : false,
      onLongPress: widget.onLongPress == null
          ? null
          : () => widget.onLongPress!(_lastPointer),
      onSecondaryTapDown: widget.onSecondaryTap == null
          ? null
          : (details) => widget.onSecondaryTap!(details.globalPosition),
      builder: (context, state) => ExcludeSemantics(child: content(state)),
    );
    if (widget.semanticActions.isNotEmpty) {
      trigger = Semantics(
        container: true,
        customSemanticsActions: {
          for (final entry in widget.semanticActions.entries)
            CustomSemanticsAction(label: entry.key): entry.value,
        },
        child: trigger,
      );
    }
    trigger = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _lastPointer = event.position,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _moveRow,
        child: trigger,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => _InboxRowWidth(
        width: constraints.maxWidth,
        child: Focus(
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
                trigger,
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
                        // Web keeps the resting actions in the accessibility
                        // tree (opacity 0, still focusable).
                        alwaysIncludeSemantics: true,
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
  const RaftInboxItemListGroup.loading({super.key, required this.children})
    : heading = null,
      first = true;

  final String? heading;
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
            child: heading == null
                ? SizedBox(
                    height: RaftScaled.extent(
                      context,
                      head.lineHeightPx ?? 18,
                      fontSize:
                          head.fontSize ??
                          RaftTokens.of(context).typeSlot('footnote').fontSize,
                    ),
                    child: _inboxSkeletonTextBar(
                      style: _skeletonTextStyle(context, head, tokens),
                      width: 40,
                    ),
                  )
                : Text(
                    heading!,
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

TextStyle _skeletonTextStyle(
  BuildContext context,
  RaftSlotStyle slot,
  RaftTokenResolver tokens,
) {
  final style = slot.text(tokens, base: DefaultTextStyle.of(context).style);
  final fontSize =
      style.fontSize ?? RaftTokens.of(context).typeSlot('callout').fontSize;
  return style.copyWith(
    fontSize: MediaQuery.textScalerOf(context).scale(fontSize),
  );
}

Widget _inboxSkeletonTextBar({
  required TextStyle style,
  required double width,
  double? baseline,
  bool mono = false,
}) {
  final fontSize = style.fontSize!;
  // CSS vertical-align: middle centers the inline box half an x-height above
  // the line baseline. These are the OS/2 sxHeight / unitsPerEm values of the
  // bundled Space Grotesk and Space Mono faces used by the recipe's slots.
  final xHeight = fontSize * (mono ? .496 : .486);
  final height = fontSize * .75;
  final top = (baseline ?? raftCssBaseline(style)) - (xHeight + height) / 2;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: Padding(
      padding: EdgeInsets.only(top: top < 0 ? 0 : top),
      child: RaftSkeleton(
        variant: RaftSkeletonVariant.line,
        width: width,
        height: height,
        fromRecipe: true,
        snapRecipeBounds: true,
      ),
    ),
  );
}

/// `InboxItemSkeleton` (compact, leading, line): a disabled row of bars with
/// the loaded row's padding and line heights, so nothing moves when the
/// content arrives. [index] is the row's zero-based position in its group.
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
        extra: [
          if (index % 3 == 1) 'nth-child(3n+2)',
          if (index % 3 == 2) 'nth-child(3n)',
        ],
      ),
      tokens: tokens,
    );
    double fraction(String slot) {
      final width = skeleton.row['--inbox-item-skeleton-$slot'] as CssNum;
      return width.value / 100;
    }

    final headingHeight = style.itemTitle.lineHeightPx ?? 22;
    final lineHeight = style.itemLine.height ?? 22;
    final titleFont =
        style.itemTitle.fontSize ?? t.typeSlot('subhead').fontSize;
    final bodyFont = style.itemBody.fontSize ?? t.typeSlot('callout').fontSize;
    final titleText = _skeletonTextStyle(context, style.itemTitle, tokens);
    final timeText = _skeletonTextStyle(context, style.itemTimestamp, tokens);
    final bodyText = _skeletonTextStyle(context, style.itemBody, tokens);
    final baseline = raftCssBaseline(titleText);
    Widget line(double widthFraction, TextStyle text) => LayoutBuilder(
      builder: (context, constraints) => _inboxSkeletonTextBar(
        style: text,
        width: constraints.maxWidth * widthFraction,
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
                      snapRecipeBounds: true,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: RaftScaled.extent(
                        context,
                        headingHeight,
                        fontSize: titleFont,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: style.itemHeading.columnGap ?? 8,
                        children: [
                          Expanded(child: line(fraction('title'), titleText)),
                          _inboxSkeletonTextBar(
                            style: timeText,
                            width: skeleton.timestampBar.width ?? 36,
                            baseline: baseline,
                            mono: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: RaftScaled.extent(
                        context,
                        lineHeight,
                        fontSize: bodyFont,
                      ),
                      child: line(fraction('body'), bodyText),
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

/// `InboxItemStatus`: a task conversation's state, last in the marks before the
/// count. The word is a [RaftTaskStatusBadge]; in a row narrower than 320 it is
/// the status icon alone (`itemStatusPixel`) with the word in a tooltip. The
/// word is also the row's accessible name, which the caller composes into
/// `RaftInboxItem.semanticLabel` (the row's content is excluded from semantics).
class RaftInboxItemStatus extends StatelessWidget {
  const RaftInboxItemStatus({
    super.key,
    required this.status,
    required this.label,
  });
  final RaftMessageTaskStatus status;
  final String label;

  /// `@max-[320px]/inbox-item-row`.
  static const double pixelBreakpoint = 320;

  @override
  Widget build(BuildContext context) {
    final width = _InboxRowWidth.of(context);
    if (width != null && width <= pixelBreakpoint) {
      final recipe = RaftMessageTaskChipRecipe(RaftTokens.of(context), status);
      return RaftTooltip(
        message: label,
        child: RaftMessageTaskStatusIcon(
          key: const ValueKey('inbox-item-status-pixel'),
          status: status,
          color: recipe.iconForeground,
        ),
      );
    }
    return RaftTaskStatusBadge(
      key: const ValueKey('inbox-item-status-word'),
      status: status,
      label: label,
    );
  }
}
