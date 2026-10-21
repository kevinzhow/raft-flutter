// raft-ui 0.7.1 `SegmentedControl`: a radio group on a `fill-muted` track (`rounded-[11px]`, 3px padding, 2px gap) whose
// items are 32px buttons. The checked item is the yellow sticker (brand fill, ink border, die-cut `sticker-edge` ring,
// bold); the others are `foreground-muted` text that takes the `fill-pressed` wash on hover. An item holds an optional
// 16px icon, a label and a mono count. A disabled group keeps the sticker and greys the ink.
import 'package:flutter/material.dart';

import '../control_typography.dart';
import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../text_scaling.dart' show RaftScaled;
import '../theme.dart';
import '../tokens/tokens.dart';
import 'css_box.dart';
import 'ui_tokens.dart';

/// Colours of one segment in one state.
class RaftSegmentColors {
  const RaftSegmentColors({
    required this.fill,
    required this.border,
    required this.foreground,
    this.ringEdge,
  });
  final Color fill, border, foreground;
  final Color? ringEdge;

  static RaftSegmentColors resolve(
    RaftUiColors ui, {
    required bool checked,
    required bool disabled,
    required bool hovered,
    required bool pressed,
  }) {
    const clear = Color(0x00000000);
    if (checked) {
      return RaftSegmentColors(
        fill: !disabled && (pressed || hovered)
            ? Color.alphaBlend(ui.stickerPressed, ui.brand)
            : ui.brand,
        border: ui.stickerInk,
        foreground: disabled ? ui.foregroundDisabled : ui.stickerInk,
        ringEdge: ui.stickerEdge,
      );
    }
    return RaftSegmentColors(
      fill: !disabled && hovered ? ui.fillPressed : clear,
      border: clear,
      foreground: disabled ? ui.foregroundDisabled : ui.foregroundMuted,
    );
  }
}

/// `SegmentedControlItem` with its `SegmentedControlLabel` and `SegmentedControlCount`. [onPressed] null is
/// `data-disabled`; [checked] is `data-checked`.
class RaftSegmentedItem extends StatelessWidget {
  const RaftSegmentedItem({
    super.key,
    required this.label,
    this.glyph,
    this.count,
    this.labelSuffix,
    this.checked = false,
    this.onPressed,
    this.height = 32,
    this.focusNode,
    this.tooltip,
  });

  final String label;
  final RaftGlyph? glyph;

  /// `SegmentedControlCount`: Space Mono 12.
  final String? count;

