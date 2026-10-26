// raft-ui `Switch` (dist `switchRecipe`), painted in the Raft look from the generated recipe (raft_theme
// recipes/switch_recipe.g.dart): the root slot is the 50x30 round track (`border-[1.5px]`, `p-[2.5px]`, `fill-muted`
// off, `brand` with the `sticker-edge` ring on, `foreground-disabled` ink when disabled, `shadow-focus` on keyboard
// focus) and the thumb slot the 22px disc with its own `0 0 0 1.5px` ring that translates 20px when checked. Sizes,
// colours, rings, translate and the transition durations and curves are read from the resolved slots; nothing here
// restates them. The frozen Elegant and Brutal paint lives in switch_frozen.dart.
import 'package:flutter/material.dart';

import '../design_primitives.dart';
import '../hover_region.dart';
import '../primitive_tokens.dart';
import '../recipe_surface.dart'
    show RaftRecipeBinding, RaftSlotPaint, raftCssColorLerp;
import '../recipes/recipe_runtime.dart' show RaftSlotStyle, RaftTokenResolver;
import '../recipes/switch_recipe.g.dart';
import '../theme.dart';
import 'css_box.dart';

part 'switch_frozen.dart';

/// `size` of the legacy looks' switch; the Raft look has the one 50x30 switch and ignores it.
enum RaftSwitchSize { sm, md }

/// Controlled raft-ui `Switch`, the one switch of the client. A null [onChanged] (or `enabled: false`) is `disabled` and never fires.
class RaftSwitch extends StatefulWidget {
  const RaftSwitch({
    super.key,
    required this.value,
    this.size = RaftSwitchSize.sm,
    this.onChanged,
    this.enabled = true,
    this.semanticLabel,
    this.semanticDescription,
    this.focusNode,
    this.minimumTargetSize,
  });

  final bool value, enabled;
  final RaftSwitchSize size;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel, semanticDescription;
  final FocusNode? focusNode;

  /// Layout minimum around the 50x30 track (a larger tap target that does take space); null adds none.
  final double? minimumTargetSize;

  @override
  State<RaftSwitch> createState() => _RaftSwitchState();
}

class _RaftSwitchState extends State<RaftSwitch> {
  bool showHover = false;

  void hoverChanged(bool value) {
    if (mounted && value != showHover) setState(() => showHover = value);
  }

  bool get _enabled => widget.enabled && widget.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final size = widget.size;
    final onChanged = widget.onChanged;
    final semanticLabel = widget.semanticLabel;
    final semanticDescription = widget.semanticDescription;
    final focusNode = widget.focusNode;
    final minimumTargetSize = widget.minimumTargetSize;
    final t = RaftTokens.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final disabled = !_enabled;
    // Touch density adds no layout (the `after:` hit slop takes no space): [RaftInteractive] extends the 48px
    // hit target and semantics rect around the 50x30 track.
    final min =
        minimumTargetSize ??
        (RaftDensityScope.of(context) == RaftDensity.touch
            ? t.size('size.touchLayoutMin', fallback: 0)
            : 0);
    return RaftInteractive(
      onPressed: disabled ? null : () => onChanged!(!value),
      button: false,
      onShowHoverHighlight: hoverChanged,
      focusNode: focusNode,
      semanticLabel: semanticLabel,
      builder: (context, st) {
        final Widget control = t.isRaftLook
            ? _RecipeSwitch(
                tokens: t,
                value: value,
                disabled: disabled,
                focusVisible: st.focusVisible,
                reduced: reduced,
              )
            : _frozenSwitchControl(
                context,
                t: t,
                size: size,
                value: value,
                disabled: disabled,
                showHover: showHover,
                st: st,
                reduced: reduced,
                min: min,
                semanticDescription: semanticDescription,
              );
        if (!t.isRaftLook) return control;
        Widget result = Semantics(
          toggled: value,
          hint: semanticDescription,
          child: ExcludeSemantics(child: control),
        );
        if (min > 0) {
          result = ConstrainedBox(
            constraints: BoxConstraints(minWidth: min, minHeight: min),
            child: Center(widthFactor: 1, heightFactor: 1, child: result),
          );
        }
        return result;
      },
    );
  }
}

/// One recipe slot read as the box [RaftCssBox] paints.
@immutable
class _SlotPaint {
  const _SlotPaint({
    required this.fill,
    required this.border,
    required this.borderColor,
    required this.rings,
    required this.translate,
  });

  factory _SlotPaint.of(
    BuildContext context,
    RaftSlotStyle slot,
    RaftTokenResolver rt,
  ) {
    final width = slot.borderWidth.top;
    return _SlotPaint(
      fill: slot.backgroundColor?.resolve(rt),
      border: width > 0 ? raftControlBorderPx(context, width) : 0,
      borderColor: width > 0 ? slot.borderColor?.resolve(rt) : null,
      // Every layer, as CSS interpolates `box-shadow` by position; zero-spread layers paint nothing.
      rings: [
        for (final layer in slot.cssShadows(rt))
          if (!layer.inset) RaftRing(layer.spread, layer.color),
      ],
      translate: slot.translate?.dx ?? 0,
    );
  }

