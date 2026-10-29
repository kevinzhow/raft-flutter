import 'raft/list_row_action.dart';
import 'hover_region.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';

import '../recipes.dart' hide RaftPanelHeaderRecipe;
import 'design_primitives.dart';
import 'recipe_surface.dart';
import 'theme.dart';
import 'raft/ui_tokens.dart';
import 'tokens/tokens.dart';

/// VirtualizedTaskStack's tanstack measurement rounds each observed row to
/// whole CSS pixels. Keep the card's fractional box, but use that same row
/// extent when placing the following cards/sections.
class SourceTaskRowExtent extends SingleChildRenderObjectWidget {
  const SourceTaskRowExtent({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SourceTaskRowExtent();
}

class _SourceTaskRowExtent extends RenderProxyBox {
  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(
      Size(child!.size.width, child!.size.height.roundToDouble()),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final measured = child!.getDryLayout(constraints.loosen());
    return constraints.constrain(
      Size(measured.width, measured.height.roundToDouble()),
    );
  }
}

/// Web v1.21.23 flat inbox/saved rows and a57b9dab resource cards.
class RaftConversationCardRecipe {
  const RaftConversationCardRecipe(this.tokens, {this.saved = false});
  final RaftTokens tokens;
  final bool saved;
  bool get flat => tokens.option('resource.rows', or: 'cards') == 'flat';
  bool get inkCard =>
      !flat && tokens.option('control.edge', or: 'ring') == 'inkBorder';

  // flat: Web v1.21.23 ThreadsInbox.tsx:103-108 / SavedPanel.tsx:269,
  // measured DOM. cards: a57b9dab resource_view.dart / resource_cards.dart.
  EdgeInsets get listInset =>
      flat ? const EdgeInsets.fromLTRB(0, 4, 0, 16) : const EdgeInsets.all(16);
  double get listGap => flat ? 0 : gap;
  double get metadataGap => flat ? 8 : 4;
  EdgeInsets get contentInset =>
      flat ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12) : inset;
  static const inset = EdgeInsets.all(12);
  static const gap = 8.0;
  // ThreadsInbox timestamp and overlaid action both use transition-opacity.
  static const actionFade = Duration(milliseconds: 150);
  Color get background => flat
      ? tokens.canvas
      : saved || inkCard
      ? tokens.panel
      : tokens.card;
  Color get hoverBackground =>
      flat ? tokens.ui.fillPressed : tokens.colors['fill-muted']!;

  /// Persistent selected row (the row whose preview is open in the detail
  /// pane). Deliberately quiet: the reader's eye belongs on the detail pane,
  /// so the list only needs to answer "which one is open" at a glance. A very
  /// light tint of the accent plus a leading accent bar; no border, shadow or
  /// text-colour change. The accent is `info` (elegant) / `brutal-cyan` tint
  /// with a black bar (brutal).
  Color get selectedTint =>
      tokens.colors['info']!.withValues(alpha: tokens.dark ? .06 : .05);

  /// Fill of a selected row over [base] (the normal or hover fill).
  Color selectedFill(Color base) =>
      flat ? tokens.ui['info-soft'] : Color.alphaBlend(selectedTint, base);

  /// Leading accent bar. Brutal 4px black, elegant 3px `info`.
  Color get selectedEdge =>
      inkCard ? tokens.colors['color-black']! : tokens.colors['info']!;
  double get selectedEdgeWidth => flat
      ? 0
      : inkCard
      ? 4
      : 3;
  BorderSide get border => flat
      ? BorderSide.none
      : BorderSide(
          // a57b9dab resource_cards.dart:71-86 (cards structure only).
          color: saved && inkCard
              ? tokens.colors['color-black']!
              : tokens.dark
              ? Colors.transparent
              : inkCard
              ? tokens.colors['color-black']!.withValues(alpha: .3)
              : tokens.colors['line-muted']!,
          width: saved && !inkCard ? .5 : tokens.border,
        );
  BorderRadius get radius => flat
      ? BorderRadius.zero
      : BorderRadius.circular(
          tokens.size(
            saved ? 'radius.container' : 'radius.control',
            fallback: saved ? 8 : 6,
          ),
        );
  TextStyle get body => flat
      ? tokens.scale(RaftTypeScale.callout, color: tokens.ink)
      : RaftTypography.body(
          tokens,
          size: saved ? 14 : 12,
          line: saved ? 20 : 16,
          color: saved ? tokens.ink : tokens.strong,
        ).copyWith(fontFamily: saved ? tokens.bodyFont : tokens.headingFont);
  TextStyle get metadata => flat
      ? tokens.scale(RaftTypeScale.caption, color: tokens.ui.foregroundHint)
      : RaftTypography.body(
          tokens,
          size: 12,
          line: 16,
          color: tokens.muted,
        ).copyWith(
          fontFamily: saved ? tokens.bodyFont : tokens.headingFont,
          fontWeight: FontWeight.w700,
        );
  TextStyle titleStyle(bool unread) => flat
      ? tokens.scale(
          RaftTypeScale.subhead,
          color: titleColor(unread),
          weight: unread ? FontWeight.w700 : FontWeight.w600,
        )
      : body.copyWith(
          fontSize: 14,
          height: 20 / 14,
          color: titleColor(unread),
          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
        );
  TextStyle get timestamp => flat
      ? tokens
            .scale(
              RaftTypeScale.monoMeta,
              mono: true,
              color: tokens.ui.foregroundHint,
            )
            .copyWith(height: (saved ? 16 : 20) / 12)
      : RaftTypography.mono(
          tokens,
          size: 12,
          line: saved ? 16 : 20,
          color: saved ? tokens.muted : tokens.colors['foreground-placeholder'],
        );
  Color get titleIconColor => flat
      ? tokens.ui.foregroundHint
      : tokens.colors['foreground-placeholder']!;
  Color titleColor(bool unread) => unread ? tokens.strong : tokens.muted;

  Color get senderColor => tokens.muted;
}

/// Explicit semantic paint keeps Ink surfaces from borrowing a distant Material
/// ancestor. The surface owns hover/focus; nested actions do not open the card.
class RaftConversationCard extends StatefulWidget {
  const RaftConversationCard({
    super.key,
    required this.child,
    required this.onOpen,
    this.saved = false,
    this.selected = false,
    this.topRule = false,
    this.onContextMenu,
    this.popupOpen = false,
    this.onActivate,
    this.onPointerActivate,
    this.doubleClickInterval = kDoubleTapTimeout,
    this.semanticLabel,
    this.actions,
  });
  final Widget child;
  final VoidCallback onOpen;

