// Small status primitives: Badge (raft-ui `badge` recipe), and the Web
// client's StatusDot / AttentionDot / CheckMarker (packages/web/src/components
// /ui/*.tsx — plain Tailwind classes, resolved in the comments below).
import 'package:flutter/material.dart';

import 'icons.dart';
import 'recipe_surface.dart';
import 'recipes/badge.g.dart';
import 'recipes/checkbox.g.dart';
import 'recipes/progress.g.dart';
import 'recipes/checkbox_indicator.g.dart';
import 'design_primitives.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/recipe_utilities.g.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

export 'recipes/badge.g.dart'
    show RaftBadgeRecipeAppearance, RaftBadgeRecipeVariant;
export 'recipes/checkbox.g.dart' show RaftCheckboxRecipeSize;
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

  /// `text-neutral-500` = oklch(55.6% 0 0).
  static const neutral500 = Color(0xFF737373);
}

/// raft-ui `Badge`: `<span>` with the `badge` recipe root.
class RaftBadge extends StatefulWidget {
  const RaftBadge({
    super.key,
    required this.label,
    this.appearance = RaftBadgeRecipeAppearance.solid,
    this.variant = RaftBadgeRecipeVariant.default_,
    this.uppercase = false,
    this.leading,
    this.onPressed,
  });

  final String label;
  final RaftBadgeRecipeAppearance appearance;
  final RaftBadgeRecipeVariant variant;
  final bool uppercase;
  final Widget? leading;

  /// Rendered as a `<button>` (`render={<button/>}`): enables hover filter.
  final VoidCallback? onPressed;

  @override
  State<RaftBadge> createState() => _RaftBadgeState();
}

class _RaftBadgeState extends State<RaftBadge> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final interactive = widget.onPressed != null;
    final s = RaftBadgeRecipe.resolve(
      theme: t.recipeTheme,
      appearance: widget.appearance,
      variant: widget.variant,
      uppercase: widget.uppercase,
      // `enabled:hover:` only matches a real <button>.
      states: t.recipeStates(
        hovered: hovered && interactive,
        extra: [if (interactive) 'enabled'],
      ),
      tokens: rt,
    ).root;
    final upper = s.textTransform == 'uppercase';
    Widget badge = RaftRecipeBox(
      style: s,
      tokens: rt,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            SizedBox(width: s.columnGap ?? 0),
          ],
          Flexible(
            child: Text(
              upper ? widget.label.toUpperCase() : widget.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
    final brightness = _brightness(s['filter']);
    if (brightness != null) {
      badge = ColorFiltered(
        colorFilter: ColorFilter.matrix([
          brightness, 0, 0, 0, 0, //
          0, brightness, 0, 0, 0, //
          0, 0, brightness, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: badge,
      );
    }
    if (!interactive) return badge;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(onTap: widget.onPressed, child: badge),
      ),
    );
  }
}

double? _brightness(CssValue? v) {
  final m = RegExp(r'brightness\(([\d.]+)(%?)\)').firstMatch('$v');
  if (m == null) return null;
  final n = double.parse(m.group(1)!);
  return m.group(2) == '%' ? n / 100 : n;
}

enum RaftStatusDotSize {
  /// `size-2`
  sm(8),

  /// `size-2.5`
  md(10),

  /// `size-[11px]`
  lg(11);

  const RaftStatusDotSize(this.px);
  final double px;
}

/// Agent activity → dot tone (`getActivityDotClass`, web utils/activity.ts).
enum RaftActivityTone { online, thinking, working, error, offline }

/// Web `StatusDot`: `inline-block shrink-0 rounded-full border
/// border-line-strong theme-brutal:border-black` + size + tone.
class RaftStatusDot extends StatelessWidget {
  const RaftStatusDot({
    super.key,
    this.color,
    this.activity,
    this.external = false,
    this.size = RaftStatusDotSize.md,
  });

  /// Explicit fill (Web `tone`, e.g. `bg-brutal-lime`); default `bg-gray-400`.
  final Color? color;
  final RaftActivityTone? activity;

  /// External agents: neutral `bg-brutal-cyan` regardless of activity.
  final bool external;
  final RaftStatusDotSize size;

  static Color activityColor(RaftTokens t, RaftActivityTone a) => switch (a) {
    RaftActivityTone.online => t.product.brutalLime,
    RaftActivityTone.thinking ||
    RaftActivityTone.working => t.product.statusBusy,
    RaftActivityTone.error => t.product.brutalOrange,
    RaftActivityTone.offline => RaftWebPalette.gray400,
  };

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fill = external
        ? t.product.brutalCyan
        : activity != null
        ? activityColor(t, activity!)
        : color ?? RaftWebPalette.gray400;
    return Container(
      width: size.px,
      height: size.px,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: t.brutal ? RaftPrimitiveColors.black : t.semantic.lineStrong,
        ),
      ),
    );
  }
}

