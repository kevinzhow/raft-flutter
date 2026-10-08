// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: component-roles.css over raft-ui-0.5.27/foundation.css, raft-ui-0.5.27/styles.css, raft-web-26f77ef/index.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Tier 3: component colour roles from tool/design-source/component-roles.css.
///
/// Each role is the CSS a raft-ui recipe class resolves to (see the comment
/// on each role in the .css file); values resolve through the same cascade.
@immutable
class RaftComponentColors {
  const RaftComponentColors({
    required this.primary,
    required this.accent,
    required this.brutalCream,
    required this.buttonDefaultFill,
    required this.buttonDefaultHover,
    required this.buttonPrimaryHover,
    required this.buttonAccentHover,
    required this.buttonAccentEdge,
    required this.buttonDangerFill,
    required this.buttonDangerHover,
    required this.buttonDangerForeground,
    required this.buttonDangerHighContrast,
    required this.buttonDangerHighContrastForeground,
    required this.taskSectionFill,
    required this.codeBorder,
    required this.fieldInsetLine,
    required this.fieldInsetTop,
    required this.fieldInsetBottom,
    required this.switchThumb,
    required this.switchThumbChecked,
    required this.switchThumbDisabled,
    required this.switchThumbCheckedDisabled,
    required this.switchShadowBottom,
  });

  /// `--primary`
  final Color primary;
  /// `--accent`
  final Color accent;
  /// `--brutal-cream`
  final Color brutalCream;
  /// `--button-default-fill`
  final Color buttonDefaultFill;
  /// `--button-default-hover`
  final Color buttonDefaultHover;
  /// `--button-primary-hover`
  final Color buttonPrimaryHover;
  /// `--button-accent-hover`
  final Color buttonAccentHover;
  /// `--button-accent-edge`
  final Color buttonAccentEdge;
  /// `--button-danger-fill`
  final Color buttonDangerFill;
  /// `--button-danger-hover`
  final Color buttonDangerHover;
  /// `--button-danger-foreground`
  final Color buttonDangerForeground;
  /// `--button-danger-high-contrast`
  final Color buttonDangerHighContrast;
  /// `--button-danger-high-contrast-foreground`
  final Color buttonDangerHighContrastForeground;
  /// `--task-section-fill`
  final Color taskSectionFill;
  /// `--code-border`
  final Color codeBorder;
  /// `--field-inset-line`
  final Color fieldInsetLine;
  /// `--field-inset-top`
  final Color fieldInsetTop;
  /// `--field-inset-bottom`
  final Color fieldInsetBottom;
  /// `--switch-thumb`
  final Color switchThumb;
  /// `--switch-thumb-checked`
  final Color switchThumbChecked;
  /// `--switch-thumb-disabled`
  final Color switchThumbDisabled;
  /// `--switch-thumb-checked-disabled`
  final Color switchThumbCheckedDisabled;
  /// `--switch-shadow-bottom`
  final Color switchShadowBottom;

  /// All tokens keyed by CSS custom-property name (without the leading `--`).
  Map<String, Color> toCssMap() => {
    'primary': primary,
    'accent': accent,
    'brutal-cream': brutalCream,
    'button-default-fill': buttonDefaultFill,
    'button-default-hover': buttonDefaultHover,
    'button-primary-hover': buttonPrimaryHover,
    'button-accent-hover': buttonAccentHover,
    'button-accent-edge': buttonAccentEdge,
    'button-danger-fill': buttonDangerFill,
    'button-danger-hover': buttonDangerHover,
    'button-danger-foreground': buttonDangerForeground,
    'button-danger-high-contrast': buttonDangerHighContrast,
    'button-danger-high-contrast-foreground': buttonDangerHighContrastForeground,
    'task-section-fill': taskSectionFill,
    'code-border': codeBorder,
    'field-inset-line': fieldInsetLine,
    'field-inset-top': fieldInsetTop,
    'field-inset-bottom': fieldInsetBottom,
    'switch-thumb': switchThumb,
    'switch-thumb-checked': switchThumbChecked,
    'switch-thumb-disabled': switchThumbDisabled,
    'switch-thumb-checked-disabled': switchThumbCheckedDisabled,
    'switch-shadow-bottom': switchShadowBottom,
  };

