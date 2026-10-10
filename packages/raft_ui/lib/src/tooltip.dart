import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'pointer_intent.dart';
import 'theme.dart';

/// RUI tooltip1392 and foundation361/489; product timing is provider-owned.
@immutable
class RaftTooltipRecipe {
  const RaftTooltipRecipe(this.tokens);
  final RaftTokens tokens;
  double get sideOffset => tokens.brutal ? 6 : 8;
  double get collisionPadding => 5;
  double get maximumWidth => 320;
  double get radius => tokens.brutal ? 0 : 6;
  EdgeInsets get padding =>
      const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
  Duration get transition => const Duration(milliseconds: 150);
  Curve get curve => const Cubic(.22, 1, .36, 1);
  bool get hasArrow => !tokens.brutal;
  // tooltip recipe `content` brutal background-color: token(primary400).
  Color get background => tokens.brutal
      ? tokens.colors['primary-400']!
      : tokens.dark
      ? tokens.popover
      // foundation.css311 oklch(.263 .009 294.9), converted to sRGB.
      : tokens.colors['layer-hud'] ?? const Color(0xff252429);
  Color get foreground => tokens.brutal
      ? tokens.strong
      : tokens.dark
      ? tokens.ink
      // foundation.css312 oklch(.965 .002 286), converted to sRGB.
      : tokens.colors['layer-hud-foreground'] ?? const Color(0xfff3f3f5);
  TextStyle get text => TextStyle(
    fontFamily: tokens.bodyFont,
    fontFamilyFallback: tokens.fontFallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: tokens.brutal ? FontWeight.w700 : FontWeight.w500,
    letterSpacing: tokens.brutal ? 0 : -.065,
    color: foreground,
  );
  List<BoxShadow> get shadows => tokens.brutal
      ? [
          BoxShadow(
            color: tokens.colors['line-strong']!,
            offset: const Offset(2, 2),
          ),
        ]
      : tokens.dark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: .55),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            offset: const Offset(0, 4),
            blurRadius: 8,
            spreadRadius: -3,
          ),
        ]
      : [
          // foundation.css371 oklch(.21 .006 106.42).
          BoxShadow(
            color: const Color(0xff191815).withValues(alpha: .1),
            offset: const Offset(0, 1),
            blurRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xff191815).withValues(alpha: .04),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xff191815).withValues(alpha: .16),
            offset: const Offset(0, 2),
            blurRadius: 12,
            spreadRadius: -4,
          ),
        ];
}

/// Generic RUI defaults: delay0, closeDelay0, adjacent-trigger timeout400.
/// Actual AppProviders must explicitly set600; the members strip sets250.
class RaftTooltipProvider extends StatefulWidget {
  const RaftTooltipProvider({
    super.key,
    this.delay = Duration.zero,
    this.closeDelay = Duration.zero,
    this.hysteresis = const Duration(milliseconds: 400),
    required this.child,
  });
  final Duration delay, closeDelay, hysteresis;
  final Widget child;
  @override
  State<RaftTooltipProvider> createState() => _RaftTooltipProviderState();
}

class _RaftTooltipProviderState extends State<RaftTooltipProvider> {
  final group = _TooltipGroup();
  @override
  void dispose() {
    group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TooltipScope(
    group: group,
    delay: widget.delay,
    closeDelay: widget.closeDelay,
    hysteresis: widget.hysteresis,
    child: widget.child,
  );
}

class _TooltipScope extends InheritedWidget {
  const _TooltipScope({
    required this.group,
    required this.delay,
    required this.closeDelay,
    required this.hysteresis,
    required super.child,
  });
  final _TooltipGroup group;
  final Duration delay, closeDelay, hysteresis;
  @override
  bool updateShouldNotify(_TooltipScope old) =>
      group != old.group ||
      delay != old.delay ||
      closeDelay != old.closeDelay ||
      hysteresis != old.hysteresis;
}

class _TooltipGroup {
  Object? owner;
  VoidCallback? replace;
  Timer? reset;
  bool instant = false;
  void activate(Object next, VoidCallback onReplace) {
    reset?.cancel();
    final retire = owner != next ? replace : null;
    owner = next;
    replace = onReplace;
    instant = true;
    retire?.call();
  }

  void release(Object previous, Duration timeout) {
    if (owner != previous) {
      return;
    }
    owner = null;
    replace = null;
    reset?.cancel();
    reset = Timer(timeout, () {
      instant = false;
    });
  }

  /// Ends adjacent instant opening at once (e.g. the list scrolled).
  void settle() {
    reset?.cancel();
    instant = false;
  }