  final Color? fill, borderColor;
  final double border, translate;
  final List<RaftRing> rings;

  static _SlotPaint lerp(_SlotPaint a, _SlotPaint b, double t) {
    final count = a.rings.length > b.rings.length
        ? a.rings.length
        : b.rings.length;
    // CSS pads the shorter shadow list with transparent zero-spread layers.
    RaftRing absent(RaftRing other) =>
        RaftRing(0, other.color.withValues(alpha: 0));
    RaftRing ring(int i) {
      final x = i < a.rings.length ? a.rings[i] : absent(b.rings[i]);
      final y = i < b.rings.length ? b.rings[i] : absent(a.rings[i]);
      return RaftRing(
        x.spread + (y.spread - x.spread) * t,
        raftCssColorLerp(x.color, y.color, t)!,
      );
    }

    return _SlotPaint(
      fill: raftCssColorLerp(a.fill, b.fill, t),
      border: a.border + (b.border - a.border) * t,
      borderColor: raftCssColorLerp(a.borderColor, b.borderColor, t),
      rings: [for (var i = 0; i < count; i++) ring(i)],
      translate: a.translate + (b.translate - a.translate) * t,
    );
  }

  List<RaftRing> get painted => [
    for (final r in rings)
      if (r.spread > 0) r,
  ];

  /// An opaque fill and opaque rings paint each ring as a whole rounded rect under the fill (no AA seam).
  bool get opaque =>
      (fill?.a ?? 1) == 1 &&
      rings.every((r) => r.spread <= 0 || r.color.a == 1);
}

/// The Raft look's switch: the `switchRecipe` root and thumb slots for the off and on state, blended by the
/// transition progress the slots themselves declare.
class _RecipeSwitch extends StatelessWidget {
  const _RecipeSwitch({
    required this.tokens,
    required this.value,
    required this.disabled,
    required this.focusVisible,
    required this.reduced,
  });

  final RaftTokens tokens;
  final bool value, disabled, focusVisible, reduced;

  @override
  Widget build(BuildContext context) {
    final rt = tokens.recipeTokens;
    RaftSwitchRecipeStyle resolve(bool checked) => RaftSwitchRecipe.resolve(
      theme: tokens.recipeTheme,
      states: tokens.recipeStates(
        focusVisible: focusVisible,
        extra: [if (checked) 'data-checked', if (disabled) 'data-disabled'],
      ),
      tokens: rt,
    );
    final off = resolve(false);
    final on = resolve(true);
    final root = value ? on.root : off.root;
    final thumb = value ? on.thumb : off.thumb;
    final trackOff = _SlotPaint.of(context, off.root, rt);
    final trackOn = _SlotPaint.of(context, on.root, rt);
    final thumbOff = _SlotPaint.of(context, off.thumb, rt);
    final thumbOn = _SlotPaint.of(context, on.thumb, rt);
    final padding = root.padding;
    final width = root.width!, height = root.height!;
    final thumbWidth = thumb.width!, thumbHeight = thumb.height!;
    final colorDuration = reduced
        ? Duration.zero
        : root.transitionDuration ?? Duration.zero;
    final slideDuration = reduced
        ? Duration.zero
        : thumb.transitionDuration ?? Duration.zero;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value ? 1 : 0),
      duration: colorDuration,
      curve: root.transitionCurve ?? Curves.linear,
      builder: (context, colour, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value ? 1 : 0),
        duration: slideDuration,
        curve: thumb.transitionCurve ?? Curves.linear,
        builder: (context, slide, _) {
          final track = _SlotPaint.lerp(trackOff, trackOn, colour);
          // The thumb's colours follow the value at once (`transition-transform` only); its translate slides.
          final disc = value ? thumbOn : thumbOff;
          final travel =
              thumbOff.translate +
              (thumbOn.translate - thumbOff.translate) * slide;
          return RaftCssBox(
            radius: height / 2,
            fill: track.fill,
            borderWidth: track.border,
            borderColor: track.borderColor,
            opaqueRings: track.opaque,
            rings: track.painted,
            width: width,
            height: height,
            padding: padding,
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: _snappedTravel(travel, track.border + padding.left),
              ),
              child: RaftCssBox(
                radius: thumbHeight / 2,
                fill: disc.fill,
                opaqueRings: disc.opaque,
                rings: disc.painted,
                width: thumbWidth,
                height: thumbHeight,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Blink lays out in CSS px under an emulated device scale factor and paints the box snapped to whole CSS px
  /// (`19.5` paints at `20`); [RaftBorderSnap] mirrors that.
  static double _snappedTravel(double travel, double origin) =>
      RaftBorderSnap.emulatedDeviceScaleFactor
      ? (origin + travel).roundToDouble() - origin
      : travel;
}
