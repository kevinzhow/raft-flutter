// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: raft-ui-0.5.27/foundation.css, raft-ui-0.5.27/styles.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Tier 2: every colour variable of the raft-ui theme blocks, resolved per theme.
///
/// Cascade (all on the html element): `:where(:root),[data-theme=brutal]` →
/// `[data-theme=elegant]` → `[data-theme=elegant].dark`. var() and
/// color-mix() resolve against the merged scope, so e.g. elegant-dark
/// `primary-active` mixes elegant-dark `--ink` into `--primary-400`.
@immutable
class RaftSemanticColors {
  const RaftSemanticColors({
    required this.foreground,
    required this.foregroundStrong,
    required this.foregroundMuted,
    required this.foregroundHint,
    required this.foregroundIcon,
    required this.foregroundPlaceholder,
    required this.foregroundDisabled,
    required this.foregroundInverse,
    required this.foregroundActive,
    required this.foregroundHover,
    required this.layerCanvas,
    required this.layerCanvasMuted,
    required this.layerPanel,
    required this.layerPopover,
    required this.layerBackdrop,
    required this.layerInset,
    required this.layerCard,
    required this.layerHud,
    required this.layerHudForeground,
    required this.fillMuted,
    required this.fillStrong,
    required this.lineStrong,
    required this.line,
    required this.lineMuted,
    required this.lineHairline,
    required this.lineField,
    required this.lineFieldHover,
    required this.ink,
    required this.ink2,
    required this.ink4,
    required this.ink6,
    required this.ink8,
    required this.ink10,
    required this.ink16,
    required this.ink20,
    required this.ink30,
    required this.ink40,
    required this.primary50,
    required this.primary100,
    required this.primary200,
    required this.primary300,
    required this.primary400,
    required this.primary500,
    required this.primary600,
    required this.primary700,
    required this.primary800,
    required this.primary900,
    required this.primary950,
    required this.accent50,
    required this.accent100,
    required this.accent200,
    required this.accent300,
    required this.accent400,
    required this.accent500,
    required this.accent600,
    required this.accent700,
    required this.accent800,
    required this.accent900,
    required this.accent950,
    required this.secondary50,
    required this.secondary100,
    required this.secondary200,
    required this.secondary300,
    required this.secondary400,
    required this.secondary500,
    required this.secondary600,
    required this.secondary700,
    required this.secondary800,
    required this.secondary900,
    required this.secondary950,
    required this.info,
    required this.infoStrong,
    required this.infoMuted,
    required this.infoSoft,
    required this.success,
    required this.successForeground,
    required this.successStrong,
    required this.successMuted,
    required this.successSoft,
    required this.warning,
    required this.warningForeground,
    required this.warningStrong,
    required this.warningMuted,
    required this.warningSoft,
    required this.danger,
    required this.dangerForeground,
    required this.dangerStrong,
    required this.dangerMuted,
    required this.dangerSoft,
    required this.inactive,
    required this.inactiveForeground,
    required this.primaryStrong,
    required this.primarySoft,
    required this.primaryEdge,
    required this.primaryGlow,
    required this.accentStrong,
    required this.accentSoft,
    required this.primaryHover,
    required this.primaryActive,
    required this.accentHover,
    required this.accentActive,
    required this.infoHover,
    required this.infoActive,
    required this.warningHover,
    required this.warningActive,
    required this.dangerHover,
    required this.dangerActive,
  });

