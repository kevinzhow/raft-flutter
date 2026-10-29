// Small status primitives: Badge (raft-ui `badge` recipe), and the Web
// client's StatusDot / AttentionDot / CheckMarker (packages/web/src/components
// /ui/*.tsx — plain Tailwind classes, resolved in the comments below).

import 'package:flutter/material.dart';

import 'raft/css_box.dart' show raftControlBorderPx;
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/progress.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/recipe_router.dart' show resolveRecipeClasses;
import 'recipes/skeleton.g.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

export 'raft/badge.dart' show RaftBadge;
export 'raft/status.dart'
    show RaftActivityTone, RaftAttentionDot, RaftStatusDot, RaftStatusDotSize;
export 'recipes/badge.g.dart'
    show RaftBadgeRecipeAppearance, RaftBadgeRecipeVariant;
export 'recipes/progress.g.dart'
    show RaftProgressRecipeVariant, RaftProgressRecipeSize;

/// Tailwind default-palette colours used by Web JSX classes (not raft-ui
/// tokens). Values are Tailwind v4 oklch → sRGB (tool/recipes/css-of.mjs).
abstract final class RaftWebPalette {
  /// `bg-gray-50` = oklch(98.5% 0.002 247.839).
  static const gray50 = Color(0xFFF9FAFB);

  /// `bg-gray-300` = oklch(87.2% 0.01 258.338), message departure badge.
  static const gray300 = Color(0xFFD1D5DC);

  /// `bg-gray-400` = oklch(70.7% 0.022 261.325).
  static const gray400 = Color(0xFF99A1AF);

  /// `text-green-700` = oklch(52.7% 0.154 150.069) (billing Included checks).
  static const green700 = Color(0xFF008236);

  /// `text-neutral-500` = oklch(55.6% 0 0).
  static const neutral500 = Color(0xFF737373);
}

/// Web `ProgressBar` (product labels over raft-ui `Progress`): optional
/// label / percent row (`mb-1 flex justify-between text-xs font-mono
/// text-foreground-muted theme-brutal:text-black/60`) and the recipe track +
/// indicator. Indeterminate ([value] null) renders the `w-1/2` stripe; in the
/// Raft look it runs raft-ui's `raft-progress-indeterminate` sweep (1.4s,
/// `ease-in-out`). With the system's reduced-motion setting the stripe rests at
/// the start of the sweep like every other loop in the client (the Web
/// reference is captured with animations disabled, which is that frame). The
/// frozen Elegant and Brutal looks keep the static stripe they always drew.
class RaftProgressBar extends StatelessWidget {
  const RaftProgressBar({
    super.key,
    this.value,
    this.tone = RaftProgressRecipeVariant.accent,
    this.label,
    this.showPercent = false,
    this.size = RaftProgressRecipeSize.md,
  });

  /// 0–100; null = indeterminate.
  final double? value;

  /// Web tones: pink → accent, cyan → information, lime → success,
  /// orange → warning.
  final RaftProgressRecipeVariant tone;
  final String? label;
  final bool showPercent;
  final RaftProgressRecipeSize size;