/// Web `AttentionDot`. Brutal: `border border-black` + `bg-brutal-pink`
/// (or the warning `bg-brutal-orange`); elegant: borderless `bg-accent`
/// (`bg-warning` for warning tones).
class RaftAttentionDot extends StatelessWidget {
  const RaftAttentionDot({
    super.key,
    this.compact = false,
    this.warning = false,
  });

  /// `sm` = `size-1` (4px); default `lg` = `size-2.5` (10px).
  final bool compact;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = compact ? 4.0 : 10.0;
    final fill = t.brutal
        ? (warning ? t.product.brutalOrange : t.product.brutalPink)
        : (warning ? t.semantic.warning : t.colors['accent']!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: t.brutal ? Border.all(color: RaftPrimitiveColors.black) : null,
      ),
    );
  }
}

enum RaftCheckMarkerSize {
  /// `size-3.5`, Check 10px stroke 4
  sm(14, 10, 4),

  /// `size-4`, Check 12px stroke 4
  md(16, 12, 4),

  /// `size-5`, Check 13px stroke 3
  lg(20, 13, 3);

  const RaftCheckMarkerSize(this.box, this.icon, this.stroke);
  final double box, icon, stroke;
}

/// Web `CheckMarker` (`check-marker-brutal inline-flex items-center
/// justify-center border border-line-strong theme-brutal:border-2
/// theme-brutal:border-black`).
class RaftCheckMarker extends StatelessWidget {
  const RaftCheckMarker({
    super.key,
    required this.checked,
    this.circle = false,
    this.size = RaftCheckMarkerSize.sm,
    this.yellow = false,
    this.disabled = false,
    this.previewOnHover = false,
    this.hovered = false,
  });

  final bool checked, circle, yellow, disabled, previewOnHover;

  /// Parent `group` hover (for [previewOnHover]).
  final bool hovered;
  final RaftCheckMarkerSize size;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = t.semantic;
    final Color fill;
    final Color ink;
    if (checked) {
      fill = yellow
          ? (t.brutal ? t.product.softSignal : s.primarySoft)
          : (t.brutal ? RaftPrimitiveColors.black : s.foregroundStrong);
      ink = yellow
          ? (t.brutal ? RaftPrimitiveColors.black : s.primaryStrong)
          : (t.brutal ? RaftPrimitiveColors.white : s.foregroundInverse);
    } else {
      fill = t.brutal ? RaftPrimitiveColors.white : s.layerPanel;
      ink = previewOnHover && hovered
          ? (t.brutal
                ? RaftPrimitiveColors.black.withValues(alpha: .2)
                : s.foregroundMuted)
          : Colors.transparent;
    }
    Widget box = Container(
      width: size.box,
      height: size.box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        border: Border.all(
          color: t.brutal ? RaftPrimitiveColors.black : s.lineStrong,
          width: t.brutal ? 2 : 1,
        ),
      ),
      child: checked || previewOnHover
          ? RaftIcon(
              RaftGlyph.check,
              size: size.icon,
              strokeWidth: size.stroke,
              color: ink,
            )
          : null,
    );
    if (disabled) box = Opacity(opacity: .5, child: box);
    return ExcludeSemantics(child: box);
  }
}

/// raft-ui `Checkbox` (`checkbox` recipe; brutal draws the
/// `checkboxIndicator` box with a lucide Check, elegant draws the
/// `ElegantCheckboxGraphic` rect + `CheckboxCheckIcon`).
class RaftCheckbox extends StatelessWidget {
  const RaftCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.size = RaftCheckboxRecipeSize.sm,
    this.primary = false,
    this.circle = false,
    this.flatWhenChecked = false,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final RaftCheckboxRecipeSize size;

  /// `data-checked:shadow-none` of the MessageMultiSelectCheckbox slot.
  final bool flatWhenChecked;

