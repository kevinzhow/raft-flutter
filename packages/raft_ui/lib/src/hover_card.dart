import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pointer_intent.dart';
import 'recipe_surface.dart';
import 'recipes/preview_card.g.dart';
import 'theme.dart';

/// Which side of the trigger the card opens on. The card flips to the other
/// side when the preferred one has no room (Floating UI `flip`).
enum RaftHoverCardSide { bottom, top }

/// Cross-axis alignment against the trigger (Floating UI `align`).
enum RaftHoverCardAlign { start, center, end }

/// Opens, pins and closes a [RaftHoverCard] from outside, e.g. a trigger
/// whose click pins the card (Web RuntimeAccountUsageChip `pinOpen`) or a
/// caller that closes the card before navigating (`previewActionsRef.close`).
class RaftHoverCardController extends ChangeNotifier {
  _RaftHoverCardState? _state;
  bool get isOpen => _state?.portal.isShowing ?? false;
  bool get pinned => _state?.pinned ?? false;

  /// Opens at once; a pinned card ignores pointer exit and closes on an
  /// outside press, Escape or [close].
  void open({bool pinned = false}) => _state?._show(pin: pinned);
  void close() => _state?._hide(immediate: true);
  void _changed() => notifyListeners();
}

/// Web raft-ui PreviewCard (Base UI) and the product's other hover-opened
/// detail popups. Desktop pointer only: a touch never opens it.
///
/// Hover intent follows [RaftTooltip]: a row scrolled under a resting pointer
/// does not open a card until the pointer itself moves; scrolling closes an
/// open, unpinned card. The pointer may travel from the trigger into the card
/// within [closeDelay] (Base UI `closeDelay` grace). Escape and an outside
/// press close it; pressing the trigger closes it (every Web trigger calls
/// `close()` before its own click action) unless [closeOnTriggerPress] is off.
class RaftHoverCard extends StatefulWidget {
  const RaftHoverCard({
    super.key,
    required this.child,
    required this.card,
    this.controller,
    this.enabled = true,
    this.width = 280,
    this.delay = const Duration(milliseconds: 200),
    this.closeDelay = const Duration(milliseconds: 120),
    this.side = RaftHoverCardSide.bottom,
    this.align = RaftHoverCardAlign.start,
    this.sideOffset = 6,
    this.collisionPadding = 6,
    this.surface = true,
    this.interactive = true,
    this.openOnKeyboardFocus = true,
    this.closeOnTriggerPress = true,
    this.onOpenChanged,
  });

  /// The trigger.
  final Widget child;

  /// Card content, painted inside the PreviewCard popup surface when
  /// [surface] is true.
  final WidgetBuilder card;
  final RaftHoverCardController? controller;
  final bool enabled;

  /// Fixed card width (`w-[280px]`); null sizes the card to its content.
  final double? width;

  /// Web PreviewCardTrigger `delay` / `closeDelay` as set at the call site.
  final Duration delay, closeDelay;
  final RaftHoverCardSide side;
  final RaftHoverCardAlign align;
  final double sideOffset, collisionPadding;

  /// Paint the raft-ui PreviewCard popup recipe around [card]. Off when the
  /// card supplies its own surface (Card, PopoverPopup).
  final bool surface;

  /// Whether the pointer can enter and use the card. A purely informational
  /// popup (`pointer-events-none`) closes as soon as the trigger is left.
  final bool interactive;

  /// Keyboard focus-visible on the trigger opens the card (Base UI focus
  /// interaction). Pointer focus never does.
  final bool openOnKeyboardFocus;
  final bool closeOnTriggerPress;
  final ValueChanged<bool>? onOpenChanged;

  /// Closes the card that encloses [context] (a navigation from inside the
  /// card dismisses it first, as Web `previewActionsRef.close()`).
  static void dismiss(BuildContext context) => context
      .getInheritedWidgetOfExactType<_HoverCardScope>()
      ?.state
      ._hide(immediate: true);

  @override
  State<RaftHoverCard> createState() => _RaftHoverCardState();
}

class _HoverCardScope extends InheritedWidget {
  const _HoverCardScope({required this.state, required super.child});
  final _RaftHoverCardState state;
  @override
  bool updateShouldNotify(_HoverCardScope old) => state != old.state;
}