  /// raft-ui 0.7 `progress` under the product `ProgressBar`: `mb-1.5` header
  /// (`text-footnote font-semibold` label, `font-mono text-mono-meta
  /// text-foreground-hint` value), an 8px `fill-muted` sticker-radius track and
  /// an indicator ringed in sticker-ink (info for cyan / pink, success, warning).
  Widget _buildRaft(BuildContext context, RaftTokens t) {
    final ui = t.ui;
    final indeterminate = value == null || value!.isNaN;
    final pct = indeterminate ? 0.0 : value!.clamp(0, 100).toDouble();
    final radius = BorderRadius.circular(t.size('radius.sticker', fallback: 4));
    final fill = switch (tone) {
      RaftProgressRecipeVariant.success => ui.success,
      RaftProgressRecipeVariant.warning => ui.warning,
      RaftProgressRecipeVariant.danger => ui.danger,
      _ => ui.info,
    };
    final height = switch (size) {
      RaftProgressRecipeSize.sm => 6.0,
      RaftProgressRecipeSize.lg => 10.0,
      _ => 8.0,
    };
    final ring = raftControlBorderPx(context, 1.5);
    final track = Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(color: ui.fillMuted, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _wrapSweep(
            indeterminate,
            FractionallySizedBox(
              widthFactor: indeterminate ? .5 : pct / 100,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: fill, borderRadius: radius),
                position: DecorationPosition.background,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: ui.stickerInk, width: ring),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final bar = Semantics(
      label: label,
      value: indeterminate ? null : '${pct.round()}%',
      child: track,
    );
    if (label == null && !(showPercent && !indeterminate)) return bar;
    final header = Row(
      children: [
        Expanded(
          child: label == null
              ? const SizedBox.shrink()
              : Text(
                  label!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: t.scale(
                    RaftTypeScale.footnote,
                    weight: FontWeight.w600,
                    color: ui.foreground,
                  ),
                ),
        ),
        if (showPercent && !indeterminate)
          Text(
            '${pct.round()}%',
            style: t.scale(
              RaftTypeScale.monoMeta,
              mono: true,
              color: ui.foregroundHint,
            ),
          ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, const SizedBox(height: 6), bar],
    );
  }

  /// The Raft look's indeterminate stripe sweeps; a determinate bar is as is.
  static Widget _wrapSweep(bool indeterminate, Widget stripe) =>
      indeterminate ? _IndeterminateSweep(child: stripe) : stripe;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final raft = t.option('progress.style', or: 'recipe') == 'raft';
    // The label row is where the Raft bar differs; a bare track keeps the
    // recipe box (the usage cards size their rows around it, see
    // text_scale_audit runtimeUsageCardPreview).
    if (raft && (label != null || showPercent)) {
      return _buildRaft(context, t);
    }
    final rt = t.recipeTokens;
    final indeterminate = value == null || value!.isNaN;
    final pct = indeterminate ? 0.0 : value!.clamp(0, 100).toDouble();
    final s = RaftProgressRecipe.resolve(
      theme: t.recipeTheme,
      variant: tone,
      size: size,
      states: t.recipeStates(
        extra: [
          'group/progress:data-size=${size.css}',
          if (pct >= 100) 'group/progress:data-complete',
        ],
      ),
      tokens: rt,
    );
    // The indicator and track inherit Progress's local CSS variables. Resolve
    // their classes together with the root declarations before painting;
    // resolving an isolated slot loses --progress-color in the dark glow.
    RaftSlotStyle inheritRoot(RaftSlotStyle slot) => resolveRecipeClasses(
      {...s.root.classes, ...slot.classes},
      t.recipeStates(
        extra: [
          'group/progress:data-size=${size.css}',
          if (pct >= 100) 'group/progress:data-complete',
        ],
      ),
      rt,
    );
    final trackStyle = inheritRoot(s.track);
    final indicatorStyle = inheritRoot(s.indicator);
    final indicator = RaftRecipeBox(style: indicatorStyle, tokens: rt);
    final track = RaftRecipeBox(
      style: trackStyle,
      tokens: rt,
      width: double.infinity,
      // Source dark determinate tracks allow the indicator's outer glow.
      clip: !(t.dark && !indeterminate),
      child: Align(
        alignment: Alignment.centerLeft,
        child: raft && indeterminate
            ? _IndeterminateSweep(
                child: FractionallySizedBox(
                  widthFactor: .5,
                  heightFactor: 1,
                  child: indicator,
                ),
              )
            : FractionallySizedBox(
                widthFactor: indeterminate ? .5 : pct / 100,
                heightFactor: 1,
                child: indicator,
              ),
      ),
    );
    final bar = Semantics(
      label: label,
      value: indeterminate ? null : '${pct.round()}%',
      child: track,
    );
    if (label == null && !(showPercent && !indeterminate)) return bar;
    final header = DefaultTextStyle.merge(
      style: TextStyle(
        fontFamily: t.monoFont,
        fontSize: 12,
        height: 16 / 12,
        color: t.semantic.foregroundMuted,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label ?? '',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showPercent && !indeterminate) Text('${pct.round()}%'),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, const SizedBox(height: 4), bar],
    );
  }
}