  /// `color="primary"` / `variant="primary"`: yellow fill.
  final bool primary;
  final bool circle;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final disabled = onChanged == null;
    return RaftInteractive(
      onPressed: disabled ? null : () => onChanged!(!value),
      button: false,
      checked: value,
      semanticLabel: semanticLabel,
      builder: (context, st) {
        final states = t.recipeStates(
          hovered: st.hovered,
          pressed: st.pressed,
          focusVisible: st.focusVisible,
          extra: [
            if (value) ...['data-checked', 'group/checkbox:data-checked'],
            if (disabled) ...['data-disabled', 'group/checkbox:data-disabled'],
            if (st.hovered) 'group/checkbox:hover',
            if (st.focusVisible) 'group/checkbox:focus-visible',
          ],
        );
        final c = RaftCheckboxRecipe.resolve(
          theme: t.recipeTheme,
          size: size,
          variant: primary
              ? RaftCheckboxRecipeVariant.primary
              : RaftCheckboxRecipeVariant.default_,
          states: states,
          tokens: rt,
        );
        if (t.brutal) {
          final i = RaftCheckboxIndicatorRecipe.resolve(
            theme: t.recipeTheme,
            shape: circle
                ? RaftCheckboxIndicatorRecipeShape.circle
                : RaftCheckboxIndicatorRecipeShape.square,
            size: RaftCheckboxIndicatorRecipeSize.values.byName(size.name),
            fill: primary
                ? RaftCheckboxIndicatorRecipeFill.yellow
                : RaftCheckboxIndicatorRecipeFill.black,
            checked: value,
            disabled: disabled,
            states: states,
            tokens: rt,
          ).root;
          final svg = i.target("& svg:not([class*='size-'])");
          final stroke = i.target('& svg')?.length('stroke-width');
          return RaftRecipeBox(
            style: c.root,
            tokens: rt,
            child: RaftRecipeBox(
              style: i,
              tokens: rt,
              alignment: Alignment.center,
              child: value
                  ? Builder(
                      builder: (context) => RaftIcon(
                        RaftGlyph.check,
                        size: svg?.width ?? 10,
                        strokeWidth: stroke ?? 4,
                        color: DefaultTextStyle.of(context).style.color,
                      ),
                    )
                  : null,
            ),
          );
        }
        final fill =
            RaftColorRef.fromCss(c.outerRect['fill'])?.resolve(rt) ??
            t.semantic.layerPanel;
        final ink = c.mark.color?.resolve(rt) ?? t.semantic.foregroundInverse;
        return RaftRecipeBox(
          style: c.root,
          tokens: rt,
          // `circle` is the SVG `rx` = half the 16-unit viewBox scaled to the
          // box (a full circle at every size); square keeps `rounded-[3px]`.
          decorationOverride: (d) => d.copyWith(
            color: fill,
            borderRadius: BorderRadius.circular(circle ? 999 : 3),
            boxShadow: flatWhenChecked && value ? const [] : d.boxShadow,
          ),
          alignment: Alignment.center,
          child: value
              ? CustomPaint(
                  size: const Size(10, 8),
                  painter: _CheckMarkPainter(ink),
                )
              : null,
        );
      },
    );
  }
}

/// `CheckboxCheckIcon`: `M1 3.5L4 6.5L9 1.5` in a 10×8 box, stroke 1,
/// round caps and joins.
class _CheckMarkPainter extends CustomPainter {
  const _CheckMarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(1, 3.5)
        ..lineTo(4, 6.5)
        ..lineTo(9, 1.5),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckMarkPainter old) => old.color != color;
}

/// Web `ProgressBar` (product labels over raft-ui `Progress`): optional
/// label / percent row (`mb-1 flex justify-between text-xs font-mono
/// text-foreground-muted theme-brutal:text-black/60`) and the recipe track +
/// indicator. Indeterminate renders the `w-1/2` stripe; its
/// Indeterminate motion remains a Flutter gap: Source defines 1.4s brutal
/// and 1.6s elegant keyframes; this widget currently renders a static stripe.
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

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
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
    RaftSlotStyle inheritRoot(RaftSlotStyle slot) =>
        raftRecipeEngine.resolveSlot(
          [
            for (final name in {...s.root.classes, ...slot.classes})
              raftRecipeUtilities.indexWhere((utility) => utility.name == name),
          ],
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
        child: FractionallySizedBox(
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
        color: t.brutal
            ? RaftPrimitiveColors.black.withValues(alpha: .6)
            : t.semantic.foregroundMuted,
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
  });

  final RaftSkeletonVariant variant;

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
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = 0;
    } else if (!pulse.isAnimating) {
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
    const black = RaftPrimitiveColors.black;
    final box = switch (widget.variant) {
      RaftSkeletonVariant.line => Container(
        width: widget.width,
        height: widget.height ?? 12,
        // CSS black/10 is stored in an 8-bit alpha channel before compositing.
        // Preserve that quantization (26/255), rather than rounding the final
        // floating-point white/black blend to 230 instead of source 229.
        color: black.withAlpha(26),
      ),
      RaftSkeletonVariant.block => Container(
        width: widget.width,
        height: widget.height,
        // CSS black/10 is stored in an 8-bit alpha channel before compositing.
        // Preserve that quantization (26/255), rather than rounding the final
        // floating-point white/black blend to 230 instead of source 229.
        color: black.withAlpha(26),
      ),
      RaftSkeletonVariant.circle => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: black.withValues(alpha: .05),
          border: Border.all(color: black, width: 2),
        ),
      ),
    };
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