  /// Optional DOM-style activation detail. Pointer clicks report 1, 2, ...;
  /// keyboard/semantic activation reports 1. The consumer owns any delay and
  /// navigation policy. The first click is delivered immediately.
  final ValueChanged<int>? onActivate;

  /// The optional override for primary pointer activation.
  ///
  /// Pointer taps use this callback instead of [onActivate]. Keyboard and
  /// semantic activation still use [onActivate], or [onOpen] when absent.
  final ValueChanged<int>? onPointerActivate;

  /// Host platform recognition window; it never delays the first activation.
  final Duration doubleClickInterval;
  final bool saved;

  /// Right click / long press, with the pointer position (global) the Web
  /// `onContextMenu` / base-ui ContextMenu opens its popup at.
  final ValueChanged<Offset>? onContextMenu;

  /// The row's context menu is open: Saved's `data-popup-open:bg-fill-muted`.
  final bool popupOpen;

  /// Persistent selected state: the row is the one currently open in the
  /// master-detail preview. Stays painted while hovered, focused or unread;
  /// ignored for [saved] cards.
  final bool selected;

  /// Inset hairline before consecutive flat rows (no rule before the first).
  final bool topRule;
  final String? semanticLabel;
  final Widget? actions;

  static bool actionsVisibleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ConversationActionScope>()
          ?.visible ??
      false;
  @override
  State<RaftConversationCard> createState() => _RaftConversationCardState();
}

class _RaftConversationCardState extends State<RaftConversationCard> {
  bool hovered = false, focused = false;
  final focusNode = FocusNode(debugLabel: 'conversation-card');
  Offset? lastPointer;
  Duration? pendingTapTime, lastTapTime;
  Offset? pendingTapPosition, lastTapPosition;
  int clickCount = 0;

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void openContextMenu(Offset at) {
    // A DOM `role=button tabIndex=0` row takes focus on the mousedown that
    // precedes `contextmenu`, so its group-focus-within chrome stays visible
    // while the menu is open. Saved rows style popup-open instead.
    if (!widget.saved) focusNode.requestFocus();
    widget.onContextMenu?.call(at);
  }