/// raft-ui `@keyframes raft-progress-indeterminate` on the half-width stripe:
/// `translateX(-65%) scaleX(.35)` to `(70%) (.6)` to `(185%) (.35)` of its own
/// width, origin left, `ease-in-out` per leg, 1.4s per loop. With reduced motion
/// it does not run: the stripe rests un-transformed (the `w-1/2` base style the
/// Web shows when animations are disabled). The track clips it.
class _IndeterminateSweep extends StatefulWidget {
  const _IndeterminateSweep({required this.child});
  final Widget child;

  @override
  State<_IndeterminateSweep> createState() => _IndeterminateSweepState();
}

class _IndeterminateSweepState extends State<_IndeterminateSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this);
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _loop.stop();
      return;
    }
    if (_loop.isAnimating) return;
    _loop.duration = const Duration(milliseconds: 1400);
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
    _loop.repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  static const _ease = Curves.easeInOut;

  @override
  Widget build(BuildContext context) =>
      _reduced ? widget.child : RepaintBoundary(child: _sweep());

  Widget _sweep() => AnimatedBuilder(
    animation: _loop,
    child: widget.child,
    builder: (context, child) {
      final v = _loop.value;
      final leg = v < .5;
      final k = _ease.transform(leg ? v * 2 : (v - .5) * 2);
      final from = leg ? -.65 : .70, to = leg ? .70 : 1.85;
      final scaleFrom = leg ? .35 : .6, scaleTo = leg ? .6 : .35;
      final shift = from + (to - from) * k;
      final scale = scaleFrom + (scaleTo - scaleFrom) * k;
      // `translateX(%)` is a fraction of the stripe's own (unscaled) width,
      // so the shift wraps the scale; neither needs the track's width.
      return FractionalTranslation(
        key: const ValueKey('progress-indeterminate-shift'),
        translation: Offset(shift, 0),
        child: Transform(
          key: const ValueKey('progress-indeterminate-sweep'),
          alignment: Alignment.centerLeft,
          transform: Matrix4.diagonal3Values(scale, 1, 1),
          child: child,
        ),
      );
    },
  );
}

enum RaftSkeletonVariant {
  /// `h-3 bg-black/10` text-line stand-in (square).
  line,

  /// `bg-black/10` filled block (square).
  block,

  /// `rounded-full border-2 border-black bg-black/5` avatar stand-in.
  circle,
}

/// Web `Skeleton` (`animate-pulse` + variant classes). The pulse is
/// Tailwind's `pulse` (opacity 1 → .5 → 1, 2s cubic-bezier(.4,0,.6,1));
/// reduced motion keeps it at full opacity.
class RaftSkeleton extends StatefulWidget {
  const RaftSkeleton({
    super.key,
    this.variant = RaftSkeletonVariant.block,
    this.width,
    this.height,
    this.themed = false,
    this.fromRecipe = false,
  });

  final RaftSkeletonVariant variant;

  /// The raft-ui `Skeleton` itself rather than the Web app's own ui/Skeleton:
  /// the recipe's `data-variant` fill and radius, held at the first frame of
  /// `animate-pulse` like Playwright's disabled animations (no pulse).
  final bool fromRecipe;

  /// The raft-ui `Skeleton` defaults (Elegant: `rounded-full` /
  /// `rounded-md` `bg-foreground-strong/8`); the sidebar rows pass `bg-ink-10`
  /// squares in every theme instead.
  final bool themed;

  /// Explicit size classes (`w-*`, `h-*`, `size-*`); `line` defaults to h-3.
  final double? width, height;

  @override
  State<RaftSkeleton> createState() => _RaftSkeletonState();
}

