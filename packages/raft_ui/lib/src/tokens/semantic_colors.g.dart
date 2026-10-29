// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: raft-ui-0.5.52/foundation.css, raft-ui-0.5.52/styles.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Tier 2: the colour variables of the raft-ui 0.5.52 theme blocks, as a field schema.
///
/// Components still read these names. The per-theme values are no longer
/// generated from the 0.5.52 CSS: [RaftTokenSet] fills this tier for the Raft
/// light and dark looks from [RaftLight] / [RaftDark] through the explicit
/// old-name to new-token table in raft_token_mapping.dart.
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
    required this.taskStatusTodo,
    required this.taskStatusTodoSoft,
    required this.taskStatusTodoStrong,
    required this.taskStatusInProgress,
    required this.taskStatusInProgressSoft,
    required this.taskStatusInProgressStrong,
    required this.taskStatusInReview,
    required this.taskStatusInReviewSoft,
    required this.taskStatusInReviewStrong,
    required this.taskStatusDone,
    required this.taskStatusDoneSoft,
    required this.taskStatusDoneStrong,
    required this.taskStatusClosed,
    required this.taskStatusClosedSoft,
    required this.taskStatusClosedStrong,
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

  /// Builds the tier from a map keyed by CSS custom-property name (without `--`); throws
  /// a [StateError] naming the first missing key, so no field can be left unmapped.
  factory RaftSemanticColors.fromCssMap(Map<String, Color> map) {
    Color of(String key) => map[key] ?? (throw StateError('RaftSemanticColors: no value for $key'));
    return RaftSemanticColors(
      foreground: of('foreground'),
      foregroundStrong: of('foreground-strong'),
      foregroundMuted: of('foreground-muted'),
      foregroundHint: of('foreground-hint'),
      foregroundIcon: of('foreground-icon'),
      foregroundPlaceholder: of('foreground-placeholder'),
      foregroundDisabled: of('foreground-disabled'),
      foregroundInverse: of('foreground-inverse'),
      foregroundActive: of('foreground-active'),
      foregroundHover: of('foreground-hover'),
      layerCanvas: of('layer-canvas'),
      layerCanvasMuted: of('layer-canvas-muted'),
      layerPanel: of('layer-panel'),
      layerPopover: of('layer-popover'),
      layerBackdrop: of('layer-backdrop'),
      layerInset: of('layer-inset'),
      layerCard: of('layer-card'),
      layerHud: of('layer-hud'),
      layerHudForeground: of('layer-hud-foreground'),
      fillMuted: of('fill-muted'),
      fillStrong: of('fill-strong'),
      lineStrong: of('line-strong'),
      line: of('line'),
      lineMuted: of('line-muted'),
      lineHairline: of('line-hairline'),
      lineField: of('line-field'),
      lineFieldHover: of('line-field-hover'),
      ink: of('ink'),
      ink2: of('ink-2'),
      ink4: of('ink-4'),
      ink6: of('ink-6'),
      ink8: of('ink-8'),
      ink10: of('ink-10'),
      ink16: of('ink-16'),
      ink20: of('ink-20'),
      ink30: of('ink-30'),
      ink40: of('ink-40'),
      primary50: of('primary-50'),
      primary100: of('primary-100'),
      primary200: of('primary-200'),
      primary300: of('primary-300'),
      primary400: of('primary-400'),
      primary500: of('primary-500'),
      primary600: of('primary-600'),
      primary700: of('primary-700'),
      primary800: of('primary-800'),
      primary900: of('primary-900'),
      primary950: of('primary-950'),
      accent50: of('accent-50'),
      accent100: of('accent-100'),
      accent200: of('accent-200'),
      accent300: of('accent-300'),
      accent400: of('accent-400'),
      accent500: of('accent-500'),
      accent600: of('accent-600'),
      accent700: of('accent-700'),
      accent800: of('accent-800'),
      accent900: of('accent-900'),
      accent950: of('accent-950'),
      secondary50: of('secondary-50'),
      secondary100: of('secondary-100'),
      secondary200: of('secondary-200'),
      secondary300: of('secondary-300'),
      secondary400: of('secondary-400'),
      secondary500: of('secondary-500'),
      secondary600: of('secondary-600'),
      secondary700: of('secondary-700'),
      secondary800: of('secondary-800'),
      secondary900: of('secondary-900'),
      secondary950: of('secondary-950'),
      info: of('info'),
      infoStrong: of('info-strong'),
      infoMuted: of('info-muted'),
      infoSoft: of('info-soft'),
      success: of('success'),
      successForeground: of('success-foreground'),
      successStrong: of('success-strong'),
      successMuted: of('success-muted'),
      successSoft: of('success-soft'),
      warning: of('warning'),
      warningForeground: of('warning-foreground'),
      warningStrong: of('warning-strong'),
      warningMuted: of('warning-muted'),
      warningSoft: of('warning-soft'),
      danger: of('danger'),
      dangerForeground: of('danger-foreground'),
      dangerStrong: of('danger-strong'),
      dangerMuted: of('danger-muted'),
      dangerSoft: of('danger-soft'),
      inactive: of('inactive'),
      inactiveForeground: of('inactive-foreground'),
      taskStatusTodo: of('task-status-todo'),
      taskStatusTodoSoft: of('task-status-todo-soft'),
      taskStatusTodoStrong: of('task-status-todo-strong'),
      taskStatusInProgress: of('task-status-in-progress'),
      taskStatusInProgressSoft: of('task-status-in-progress-soft'),
      taskStatusInProgressStrong: of('task-status-in-progress-strong'),
      taskStatusInReview: of('task-status-in-review'),
      taskStatusInReviewSoft: of('task-status-in-review-soft'),
      taskStatusInReviewStrong: of('task-status-in-review-strong'),
      taskStatusDone: of('task-status-done'),
      taskStatusDoneSoft: of('task-status-done-soft'),
      taskStatusDoneStrong: of('task-status-done-strong'),
      taskStatusClosed: of('task-status-closed'),
      taskStatusClosedSoft: of('task-status-closed-soft'),
      taskStatusClosedStrong: of('task-status-closed-strong'),
      primaryStrong: of('primary-strong'),
      primarySoft: of('primary-soft'),
      primaryEdge: of('primary-edge'),
      primaryGlow: of('primary-glow'),
      accentStrong: of('accent-strong'),
      accentSoft: of('accent-soft'),
      primaryHover: of('primary-hover'),
      primaryActive: of('primary-active'),
      accentHover: of('accent-hover'),
      accentActive: of('accent-active'),
      infoHover: of('info-hover'),
      infoActive: of('info-active'),
      warningHover: of('warning-hover'),
      warningActive: of('warning-active'),
      dangerHover: of('danger-hover'),
      dangerActive: of('danger-active'),
    );
  }

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
  /// `--task-status-todo` — declared in brutal, elegant, elegant.dark
  final Color taskStatusTodo;
  /// `--task-status-todo-soft` — declared in brutal, elegant, elegant.dark
  final Color taskStatusTodoSoft;
  /// `--task-status-todo-strong` — declared in brutal, elegant, elegant.dark
  final Color taskStatusTodoStrong;
  /// `--task-status-in-progress` — declared in brutal, elegant, elegant.dark
  final Color taskStatusInProgress;
  /// `--task-status-in-progress-soft` — declared in brutal, elegant, elegant.dark
  final Color taskStatusInProgressSoft;
  /// `--task-status-in-progress-strong` — declared in brutal, elegant, elegant.dark
  final Color taskStatusInProgressStrong;
  /// `--task-status-in-review` — declared in brutal, elegant, elegant.dark
  final Color taskStatusInReview;
  /// `--task-status-in-review-soft` — declared in brutal, elegant, elegant.dark
  final Color taskStatusInReviewSoft;
  /// `--task-status-in-review-strong` — declared in brutal, elegant, elegant.dark
  final Color taskStatusInReviewStrong;
  /// `--task-status-done` — declared in brutal, elegant, elegant.dark
  final Color taskStatusDone;
  /// `--task-status-done-soft` — declared in brutal, elegant, elegant.dark
  final Color taskStatusDoneSoft;
  /// `--task-status-done-strong` — declared in brutal, elegant, elegant.dark
  final Color taskStatusDoneStrong;
  /// `--task-status-closed` — declared in brutal, elegant, elegant.dark
  final Color taskStatusClosed;
  /// `--task-status-closed-soft` — declared in brutal, elegant, elegant.dark
  final Color taskStatusClosedSoft;
  /// `--task-status-closed-strong` — declared in brutal, elegant, elegant.dark
  final Color taskStatusClosedStrong;
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

  /// Every CSS name of this tier, in field order (without the leading `--`).
  static const List<String> cssNames = [
    'foreground',
    'foreground-strong',
    'foreground-muted',
    'foreground-hint',
    'foreground-icon',
    'foreground-placeholder',
    'foreground-disabled',
    'foreground-inverse',
    'foreground-active',
    'foreground-hover',
    'layer-canvas',
    'layer-canvas-muted',
    'layer-panel',
    'layer-popover',
    'layer-backdrop',
    'layer-inset',
    'layer-card',
    'layer-hud',
    'layer-hud-foreground',
    'fill-muted',
    'fill-strong',
    'line-strong',
    'line',
    'line-muted',
    'line-hairline',
    'line-field',
    'line-field-hover',
    'ink',
    'ink-2',
    'ink-4',
    'ink-6',
    'ink-8',
    'ink-10',
    'ink-16',
    'ink-20',
    'ink-30',
    'ink-40',
    'primary-50',
    'primary-100',
    'primary-200',
    'primary-300',
    'primary-400',
    'primary-500',
    'primary-600',
    'primary-700',
    'primary-800',
    'primary-900',
    'primary-950',
    'accent-50',
    'accent-100',
    'accent-200',
    'accent-300',
    'accent-400',
    'accent-500',
    'accent-600',
    'accent-700',
    'accent-800',
    'accent-900',
    'accent-950',
    'secondary-50',
    'secondary-100',
    'secondary-200',
    'secondary-300',
    'secondary-400',
    'secondary-500',
    'secondary-600',
    'secondary-700',
    'secondary-800',
    'secondary-900',
    'secondary-950',
    'info',
    'info-strong',
    'info-muted',
    'info-soft',
    'success',
    'success-foreground',
    'success-strong',
    'success-muted',
    'success-soft',
    'warning',
    'warning-foreground',
    'warning-strong',
    'warning-muted',
    'warning-soft',
    'danger',
    'danger-foreground',
    'danger-strong',
    'danger-muted',
    'danger-soft',
    'inactive',
    'inactive-foreground',
    'task-status-todo',
    'task-status-todo-soft',
    'task-status-todo-strong',
    'task-status-in-progress',
    'task-status-in-progress-soft',
    'task-status-in-progress-strong',
    'task-status-in-review',
    'task-status-in-review-soft',
    'task-status-in-review-strong',
    'task-status-done',
    'task-status-done-soft',
    'task-status-done-strong',
    'task-status-closed',
    'task-status-closed-soft',
    'task-status-closed-strong',
    'primary-strong',
    'primary-soft',
    'primary-edge',
    'primary-glow',
    'accent-strong',
    'accent-soft',
    'primary-hover',
    'primary-active',
    'accent-hover',
    'accent-active',
    'info-hover',
    'info-active',
    'warning-hover',
    'warning-active',
    'danger-hover',
    'danger-active',
  ];

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
    'task-status-todo': taskStatusTodo,
    'task-status-todo-soft': taskStatusTodoSoft,
    'task-status-todo-strong': taskStatusTodoStrong,
    'task-status-in-progress': taskStatusInProgress,
    'task-status-in-progress-soft': taskStatusInProgressSoft,
    'task-status-in-progress-strong': taskStatusInProgressStrong,
    'task-status-in-review': taskStatusInReview,
    'task-status-in-review-soft': taskStatusInReviewSoft,
    'task-status-in-review-strong': taskStatusInReviewStrong,
    'task-status-done': taskStatusDone,
    'task-status-done-soft': taskStatusDoneSoft,
    'task-status-done-strong': taskStatusDoneStrong,
    'task-status-closed': taskStatusClosed,
    'task-status-closed-soft': taskStatusClosedSoft,
    'task-status-closed-strong': taskStatusClosedStrong,
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
}