  /// `--foreground` — declared in brutal, elegant, elegant.dark
  final Color foreground;
  /// `--foreground-strong` — declared in brutal, elegant, elegant.dark
  final Color foregroundStrong;
  /// `--foreground-muted` — declared in brutal, elegant, elegant.dark
  final Color foregroundMuted;
  /// `--foreground-hint` — declared in brutal, elegant, elegant.dark
  final Color foregroundHint;
  /// `--foreground-icon` — declared in brutal, elegant, elegant.dark
  final Color foregroundIcon;
  /// `--foreground-placeholder` — declared in brutal, elegant, elegant.dark
  final Color foregroundPlaceholder;
  /// `--foreground-disabled` — declared in brutal, elegant, elegant.dark
  final Color foregroundDisabled;
  /// `--foreground-inverse` — declared in brutal, elegant, elegant.dark
  final Color foregroundInverse;
  /// `--foreground-active` — declared in brutal, elegant, elegant.dark
  final Color foregroundActive;
  /// `--foreground-hover` — declared in brutal, elegant, elegant.dark
  final Color foregroundHover;
  /// `--layer-canvas` — declared in brutal, elegant, elegant.dark
  final Color layerCanvas;
  /// `--layer-canvas-muted` — declared in brutal, elegant, elegant.dark
  final Color layerCanvasMuted;
  /// `--layer-panel` — declared in brutal, elegant, elegant.dark
  final Color layerPanel;
  /// `--layer-popover` — declared in brutal, elegant, elegant.dark
  final Color layerPopover;
  /// `--layer-backdrop` — declared in brutal, elegant, elegant.dark
  final Color layerBackdrop;
  /// `--layer-inset` — declared in brutal, elegant, elegant.dark
  final Color layerInset;
  /// `--layer-card` — declared in brutal, elegant, elegant.dark
  final Color layerCard;
  /// `--layer-hud` — declared in brutal, elegant, elegant.dark
  final Color layerHud;
  /// `--layer-hud-foreground` — declared in brutal, elegant, elegant.dark
  final Color layerHudForeground;
  /// `--fill-muted` — declared in brutal, elegant, elegant.dark
  final Color fillMuted;
  /// `--fill-strong` — declared in brutal, elegant, elegant.dark
  final Color fillStrong;
  /// `--line-strong` — declared in brutal, elegant, elegant.dark
  final Color lineStrong;
  /// `--line` — declared in brutal, elegant, elegant.dark
  final Color line;
  /// `--line-muted` — declared in brutal, elegant, elegant.dark
  final Color lineMuted;
  /// `--line-hairline` — declared in brutal, elegant, elegant.dark
  final Color lineHairline;
  /// `--line-field` — declared in brutal, elegant, elegant.dark
  final Color lineField;
  /// `--line-field-hover` — declared in brutal, elegant, elegant.dark
  final Color lineFieldHover;
  /// `--ink` — declared in brutal, elegant, elegant.dark
  final Color ink;
  /// `--ink-2` — declared in brutal, elegant, elegant.dark
  final Color ink2;
  /// `--ink-4` — declared in brutal, elegant, elegant.dark
  final Color ink4;
  /// `--ink-6` — declared in brutal, elegant, elegant.dark
  final Color ink6;
  /// `--ink-8` — declared in brutal, elegant, elegant.dark
  final Color ink8;
  /// `--ink-10` — declared in brutal, elegant, elegant.dark
  final Color ink10;
  /// `--ink-16` — declared in brutal, elegant, elegant.dark
  final Color ink16;
  /// `--ink-20` — declared in brutal, elegant, elegant.dark
  final Color ink20;
  /// `--ink-30` — declared in brutal, elegant, elegant.dark
  final Color ink30;
  /// `--ink-40` — declared in brutal, elegant, elegant.dark
  final Color ink40;
  /// `--primary-50` — declared in brutal
  final Color primary50;
  /// `--primary-100` — declared in brutal
  final Color primary100;
  /// `--primary-200` — declared in brutal
  final Color primary200;
  /// `--primary-300` — declared in brutal
  final Color primary300;
  /// `--primary-400` — declared in brutal
  final Color primary400;
  /// `--primary-500` — declared in brutal
  final Color primary500;
  /// `--primary-600` — declared in brutal
  final Color primary600;
  /// `--primary-700` — declared in brutal
  final Color primary700;
  /// `--primary-800` — declared in brutal
  final Color primary800;
  /// `--primary-900` — declared in brutal
  final Color primary900;
  /// `--primary-950` — declared in brutal
  final Color primary950;
  /// `--accent-50` — declared in brutal
  final Color accent50;
  /// `--accent-100` — declared in brutal
  final Color accent100;
  /// `--accent-200` — declared in brutal
  final Color accent200;
  /// `--accent-300` — declared in brutal
  final Color accent300;
  /// `--accent-400` — declared in brutal
  final Color accent400;
  /// `--accent-500` — declared in brutal
  final Color accent500;
  /// `--accent-600` — declared in brutal
  final Color accent600;
  /// `--accent-700` — declared in brutal
  final Color accent700;
  /// `--accent-800` — declared in brutal
  final Color accent800;
  /// `--accent-900` — declared in brutal
  final Color accent900;
  /// `--accent-950` — declared in brutal
  final Color accent950;
  /// `--secondary-50` — declared in brutal
  final Color secondary50;
  /// `--secondary-100` — declared in brutal
  final Color secondary100;
  /// `--secondary-200` — declared in brutal
  final Color secondary200;
  /// `--secondary-300` — declared in brutal
  final Color secondary300;
  /// `--secondary-400` — declared in brutal
  final Color secondary400;
  /// `--secondary-500` — declared in brutal
  final Color secondary500;
  /// `--secondary-600` — declared in brutal
  final Color secondary600;
  /// `--secondary-700` — declared in brutal
  final Color secondary700;
  /// `--secondary-800` — declared in brutal
  final Color secondary800;
  /// `--secondary-900` — declared in brutal
  final Color secondary900;
  /// `--secondary-950` — declared in brutal
  final Color secondary950;
  /// `--info` — declared in brutal
  final Color info;
  /// `--info-strong` — declared in brutal, elegant, elegant.dark
  final Color infoStrong;
  /// `--info-muted` — declared in brutal, elegant, elegant.dark
  final Color infoMuted;
  /// `--info-soft` — declared in brutal, elegant, elegant.dark
  final Color infoSoft;
  /// `--success` — declared in brutal
  final Color success;
  /// `--success-foreground` — declared in brutal
  final Color successForeground;
  /// `--success-strong` — declared in brutal, elegant, elegant.dark
  final Color successStrong;
  /// `--success-muted` — declared in brutal, elegant, elegant.dark
  final Color successMuted;
  /// `--success-soft` — declared in brutal, elegant, elegant.dark
  final Color successSoft;
  /// `--warning` — declared in brutal
  final Color warning;
  /// `--warning-foreground` — declared in brutal
  final Color warningForeground;
  /// `--warning-strong` — declared in brutal, elegant, elegant.dark
  final Color warningStrong;
  /// `--warning-muted` — declared in brutal, elegant, elegant.dark
  final Color warningMuted;
  /// `--warning-soft` — declared in brutal, elegant, elegant.dark
  final Color warningSoft;
  /// `--danger` — declared in brutal
  final Color danger;
  /// `--danger-foreground` — declared in brutal
  final Color dangerForeground;
  /// `--danger-strong` — declared in brutal, elegant, elegant.dark
  final Color dangerStrong;
  /// `--danger-muted` — declared in brutal, elegant, elegant.dark
  final Color dangerMuted;
  /// `--danger-soft` — declared in brutal, elegant, elegant.dark
  final Color dangerSoft;
  /// `--inactive` — declared in brutal, elegant, elegant.dark
  final Color inactive;
  /// `--inactive-foreground` — declared in brutal, elegant, elegant.dark
  final Color inactiveForeground;
  /// `--primary-strong` — declared in brutal, elegant, elegant.dark
  final Color primaryStrong;
  /// `--primary-soft` — declared in brutal, elegant, elegant.dark
  final Color primarySoft;
  /// `--primary-edge` — declared in brutal, elegant, elegant.dark
  final Color primaryEdge;
  /// `--primary-glow` — declared in brutal
  final Color primaryGlow;
  /// `--accent-strong` — declared in brutal, elegant, elegant.dark
  final Color accentStrong;
  /// `--accent-soft` — declared in brutal, elegant, elegant.dark
  final Color accentSoft;
  /// `--primary-hover` — declared in brutal, elegant, elegant.dark
  final Color primaryHover;
  /// `--primary-active` — declared in brutal
  final Color primaryActive;
  /// `--accent-hover` — declared in brutal, elegant, elegant.dark
  final Color accentHover;
  /// `--accent-active` — declared in brutal
  final Color accentActive;
  /// `--info-hover` — declared in brutal
  final Color infoHover;
  /// `--info-active` — declared in brutal
  final Color infoActive;
  /// `--warning-hover` — declared in brutal
  final Color warningHover;
  /// `--warning-active` — declared in brutal
  final Color warningActive;
  /// `--danger-hover` — declared in brutal
  final Color dangerHover;
  /// `--danger-active` — declared in brutal
  final Color dangerActive;