  /// `brutal-light` resolved values.
  static const brutal = RaftComponentColors(
    // var(--color-brutal-yellow)
    primary: Color(0xffffd440),
    // var(--color-brutal-pink)
    accent: Color(0xfffe7da8),
    // var(--color-brutal-cream)
    brutalCream: Color(0xfffffaef),
    // var(--foreground)
    buttonDefaultFill: Color(0xff141110),
    // oklch(0.31 0.006 106.42)
    buttonDefaultHover: Color(0xff31312d),
    // var(--primary-hover)
    buttonPrimaryHover: Color(0xfff6cc3e),
    // var(--accent-hover)
    buttonAccentHover: Color(0xfff578a2),
    // color-mix(in srgb-linear, var(--accent-strong) 28%, transparent)
    // Chrome-composite fit, CSS alpha 0.28 (see docs/design-tokens.md)
    buttonAccentEdge: Color.from(alpha: 0.280000, red: 0.757003, green: 0.001751, blue: 0.393585),
    // var(--danger)
    buttonDangerFill: Color(0xfff70720),
    // var(--danger-hover)
    buttonDangerHover: Color(0xffe5061d),
    // var(--danger-foreground)
    buttonDangerForeground: Color(0xffffffff),
    // var(--color-brutal-red-700)
    buttonDangerHighContrast: Color(0xff8e2510),
    // var(--color-white)
    buttonDangerHighContrastForeground: Color(0xffffffff),
    // transparent
    taskSectionFill: Color(0x00000000),
    // var(--color-black)
    codeBorder: Color(0xff000000),
    // transparent
    fieldInsetLine: Color(0x00000000),
    // transparent
    fieldInsetTop: Color(0x00000000),
    // transparent
    fieldInsetBottom: Color(0x00000000),
    // var(--line-strong)
    switchThumb: Color(0xff141110),
    // var(--line-strong)
    switchThumbChecked: Color(0xff141110),
    // var(--line)
    switchThumbDisabled: Color(0xff141110),
    // var(--line)
    switchThumbCheckedDisabled: Color(0xff141110),
    // transparent
    switchShadowBottom: Color(0x00000000),
  );
  /// `elegant-light` resolved values.
  static const elegantLight = RaftComponentColors(
    // var(--primary-400)
    primary: Color(0xffffd441),
    // var(--accent-400)
    accent: Color(0xfffe7da8),
    // var(--color-brutal-cream)
    brutalCream: Color(0xfffffaef),
    // var(--foreground)
    buttonDefaultFill: Color(0xff191815),
    // oklch(0.31 0.006 106.42)
    buttonDefaultHover: Color(0xff31312d),
    // var(--primary-hover)
    buttonPrimaryHover: Color(0xfff3e4b3),
    // var(--accent-hover)
    buttonAccentHover: Color(0xfff8cad8),
    // color-mix(in srgb-linear, var(--accent-strong) 28%, transparent)
    // Chrome-composite fit, CSS alpha 0.28 (see docs/design-tokens.md)
    buttonAccentEdge: Color.from(alpha: 0.280000, red: 0.757423, green: 0.001751, blue: 0.393585),
    // var(--danger)
    buttonDangerFill: Color(0xfff70720),
    // var(--danger-hover)
    buttonDangerHover: Color(0xffe50b1e),
    // var(--danger-foreground)
    buttonDangerForeground: Color(0xffffffff),
    // var(--color-brutal-red-700)
    buttonDangerHighContrast: Color(0xff8e2510),
    // var(--color-white)
    buttonDangerHighContrastForeground: Color(0xffffffff),
    // color-mix(in oklch, var(--ink-4), var(--layer-panel))
    // Chrome-composite fit, CSS alpha 0.52 (see docs/design-tokens.md)
    taskSectionFill: Color.from(alpha: 0.520000, red: 0.962519, green: 0.962670, blue: 0.962368),
    // var(--line)
    codeBorder: Color(0xffcbcbc6),
    // transparent
    fieldInsetLine: Color(0x00000000),
    // transparent
    fieldInsetTop: Color(0x00000000),
    // transparent
    fieldInsetBottom: Color(0x00000000),
    // var(--layer-popover)
    switchThumb: Color(0xffffffff),
    // var(--layer-popover)
    switchThumbChecked: Color(0xffffffff),
    // oklch(0.88 0.004 106.42)
    switchThumbDisabled: Color(0xffd8d8d5),
    // oklch(0.88 0.004 106.42)
    switchThumbCheckedDisabled: Color(0xffd8d8d5),
    // transparent
    switchShadowBottom: Color(0x00000000),
  );
  /// `elegant-dark` resolved values.
  static const elegantDark = RaftComponentColors(
    // var(--primary-400)
    primary: Color(0xffffd441),
    // var(--accent-400)
    accent: Color(0xfffe7da8),
    // var(--color-brutal-cream)
    brutalCream: Color(0xfffffaef),
    // var(--ink)
    buttonDefaultFill: Color(0xfffafaf7),
    // var(--foreground-strong)
    buttonDefaultHover: Color(0xffe5e5e2),
    // var(--primary-hover)
    // Chrome-composite fit, CSS alpha 0.3448 (see docs/design-tokens.md)
    buttonPrimaryHover: Color.from(alpha: 0.345106, red: 0.836486, green: 0.711489, blue: 0.348307),
    // var(--accent-hover)
    // Chrome-composite fit, CSS alpha 0.3448 (see docs/design-tokens.md)
    buttonAccentHover: Color.from(alpha: 0.345106, red: 0.950120, green: 0.563765, blue: 0.691403),
    // color-mix(in srgb-linear, var(--accent-strong) 28%, transparent)
    // Chrome-composite fit, CSS alpha 0.28 (see docs/design-tokens.md)
    buttonAccentEdge: Color.from(alpha: 0.280000, red: 0.998249, green: 0.675490, blue: 0.781793),
    // oklch(0.58 0.21 27)
    buttonDangerFill: Color(0xffdb2c2b),
    // oklch(0.61 0.21 27)
    buttonDangerHover: Color(0xffe63935),
    // oklch(0.985 0.004 106.42)
    buttonDangerForeground: Color(0xfffafaf7),
    // var(--color-brutal-red-700)
    buttonDangerHighContrast: Color(0xff8e2510),
    // var(--color-white)
    buttonDangerHighContrastForeground: Color(0xffffffff),
    // var(--layer-card)
    taskSectionFill: Color(0xff1b1b19),
    // var(--line)
    codeBorder: Color(0xff757571),
    // oklch(0 0 0 / 0.35)
    // Chrome-composite fit, CSS alpha 0.35 (see docs/design-tokens.md)
    fieldInsetLine: Color.from(alpha: 0.350980, red: 0.000175, green: 0.000175, blue: 0.000526),
    // oklch(0 0 0 / 0.3)
    // Chrome-composite fit, CSS alpha 0.3 (see docs/design-tokens.md)
    fieldInsetTop: Color.from(alpha: 0.303922, red: 0.001423, green: 0.001423, blue: 0.000316),
    // oklch(0.985 0.004 106.42 / 0.04)
    // Chrome-composite fit, CSS alpha 0.04 (see docs/design-tokens.md)
    fieldInsetBottom: Color.from(alpha: 0.039203, red: 0.954685, green: 0.954685, blue: 0.969524),
    // oklch(0.45 0.006 106.42)
    switchThumb: Color(0xff555552),
    // oklch(0.205 0.004 106.42)
    switchThumbChecked: Color(0xff171715),
    // oklch(0.38 0.002 106.42)
    switchThumbDisabled: Color(0xff424241),
    // oklch(0.28 0.002 106.42)
    switchThumbCheckedDisabled: Color(0xff292928),
    // oklch(0.985 0.004 106.42 / 0.04)
    // Chrome-composite fit, CSS alpha 0.04 (see docs/design-tokens.md)
    switchShadowBottom: Color.from(alpha: 0.039203, red: 0.954685, green: 0.954685, blue: 0.969524),
  );
}