class _RaftSkeletonState extends State<RaftSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.fromRecipe || MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = 0;
    } else if (!pulse.isAnimating) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
      pulse.repeat();
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  static const _curve = Cubic(.4, 0, .6, 1);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (widget.fromRecipe) {
      final rt = t.recipeTokens;
      final variant = switch (widget.variant) {
        RaftSkeletonVariant.line => RaftSkeletonRecipeVariant.line,
        RaftSkeletonVariant.block => RaftSkeletonRecipeVariant.block,
        RaftSkeletonVariant.circle => RaftSkeletonRecipeVariant.circle,
      };
      return ExcludeSemantics(
        child: RaftRecipeBox(
          style: RaftSkeletonRecipe.resolve(
            theme: t.recipeTheme,
            variant: variant,
            states: t.recipeStates(extra: ['data-variant=${variant.css}']),
            tokens: rt,
          ).root,
          tokens: rt,
          width: widget.width,
          height: widget.height,
          applyOpacity: false,
        ),
      );
    }
    final avatar = widget.variant == RaftSkeletonVariant.circle;
    final themed = widget.themed && !avatar;
    final circular =
        avatar && t.option('skeleton.avatarShape', or: 'circle') == 'circle';
    final fill = t.colors[themed ? 'layer-skeleton-themed' : 'layer-skeleton']!;
    final opacity = t.size(
      themed
          ? 'opacity.skeletonThemed'
          : avatar
          ? 'opacity.skeletonAvatar'
          : 'opacity.skeleton',
      fallback: 1,
    );
    final radius = t.size(
      avatar
          ? 'radius.skeletonAvatar'
          : themed
          ? widget.variant == RaftSkeletonVariant.line
                ? 'radius.skeletonThemedLine'
                : 'radius.skeletonThemedBlock'
          : widget.variant == RaftSkeletonVariant.line
          ? 'radius.skeletonLine'
          : 'radius.skeletonBlock',
      fallback: 0,
    );
    final stroke = avatar ? t.size('stroke.skeletonAvatar', fallback: 2) : 0.0;
    final box = Container(
      width: widget.width,
      height:
          widget.height ??
          (widget.variant == RaftSkeletonVariant.line ? 12 : null),
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        color: fill.withValues(alpha: fill.a * opacity),
        borderRadius: circular ? null : BorderRadius.circular(radius),
        border: stroke > 0
            ? Border.all(
                color: t.colors['line-skeleton-avatar']!,
                width: stroke,
              )
            : null,
      ),
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          // @keyframes pulse { 50% { opacity: .5 } }
          final v = pulse.value;
          final half = v < .5 ? v * 2 : (1 - v) * 2;
          return Opacity(
            opacity: 1 - .5 * _curve.transform(half),
            child: child,
          );
        },
        child: box,
      ),
    );
  }
}

/// Web `SkeletonRow`: optional circle avatar + a column of `line` bars
/// (`flex min-w-0 flex-1 flex-col gap-1.5`).
class RaftSkeletonRow extends StatelessWidget {
  const RaftSkeletonRow({
    super.key,
    this.avatar = false,
    this.avatarSize = 18,
    this.gap = 0,
    this.lineWidths = const [null, null],
    this.lineFractions,
  });

  final bool avatar;
  final double avatarSize;

  /// Row `gap-*` from the caller's className.
  final double gap;

  /// Fixed line widths (`w-32` = 128); null entries stretch.
  final List<double?> lineWidths;

  /// Fractional widths (`w-3/4`, `w-1/2`); used when non-null.
  final List<double>? lineFractions;

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[
      if (lineFractions != null)
        for (final f in lineFractions!)
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: f,
            child: const RaftSkeleton(variant: RaftSkeletonVariant.line),
          )
      else
        for (final w in lineWidths)
          Align(
            alignment: Alignment.centerLeft,
            child: RaftSkeleton(variant: RaftSkeletonVariant.line, width: w),
          ),
    ];
    return Row(
      children: [
        if (avatar) ...[
          RaftSkeleton(
            variant: RaftSkeletonVariant.circle,
            width: avatarSize,
            height: avatarSize,
          ),
          SizedBox(width: gap),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                lines[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