  /// All tokens keyed by CSS custom-property name (without the leading `--`).
  Map<String, Color> toCssMap() => {
    'foreground': foreground,
    'foreground-strong': foregroundStrong,
    'foreground-muted': foregroundMuted,
    'foreground-hint': foregroundHint,
    'foreground-icon': foregroundIcon,
    'foreground-placeholder': foregroundPlaceholder,
    'foreground-disabled': foregroundDisabled,
    'foreground-inverse': foregroundInverse,
    'foreground-active': foregroundActive,
    'foreground-hover': foregroundHover,
    'layer-canvas': layerCanvas,
    'layer-canvas-muted': layerCanvasMuted,
    'layer-panel': layerPanel,
    'layer-popover': layerPopover,
    'layer-backdrop': layerBackdrop,
    'layer-inset': layerInset,
    'layer-card': layerCard,
    'layer-hud': layerHud,
    'layer-hud-foreground': layerHudForeground,
    'fill-muted': fillMuted,
    'fill-strong': fillStrong,
    'line-strong': lineStrong,
    'line': line,
    'line-muted': lineMuted,
    'line-hairline': lineHairline,
    'line-field': lineField,
    'line-field-hover': lineFieldHover,
    'ink': ink,
    'ink-2': ink2,
    'ink-4': ink4,
    'ink-6': ink6,
    'ink-8': ink8,
    'ink-10': ink10,
    'ink-16': ink16,
    'ink-20': ink20,
    'ink-30': ink30,
    'ink-40': ink40,
    'primary-50': primary50,
    'primary-100': primary100,
    'primary-200': primary200,
    'primary-300': primary300,
    'primary-400': primary400,
    'primary-500': primary500,
    'primary-600': primary600,
    'primary-700': primary700,
    'primary-800': primary800,
    'primary-900': primary900,
    'primary-950': primary950,
    'accent-50': accent50,
    'accent-100': accent100,
    'accent-200': accent200,
    'accent-300': accent300,
    'accent-400': accent400,
    'accent-500': accent500,
    'accent-600': accent600,
    'accent-700': accent700,
    'accent-800': accent800,
    'accent-900': accent900,
    'accent-950': accent950,
    'secondary-50': secondary50,
    'secondary-100': secondary100,
    'secondary-200': secondary200,
    'secondary-300': secondary300,
    'secondary-400': secondary400,
    'secondary-500': secondary500,
    'secondary-600': secondary600,
    'secondary-700': secondary700,
    'secondary-800': secondary800,
    'secondary-900': secondary900,
    'secondary-950': secondary950,
    'info': info,
    'info-strong': infoStrong,
    'info-muted': infoMuted,
    'info-soft': infoSoft,
    'success': success,
    'success-foreground': successForeground,
    'success-strong': successStrong,
    'success-muted': successMuted,
    'success-soft': successSoft,
    'warning': warning,
    'warning-foreground': warningForeground,
    'warning-strong': warningStrong,
    'warning-muted': warningMuted,
    'warning-soft': warningSoft,
    'danger': danger,
    'danger-foreground': dangerForeground,
    'danger-strong': dangerStrong,
    'danger-muted': dangerMuted,
    'danger-soft': dangerSoft,
    'inactive': inactive,
    'inactive-foreground': inactiveForeground,
    'primary-strong': primaryStrong,
    'primary-soft': primarySoft,
    'primary-edge': primaryEdge,
    'primary-glow': primaryGlow,
    'accent-strong': accentStrong,
    'accent-soft': accentSoft,
    'primary-hover': primaryHover,
    'primary-active': primaryActive,
    'accent-hover': accentHover,
    'accent-active': accentActive,
    'info-hover': infoHover,
    'info-active': infoActive,
    'warning-hover': warningHover,
    'warning-active': warningActive,
    'danger-hover': dangerHover,
    'danger-active': dangerActive,
  };

