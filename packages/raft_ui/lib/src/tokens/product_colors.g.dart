// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: raft-ui-0.5.52/styles.css, raft-web-a98ae00/index.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Tier 2b: effective Tailwind colour aliases (`bg-brutal-cyan`, `text-status-busy`, ...).
///
/// raft-ui styles.css @theme declares the bare brutal aliases; the Web product
/// index.css @theme re-declares several with hex literals and wins (later
/// @theme declaration). These are NOT the `--primary-*` ladders. Values: see
/// [RaftSemanticColors] and raft_token_mapping.dart.
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
    required this.brutalBlack,
    required this.codeSurface,
    required this.codeForeground,
  });

  /// Builds the tier from a map keyed by CSS custom-property name (without `--`); throws
  /// a [StateError] naming the first missing key, so no field can be left unmapped.
  factory RaftProductColors.fromCssMap(Map<String, Color> map) {
    Color of(String key) => map[key] ?? (throw StateError('RaftProductColors: no value for $key'));
    return RaftProductColors(
      brutalYellow: of('color-brutal-yellow'),
      softSignal: of('color-soft-signal'),
      brutalLavender: of('color-brutal-lavender'),
      brutalPink: of('color-brutal-pink'),
      brutalCyan: of('color-brutal-cyan'),
      brutalOrange: of('color-brutal-orange'),
      brutalLime: of('color-brutal-lime'),
      brutalRed: of('color-brutal-red'),
      brutalStone: of('color-brutal-stone'),
      brutalCream: of('color-brutal-cream'),
      statusBusy: of('color-status-busy'),
      brutalBlack: of('color-brutal-black'),
      codeSurface: of('color-code-surface'),
      codeForeground: of('color-code-foreground'),
    );
  }

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
  /// `--color-brutal-black` — product @theme
  final Color brutalBlack;
  /// `--color-code-surface` — product @theme (:root.dark override)
  final Color codeSurface;
  /// `--color-code-foreground` — product @theme (:root.dark override)
  final Color codeForeground;

  /// Every CSS name of this tier, in field order (without the leading `--`).
  static const List<String> cssNames = [
    'color-brutal-yellow',
    'color-soft-signal',
    'color-brutal-lavender',
    'color-brutal-pink',
    'color-brutal-cyan',
    'color-brutal-orange',
    'color-brutal-lime',
    'color-brutal-red',
    'color-brutal-stone',
    'color-brutal-cream',
    'color-status-busy',
    'color-brutal-black',
    'color-code-surface',
    'color-code-foreground',
  ];

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
    'color-brutal-black': brutalBlack,
    'color-code-surface': codeSurface,
    'color-code-foreground': codeForeground,
  };
}
