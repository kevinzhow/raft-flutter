// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: raft-ui-0.5.27/styles.css, raft-web-26f77ef/index.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Tier 2b: effective Tailwind colour aliases (`bg-brutal-cyan`, `text-status-busy`, ...).
///
/// raft-ui styles.css @theme declares the bare brutal aliases; the Web product
/// index.css @theme re-declares several with hex literals and wins (later
/// @theme declaration). These are NOT the `--primary-*` ladders.
@immutable
class RaftProductColors {
  const RaftProductColors({
    required this.brutalYellow,
    required this.softSignal,
    required this.brutalLavender,
    required this.brutalPink,
    required this.brutalCyan,
    required this.brutalOrange,
    required this.brutalLime,
    required this.brutalRed,
    required this.brutalStone,
    required this.brutalCream,
    required this.statusBusy,
    required this.workspaceModeActive,
    required this.brutalBlack,
    required this.codeSurface,
    required this.codeForeground,
  });

  /// `--color-brutal-yellow` — product @theme overrides raft-ui `var(--color-brutal-yellow-400)`
  final Color brutalYellow;
  /// `--color-soft-signal` — product @theme overrides raft-ui `var(--color-brutal-yellow)`
  final Color softSignal;
  /// `--color-brutal-lavender` — product @theme overrides raft-ui `var(--color-brutal-purple-400)`
  final Color brutalLavender;
  /// `--color-brutal-pink` — product @theme overrides raft-ui `var(--color-brutal-pink-400)`
  final Color brutalPink;
  /// `--color-brutal-cyan` — product @theme overrides raft-ui `var(--color-brutal-cyan-400)`
  final Color brutalCyan;
  /// `--color-brutal-orange` — product @theme overrides raft-ui `var(--color-brutal-orange-400)`
  final Color brutalOrange;
  /// `--color-brutal-lime` — product @theme overrides raft-ui `var(--color-brutal-lime-400)`
  final Color brutalLime;
  /// `--color-brutal-red` — product @theme overrides raft-ui `var(--color-brutal-red-400)`
  final Color brutalRed;
  /// `--color-brutal-stone` — product @theme overrides raft-ui `var(--color-brutal-stone-400)`
  final Color brutalStone;
  /// `--color-brutal-cream` — product @theme overrides raft-ui `var(--color-brutal-cream-200)`
  final Color brutalCream;
  /// `--color-status-busy` — product @theme
  final Color statusBusy;
  /// `--color-workspace-mode-active` — product @theme
  final Color workspaceModeActive;
  /// `--color-brutal-black` — product @theme
  final Color brutalBlack;
  /// `--color-code-surface` — product @theme (:root.dark override)
  final Color codeSurface;
  /// `--color-code-foreground` — product @theme (:root.dark override)
  final Color codeForeground;

  /// All tokens keyed by CSS custom-property name (without the leading `--`).
  Map<String, Color> toCssMap() => {
    'color-brutal-yellow': brutalYellow,
    'color-soft-signal': softSignal,
    'color-brutal-lavender': brutalLavender,
    'color-brutal-pink': brutalPink,
    'color-brutal-cyan': brutalCyan,
    'color-brutal-orange': brutalOrange,
    'color-brutal-lime': brutalLime,
    'color-brutal-red': brutalRed,
    'color-brutal-stone': brutalStone,
    'color-brutal-cream': brutalCream,
    'color-status-busy': statusBusy,
    'color-workspace-mode-active': workspaceModeActive,
    'color-brutal-black': brutalBlack,
    'color-code-surface': codeSurface,
    'color-code-foreground': codeForeground,
  };

  /// `brutal-light` resolved values.
  static const brutal = RaftProductColors(
    // #FFD440
    brutalYellow: Color(0xffffd440),
    // var(--color-brutal-yellow)
    softSignal: Color(0xffffd440),
    // #BBAFE6
    brutalLavender: Color(0xffbbafe6),
    // #FE7DA8
    brutalPink: Color(0xfffe7da8),
    // #27CCF3
    brutalCyan: Color(0xff27ccf3),
    // #F8A16F
    brutalOrange: Color(0xfff8a16f),
    // #A9D877
    brutalLime: Color(0xffa9d877),
    // #F97264
    brutalRed: Color(0xfff97264),
    // #C0B9B1
    brutalStone: Color(0xffc0b9b1),
    // #FFFAEF
    brutalCream: Color(0xfffffaef),
    // #FFD440
    statusBusy: Color(0xffffd440),
    // #E3B100
    workspaceModeActive: Color(0xffe3b100),
    // #141111
    brutalBlack: Color(0xff141111),
    // #ffffff
    codeSurface: Color(0xffffffff),
    // #24292e
    codeForeground: Color(0xff24292e),
  );
  /// `elegant-light` resolved values.
  static const elegantLight = RaftProductColors(
    // #FFD440
    brutalYellow: Color(0xffffd440),
    // var(--color-brutal-yellow)
    softSignal: Color(0xffffd440),
    // #BBAFE6
    brutalLavender: Color(0xffbbafe6),
    // #FE7DA8
    brutalPink: Color(0xfffe7da8),
    // #27CCF3
    brutalCyan: Color(0xff27ccf3),
    // #F8A16F
    brutalOrange: Color(0xfff8a16f),
    // #A9D877
    brutalLime: Color(0xffa9d877),
    // #F97264
    brutalRed: Color(0xfff97264),
    // #C0B9B1
    brutalStone: Color(0xffc0b9b1),
    // #FFFAEF
    brutalCream: Color(0xfffffaef),
    // #FFD440
    statusBusy: Color(0xffffd440),
    // #E3B100
    workspaceModeActive: Color(0xffe3b100),
    // #141111
    brutalBlack: Color(0xff141111),
    // #ffffff
    codeSurface: Color(0xffffffff),
    // #24292e
    codeForeground: Color(0xff24292e),
  );
  /// `elegant-dark` resolved values.
  static const elegantDark = RaftProductColors(
    // #FFD440
    brutalYellow: Color(0xffffd440),
    // var(--color-brutal-yellow)
    softSignal: Color(0xffffd440),
    // #BBAFE6
    brutalLavender: Color(0xffbbafe6),
    // #FE7DA8
    brutalPink: Color(0xfffe7da8),
    // #27CCF3
    brutalCyan: Color(0xff27ccf3),
    // #F8A16F
    brutalOrange: Color(0xfff8a16f),
    // #A9D877
    brutalLime: Color(0xffa9d877),
    // #F97264
    brutalRed: Color(0xfff97264),
    // #C0B9B1
    brutalStone: Color(0xffc0b9b1),
    // #FFFAEF
    brutalCream: Color(0xfffffaef),
    // #FFD440
    statusBusy: Color(0xffffd440),
    // #E3B100
    workspaceModeActive: Color(0xffe3b100),
    // #141111
    brutalBlack: Color(0xff141111),
    // #0a0c10
    codeSurface: Color(0xff0a0c10),
    // #f0f3f6
    codeForeground: Color(0xfff0f3f6),
  );
}
