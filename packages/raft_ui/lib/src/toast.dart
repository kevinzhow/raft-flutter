import 'hover_region.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'design_primitives.dart'
    show RaftInteractive, RaftLayoutMetrics, RaftTouchTarget;
import 'interaction.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'raft/ui_tokens.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/toast_styles.g.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

/// The mounted Web selection toast: inline, title-only, without an icon or
/// dismiss button (ChatPanel/ThreadPanel SELECTION_TOAST_OPTIONS). Paint comes
/// from raft-ui toastStyles; LocalizedToastProvider overrides title to normal
/// weight and permits wrapping. This is not the stacked/action toast variant.
class RaftToast extends StatelessWidget {
  const RaftToast({
    super.key,
    required this.title,
    this.description,
    this.tone = RaftToastRecipeTone.success,
    this.icon = false,
    this.onClose,
    this.actionLabel,
    this.onAction,
  });
  final String title;

  /// `toast.success(..., { action: { label, onClick } })`: a trailing text
  /// action (the follower removal toast's "Undo").
  final String? actionLabel;
  final VoidCallback? onAction;

  /// `ToastDescription` under the title (stacked in the same body column).
  final String? description;
  final RaftToastRecipeTone tone;

  /// LocalizedToastProvider default (`hasIcon !== false`): the tone glyph in a
  /// 20px `ToastIcon` cell before the body.
  final bool icon;

