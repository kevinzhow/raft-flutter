// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: component-roles.css over raft-ui-0.5.52/foundation.css, raft-ui-0.5.52/styles.css, raft-web-a98ae00/index.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Tier 3: component colour roles from tool/design-source/component-roles.css.
///
/// Each role is the CSS a raft-ui recipe class resolves to (see the comment
/// on each role in the .css file). Values: see [RaftSemanticColors] and
/// raft_token_mapping.dart.
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

  /// Builds the tier from a map keyed by CSS custom-property name (without `--`); throws
  /// a [StateError] naming the first missing key, so no field can be left unmapped.
  factory RaftComponentColors.fromCssMap(Map<String, Color> map) {
    Color of(String key) => map[key] ?? (throw StateError('RaftComponentColors: no value for $key'));
    return RaftComponentColors(
      primary: of('primary'),
      accent: of('accent'),
      brutalCream: of('brutal-cream'),
      buttonDefaultFill: of('button-default-fill'),
      buttonDefaultHover: of('button-default-hover'),
      buttonPrimaryHover: of('button-primary-hover'),
      buttonAccentHover: of('button-accent-hover'),
      buttonAccentEdge: of('button-accent-edge'),
      buttonDangerFill: of('button-danger-fill'),
      buttonDangerHover: of('button-danger-hover'),
      buttonDangerForeground: of('button-danger-foreground'),
      buttonDangerHighContrast: of('button-danger-high-contrast'),
      buttonDangerHighContrastForeground: of('button-danger-high-contrast-foreground'),
      taskSectionFill: of('task-section-fill'),
      codeBorder: of('code-border'),
      fieldInsetLine: of('field-inset-line'),
      fieldInsetTop: of('field-inset-top'),
      fieldInsetBottom: of('field-inset-bottom'),
      switchThumb: of('switch-thumb'),
      switchThumbChecked: of('switch-thumb-checked'),
      switchThumbDisabled: of('switch-thumb-disabled'),
      switchThumbCheckedDisabled: of('switch-thumb-checked-disabled'),
      switchShadowBottom: of('switch-shadow-bottom'),
    );
  }

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

  /// Every CSS name of this tier, in field order (without the leading `--`).
  static const List<String> cssNames = [
    'primary',
    'accent',
    'brutal-cream',
    'button-default-fill',
    'button-default-hover',
    'button-primary-hover',
    'button-accent-hover',
    'button-accent-edge',
    'button-danger-fill',
    'button-danger-hover',
    'button-danger-foreground',
    'button-danger-high-contrast',
    'button-danger-high-contrast-foreground',
    'task-section-fill',
    'code-border',
    'field-inset-line',
    'field-inset-top',
    'field-inset-bottom',
    'switch-thumb',
    'switch-thumb-checked',
    'switch-thumb-disabled',
    'switch-thumb-checked-disabled',
    'switch-shadow-bottom',
  ];

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
}