  void deliverActivation() {
    final callback = pendingTapPosition != null
        ? widget.onPointerActivate ?? widget.onActivate
        : widget.onActivate;
    if (callback == null) {
      widget.onOpen();
      return;
    }
    final time = pendingTapTime, position = pendingTapPosition;
    final interval = time != null && lastTapTime != null
        ? time - lastTapTime!
        : null;
    final repeat =
        interval != null &&
        interval >= Duration.zero &&
        interval <= widget.doubleClickInterval &&
        position != null &&
        lastTapPosition != null &&
        (position - lastTapPosition!).distance <= kDoubleTapSlop;
    clickCount = repeat ? clickCount + 1 : 1;
    lastTapTime = time;
    lastTapPosition = position;
    pendingTapTime = null;
    pendingTapPosition = null;
    callback(clickCount);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftConversationCardRecipe(t, saved: widget.saved);
    final showActions =
        hovered ||
        focused ||
        widget.popupOpen ||
        (!recipe.flat && RaftDensityScope.of(context) == RaftDensity.touch) ||
        (recipe.flat && widget.selected);
    final rt = RaftRecipeTokens(t);
    // raft-ui Card root shadow (brutal themeShadowMd, elegant themeShadowXs);
    // SavedItem opts out with `shadow-none`.
    final selected = widget.selected && !widget.saved;
    final cardStyle = RaftCardRecipe.resolve(
      theme: recipe.inkCard ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).root;
    // InboxRow: only `hover:bg-fill-muted` changes the fill; focus-within just
    // reveals the row action.
    final base = hovered ? recipe.hoverBackground : recipe.background;
    final background = selected ? recipe.selectedFill(base) : base;
    Widget surface(Widget child) {
      if (recipe.flat) {
        return Material(
          color: !selected && (hovered || widget.popupOpen)
              ? recipe.hoverBackground
              : background,
          child: Stack(
            children: [
              child,
              // SavedPanel ContextMenu rows have no visible sibling rule in Web v1.21.23.
              if (widget.topRule && !widget.saved)
                Positioned(
                  top: 0,
                  left: 16,
                  right: 0,
                  height: 1,
                  child: IgnorePointer(
                    child: ColoredBox(color: t.ui.lineHairline),
                  ),
                ),
            ],
          ),
        );
      }
      if (widget.saved) {
        return Material(
          color: hovered || focused || widget.popupOpen
              ? recipe.hoverBackground
              : recipe.background,
          shape: RoundedRectangleBorder(
            borderRadius: recipe.radius,
            side: recipe.border,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      }
      // Card's dark elevation contains an inset top-light and a dark outer
      // ring. The shared CSS painter retains both and keeps outer shadows
      // outside a translucent background throughout transitions.
      return RaftRecipeBox(
        style: cardStyle,
        tokens: rt,
        padding: EdgeInsets.zero,
        applyText: false,
        clip: true,
        decorationOverride: (base) => base.copyWith(
          color: background,
          border: Border.fromBorderSide(recipe.border),
          borderRadius: recipe.radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: selected
              ? Stack(
                  children: [
                    child,
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: recipe.selectedEdgeWidth,
                      child: IgnorePointer(
                        child: ColoredBox(color: recipe.selectedEdge),
                      ),
                    ),
                  ],
                )
              : child,
        ),
      );
    }

    return _ConversationActionScope(
      visible: widget.actions != null && showActions,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        // Source group-focus-within includes the row's nested action button.
        onFocusChange: (value) => setState(() => focused = value),
        child: RaftHoverRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => lastPointer = e.position,
            child: surface(
              RaftListRowAction(
                selected: selected,
                semanticLabel: widget.semanticLabel,
                onTapDown: // InkWell.onDoubleTap would delay the first onTap before the
                    // consumer sees it. Count successful primary
                    // taps without installing a double-tap recognizer instead.
                    widget.onActivate == null &&
                        widget.onPointerActivate == null
                    ? null
                    : (details) {
                        pendingTapTime = SchedulerBinding
                            .instance
                            .currentSystemFrameTimeStamp;
                        pendingTapPosition = details.globalPosition;
                      },
                onTapCancel: () {
                  pendingTapTime = null;
                  pendingTapPosition = null;
                },
                onPressed: deliverActivation,
                focusNode: focusNode,
                onLongPress: widget.onContextMenu == null
                    ? null
                    : () => openContextMenu(lastPointer ?? Offset.zero),
                onSecondaryTapDown: widget.onContextMenu == null
                    ? null
                    : (details) => openContextMenu(details.globalPosition),
                child: Padding(
                  // RecipeBox includes its CSS border in Container padding;
                  // the Saved Material shape only paints the border.
                  padding: recipe.contentInset.add(
                    EdgeInsets.all(widget.saved ? recipe.border.width : 0),
                  ),
                  child: Stack(
                    children: [
                      widget.child,
                      if (widget.actions != null)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: ExcludeSemantics(
                            excluding: !showActions,
                            child: IgnorePointer(
                              ignoring: !showActions,
                              child: AnimatedOpacity(
                                opacity: showActions ? 1 : 0,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : RaftConversationCardRecipe.actionFade,
                                child: Material(
                                  color: selected
                                      ? recipe.selectedFill(recipe.background)
                                      : recipe.background,
                                  child: widget.actions!,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                decorate: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationActionScope extends InheritedWidget {
  const _ConversationActionScope({required this.visible, required super.child});
  final bool visible;
  @override
  bool updateShouldNotify(_ConversationActionScope oldWidget) =>
      visible != oldWidget.visible;
}

/// InboxRow hides its timestamp when the overlaid action is available, while
/// keeping the timestamp's layout width so hover never changes title wrapping.
class RaftConversationTimestamp extends StatelessWidget {
  const RaftConversationTimestamp({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final hidden = RaftConversationCard.actionsVisibleOf(context);
    return ExcludeSemantics(
      excluding: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : RaftConversationCardRecipe.actionFade,
        child: child,
      ),
    );
  }
}