  /// `ToastClose` (default on toasts that keep their dismiss button): a 32px
  /// button in the trailing grid cell.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    if (t.option('toast.style', or: 'recipe') == 'hud') {
      return _buildHud(context, t);
    }
    final hasClose = onClose != null;
    final s = RaftToastRecipe.resolve(
      theme: t.recipeTheme,
      layout: RaftToastRecipeLayout.inline,
      tone: tone,
      states: t.recipeStates(
        extra: [
          // The base content rules moved from `:has([data-slot=...])` to
          // `data-has-*` attributes on the content element in 0.5.52; the
          // per-theme blocks still use `:has()`. Negatives are explicit: the
          // resolver does not infer them.
          icon ? 'data-has-icon' : 'not:data-has-icon',
          hasClose ? 'data-has-actions' : 'not:data-has-actions',
          description != null
              ? 'data-has-description'
              : 'not:data-has-description',
          if (icon)
            'has:data-slot=toast-icon'
          else
            'not:has:data-slot=toast-icon',
          if (hasClose)
            'has:data-slot=toast-actions'
          else
            'not:has:data-slot=toast-actions',
          if (description != null)
            'has:data-slot=toast-description'
          else
            'not:has:data-slot=toast-description',
        ],
      ),
      tokens: rt,
    );
    final titleStyle = s.title.text(rt).copyWith(fontWeight: FontWeight.w400);
    // Elegant (light) tone compound variants: `**:data-[slot=toast-icon]:
    // text-info / text-success / text-warning / text-brutal-red` (dark keeps
    // `text-foreground-muted`, brutal keeps `text-foreground-strong`).
    final iconColor = !t.dark
        ? switch (tone) {
            RaftToastRecipeTone.info => t.colors['info'],
            RaftToastRecipeTone.success => t.colors['success'],
            RaftToastRecipeTone.warning => t.colors['warning'],
            RaftToastRecipeTone.error => t.product.brutalRed,
          }
        : null;
    final glyph = switch (tone) {
      RaftToastRecipeTone.success => RaftGlyph.checkCircle2,
      RaftToastRecipeTone.info => RaftGlyph.info,
      _ => RaftGlyph.alertTriangle,
    };
    // `!grid-cols-[auto_minmax(0,1fr)_auto] !gap-x-3`: three tracks, so the
    // two column gaps (24px) stay even when a track is empty.
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (description != null)
          Text(description!, style: s.description.text(rt)),
      ],
    );
    final Widget row = icon
        ? LayoutBuilder(
            // `grid-cols-[auto_minmax(0,1fr)_auto]`: when the content has a
            // min width (elegant `min-w-[18rem]`) the body track takes the
            // extra space and the close button stays at the trailing edge.
            builder: (context, c) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: Center(
                    child: RaftIcon(
                      glyph,
                      size: 18,
                      // `[&_svg]:stroke-[2.5]` (brutal) / `stroke-[1.5]` (elegant).
                      strokeWidth: 1.5,
                      color: iconColor ?? s.icon.textStyle(rt).color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: actionLabel == null
                          ? math.max(
                              0,
                              c.minWidth - 20 - 12 - 12 - (hasClose ? 32 : 0),
                            )
                          : 0,
                    ),
                    child: body,
                  ),
                ),
                const SizedBox(width: 12),
                if (actionLabel != null) ...[
                  RaftRecipeButton(
                    key: const Key('toast-action'),
                    variant: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    label: actionLabel,
                    onPressed: onAction,
                  ),
                  if (hasClose) const SizedBox(width: 4),
                ],
                if (hasClose)
                  Semantics(
                    button: true,
                    label: raftText(context, 'Close'),
                    child: _ToastPaintSnap(
                      child: GestureDetector(
                        key: const Key('toast-close'),
                        onTap: onClose,
                        child: RaftRecipeBox(
                          style: s.close,
                          tokens: rt,
                          width: 32,
                          height: 32,
                          child: Center(
                            child: RaftIcon(
                              RaftGlyph.x,
                              size: 14,
                              color: s.close.textStyle(rt).color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: body),
              if (actionLabel != null) ...[
                const SizedBox(width: 12),
                RaftRecipeButton(
                  key: const Key('toast-action'),
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
              const SizedBox(width: 24),
            ],
          );
    Widget root = RaftRecipeBox(
      style: s.root,
      tokens: rt,
      child: RaftRecipeBox(
        style: s.content,
        tokens: rt,
        child: _ToastSnapWidth(child: row),
      ),
    );
    // Elegant root `saturate-150` (`dark:saturate-100`): a CSS filter over the
    // whole toast (fill, icon and text), standard sRGB saturate matrix.
    if (!t.dark) {
      root = ColorFiltered(colorFilter: _saturate(1.5), child: root);
    }
    // The host's overlay sits above the router, outside any Material or
    // Scaffold, where the WidgetsApp fallback text style (yellow double
    // underline, monospace) would reach every unstyled Text. Give the toast
    // its own base so it renders the same from any context.
    return DefaultTextStyle(
      style: titleStyle.copyWith(decoration: TextDecoration.none),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: _ToastPaintSnap(child: root),
      ),
    );
  }

  /// raft-ui 0.95.3 `toastStyles` (`layout: inline`) as the Web wraps it
  /// (LocalizedToastProvider): the neutral HUD. Root, content, icon, title and
  /// description read the recipe slots; the leading mark is the tone's Lucide
  /// glyph (16px) in a 20px cell, and the dismiss control is a bare 16px `X`
  /// the caller opts into (`hasClose === true`).
  Widget _buildHud(BuildContext context, RaftTokens t) {
    final ui = t.ui, rt = t.recipeTokens;
    final hasClose = onClose != null;
    final hasAction = actionLabel != null;
    final hasDescription = description != null;
    final s = RaftToastRecipe.resolve(
      theme: t.recipeTheme,
      layout: RaftToastRecipeLayout.inline,
      states: t.recipeStates(
        extra: [
          icon ? 'data-has-icon' : 'not:data-has-icon',
          hasClose || hasAction ? 'data-has-actions' : 'not:data-has-actions',
          hasDescription ? 'data-has-description' : 'not:data-has-description',
        ],
      ),
      tokens: rt,
    );
    final onHud = ui['foreground-on-hud'];
    // `text-callout font-normal text-foreground-on-hud` (`s.title`).
    final title = t.scale(
      RaftTypeScale.callout,
      weight: s.title.fontWeight ?? FontWeight.w400,
      color: onHud,
    );
    final glyph = switch (tone) {
      RaftToastRecipeTone.success => RaftGlyph.checkCircle2,
      RaftToastRecipeTone.info => RaftGlyph.info,
      _ => RaftGlyph.alertTriangle,
    };
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(this.title, style: title),
        if (hasDescription)
          Text(
            description!,
            style: s.description
                .text(rt)
                .copyWith(color: onHud.withValues(alpha: .7)),
          ),
      ],
    );
    final close = hasClose
        ? Semantics(
            button: true,
            label: raftText(context, 'Close'),
            child: _ToastPaintSnap(
              child: RaftTouchTarget(
                child: GestureDetector(
                  key: const Key('toast-close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: SizedBox.square(
                    dimension: 16,
                    child: RaftIcon(RaftGlyph.x, size: 16, color: onHud),
                  ),
                ),
              ),
            ),
          )
        : null;
    final action = hasAction
        ? _ToastAction(
            label: actionLabel!,
            style: title,
            color: onHud,
            onPressed: onAction,
          )
        : null;
    // `[&[data-has-description]_[data-slot=toast-icon]]:self-start`: the mark
    // and the body start at the first line when a description is present.
    final cross = hasDescription
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    final cell = s.icon.width ?? 20;
    final titleOnly = !icon && !hasAction && !hasClose && !hasDescription;
    final padding = s.content.padding;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        if (icon) ...[
          SizedBox(
            width: cell,
            height: cell,
            child: Center(
              child: RaftIcon(
                glyph,
                size: s.icon.target('& svg')?.width ?? 16,
                color: onHud,
              ),
            ),
          ),
          SizedBox(width: s.content.columnGap ?? 12),
        ],
        Flexible(child: body),
        if (close != null || action != null) ...[
          SizedBox(width: s.content.columnGap ?? 12),
          // `ToastActions`: `gap-4`, close before the action.
          if (close != null) close,
          if (close != null && action != null)
            SizedBox(width: s.actions.columnGap ?? 16),
          if (action != null) action,
        ],
      ],
    );
    Widget root = RaftRecipeBox(
      style: s.root,
      tokens: rt,
      child: RaftRecipeBox(
        style: s.content,
        tokens: rt,
        child: ConstrainedBox(
          // `--toast-title-only-min-w` (7rem, a border-box minimum).
          constraints: BoxConstraints(
            minWidth: titleOnly
                ? math.max(0, (s.content.minWidth ?? 112) - padding.horizontal)
                : 0,
          ),
          // LocalizedToastProvider's `grid-cols-[auto_minmax(0,1fr)_auto]
          // gap-x-3` keeps three tracks: a title-only body sits in the first
          // (auto) one at the start, the two empty tracks leave their 12px
          // gaps on the right (text 16 from the left, 40 from the right), and
          // the 7rem minimum widens the `1fr` track.
          child: _ToastSnapWidth(
            child: titleOnly
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: body),
                      SizedBox(width: (s.content.columnGap ?? 12) * 2),
                    ],
                  )
                : row,
          ),
        ),
      ),
    );
    return DefaultTextStyle(
      style: title.copyWith(decoration: TextDecoration.none),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: _ToastPaintSnap(child: root),
      ),
    );
  }
}