  void dispose() {
    reset?.cancel();
    owner = null;
    replace = null;
  }
}

/// No Focus node, focus request, scroll reveal or flow-sized overlay is created.
/// [keyboardFocused] must project the existing control's genuine focus-visible
/// state, including the shared pointer/keyboard modality. Pointer focus is false.
// Retain Flutter Tooltip metadata for existing accessibility/testing finders.
// Our state owns every timer, overlay and paint; Material TooltipState is unused.
class RaftTooltip extends Tooltip {
  const RaftTooltip({
    Key? key,
    required this.message,
    required this.child,
    this.enabled = true,
    this.keyboardFocused = false,
    this.delay,
    this.closeDelay,
    this.onlyWhenTruncated = false,
    bool excludeFromSemantics = false,
  }) : excludeDescription = excludeFromSemantics,
       super(
         key: key,
         message: message,
         child: child,
         excludeFromSemantics: true,
       );
  @override
  final String message;
  @override
  final Widget child;
  final bool enabled, keyboardFocused, excludeDescription;
  final Duration? delay, closeDelay;

  /// For a tooltip that repeats its child's own text: it opens only while
  /// that text is cut off (a single-line ellipsis), never when fully shown.
  final bool onlyWhenTruncated;
  @override
  State<RaftTooltip> createState() => _RaftTooltipState();
}

class _RaftTooltipState extends State<RaftTooltip>
    with SingleTickerProviderStateMixin {
  final anchor = GlobalKey();
  final portal = OverlayPortalController();
  late final AnimationController motion;
  Timer? openTimer, closeTimer;
  _TooltipScope? scope;
  ScrollPosition? scroll;
  Offset? pointer;
  bool hovered = false, closing = false, instant = false, tracking = false;
  bool hoverBlocked = false, focusBlocked = false;

  /// Entered by scrolling rather than by moving the pointer; opening waits
  /// for a real pointer move.
  bool awaitingMove = false;
  int epoch = 0;
  bool get allowed => widget.enabled && widget.message.isNotEmpty;
  bool get reduced => MediaQuery.disableAnimationsOf(context);
  @override
  void initState() {
    super.initState();
    motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    HardwareKeyboard.instance.addHandler(_key);
    RaftPointerIntent.install();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScope = context
        .dependOnInheritedWidgetOfExactType<_TooltipScope>();
    if (scope?.group != nextScope?.group) {
      scope?.group.release(this, scope!.hysteresis);
      _hide(immediate: true);
    }
    scope = nextScope;
    final nextScroll = Scrollable.maybeOf(context)?.position;
    if (nextScroll != scroll) {
      scroll?.removeListener(_trackAnchor);
      scroll = nextScroll;
      scroll?.addListener(_trackAnchor);
    }
    if (widget.keyboardFocused && allowed && !focusBlocked) {
      _deferKeyboard();
    }
  }

  @override
  void didUpdateWidget(RaftTooltip old) {
    super.didUpdateWidget(old);
    if (!allowed) {
      hovered = false;
      _hide(immediate: true);
    }
    if (!widget.keyboardFocused) {
      focusBlocked = false;
    }
    if (widget.keyboardFocused &&
        allowed &&
        !old.keyboardFocused &&
        !focusBlocked) {
      _deferKeyboard();
    } else if (!widget.keyboardFocused && old.keyboardFocused && !hovered) {
      _hide();
    }
  }

  void _deferKeyboard() {
    final ticket = ++epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ticket == epoch &&
          widget.keyboardFocused &&
          allowed &&
          !focusBlocked) {
        _show(immediate: true);
      }
    });
  }

  void _enter(PointerEnterEvent event) {
    if (!allowed ||
        (event.kind != PointerDeviceKind.mouse &&
            event.kind != PointerDeviceKind.stylus)) {
      return;
    }
    if (widget.onlyWhenTruncated && !_truncated()) return;
    pointer = event.position;
    hovered = true;
    hoverBlocked = false;
    awaitingMove = !RaftPointerIntent.movedSinceScroll;
    if (!awaitingMove) _scheduleHover();
  }

  void _scheduleHover() {
    closeTimer?.cancel();
    openTimer?.cancel();
    final wait = scope?.group.instant == true
        ? Duration.zero
        : widget.delay ?? scope?.delay ?? const Duration(milliseconds: 600);
    if (wait == Duration.zero) {
      _show(immediate: scope?.group.instant == true);
      return;
    }
    final ticket = ++epoch;
    openTimer = Timer(wait, () {
      if (mounted && ticket == epoch && hovered && allowed && !hoverBlocked) {
        _show();
      }
    });
  }

  void _hover(PointerHoverEvent event) {
    final previous = pointer;
    pointer = event.position;
    if (!allowed ||
        !hovered ||
        hoverBlocked ||
        portal.isShowing ||
        widget.keyboardFocused) {
      return;
    }
    if (awaitingMove) {
      if (event.delta == Offset.zero) return;
      awaitingMove = false;
    }
    if (openTimer?.isActive == true &&
        previous != null &&
        (previous - event.position).distanceSquared < 2) {
      return;
    }
    _scheduleHover();
  }

  void _exit(PointerExitEvent event) {
    hovered = false;
    pointer = null;
    hoverBlocked = false;
    focusBlocked = false;
    awaitingMove = false;
    openTimer?.cancel();
    epoch++;
    if (widget.keyboardFocused && allowed) {
      return;
    }
    closeTimer?.cancel();
    final wait = widget.closeDelay ?? scope?.closeDelay ?? Duration.zero;
    if (wait == Duration.zero) {
      _hide();
      return;
    }
    final ticket = epoch;
    closeTimer = Timer(wait, () {
      if (mounted && ticket == epoch && !hovered && !widget.keyboardFocused) {
        _hide();
      }
    });
  }

  void _dismiss() {
    hoverBlocked = true;
    focusBlocked = widget.keyboardFocused;
    _hide();
  }

  bool _key(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        portal.isShowing) {
      _dismiss();
    }
    return false;
  }

  void _show({bool immediate = false}) {
    if (!mounted || !allowed) {
      return;
    }
    openTimer?.cancel();
    closeTimer?.cancel();
    epoch++;
    final adjacent = scope?.group.instant == true;
    scope?.group.activate(this, () => _hide(immediate: true));
    instant = immediate || adjacent || reduced;
    closing = false;
    portal.show();
    if (instant) {
      motion.value = 1;
    } else {
      motion.forward();
    }
  }

  void _hide({bool immediate = false}) {
    openTimer?.cancel();
    closeTimer?.cancel();
    final ticket = ++epoch;
    scope?.group.release(this, scope!.hysteresis);
    if (!portal.isShowing) {
      return;
    }
    closing = true;
    if (immediate || reduced || motion.value == 0) {
      motion.stop();
      portal.hide();
      return;
    }
    motion.reverse().then((_) {
      if (mounted && ticket == epoch && closing) {
        portal.hide();
      }
    });
  }

  /// Whether a paragraph under the anchor is cut off.
  bool _truncated() {
    var found = false;
    void visit(RenderObject node) {
      if (found) return;
      if (node is RenderParagraph && node.didExceedMaxLines) {
        found = true;
        return;
      }
      node.visitChildren(visit);
    }

    final root = anchor.currentContext?.findRenderObject();
    if (root != null) visit(root);
    return found;
  }

  Rect? _anchorRect() {
    final box = anchor.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _trackAnchor() {
    RaftPointerIntent.scrolled();
    // Scrolling is not hover intent: a pending open waits for a pointer move
    // and an open tooltip closes without arming adjacent instant opens.
    if (openTimer?.isActive == true && !widget.keyboardFocused) {
      openTimer!.cancel();
      epoch++;
      awaitingMove = true;
    }
    if (portal.isShowing && !widget.keyboardFocused) {
      awaitingMove = hovered;
      _hide(immediate: true);
      scope?.group.settle();
      return;
    }
    if (tracking || !portal.isShowing) {
      return;
    }
    tracking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tracking = false;
      if (!mounted) {
        return;
      }
      final rect = _anchorRect();
      // A moving/recycled row no longer under the original pointer owns no
      // hover. Cancel its delayed callback instead of opening at stale geometry.
      if (hovered &&
          pointer != null &&
          (rect == null || !rect.contains(pointer!))) {
        hovered = false;
        openTimer?.cancel();
        epoch++;
        if (!widget.keyboardFocused) {
          _hide();
        }
      }
      if (portal.isShowing) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    epoch++;
    openTimer?.cancel();
    closeTimer?.cancel();
    scroll?.removeListener(_trackAnchor);
    HardwareKeyboard.instance.removeHandler(_key);
    scope?.group.release(this, scope!.hysteresis);
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: portal,
    overlayChildBuilder: (overlayContext) {
      final rect = _anchorRect();
      final root = Overlay.of(context).context.findRenderObject();
      if (rect == null || root is! RenderBox || !root.hasSize) {
        return const SizedBox.shrink();
      }
      final recipe = RaftTooltipRecipe(RaftTokens.of(context));
      final localRect = rect.shift(-root.localToGlobal(Offset.zero));
      final placement = _TooltipPlacement(recipe, localRect);
      return Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: motion,
              builder: (context, child) {
                final value = recipe.curve.transform(motion.value);
                return CustomMultiChildLayout(
                  delegate: placement,
                  children: [
                    LayoutId(
                      id: 0,
                      child: Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: closing
                              ? .99 + .01 * value
                              : .97 + .03 * value,
                          child: _TooltipSurface(recipe, widget.message),
                        ),
                      ),
                    ),
                    if (recipe.hasArrow)
                      LayoutId(
                        id: 1,
                        child: Opacity(
                          opacity: value,
                          child: CustomPaint(
                            size: const Size(12, 6),
                            painter: _TooltipArrow(recipe, placement),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
    child: Semantics(
      tooltip: widget.excludeDescription || !allowed ? null : widget.message,
      child: MouseRegion(
        onEnter: _enter,
        onExit: _exit,
        onHover: _hover,
        child: Listener(
          onPointerDown: (_) => _dismiss(),
          child: SizedBox(key: anchor, child: widget.child),
        ),
      ),
    ),
  );
}

class _TooltipPlacement extends MultiChildLayoutDelegate {
  _TooltipPlacement(this.recipe, this.anchor);
  final RaftTooltipRecipe recipe;
  final Rect anchor;
  bool above = true;
  @override
  void performLayout(Size size) {
    final inset = recipe.collisionPadding;
    final body = layoutChild(
      0,
      BoxConstraints.loose(
        Size(
          math.min(recipe.maximumWidth, math.max(0, size.width - inset * 2)),
          math.max(0, size.height - inset * 2),
        ),
      ),
    );
    final x = (anchor.center.dx - body.width / 2)
        .clamp(inset, math.max(inset, size.width - inset - body.width))
        .toDouble();
    final top = anchor.top - recipe.sideOffset - body.height;
    above =
        top >= inset ||
        anchor.bottom + recipe.sideOffset + body.height > size.height - inset;
    final y = (above ? top : anchor.bottom + recipe.sideOffset)
        .clamp(inset, math.max(inset, size.height - inset - body.height))
        .toDouble();
    positionChild(0, Offset(x, y));
    if (hasChild(1)) {
      layoutChild(1, const BoxConstraints.tightFor(width: 12, height: 6));
      final arrowCenter = (anchor.center.dx - x)
          .clamp(
            math.min(11, body.width / 2),
            math.max(body.width / 2, body.width - 11),
          )
          .toDouble();
      positionChild(
        1,
        Offset(x + arrowCenter - 6, above ? y + body.height - 1 : y - 5),
      );
    }
  }

  @override
  bool shouldRelayout(_TooltipPlacement old) =>
      anchor != old.anchor || recipe.tokens != old.recipe.tokens;
}

class _TooltipSurface extends StatelessWidget {
  const _TooltipSurface(this.recipe, this.message);
  final RaftTooltipRecipe recipe;
  final String message;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('raft-tooltip-surface'),
    decoration: BoxDecoration(
      color: recipe.background,
      borderRadius: BorderRadius.circular(recipe.radius),
      border: recipe.tokens.brutal
          ? Border.all(color: recipe.tokens.colors['line-strong']!, width: 2)
          : null,
      boxShadow: recipe.shadows,
    ),
    child: CustomPaint(
      foregroundPainter: recipe.tokens.dark && !recipe.tokens.brutal
          ? _TooltipInset(recipe.radius)
          : null,
      child: Padding(
        // CSS border-box: the brutal border sits outside the padding.
        padding: recipe.padding + EdgeInsets.all(recipe.tokens.brutal ? 2 : 0),
        child: Text(message, style: recipe.text),
      ),
    ),
  );
}

class _TooltipInset extends CustomPainter {
  const _TooltipInset(this.radius);
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    const white = Color(0xfffafaf7); // foundation.css489 .985 .004 106.42.
    final shape = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(.5),
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = white.withValues(alpha: .04),
    );
    canvas.drawLine(
      const Offset(0, .5),
      Offset(size.width, .5),
      Paint()
        ..strokeWidth = 1
        ..color = white.withValues(alpha: .06),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TooltipInset old) => radius != old.radius;
}

class _TooltipArrow extends CustomPainter {
  const _TooltipArrow(this.recipe, this.placement);
  final RaftTooltipRecipe recipe;
  final _TooltipPlacement placement;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (!placement.above) {
      canvas.translate(0, 6);
      canvas.scale(1, -1);
    }
    final path = Path()
      ..moveTo(1, 0)
      ..lineTo(11, 0)
      ..lineTo(6, 5.25)
      ..close();
    if (recipe.tokens.dark) {
      canvas.save();
      canvas.translate(0, 1);
      canvas.drawPath(
        path,
        Paint()..color = Colors.black.withValues(alpha: .55),
      );
      canvas.restore();
    }
    canvas.drawPath(path, Paint()..color = recipe.background);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TooltipArrow old) =>
      recipe.tokens != old.recipe.tokens || placement != old.placement;
}