class _RaftHoverCardState extends State<RaftHoverCard>
    with SingleTickerProviderStateMixin {
  final anchor = GlobalKey();
  final portal = OverlayPortalController();
  late final AnimationController motion;
  Timer? openTimer, closeTimer;
  ScrollPosition? scroll;
  bool triggerHovered = false, cardHovered = false, focused = false;
  bool pinned = false, closing = false, blocked = false, awaitingMove = false;
  bool tracking = false;
  int epoch = 0;

  bool get allowed => widget.enabled;
  bool get reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 150),
    );
    widget.controller?._state = this;
    HardwareKeyboard.instance.addHandler(_key);
    RaftPointerIntent.install();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != scroll) {
      scroll?.removeListener(_scrolled);
      scroll = next;
      scroll?.addListener(_scrolled);
    }
  }

  @override
  void didUpdateWidget(RaftHoverCard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller?._state = null;
      widget.controller?._state = this;
    }
    if (!allowed) _hide(immediate: true);
  }

  @override
  void dispose() {
    epoch++;
    openTimer?.cancel();
    closeTimer?.cancel();
    scroll?.removeListener(_scrolled);
    HardwareKeyboard.instance.removeHandler(_key);
    if (widget.controller?._state == this) widget.controller?._state = null;
    motion.dispose();
    super.dispose();
  }

  bool _pointer(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse || kind == PointerDeviceKind.stylus;

  void _enter(PointerEnterEvent event) {
    if (!allowed || !_pointer(event.kind)) return;
    triggerHovered = true;
    closeTimer?.cancel();
    if (portal.isShowing || blocked) return;
    awaitingMove = !RaftPointerIntent.movedSinceScroll;
    if (!awaitingMove) _scheduleOpen();
  }

  void _hover(PointerHoverEvent event) {
    if (!allowed || !triggerHovered || blocked || portal.isShowing) return;
    if (awaitingMove) {
      if (event.delta == Offset.zero) return;
      awaitingMove = false;
      _scheduleOpen();
    }
  }

  void _exit(PointerExitEvent event) {
    triggerHovered = false;
    blocked = false;
    awaitingMove = false;
    openTimer?.cancel();
    _scheduleClose();
  }

  void _scheduleOpen() {
    openTimer?.cancel();
    final ticket = ++epoch;
    if (widget.delay == Duration.zero) {
      _show();
      return;
    }
    openTimer = Timer(widget.delay, () {
      if (mounted && ticket == epoch && triggerHovered && !blocked) _show();
    });
  }

  void _scheduleClose() {
    if (pinned || !portal.isShowing) return;
    if (focused && widget.openOnKeyboardFocus && _keyboardMode) return;
    closeTimer?.cancel();
    if (!widget.interactive || widget.closeDelay == Duration.zero) {
      if (!triggerHovered) _hide();
      return;
    }
    final ticket = epoch;
    closeTimer = Timer(widget.closeDelay, () {
      if (mounted && ticket == epoch && !triggerHovered && !cardHovered) {
        _hide();
      }
    });
  }

  bool get _keyboardMode =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _focusChanged(bool value) {
    focused = value;
    if (!widget.openOnKeyboardFocus || !allowed) return;
    if (value && _keyboardMode) {
      _show();
    } else if (!value && !triggerHovered && !cardHovered) {
      _scheduleClose();
    }
  }

  bool _key(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        portal.isShowing) {
      blocked = triggerHovered;
      _hide(immediate: true);
      return true;
    }
    return false;
  }

  void _show({bool pin = false}) {
    if (!mounted || !allowed) return;
    openTimer?.cancel();
    closeTimer?.cancel();
    epoch++;
    if (pin) pinned = true;
    if (portal.isShowing && !closing) {
      if (pin) setState(() {});
      return;
    }
    closing = false;
    final opening = !portal.isShowing;
    portal.show();
    if (reduced) {
      motion.value = 1;
    } else {
      motion.forward();
    }
    if (opening) {
      widget.onOpenChanged?.call(true);
      widget.controller?._changed();
    }
  }

  void _hide({bool immediate = false}) {
    openTimer?.cancel();
    closeTimer?.cancel();
    final ticket = ++epoch;
    pinned = false;
    cardHovered = false;
    if (!portal.isShowing) return;
    void done() {
      portal.hide();
      widget.onOpenChanged?.call(false);
      widget.controller?._changed();
    }

    closing = true;
    if (immediate || reduced || motion.value == 0) {
      motion.stop();
      motion.value = 0;
      done();
      return;
    }
    motion.reverse().then((_) {
      if (mounted && ticket == epoch && closing) done();
    });
  }

  void _scrolled() {
    RaftPointerIntent.scrolled();
    if (openTimer?.isActive == true) {
      openTimer!.cancel();
      epoch++;
      awaitingMove = triggerHovered;
    }
    if (!portal.isShowing) return;
    if (!pinned) {
      awaitingMove = triggerHovered;
      _hide(immediate: true);
      return;
    }
    // A pinned card follows its trigger.
    if (tracking) return;
    tracking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tracking = false;
      if (mounted && portal.isShowing) setState(() {});
    });
  }

  Rect? _anchorRect(RenderBox overlay) {
    final box = anchor.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  }

  Widget _overlay(BuildContext overlayContext) {
    final root = Overlay.of(context).context.findRenderObject();
    if (root is! RenderBox || !root.hasSize) return const SizedBox.shrink();
    final rect = _anchorRect(root);
    if (rect == null) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    Widget card = Builder(builder: widget.card);
    if (widget.surface) {
      final style = RaftPreviewCardRecipe.resolve(
        theme: t.recipeTheme,
        states: t.recipeStates(),
        tokens: t.recipeTokens,
      ).popup;
      card = RaftRecipeBox(
        key: const ValueKey('raft-hover-card-surface'),
        style: style,
        tokens: t.recipeTokens,
        width: widget.width,
        clip: true,
        child: card,
      );
    } else if (widget.width != null) {
      card = SizedBox(width: widget.width, child: card);
    }
    final placement = _HoverCardPlacement(
      anchor: rect,
      side: widget.side,
      align: widget.align,
      sideOffset: widget.sideOffset,
      padding: widget.collisionPadding,
    );
    card = _HoverCardScope(
      state: this,
      child: TapRegion(
        groupId: this,
        onTapOutside: (_) => _hide(immediate: true),
        child: MouseRegion(
          onEnter: (_) {
            cardHovered = true;
            closeTimer?.cancel();
          },
          onExit: (_) {
            cardHovered = false;
            _scheduleClose();
          },
          child: card,
        ),
      ),
    );
    if (!widget.interactive) card = IgnorePointer(child: card);
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: placement,
        child: AnimatedBuilder(
          animation: motion,
          builder: (context, child) {
            final value = const Cubic(.22, 1, .36, 1).transform(motion.value);
            return Opacity(
              opacity: value,
              child: Transform.scale(
                alignment: placement.origin,
                scale: closing ? .99 + .01 * value : .97 + .03 * value,
                child: child,
              ),
            );
          },
          child: card,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: portal,
    overlayChildBuilder: _overlay,
    child: TapRegion(
      groupId: this,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: _focusChanged,
        child: MouseRegion(
          onEnter: _enter,
          onHover: _hover,
          onExit: _exit,
          child: Listener(
            onPointerDown: (event) {
              if (!widget.closeOnTriggerPress || pinned) return;
              blocked = _pointer(event.kind);
              _hide(immediate: true);
            },
            child: KeyedSubtree(key: anchor, child: widget.child),
          ),
        ),
      ),
    ),
  );
}

