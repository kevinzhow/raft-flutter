import 'package:flutter/material.dart';

import '../theme.dart';
import 'button.dart' show RaftButtonVariant;
import 'ui_tokens.dart';

/// Resolved colours of one variant in one state.
class RaftButtonColors {
  const RaftButtonColors({
    required this.fill,
    required this.border,
    required this.foreground,
    this.ringEdge,
  });
  final Color fill, border, foreground;

  /// `ring-sticker-edge`: the die-cut ring outside a sticker.
  final Color? ringEdge;

  /// Component colors and hover computation vary independently of motion/edge.
  static RaftButtonColors themed(
    RaftTokens t,
    RaftButtonVariant variant, {
    required bool disabled,
    required bool overlay,
    bool iconSize = false,
    bool highContrast = false,
  }) {
    final ui = t.ui;
    if (disabled &&
        t.option('button.disabledSurface', or: 'muted') == 'muted') {
      return resolve(
        ui,
        variant,
        disabled: true,
        overlay: false,
        iconSize: iconSize,
      );
    }
    final base = resolve(
      ui,
      variant,
      disabled: false,
      overlay: false,
      iconSize: iconSize,
    );
    final name = switch (variant) {
      RaftButtonVariant.dangerSecondary => 'danger-secondary',
      RaftButtonVariant.dangerOutline => 'danger-outline',
      _ => variant.name,
    };
    Color role(String name, Color fallback) => t.colors[name] ?? fallback;
    var fill =
        (variant == RaftButtonVariant.primary ||
            variant == RaftButtonVariant.accent)
        ? role(
            'layer-button-$name-${t.option('emphasis.fill', or: 'solid')}',
            base.fill,
          )
        : role('layer-button-$name', base.fill);
    var border = variant.isSticker
        ? role('line-button-emphasis', base.border)
        : base.border;
    var fore = role('foreground-button-$name', base.foreground);
    final contrastDanger = highContrast && variant == RaftButtonVariant.danger;
    if (contrastDanger) {
      fill = role('layer-button-danger-high-contrast', fill);
      fore = role('foreground-button-danger-high-contrast', fore);
    }
    if (overlay && !disabled) {
      if (t.option('button.hoverSurface', or: 'overlay') == 'overlay') {
        fill = variant.isSticker
            ? raftChromeBlend(ui.stickerPressed, fill)
            : variant.isOutline
            ? raftChromeBlend(ui.fillPressed, fill)
            : variant == RaftButtonVariant.ghost
            ? ui.fillPressed
            : variant == RaftButtonVariant.onFrame
            ? ui.fillFramePressed
            : fill;
      } else if (!contrastDanger) {
        fill = role('layer-button-$name-hover', fill);
        if (variant == RaftButtonVariant.ghost) {
          border = role('line-button-ghost-hover', border);
        }
      }
    }
    return RaftButtonColors(
      fill: fill,
      border: border,
      foreground: fore,
      ringEdge:
          variant.isSticker && t.option('sticker.ring', or: 'none') == 'dieCut'
          ? ui.stickerEdge
          : null,
    );
  }

  static RaftButtonColors resolve(
    RaftUiColors ui,
    RaftButtonVariant variant, {
    required bool disabled,
    required bool overlay,
    bool iconSize = false,
  }) {
    // `disabled:border-transparent disabled:bg-transparent`: on-frame always, ghost only as an icon button.
    if (disabled &&
        (variant == RaftButtonVariant.onFrame ||
            (variant == RaftButtonVariant.ghost && iconSize))) {
      return RaftButtonColors(
        fill: const Color(0x00000000),
        border: const Color(0x00000000),
        foreground: ui.foregroundDisabled,
      );
    }
    if (disabled) {
      if (variant == RaftButtonVariant.link) {
        return RaftButtonColors(
          fill: const Color(0x00000000),
          border: const Color(0x00000000),
          foreground: ui.foregroundDisabled,
        );
      }
      return RaftButtonColors(
        fill: ui.fillMuted,
        border: raftChromeBlend(ui.lineHairline, ui.fillMuted),
        foreground: raftChromeBlend(ui.foregroundDisabled, ui.fillMuted),
      );
    }
    Color over(Color fill, Color pressed) =>
        overlay ? raftChromeBlend(pressed, fill) : fill;
    const clear = Color(0x00000000);
    return switch (variant) {
      RaftButtonVariant.primary || RaftButtonVariant.accent => RaftButtonColors(
        fill: over(ui.attention, ui.stickerPressed),
        border: ui.stickerInk,
        foreground: ui.stickerInk,
        ringEdge: ui.stickerEdge,
      ),
      RaftButtonVariant.warning => RaftButtonColors(
        fill: over(ui.warning, ui.stickerPressed),
        border: ui.stickerInk,
        foreground: ui.stickerInk,
        ringEdge: ui.stickerEdge,
      ),
      RaftButtonVariant.danger => RaftButtonColors(
        fill: over(ui.danger, ui.stickerPressed),
        border: ui.stickerInk,
        foreground: ui.stickerInk,
        ringEdge: ui.stickerEdge,
      ),
      RaftButtonVariant.dangerSecondary ||
      RaftButtonVariant.dangerOutline => RaftButtonColors(
        fill: over(ui.layerCard, ui.fillPressed),
        border: ui.lineStrong,
        foreground: ui.dangerStrong,
      ),
      RaftButtonVariant.ghost => RaftButtonColors(
        fill: overlay ? ui.fillPressed : clear,
        border: clear,
        foreground: ui.foreground,
      ),
      RaftButtonVariant.onFrame => RaftButtonColors(
        fill: overlay ? ui.fillFramePressed : clear,
        border: clear,
        foreground: ui.foregroundOnFrame,
      ),
      RaftButtonVariant.link => RaftButtonColors(
        fill: clear,
        border: clear,
        foreground: ui.foreground,
      ),
      _ => RaftButtonColors(
        fill: over(ui.layerCard, ui.fillPressed),
        border: ui.lineStrong,
        foreground: ui.foreground,
      ),
    };
  }
}