  /// `brutal-light` resolved values.
  static const brutal = RaftSemanticColors(
    // oklch(0.18 0.006 25)
    foreground: Color(0xff141110),
    // oklch(0.18 0.006 25)
    foregroundStrong: Color(0xff141110),
    // oklch(0.18 0.006 25 / 0.6)
    // Chrome-composite fit, CSS alpha 0.6 (see docs/design-tokens.md)
    foregroundMuted: Color.from(alpha: 0.600000, red: 0.078105, green: 0.065073, blue: 0.063583),
    // oklch(0.48 0 0)
    foregroundHint: Color(0xff5d5d5d),
    // oklch(0.18 0.006 25 / 0.68)
    // Chrome-composite fit, CSS alpha 0.68 (see docs/design-tokens.md)
    foregroundIcon: Color.from(alpha: 0.679142, red: 0.081409, green: 0.071250, blue: 0.063924),
    // oklch(0.18 0.006 25 / 0.5)
    // Chrome-composite fit, CSS alpha 0.5 (see docs/design-tokens.md)
    foregroundPlaceholder: Color.from(alpha: 0.500000, red: 0.077451, green: 0.067647, blue: 0.061765),
    // oklch(0.18 0.006 25 / 0.3)
    // Chrome-composite fit, CSS alpha 0.3 (see docs/design-tokens.md)
    foregroundDisabled: Color.from(alpha: 0.300858, red: 0.076728, green: 0.060752, blue: 0.063583),
    // oklch(1 0 0)
    foregroundInverse: Color(0xffffffff),
    // oklch(0.38 0.006 106.42)
    foregroundActive: Color(0xff43433f),
    // oklch(0.42 0.006 106.42)
    foregroundHover: Color(0xff4d4d4a),
    // oklch(1 0 0)
    layerCanvas: Color(0xffffffff),
    // oklch(1 0 0)
    layerCanvasMuted: Color(0xffffffff),
    // oklch(1 0 0)
    layerPanel: Color(0xffffffff),
    // oklch(1 0 0)
    layerPopover: Color(0xffffffff),
    // oklch(0 0 0 / 0.65)
    // Chrome-composite fit, CSS alpha 0.65 (see docs/design-tokens.md)
    layerBackdrop: Color.from(alpha: 0.650858, red: 0.000706, green: 0.000323, blue: 0.000706),
    // oklch(0.99 0.002 84.559)
    layerInset: Color(0xfffcfcfa),
    // oklch(0.985 0.003 84.559)
    layerCard: Color(0xfffbfaf8),
    // oklch(0.263 0.009 294.9)
    layerHud: Color(0xff252429),
    // oklch(0.965 0.002 286)
    layerHudForeground: Color(0xfff3f3f5),
    // oklch(0.9645 0.0002 25)
    fillMuted: Color(0xfff3f3f3),
    // oklch(0.9389 0 0)
    fillStrong: Color(0xffebebeb),
    // oklch(0.18 0.006 25)
    lineStrong: Color(0xff141110),
    // oklch(0.18 0.006 25)
    line: Color(0xff141110),
    // oklch(0.18 0.006 25 / 0.3)
    // Chrome-composite fit, CSS alpha 0.3 (see docs/design-tokens.md)
    lineMuted: Color.from(alpha: 0.300858, red: 0.076728, green: 0.060752, blue: 0.063583),
    // oklch(0.18 0.006 25 / 0.15)
    // Chrome-composite fit, CSS alpha 0.15 (see docs/design-tokens.md)
    lineHairline: Color.from(alpha: 0.150000, red: 0.079024, green: 0.073529, blue: 0.060458),
    // var(--ink-8)
    // Chrome-composite fit, CSS alpha 0.08 (see docs/design-tokens.md)
    lineField: Color.from(alpha: 0.080000, red: 0.006127, green: 0.006127, blue: 0.004167),
    // var(--ink-10)
    // Chrome-composite fit, CSS alpha 0.1 (see docs/design-tokens.md)
    lineFieldHover: Color.from(alpha: 0.103676, red: 0.004728, green: 0.003963, blue: 0.002003),
    // oklch(0 0 0)
    ink: Color(0xff000000),
    // oklch(0 0 0 / 0.02)
    // Chrome-composite fit, CSS alpha 0.02 (see docs/design-tokens.md)
    ink2: Color.from(alpha: 0.020000, red: 0.024510, green: 0.024510, blue: 0.022549),
    // oklch(0 0 0 / 0.04)
    // Chrome-composite fit, CSS alpha 0.04 (see docs/design-tokens.md)
    ink4: Color.from(alpha: 0.040000, red: 0.012255, green: 0.012255, blue: 0.010294),
    // oklch(0 0 0 / 0.06)
    // Chrome-composite fit, CSS alpha 0.06 (see docs/design-tokens.md)
    ink6: Color.from(alpha: 0.060000, red: 0.008170, green: 0.008170, blue: 0.006209),
    // oklch(0 0 0 / 0.08)
    // Chrome-composite fit, CSS alpha 0.08 (see docs/design-tokens.md)
    ink8: Color.from(alpha: 0.080000, red: 0.006127, green: 0.006127, blue: 0.004167),
    // oklch(0 0 0 / 0.1)
    // Chrome-composite fit, CSS alpha 0.1 (see docs/design-tokens.md)
    ink10: Color.from(alpha: 0.103676, red: 0.004728, green: 0.003963, blue: 0.002003),
    // oklch(0 0 0 / 0.16)
    // Chrome-composite fit, CSS alpha 0.16 (see docs/design-tokens.md)
    ink16: Color.from(alpha: 0.162757, red: 0.002177, green: 0.001197, blue: 0.003068),
    // oklch(0 0 0 / 0.2)
    // Chrome-composite fit, CSS alpha 0.2 (see docs/design-tokens.md)
    ink20: Color.from(alpha: 0.201961, red: 0.000933, green: 0.002427, blue: 0.002427),
    // oklch(0 0 0 / 0.3)
    // Chrome-composite fit, CSS alpha 0.3 (see docs/design-tokens.md)
    ink30: Color.from(alpha: 0.302819, red: 0.001619, green: 0.000663, blue: 0.001619),
    // oklch(0 0 0 / 0.4)
    // Chrome-composite fit, CSS alpha 0.4 (see docs/design-tokens.md)
    ink40: Color.from(alpha: 0.401225, red: 0.000507, green: 0.001222, blue: 0.001250),
    // var(--color-brutal-yellow-50)
    primary50: Color(0xfffff9ed),
    // var(--color-brutal-yellow-100)
    primary100: Color(0xfffff6e3),
    // var(--color-brutal-yellow-200)
    primary200: Color(0xffffe9b9),
    // var(--color-brutal-yellow-300)
    primary300: Color(0xffffdf91),
    // var(--color-brutal-yellow-400)
    primary400: Color(0xffffd441),
    // var(--color-brutal-yellow-500)
    primary500: Color(0xffd3ad03),
    // var(--color-brutal-yellow-600)
    primary600: Color(0xffa78802),
    // var(--color-brutal-yellow-700)
    primary700: Color(0xff7a6300),
    // var(--color-brutal-yellow-800)
    primary800: Color(0xff534300),
    // var(--color-brutal-yellow-900)
    primary900: Color(0xff2d2300),
    // var(--color-brutal-yellow-950)
    primary950: Color(0xff1c1500),
    // var(--color-brutal-pink-50)
    accent50: Color(0xfffff0f4),
    // var(--color-brutal-pink-100)
    accent100: Color(0xffffe1e8),
    // var(--color-brutal-pink-200)
    accent200: Color(0xfffec1d2),
    // var(--color-brutal-pink-300)
    accent300: Color(0xfffea0bc),
    // var(--color-brutal-pink-400)
    accent400: Color(0xfffe7da8),
    // var(--color-brutal-pink-500)
    accent500: Color(0xfffe2f8b),
    // var(--color-brutal-pink-600)
    accent600: Color(0xffd4086f),
    // var(--color-brutal-pink-700)
    accent700: Color(0xff9f0551),
    // var(--color-brutal-pink-800)
    accent800: Color(0xff700238),
    // var(--color-brutal-pink-900)
    accent900: Color(0xff42011e),
    // var(--color-brutal-pink-950)
    accent950: Color(0xff2f0014),
    // var(--color-brutal-stone-50)
    secondary50: Color(0xfff7f6f5),
    // var(--color-brutal-stone-100)
    secondary100: Color(0xffefedeb),
    // var(--color-brutal-stone-200)
    secondary200: Color(0xffe0dcd7),
    // var(--color-brutal-stone-300)
    secondary300: Color(0xffd2cbc2),
    // var(--color-brutal-stone-400)
    secondary400: Color(0xffc0b9b1),
    // var(--color-brutal-stone-500)
    secondary500: Color(0xff9d9891),
    // var(--color-brutal-stone-600)
    secondary600: Color(0xff7b7671),
    // var(--color-brutal-stone-700)
    secondary700: Color(0xff5d5955),
    // var(--color-brutal-stone-800)
    secondary800: Color(0xff3e3b38),
    // var(--color-brutal-stone-900)
    secondary900: Color(0xff23211f),
    // var(--color-brutal-stone-950)
    secondary950: Color(0xff141312),
    // var(--color-brutal-cyan-400)
    info: Color(0xff28ccf3),
    // var(--color-brutal-cyan-800)
    infoStrong: Color(0xff06414f),
    // var(--color-brutal-cyan-200)
    infoMuted: Color(0xffa9e6fe),
    // var(--color-brutal-cyan-100)
    infoSoft: Color(0xffd7f2fe),
    // oklch(0.714 0.176 153.079)
    success: Color(0xff1fc16b),
    // oklch(1 0 0)
    successForeground: Color(0xffffffff),
    // oklch(0.366 0.09 153.079)
    successStrong: Color(0xff074c27),
    // oklch(0.91 0.149 153.079)
    successMuted: Color(0xff8cfeb2),
    // oklch(0.949 0.079 153.079)
    successSoft: Color(0xffc6fed5),
    // oklch(0.7 0.202 44.441)
    warning: Color(0xffff6900),
    // oklch(1 0 0)
    warningForeground: Color(0xffffffff),
    // oklch(0.366 0.106 44.441)
    warningStrong: Color(0xff6a2700),
    // oklch(0.91 0.05 44.441)
    warningMuted: Color(0xffffd8c7),
    // oklch(0.949 0.027 44.441)
    warningSoft: Color(0xffffe9e0),
    // oklch(0.616 0.249 26.758)
    danger: Color(0xfff70720),
    // oklch(1 0 0)
    dangerForeground: Color(0xffffffff),
    // var(--color-brutal-red-800)
    dangerStrong: Color(0xff621708),
    // var(--color-brutal-red-200)
    dangerMuted: Color(0xfffbbdb9),
    // var(--color-brutal-red-100)
    dangerSoft: Color(0xfffddedd),
    // oklch(0.573 0 0)
    inactive: Color(0xff787878),
    // oklch(0.946 0 0)
    inactiveForeground: Color(0xffededed),
    // oklch(0.44 0.09 91.39)
    primaryStrong: Color(0xff655000),
    // oklch(0.955 0.067 93.62)
    primarySoft: Color(0xfffff0bd),
    // oklch(0.83 0.14 91.89 / 0.7)
    // Chrome-composite fit, CSS alpha 0.7 (see docs/design-tokens.md)
    primaryEdge: Color.from(alpha: 0.700000, red: 0.911064, green: 0.771008, blue: 0.306022),
    // oklch(0.85 0.162 91.89)
    primaryGlow: Color(0xfff4c931),
    // oklch(0.52 0.215 359.77)
    accentStrong: Color(0xffc00064),
    // oklch(0.914 0.048 358.59)
    accentSoft: Color(0xffffd6e2),
    // color-mix(in srgb-linear, var(--primary-400) 92%, var(--ink))
    primaryHover: Color(0xfff6cc3e),
    // color-mix(in srgb-linear, var(--primary-400) 84%, var(--ink))
    primaryActive: Color(0xffecc43b),
    // color-mix(in srgb-linear, var(--accent-400) 92%, var(--ink))
    accentHover: Color(0xfff578a2),
    // color-mix(in srgb-linear, var(--accent-400) 84%, var(--ink))
    accentActive: Color(0xffeb739b),
    // color-mix(in srgb-linear, var(--info) 84%, var(--ink))
    infoHover: Color(0xff24bde1),
    // color-mix(in srgb-linear, var(--info) 76%, var(--ink))
    infoActive: Color(0xff22b4d7),
    // color-mix(in srgb-linear, var(--warning) 84%, var(--ink))
    warningHover: Color(0xffec6100),
    // color-mix(in srgb-linear, var(--warning) 76%, var(--ink))
    warningActive: Color(0xffe25c00),
    // color-mix(in srgb-linear, var(--danger) 84%, var(--ink))
    dangerHover: Color(0xffe5061d),
    // color-mix(in srgb-linear, var(--danger) 76%, var(--ink))
    dangerActive: Color(0xffdb051b),
  );
  /// `elegant-light` resolved values.
  static const elegantLight = RaftSemanticColors(
    // oklch(0.21 0.006 106.42)
    foreground: Color(0xff191815),
    // oklch(0.145 0 0)
    foregroundStrong: Color(0xff0a0a0a),
    // oklch(0.36 0.006 106.42)
    foregroundMuted: Color(0xff3d3d3a),
    // oklch(0.48 0 0)
    foregroundHint: Color(0xff5d5d5d),
    // oklch(0.36 0.006 106.42 / 0.68)
    // Chrome-composite fit, CSS alpha 0.68 (see docs/design-tokens.md)
    foregroundIcon: Color.from(alpha: 0.679142, red: 0.238861, green: 0.239324, blue: 0.226994),
    // oklch(0.58 0.006 106.42)
    foregroundPlaceholder: Color(0xff7b7b77),
    // oklch(0.7 0.006 106.42)
    foregroundDisabled: Color(0xff9f9f9a),
    // oklch(1 0 0)
    foregroundInverse: Color(0xffffffff),
    // oklch(0.38 0.006 106.42)
    foregroundActive: Color(0xff43433f),
    // oklch(0.42 0.006 106.42)
    foregroundHover: Color(0xff4d4d4a),
    // oklch(1 0 0)
    layerCanvas: Color(0xffffffff),
    // oklch(0.97885053 0.00132105 106.423534)
    layerCanvasMuted: Color(0xfff8f8f7),
    // oklch(1 0 0)
    layerPanel: Color(0xffffffff),
    // oklch(1 0 0)
    layerPopover: Color(0xffffffff),
    // oklch(0 0 0 / 0.35)
    // Chrome-composite fit, CSS alpha 0.35 (see docs/design-tokens.md)
    layerBackdrop: Color.from(alpha: 0.350000, red: 0.000840, green: 0.000840, blue: 0.000840),
    // oklch(0.99 0.001 106.42)
    layerInset: Color(0xfffcfcfb),
    // oklch(0.985 0.003 84.559)
    layerCard: Color(0xfffbfaf8),
    // oklch(0.263 0.009 294.9)
    layerHud: Color(0xff252429),
    // oklch(0.965 0.002 286)
    layerHudForeground: Color(0xfff3f3f5),
    // oklch(0.96743433 0.00132586 106.423534)
    fillMuted: Color(0xfff4f4f3),
    // oklch(0.94883828 0.00133136 106.424517)
    fillStrong: Color(0xffeeeeed),
    // oklch(0.21 0.006 106.42)
    lineStrong: Color(0xff191815),
    // oklch(0.84 0.006 106.42)
    line: Color(0xffcbcbc6),
    // oklch(0.92 0.004 106.42)
    lineMuted: Color(0xffe5e5e2),
    // var(--ink-8)
    // Chrome-composite fit, CSS alpha 0.08 (see docs/design-tokens.md)
    lineHairline: Color.from(alpha: 0.080000, red: 0.098529, green: 0.098529, blue: 0.097549),
    // var(--ink-8)
    // Chrome-composite fit, CSS alpha 0.08 (see docs/design-tokens.md)
    lineField: Color.from(alpha: 0.080000, red: 0.098529, green: 0.098529, blue: 0.097549),
    // var(--ink-10)
    // Chrome-composite fit, CSS alpha 0.1 (see docs/design-tokens.md)
    lineFieldHover: Color.from(alpha: 0.104412, red: 0.119898, green: 0.087393, blue: 0.083807),
    // oklch(0.21 0.006 106.42)
    ink: Color(0xff191815),
    // oklch(0.21 0.006 106.42 / 0.02)
    // Chrome-composite fit, CSS alpha 0.02 (see docs/design-tokens.md)
    ink2: Color.from(alpha: 0.020000, red: 0.067647, green: 0.067647, blue: 0.064706),
    // oklch(0.21 0.006 106.42 / 0.04)
    // Chrome-composite fit, CSS alpha 0.04 (see docs/design-tokens.md)
    ink4: Color.from(alpha: 0.040000, red: 0.096138, green: 0.096037, blue: 0.085294),
    // oklch(0.21 0.006 106.42 / 0.06)
    // Chrome-composite fit, CSS alpha 0.06 (see docs/design-tokens.md)
    ink6: Color.from(alpha: 0.060000, red: 0.080719, green: 0.080719, blue: 0.077778),
    // oklch(0.21 0.006 106.42 / 0.08)
    // Chrome-composite fit, CSS alpha 0.08 (see docs/design-tokens.md)
    ink8: Color.from(alpha: 0.080000, red: 0.098529, green: 0.098529, blue: 0.097549),
    // oklch(0.21 0.006 106.42 / 0.1)
    // Chrome-composite fit, CSS alpha 0.1 (see docs/design-tokens.md)
    ink10: Color.from(alpha: 0.104412, red: 0.119898, green: 0.087393, blue: 0.083807),
    // oklch(0.21 0.006 106.42 / 0.16)
    // Chrome-composite fit, CSS alpha 0.16 (see docs/design-tokens.md)
    ink16: Color.from(alpha: 0.162083, red: 0.096138, green: 0.096037, blue: 0.080637),
    // oklch(0.21 0.006 106.42 / 0.2)
    // Chrome-composite fit, CSS alpha 0.2 (see docs/design-tokens.md)
    ink20: Color.from(alpha: 0.200000, red: 0.091176, green: 0.096037, blue: 0.074510),
    // oklch(0.21 0.006 106.42 / 0.3)
    // Chrome-composite fit, CSS alpha 0.3 (see docs/design-tokens.md)
    ink30: Color.from(alpha: 0.300858, red: 0.099439, green: 0.086822, blue: 0.074739),
    // oklch(0.21 0.006 106.42 / 0.4)
    // Chrome-composite fit, CSS alpha 0.4 (see docs/design-tokens.md)
    ink40: Color.from(alpha: 0.400000, red: 0.096138, green: 0.097059, blue: 0.079902),
    // var(--color-brutal-yellow-50)
    primary50: Color(0xfffff9ed),
    // var(--color-brutal-yellow-100)
    primary100: Color(0xfffff6e3),
    // var(--color-brutal-yellow-200)
    primary200: Color(0xffffe9b9),
    // var(--color-brutal-yellow-300)
    primary300: Color(0xffffdf91),
    // var(--color-brutal-yellow-400)
    primary400: Color(0xffffd441),
    // var(--color-brutal-yellow-500)
    primary500: Color(0xffd3ad03),
    // var(--color-brutal-yellow-600)
    primary600: Color(0xffa78802),
    // var(--color-brutal-yellow-700)
    primary700: Color(0xff7a6300),
    // var(--color-brutal-yellow-800)
    primary800: Color(0xff534300),
    // var(--color-brutal-yellow-900)
    primary900: Color(0xff2d2300),
    // var(--color-brutal-yellow-950)
    primary950: Color(0xff1c1500),
    // var(--color-brutal-pink-50)
    accent50: Color(0xfffff0f4),
    // var(--color-brutal-pink-100)
    accent100: Color(0xffffe1e8),
    // var(--color-brutal-pink-200)
    accent200: Color(0xfffec1d2),
    // var(--color-brutal-pink-300)
    accent300: Color(0xfffea0bc),
    // var(--color-brutal-pink-400)
    accent400: Color(0xfffe7da8),
    // var(--color-brutal-pink-500)
    accent500: Color(0xfffe2f8b),
    // var(--color-brutal-pink-600)
    accent600: Color(0xffd4086f),
    // var(--color-brutal-pink-700)
    accent700: Color(0xff9f0551),
    // var(--color-brutal-pink-800)
    accent800: Color(0xff700238),
    // var(--color-brutal-pink-900)
    accent900: Color(0xff42011e),
    // var(--color-brutal-pink-950)
    accent950: Color(0xff2f0014),
    // var(--color-brutal-stone-50)
    secondary50: Color(0xfff7f6f5),
    // var(--color-brutal-stone-100)
    secondary100: Color(0xffefedeb),
    // var(--color-brutal-stone-200)
    secondary200: Color(0xffe0dcd7),
    // var(--color-brutal-stone-300)
    secondary300: Color(0xffd2cbc2),
    // var(--color-brutal-stone-400)
    secondary400: Color(0xffc0b9b1),
    // var(--color-brutal-stone-500)
    secondary500: Color(0xff9d9891),
    // var(--color-brutal-stone-600)
    secondary600: Color(0xff7b7671),
    // var(--color-brutal-stone-700)
    secondary700: Color(0xff5d5955),
    // var(--color-brutal-stone-800)
    secondary800: Color(0xff3e3b38),
    // var(--color-brutal-stone-900)
    secondary900: Color(0xff23211f),
    // var(--color-brutal-stone-950)
    secondary950: Color(0xff141312),
    // var(--color-brutal-cyan-400)
    info: Color(0xff28ccf3),
    // oklch(0.441 0.078 221.2)
    infoStrong: Color(0xff095c71),
    // oklch(0.87 0.07 224)
    infoMuted: Color(0xffa2dff7),
    // oklch(0.91 0.056 224.02)
    infoSoft: Color(0xffbaeafd),
    // oklch(0.714 0.176 153.079)
    success: Color(0xff1fc16b),
    // oklch(1 0 0)
    successForeground: Color(0xffffffff),
    // oklch(0.425 0.113 151.2)
    successStrong: Color(0xff025f2c),
    // oklch(0.875 0.13 160)
    successMuted: Color(0xff82f0b8),
    // oklch(0.913 0.11 159.9)
    successSoft: Color(0xff9ff9c9),
    // oklch(0.7 0.202 44.441)
    warning: Color(0xffff6900),
    // oklch(1 0 0)
    warningForeground: Color(0xffffffff),
    // oklch(0.59 0.2 40.57)
    warningStrong: Color(0xffd84100),
    // oklch(0.92 0.045 44.4)
    warningMuted: Color(0xffffdccd),
    // oklch(0.95 0.03 44.33)
    warningSoft: Color(0xffffe9df),
    // oklch(0.616 0.249 26.758)
    danger: Color(0xfff70720),
    // oklch(1 0 0)
    dangerForeground: Color(0xffffffff),
    // oklch(0.445 0.153 32.91)
    dangerStrong: Color(0xff96240e),
    // oklch(0.862 0.065 22.7)
    dangerMuted: Color(0xfffac2be),
    // oklch(0.898 0.05 22.7)
    dangerSoft: Color(0xfffdd1ce),
    // oklch(0.573 0 0)
    inactive: Color(0xff787878),
    // oklch(0.946 0 0)
    inactiveForeground: Color(0xffededed),
    // oklch(0.44 0.09 91.39)
    primaryStrong: Color(0xff655000),
    // oklch(0.955 0.067 93.62)
    primarySoft: Color(0xfffff0bd),
    // oklch(0.83 0.14 91.89 / 0.7)
    // Chrome-composite fit, CSS alpha 0.7 (see docs/design-tokens.md)
    primaryEdge: Color.from(alpha: 0.700000, red: 0.911064, green: 0.771008, blue: 0.306022),
    // oklch(0.85 0.162 91.89)
    primaryGlow: Color(0xfff4c931),
    // oklch(0.52 0.215 359.77)
    accentStrong: Color(0xffc00064),
    // oklch(0.914 0.048 358.59)
    accentSoft: Color(0xffffd6e2),
    // color-mix(in srgb-linear, var(--primary-soft) 88%, var(--primary-strong))
    primaryHover: Color(0xfff3e4b3),
    // color-mix(in srgb-linear, var(--primary-400) 84%, var(--ink))
    primaryActive: Color(0xffecc43c),
    // color-mix(in srgb-linear, var(--accent-soft) 88%, var(--accent-strong))
    accentHover: Color(0xfff8cad8),
    // color-mix(in srgb-linear, var(--accent-400) 84%, var(--ink))
    accentActive: Color(0xffeb749c),
    // color-mix(in srgb-linear, var(--info) 84%, var(--ink))
    infoHover: Color(0xff26bde1),
    // color-mix(in srgb-linear, var(--info) 76%, var(--ink))
    infoActive: Color(0xff25b5d7),
    // color-mix(in srgb-linear, var(--warning) 84%, var(--ink))
    warningHover: Color(0xffec6104),
    // color-mix(in srgb-linear, var(--warning) 76%, var(--ink))
    warningActive: Color(0xffe25d06),
    // color-mix(in srgb-linear, var(--danger) 84%, var(--ink))
    dangerHover: Color(0xffe50b1e),
    // color-mix(in srgb-linear, var(--danger) 76%, var(--ink))
    dangerActive: Color(0xffdb0c1e),
  );
  /// `elegant-dark` resolved values.
  static const elegantDark = RaftSemanticColors(
    // oklch(0.88 0.004 106.42)
    foreground: Color(0xffd8d8d5),
    // oklch(0.92 0.003 106.42)
    foregroundStrong: Color(0xffe5e5e2),
    // oklch(0.82 0.005 106.42)
    foregroundMuted: Color(0xffc4c4c1),
    // oklch(0.76 0.005 106.42)
    foregroundHint: Color(0xffb1b1ae),
    // oklch(0.82 0.005 106.42 / 0.68)
    // Chrome-composite fit, CSS alpha 0.68 (see docs/design-tokens.md)
    foregroundIcon: Color.from(alpha: 0.678897, red: 0.766973, green: 0.766973, blue: 0.755370),
    // oklch(0.72 0.005 106.42)
    foregroundPlaceholder: Color(0xffa5a5a1),
    // oklch(0.65 0.005 106.42)
    foregroundDisabled: Color(0xff8f8f8c),
    // oklch(0.145 0 0)
    foregroundInverse: Color(0xff0a0a0a),
    // oklch(0.88 0.004 106.42)
    foregroundActive: Color(0xffd8d8d5),
    // oklch(0.85 0.004 106.42)
    foregroundHover: Color(0xffcececb),
    // oklch(0.19 0.005 106.42)
    layerCanvas: Color(0xff141411),
    // oklch(0.16 0.005 106.42)
    layerCanvasMuted: Color(0xff0d0d0b),
    // oklch(0.26 0.004 106.42)
    layerPanel: Color(0xff242422),
    // oklch(0.28 0.004 106.42)
    layerPopover: Color(0xff292927),
    // oklch(0 0 0 / 0.6)
    // Chrome-composite fit, CSS alpha 0.6 (see docs/design-tokens.md)
    layerBackdrop: Color.from(alpha: 0.601961, red: 0.000278, green: 0.000278, blue: 0.000198),
    // oklch(0.185 0.003 106.42)
    layerInset: Color(0xff131311),
    // oklch(0.22 0.004 106.42)
    layerCard: Color(0xff1b1b19),
    // oklch(0.23 0.01 294.8)
    layerHud: Color(0xff1d1c21),
    // oklch(0.78 0.006 294.8)
    layerHudForeground: Color(0xffb7b7bb),
    // oklch(0.315 0.005 106.42)
    fillMuted: Color(0xff32322f),
    // oklch(0.345 0.005 106.42)
    fillStrong: Color(0xff393936),
    // oklch(0.95 0.003 106.42)
    lineStrong: Color(0xffeeefec),
    // oklch(0.56 0.005 106.42)
    line: Color(0xff757571),
    // var(--ink-10)
    // Chrome-composite fit, CSS alpha 0.1 (see docs/design-tokens.md)
    lineMuted: Color.from(alpha: 0.101961, red: 0.943439, green: 0.943439, blue: 0.945814),
    // var(--ink-6)
    // Chrome-composite fit, CSS alpha 0.06 (see docs/design-tokens.md)
    lineHairline: Color.from(alpha: 0.058162, red: 0.981243, green: 0.981409, blue: 0.982188),
    // var(--ink-16)
    // Chrome-composite fit, CSS alpha 0.16 (see docs/design-tokens.md)
    lineField: Color.from(alpha: 0.160735, red: 0.965347, green: 0.965347, blue: 0.964045),
    // var(--ink-20)
    // Chrome-composite fit, CSS alpha 0.2 (see docs/design-tokens.md)
    lineFieldHover: Color.from(alpha: 0.200000, red: 0.973529, green: 0.973529, blue: 0.953922),
    // oklch(0.985 0.004 106.42)
    ink: Color(0xfffafaf7),
    // oklch(0.985 0.004 106.42 / 0.02)
    // Chrome-composite fit, CSS alpha 0.02 (see docs/design-tokens.md)
    ink2: Color.from(alpha: 0.019632, red: 0.937424, green: 0.937424, blue: 0.931541),
    // oklch(0.985 0.004 106.42 / 0.04)
    // Chrome-composite fit, CSS alpha 0.04 (see docs/design-tokens.md)
    ink4: Color.from(alpha: 0.039203, red: 0.954685, green: 0.954685, blue: 0.969524),
    // oklch(0.985 0.004 106.42 / 0.06)
    // Chrome-composite fit, CSS alpha 0.06 (see docs/design-tokens.md)
    ink6: Color.from(alpha: 0.058162, red: 0.981243, green: 0.981409, blue: 0.982188),
    // oklch(0.985 0.004 106.42 / 0.08)
    // Chrome-composite fit, CSS alpha 0.08 (see docs/design-tokens.md)
    ink8: Color.from(alpha: 0.078407, red: 0.976028, green: 0.976028, blue: 0.927460),
    // oklch(0.985 0.004 106.42 / 0.1)
    // Chrome-composite fit, CSS alpha 0.1 (see docs/design-tokens.md)
    ink10: Color.from(alpha: 0.101961, red: 0.943439, green: 0.943439, blue: 0.945814),
    // oklch(0.985 0.004 106.42 / 0.16)
    // Chrome-composite fit, CSS alpha 0.16 (see docs/design-tokens.md)
    ink16: Color.from(alpha: 0.160735, red: 0.965347, green: 0.965347, blue: 0.964045),
    // oklch(0.985 0.004 106.42 / 0.2)
    // Chrome-composite fit, CSS alpha 0.2 (see docs/design-tokens.md)
    ink20: Color.from(alpha: 0.200000, red: 0.973529, green: 0.973529, blue: 0.953922),
    // oklch(0.985 0.004 106.42 / 0.3)
    // Chrome-composite fit, CSS alpha 0.3 (see docs/design-tokens.md)
    ink30: Color.from(alpha: 0.301961, red: 0.967914, green: 0.967914, blue: 0.968831),
    // oklch(0.985 0.004 106.42 / 0.4)
    // Chrome-composite fit, CSS alpha 0.4 (see docs/design-tokens.md)
    ink40: Color.from(alpha: 0.400000, red: 0.976961, green: 0.976961, blue: 0.968627),
    // var(--color-brutal-yellow-50)
    primary50: Color(0xfffff9ed),
    // var(--color-brutal-yellow-100)
    primary100: Color(0xfffff6e3),
    // var(--color-brutal-yellow-200)
    primary200: Color(0xffffe9b9),
    // var(--color-brutal-yellow-300)
    primary300: Color(0xffffdf91),
    // var(--color-brutal-yellow-400)
    primary400: Color(0xffffd441),
    // var(--color-brutal-yellow-500)
    primary500: Color(0xffd3ad03),
    // var(--color-brutal-yellow-600)
    primary600: Color(0xffa78802),
    // var(--color-brutal-yellow-700)
    primary700: Color(0xff7a6300),
    // var(--color-brutal-yellow-800)
    primary800: Color(0xff534300),
    // var(--color-brutal-yellow-900)
    primary900: Color(0xff2d2300),
    // var(--color-brutal-yellow-950)
    primary950: Color(0xff1c1500),
    // var(--color-brutal-pink-50)
    accent50: Color(0xfffff0f4),
    // var(--color-brutal-pink-100)
    accent100: Color(0xffffe1e8),
    // var(--color-brutal-pink-200)
    accent200: Color(0xfffec1d2),
    // var(--color-brutal-pink-300)
    accent300: Color(0xfffea0bc),
    // var(--color-brutal-pink-400)
    accent400: Color(0xfffe7da8),
    // var(--color-brutal-pink-500)
    accent500: Color(0xfffe2f8b),
    // var(--color-brutal-pink-600)
    accent600: Color(0xffd4086f),
    // var(--color-brutal-pink-700)
    accent700: Color(0xff9f0551),
    // var(--color-brutal-pink-800)
    accent800: Color(0xff700238),
    // var(--color-brutal-pink-900)
    accent900: Color(0xff42011e),
    // var(--color-brutal-pink-950)
    accent950: Color(0xff2f0014),
    // var(--color-brutal-stone-50)
    secondary50: Color(0xfff7f6f5),
    // var(--color-brutal-stone-100)
    secondary100: Color(0xffefedeb),
    // var(--color-brutal-stone-200)
    secondary200: Color(0xffe0dcd7),
    // var(--color-brutal-stone-300)
    secondary300: Color(0xffd2cbc2),
    // var(--color-brutal-stone-400)
    secondary400: Color(0xffc0b9b1),
    // var(--color-brutal-stone-500)
    secondary500: Color(0xff9d9891),
    // var(--color-brutal-stone-600)
    secondary600: Color(0xff7b7671),
    // var(--color-brutal-stone-700)
    secondary700: Color(0xff5d5955),
    // var(--color-brutal-stone-800)
    secondary800: Color(0xff3e3b38),
    // var(--color-brutal-stone-900)
    secondary900: Color(0xff23211f),
    // var(--color-brutal-stone-950)
    secondary950: Color(0xff141312),
    // var(--color-brutal-cyan-400)
    info: Color(0xff28ccf3),
    // oklch(0.8 0.1 220)
    infoStrong: Color(0xff6ccdea),
    // oklch(0.52 0.1 222 / 0.28)
    // Chrome-composite fit, CSS alpha 0.28 (see docs/design-tokens.md)
    infoMuted: Color.from(alpha: 0.280368, red: 0.000245, green: 0.461772, blue: 0.574749),
    // oklch(0.45 0.09 224 / 0.18)
    // Chrome-composite fit, CSS alpha 0.18 (see docs/design-tokens.md)
    infoSoft: Color.from(alpha: 0.180551, red: 0.000603, green: 0.371047, blue: 0.476102),
    // oklch(0.714 0.176 153.079)
    success: Color(0xff1fc16b),
    // oklch(1 0 0)
    successForeground: Color(0xffffffff),
    // oklch(0.8 0.14 153)
    successStrong: Color(0xff6ed892),
    // oklch(0.52 0.13 153 / 0.28)
    // Chrome-composite fit, CSS alpha 0.28 (see docs/design-tokens.md)
    successMuted: Color.from(alpha: 0.277733, red: 0.039399, green: 0.491236, blue: 0.261633),
    // oklch(0.5 0.12 153 / 0.18)
    // Chrome-composite fit, CSS alpha 0.18 (see docs/design-tokens.md)
    successSoft: Color.from(alpha: 0.180368, red: 0.081719, green: 0.451335, blue: 0.250594),
    // oklch(0.7 0.202 44.441)
    warning: Color(0xffff6900),
    // oklch(1 0 0)
    warningForeground: Color(0xffffffff),
    // oklch(0.82 0.12 55)
    warningStrong: Color(0xffffaf76),
    // oklch(0.55 0.13 50 / 0.28)
    // Chrome-composite fit, CSS alpha 0.28 (see docs/design-tokens.md)
    warningMuted: Color.from(alpha: 0.278407, red: 0.673534, green: 0.335476, blue: 0.106303),
    // oklch(0.52 0.12 50 / 0.18)
    // Chrome-composite fit, CSS alpha 0.18 (see docs/design-tokens.md)
    warningSoft: Color.from(alpha: 0.180368, red: 0.621523, green: 0.317134, blue: 0.098399),
    // oklch(0.616 0.249 26.758)
    danger: Color(0xfff70720),
    // oklch(1 0 0)
    dangerForeground: Color(0xffffffff),
    // oklch(0.8 0.1 25)
    dangerStrong: Color(0xfff8a49d),
    // oklch(0.58 0.19 29 / 0.3)
    // Chrome-composite fit, CSS alpha 0.3 (see docs/design-tokens.md)
    dangerMuted: Color.from(alpha: 0.301961, red: 0.825057, green: 0.227655, blue: 0.176623),
    // oklch(0.55 0.19 29 / 0.18)
    // Chrome-composite fit, CSS alpha 0.18 (see docs/design-tokens.md)
    dangerSoft: Color.from(alpha: 0.180368, red: 0.777466, green: 0.190430, blue: 0.141883),
    // oklch(0.65 0.004 106.42)
    inactive: Color(0xff8f8f8d),
    // oklch(0.145 0.002 106.42)
    inactiveForeground: Color(0xff0a0a09),
    // oklch(0.88 0.13 92)
    primaryStrong: Color(0xfff6d56b),
    // oklch(0.55 0.1 92 / 0.16)
    // Chrome-composite fit, CSS alpha 0.16 (see docs/design-tokens.md)
    primarySoft: Color.from(alpha: 0.160735, red: 0.526189, green: 0.428598, blue: 0.110126),
    // oklch(0.88 0.15 92 / 0.4)
    // Chrome-composite fit, CSS alpha 0.4 (see docs/design-tokens.md)
    primaryEdge: Color.from(alpha: 0.400000, red: 0.976961, green: 0.829902, blue: 0.321569),
    // oklch(0.85 0.162 91.89)
    primaryGlow: Color(0xfff4c931),
    // oklch(0.84 0.11 0)
    accentStrong: Color(0xffffacc7),
    // oklch(0.6 0.18 0 / 0.16)
    // Chrome-composite fit, CSS alpha 0.16 (see docs/design-tokens.md)
    accentSoft: Color.from(alpha: 0.160735, red: 0.794563, green: 0.257814, blue: 0.476091),
    // color-mix(in srgb-linear, var(--primary-soft) 78%, var(--primary-strong))
    // Chrome-composite fit, CSS alpha 0.3448 (see docs/design-tokens.md)
    primaryHover: Color.from(alpha: 0.345106, red: 0.836486, green: 0.711489, blue: 0.348307),
    // color-mix(in srgb-linear, var(--primary-400) 84%, var(--ink))
    primaryActive: Color(0xfffedb7a),
    // color-mix(in srgb-linear, var(--accent-soft) 78%, var(--accent-strong))
    // Chrome-composite fit, CSS alpha 0.3448 (see docs/design-tokens.md)
    accentHover: Color.from(alpha: 0.345106, red: 0.950120, green: 0.563765, blue: 0.691403),
    // color-mix(in srgb-linear, var(--accent-400) 84%, var(--ink))
    accentActive: Color(0xfffd9bb8),
    // color-mix(in srgb-linear, var(--info) 84%, var(--ink))
    infoHover: Color(0xff73d4f4),
    // color-mix(in srgb-linear, var(--info) 76%, var(--ink))
    infoActive: Color(0xff88d8f4),
    // color-mix(in srgb-linear, var(--warning) 84%, var(--ink))
    warningHover: Color(0xfffe8e6c),
    // color-mix(in srgb-linear, var(--warning) 76%, var(--ink))
    warningActive: Color(0xfffe9d82),
    // color-mix(in srgb-linear, var(--danger) 84%, var(--ink))
    dangerHover: Color(0xfff86e70),
    // color-mix(in srgb-linear, var(--danger) 76%, var(--ink))
    dangerActive: Color(0xfff88485),
  );
}