/// `toastAction` / `hudTextAction`: a bold `text-callout` link in the on-HUD
/// ink, underlined only on hover or press, a 15% on-HUD wash behind it while
/// pressed (`after:-inset-x-2 -inset-y-3 rounded-control`), and a 2px
/// keyboard focus outline.
class _ToastAction extends StatelessWidget {
  const _ToastAction({
    required this.label,
    required this.style,
    required this.color,
    required this.onPressed,
  });
  final String label;
  final TextStyle style;
  final Color color;
  final VoidCallback? onPressed;

  /// The keyboard focus outline drawn around the action label.
  static const _focusRingWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final controlRadius = t.size('radius.control', fallback: 8);
    final radius = BorderRadius.circular(controlRadius);
    return RaftInteractive(
      key: const Key('toast-action'),
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, state) => Stack(
        clipBehavior: Clip.none,
        children: [
          if (state.pressed)
            Positioned(
              left: -8,
              right: -8,
              top: -12,
              bottom: -12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: radius,
                ),
              ),
            ),
          if (state.focusVisible)
            Positioned(
              left: -4,
              right: -4,
              top: -4,
              bottom: -4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: _focusRingWidth),
                  ),
                ),
              ),
            ),
          Text(
            label,
            style: style.copyWith(
              fontWeight: FontWeight.w700,
              decoration: state.hovered || state.pressed
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationThickness: 1.5,
              decorationColor: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Blink lays a `w-max` box out at its fractional width but snaps the painted
/// edges (and so every border) to whole device pixels: the content width
/// rounds up to a whole pixel here so the root and the close button borders stay
/// crisp like Web.
class _ToastSnapWidth extends SingleChildRenderObjectWidget {
  const _ToastSnapWidth({required Widget super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderToastSnapWidth();
}

class _RenderToastSnapWidth extends RenderProxyBox {
  @override
  void performLayout() {
    final c = child!;
    c.layout(constraints, parentUsesSize: true);
    final width = c.size.width;
    final snapped = width.ceilToDouble();
    if (snapped != width && constraints.isTight == false) {
      c.layout(
        constraints.copyWith(
          minWidth: constraints.constrainWidth(snapped),
          maxWidth: constraints.constrainWidth(snapped),
        ),
        parentUsesSize: true,
      );
    }
    size = c.size;
  }
}

/// Paints its child at the whole CSS pixel (round half up) of its global
/// origin, like Blink's pixel-snapped box painting.
class _ToastPaintSnap extends SingleChildRenderObjectWidget {
  const _ToastPaintSnap({required Widget super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderToastPaintSnap();
}

class _RenderToastPaintSnap extends RenderProxyBox {
  Offset _delta = Offset.zero;

  Offset _snap() {
    if (!attached) return Offset.zero;
    final origin = localToGlobal(Offset.zero);
    double round(double v) => (v + .5).floorToDouble() - v;
    return Offset(round(origin.dx), round(origin.dy));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _delta = _snap();
    super.paint(context, offset + _delta);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_delta.dx, _delta.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _delta,
        position: position,
        hitTest: (result, transformed) =>
            super.hitTestChildren(result, position: transformed),
      );
}

/// CSS `saturate(amount)` as a colour matrix.
ColorFilter _saturate(double a) => ColorFilter.matrix([
  0.213 + 0.787 * a,
  0.715 - 0.715 * a,
  0.072 - 0.072 * a,
  0,
  0,
  0.213 - 0.213 * a,
  0.715 + 0.285 * a,
  0.072 - 0.072 * a,
  0,
  0,
  0.213 - 0.213 * a,
  0.715 - 0.715 * a,
  0.072 + 0.928 * a,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

/// UI-owned transient feedback. No payload persistence or app/API dependency.
/// A new notice replaces this owner's old notice and restarts its timeout.
class RaftToastController extends ChangeNotifier {
  Timer? _timer;
  DateTime? _started;
  Duration _remaining = Duration.zero;
  bool _paused = false;
  String? _title;
  String? get title => _title;
  String? _description;
  String? get description => _description;
  String? _actionLabel;
  VoidCallback? _onAction;
  String? get actionLabel => _actionLabel;
  VoidCallback? get onAction => _onAction;
  RaftToastRecipeTone _tone = RaftToastRecipeTone.success;
  RaftToastRecipeTone get tone => _tone;
  bool? _dismissible;
  bool? _icon;

  /// Elegant and Brutal (frozen v1.21 looks): the mark and the close button
  /// are both on unless `dismissible: false`.
  bool get dismissible => _dismissible ?? true;

  /// Raft look, Web v1.24 `hasClose === true`: the close `X` is shown only
  /// when the caller opted in with `dismissible: true`.
  bool get hasClose => _dismissible == true;

  /// Raft look, Web `hasIcon !== false`: the tone glyph. An explicit
  /// `dismissible: false` (the selection toast, which predates the separate
  /// flag) also drops it unless [icon] says otherwise.
  bool get hasIcon => _icon ?? _dismissible != false;

  // Surfaces a narrow-layout toast must clear (the composer). Registered by
  // the surface, read by the portal each build.
  final Map<GlobalKey, bool Function()> _avoided = {};

  /// Keeps a narrow-layout toast above the box [key] is attached to while
  /// [active] is true (a covered route's composer does not count).
  void avoid(GlobalKey key, bool Function() active) {
    _avoided[key] = active;
  }

  void unavoid(GlobalKey key) {
    _avoided.remove(key);
  }

  /// Top edge, in [overlay]'s coordinates, of the highest avoided surface, or
  /// null when none is on screen.
  ///
  /// With [reachesBottom] only a surface whose bottom edge lies within that
  /// many px of the overlay's bottom counts (Web toastViewportBottom.ts: a
  /// floor must reach the page's bottom).
  double? avoidedTop(RenderBox overlay, {double? reachesBottom}) {
    double? top;
    for (final entry in _avoided.entries) {
      final box = entry.key.currentContext?.findRenderObject();
      if (!entry.value() ||
          box is! RenderBox ||
          !box.attached ||
          !box.hasSize ||
          !overlay.attached) {
        continue;
      }
      final y = overlay.globalToLocal(box.localToGlobal(Offset.zero)).dy;
      if (reachesBottom != null &&
          y + box.size.height < overlay.size.height - reachesBottom) {
        continue;
      }
      if (y < overlay.size.height && (top == null || y < top)) top = y;
    }
    return top;
  }

  /// raft-ui toast manager timing (Web toastBridge.ts): 5s, or 8s when the
  /// toast has an action or is an error, unless [duration] is given.
  void show(
    String title, {
    Duration? duration,
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
    RaftToastRecipeTone tone = RaftToastRecipeTone.success,

    /// Raft look (Web `hasClose`): the close `X` shows only with `true`
    /// (default off). An explicit `false` also hides the mark unless [icon]
    /// says otherwise, so the selection toasts stay bare. The frozen looks
    /// keep close and mark on unless `false`.
    bool? dismissible,

    /// Raft look (Web `hasIcon !== false`): the tone glyph before the text.
    /// Null follows [dismissible].
    bool? icon,
  }) {
    _timer?.cancel();
    _dismissible = dismissible;
    _icon = icon;
    _title = title;
    _description = description;
    _actionLabel = actionLabel;
    _onAction = onAction;
    _tone = tone;
    _remaining =
        duration ??
        (actionLabel != null || tone == RaftToastRecipeTone.error
            ? const Duration(seconds: 8)
            : const Duration(seconds: 5));
    if (!_paused) _start();
    notifyListeners();
  }

  void _start() {
    _started = DateTime.now();
    _timer = Timer(_remaining, clear);
  }

  void pause(bool value) {
    if (_paused == value) return;
    _paused = value;
    if (_title == null) return;
    if (value) {
      _timer?.cancel();
      final elapsed = DateTime.now().difference(_started!);
      _remaining = _remaining - elapsed;
      if (_remaining.isNegative) _remaining = Duration.zero;
    } else {
      _start();
    }
  }

  void clear() {
    _timer?.cancel();
    if (_title == null) return;
    _title = null;
    _description = null;
    _actionLabel = null;
    _onAction = null;
    _paused = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _title = null;
    super.dispose();
  }
}

/// Scoped portal: inherits the owner's theme and disappears with its widget.
/// Matches the bottom-center viewport: min(24rem, viewport - 2rem), bottom 16.
/// Safe-area/keyboard insets protect native system chrome without moving the
/// underlying layout or capturing focus. Hover/focus pauses the timeout.
class RaftToastPortal extends StatefulWidget {
  const RaftToastPortal({
    super.key,
    required this.controller,
    this.child = const SizedBox.shrink(),
  });
  final RaftToastController controller;
  final Widget child;
  @override
  State<RaftToastPortal> createState() => _RaftToastPortalState();
}

/// What the portal paints; kept past `controller.clear()` so the exit motion
/// has something to fade.
class _ToastContent {
  const _ToastContent({
    required this.title,
    required this.description,
    required this.tone,
    required this.icon,
    required this.close,
    required this.actionLabel,
  });
  final String title;
  final String? description;
  final RaftToastRecipeTone tone;
  final bool icon, close;
  final String? actionLabel;
}

class _RaftToastPortalState extends State<RaftToastPortal>
    with SingleTickerProviderStateMixin {
  final portal = OverlayPortalController();
  bool hovered = false, focused = false;

  /// Enter and exit: `opacity` and `scale` over 220ms on
  /// `cubic-bezier(.22,1,.36,1)` (toast.mjs inline root).
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation curved = CurvedAnimation(
    parent: _motion,
    curve: const Cubic(.22, 1, .36, 1),
  );
  _ToastContent? _content;
  bool _exiting = false;

  /// Swipe-to-dismiss offset (touch): down and right only.
  Offset _drag = Offset.zero;

  /// The tallest floor seen while this toast is up (toastViewportBottom.ts).
  double _held = 0;

  /// The Raft look's HUD toast. The frozen looks keep the v1.21 toast: mark
  /// and close together, no motion, lifted above the composer only when narrow.
  bool _hud = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hud =
        RaftTokens.of(context).option('toast.style', or: 'recipe') == 'hud';
    if (hud != _hud) {
      _hud = hud;
      if (_content != null && widget.controller.title != null) _snapshot();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
    if (widget.controller.title != null) {
      _snapshot();
      _motion.value = 1;
      portal.show();
    }
  }

  void _snapshot() {
    final c = widget.controller;
    _content = _ToastContent(
      title: c.title!,
      description: c.description,
      tone: c.tone,
      icon: _hud ? c.hasIcon : c.dismissible,
      close: _hud ? c.hasClose : c.dismissible,
      actionLabel: c.actionLabel,
    );
  }

  void changed() {
    if (widget.controller.title == null) {
      hovered = focused = false;
      _held = 0;
      _drag = Offset.zero;
      if (_hud &&
          _content != null &&
          !_exiting &&
          _motion.value > 0 &&
          !MediaQuery.disableAnimationsOf(context)) {
        _exiting = true;
        unawaited(
          _motion.reverse().whenComplete(() {
            if (!mounted || !_exiting) return;
            _exiting = false;
            _content = null;
            portal.hide();
            setState(() {});
          }),
        );
      } else if (!_exiting) {
        _content = null;
        portal.hide();
      }
    } else {
      final entering = _content == null || _exiting;
      _snapshot();
      _exiting = false;
      portal.show();
      if (entering) {
        if (!_hud || MediaQuery.disableAnimationsOf(context)) {
          _motion.value = 1;
        } else {
          _motion.value = 0;
          unawaited(_motion.forward());
        }
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(RaftToastPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      oldWidget.controller.pause(false);
      widget.controller.addListener(changed);
      widget.controller.pause(hovered || focused);
      changed();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    // Only this owner's controller is affected, never another toast host.
    widget.controller.pause(false);
    curved.dispose();
    _motion.dispose();
    super.dispose();
  }

  /// Lifts the toast above the composer (Web `--toast-viewport-bottom`: the
  /// top edge of the lowest page floor, 1rem below the toast), at every width.
  /// A wide layout only counts a floor that reaches the overlay's bottom (the
  /// composer, not a side panel); a narrow layout keeps every registered
  /// surface. Measured from the last layout, then re-measured once the frame
  /// settles (keyboard, a new attachment strip), and held at the tallest value
  /// seen while the toast stays up.
  double composerClearance(BuildContext context) {
    double measure() {
      final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
      if (overlay is! RenderBox || !overlay.hasSize) return 0;
      final m = MediaQuery.of(context);
      final wide = m.size.width >= RaftLayoutMetrics.desktopBreakpoint;
      // Frozen looks: a wide layout keeps the bottom-centre placement.
      if (wide && !_hud) return 0;
      final top = widget.controller.avoidedTop(
        overlay,
        reachesBottom: wide
            ? math.max(m.padding.bottom, m.viewInsets.bottom) + 1
            : null,
      );
      return top == null ? 0 : overlay.size.height - top + (_hud ? 16 : 8);
    }

    final clearance = math.max(_held, measure());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      final next = math.max(_held, measure());
      if ((next - clearance).abs() > .5) {
        _held = next;
        setState(() {});
      }
    });
    _held = clearance;
    return clearance;
  }

  void _swipeEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    final done =
        math.max(_drag.dx, _drag.dy) >= 40 || math.max(v.dx, v.dy) >= 700;
    if (done) {
      widget.controller.clear();
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        widget.controller.title != null) {
      widget.controller.clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: portal,
    overlayChildBuilder: (context) {
      final m = MediaQuery.of(context);
      final content = _content;
      if (content == null) return const SizedBox.shrink();
      final touch = RaftInteraction.of(context).touch;
      Widget toast = RaftToast(
        title: content.title,
        description: content.description,
        tone: content.tone,
        // LocalizedToastProvider: the mark is on unless `hasIcon === false`;
        // the close button only when the caller asked for it.
        icon: content.icon,
        onClose: content.close ? widget.controller.clear : null,
        actionLabel: content.actionLabel,
        onAction: () {
          final action = widget.controller.onAction;
          widget.controller.clear();
          action?.call();
        },
      );
      if (touch) {
        toast = GestureDetector(
          onPanUpdate: (d) => setState(
            () => _drag = Offset(
              math.max(0, _drag.dx + d.delta.dx),
              math.max(0, _drag.dy + d.delta.dy),
            ),
          ),
          onPanEnd: _swipeEnd,
          onPanCancel: () => setState(() => _drag = Offset.zero),
          child: toast,
        );
      }
      return Positioned(
        bottom: math.max(
          16 + math.max(m.padding.bottom, m.viewInsets.bottom),
          composerClearance(context),
        ),
        left: 16 + m.padding.left,
        right: 16 + m.padding.right,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: IgnorePointer(
              ignoring: _exiting,
              child: Focus(
                onKeyEvent: _key,
                onFocusChange: (value) {
                  focused = value;
                  widget.controller.pause(hovered || focused);
                },
                child: RaftHoverRegion(
                  onEnter: (_) {
                    hovered = true;
                    widget.controller.pause(true);
                  },
                  onExit: (_) {
                    hovered = false;
                    widget.controller.pause(focused);
                  },
                  child: AnimatedBuilder(
                    animation: curved,
                    builder: (context, child) => FadeTransition(
                      opacity: curved,
                      child: Transform.translate(
                        offset: _drag,
                        child: Transform.scale(
                          scale: _exiting
                              ? .99 + .01 * curved.value
                              : .97 + .03 * curved.value,
                          child: child,
                        ),
                      ),
                    ),
                    child: toast,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    child: widget.child,
  );
}