  /// A small mono note inside the label (`Save 12%`).
  final String? labelSuffix;
  final bool checked;
  final VoidCallback? onPressed;
  final double height;
  final FocusNode? focusNode;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final borderWidth = raftControlBorderPx(context, 1.5);
    final grows = RaftScaled.grows(context);
    final text = raftText(context, label);
    return RaftInteractive(
      onPressed: onPressed,
      focusNode: focusNode,
      button: false,
      checked: checked,
      tooltip: tooltip,
      semanticLabel: text,
      builder: (context, st) {
        final disabled = onPressed == null;
        final colors = RaftSegmentColors.resolve(
          ui,
          checked: checked,
          disabled: disabled,
          hovered: st.hovered,
          pressed: st.pressed,
        );
        final fg = colors.foreground;
        final labelStyle = RaftControlTypography.of(
          context,
          t.scale(
            RaftTypeScale.callout,
            weight: checked ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        );
        final children = <Widget>[
          if (glyph != null) ...[
            RaftIcon(glyph!, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          _Shrink(
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (labelSuffix != null) ...[
            const SizedBox(width: 6),
            Text(
              raftText(context, labelSuffix!),
              maxLines: 1,
              softWrap: false,
              style: RaftControlTypography.of(
                context,
                t.scale(
                  RaftTypeScale.monoMeta,
                  mono: true,
                  weight: FontWeight.w700,
                  color: fg.withValues(alpha: fg.a * .6),
                ),
              ),
            ),
          ],
          if (count != null) ...[
            const SizedBox(width: 6),
            // Chromium rounds Space Mono's ascent and descent at 12px, which seats the line box 1px higher.
            Transform.translate(
              offset: const Offset(0, -1),
              child: Text(
                count!,
                maxLines: 1,
                softWrap: false,
                style: RaftControlTypography.of(
                  context,
                  t.scale(
                    RaftTypeScale.monoMeta,
                    mono: true,
                    weight: FontWeight.w400,
                    color: fg,
                  ),
                ),
              ),
            ),
          ],
        ];
        // LimitedBox bounds an unbounded parent so the label can be Flexible; unlike a LayoutBuilder it keeps the
        // intrinsic sizes (IntrinsicHeight rows host segmented controls).
        Widget row(List<Widget> c) => LimitedBox(
          maxWidth: 4096,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final w in c) w is _Shrink ? Flexible(child: w.child) : w,
            ],
          ),
        );
        Widget box = RaftCssBox(
          // Raft's segment is `rounded-control` (8). The pre-theme app drew the
          // segment with `rounded-sm` (4) for Elegant and square for Brutal, and
          // 4 is what the contract carries as `radius.chip`; `radius.control`
          // would give Elegant 6 and miss the measurement. The chip token is used
          // for both looks because Brutal's chip is 0 and Raft keeps its own 8
          // through `radius.control` in the framed structure below.
          radius: t.option('segmented.frame', fallback: 'framed') == 'framed'
              ? t.size('radius.control', fallback: 8)
              : t.size('radius.chip', fallback: 4),
          fill: colors.fill,
          borderWidth: borderWidth,
          borderColor: colors.border,
          rings: [
            if (colors.ringEdge != null) RaftRing(1.5, colors.ringEdge!),
            if (st.focusVisible)
              for (final layer in ui.focusRing.layers)
                RaftRing(layer.spread, layer.color),
          ],
          height: grows ? null : height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: row(children),
        );
        if (grows) {
          box = ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: box,
          );
        }
        return box;
      },
    );
  }
}

/// The `SegmentedControl` track: `bg-fill-muted rounded-[11px] p-[3px] gap-0.5`, as wide as its items. The web
/// control is `flex-nowrap`; a track narrower than its items wraps them onto further lines instead of overflowing.
class RaftSegmentedTrack extends StatelessWidget {
  const RaftSegmentedTrack({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;

    // Two structures, chosen by the theme: raft-ui 0.7.1 wraps the segments in a
    // rounded, padded track; the pre-theme app drew a flat row of separate
    // segments with a gap. Replicating Elegant and Brutal means matching the
    // latter exactly, so the frame is a structural option rather than always on.
    final framed = t.option('segmented.frame', fallback: 'framed') == 'framed';

    if (!framed) {
      // a57b9dab separates the segments with `gap-1` (Brutal, 4px) or `gap-1.5`
      // (Elegant, 6px) -- Tailwind `--spacing` is 0.25rem, so 1 and 1.5 steps.
      // The family packs carry their own `itemGap` so neither is hardcoded here.
      final gap = t.size('space.segmentGap', fallback: 4);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }

    // The track is the control radius plus its inset: the official source nests
    // `rounded-[11px]` around `p-[3px]` holding a `rounded-control` (8px) segment,
    // so the two corners stay concentric.
    final inset = 3.0;
    final trackRadius = t.size('radius.control', fallback: 8) + inset;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.fillMuted,
        borderRadius: BorderRadius.circular(
          trackRadius >= 999 ? 999 : trackRadius,
        ),
      ),
      child: Padding(
        // ignore: raft_lints/off_grid_spacing -- the track's `p-[3px]` is an explicit arbitrary value in the raft-ui source (3px ink-to-sticker inset), not a spacing step.
        padding: EdgeInsets.all(inset),
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

/// Marks the label a segment lets shrink (`min-w-0 truncate`) when the width is bounded.
class _Shrink extends StatelessWidget {
  const _Shrink({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