class _HoverCardPlacement extends SingleChildLayoutDelegate {
  _HoverCardPlacement({
    required this.anchor,
    required this.side,
    required this.align,
    required this.sideOffset,
    required this.padding,
  });
  final Rect anchor;
  final RaftHoverCardSide side;
  final RaftHoverCardAlign align;
  final double sideOffset, padding;
  bool below = true;

  Alignment get origin => switch ((below, align)) {
    (true, RaftHoverCardAlign.start) => Alignment.topLeft,
    (true, RaftHoverCardAlign.center) => Alignment.topCenter,
    (true, RaftHoverCardAlign.end) => Alignment.topRight,
    (false, RaftHoverCardAlign.start) => Alignment.bottomLeft,
    (false, RaftHoverCardAlign.center) => Alignment.bottomCenter,
    (false, RaftHoverCardAlign.end) => Alignment.bottomRight,
  };

  double _below(Size size) =>
      size.height - padding - anchor.bottom - sideOffset;
  double _above() => anchor.top - sideOffset - padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final room = math.max(_below(size), _above());
    return BoxConstraints(
      maxWidth: math.max(0, size.width - padding * 2),
      maxHeight: math.max(0, room),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final roomBelow = _below(size), roomAbove = _above();
    below = side == RaftHoverCardSide.bottom
        ? child.height <= roomBelow || roomBelow >= roomAbove
        : !(child.height <= roomAbove || roomAbove >= roomBelow);
    final x = switch (align) {
      RaftHoverCardAlign.start => anchor.left,
      RaftHoverCardAlign.center => anchor.center.dx - child.width / 2,
      RaftHoverCardAlign.end => anchor.right - child.width,
    };
    final y = below
        ? anchor.bottom + sideOffset
        : anchor.top - sideOffset - child.height;
    return Offset(
      x.clamp(padding, math.max(padding, size.width - padding - child.width)),
      y.clamp(padding, math.max(padding, size.height - padding - child.height)),
    );
  }

  @override
  bool shouldRelayout(_HoverCardPlacement old) =>
      anchor != old.anchor ||
      side != old.side ||
      align != old.align ||
      sideOffset != old.sideOffset ||
      padding != old.padding;
}
