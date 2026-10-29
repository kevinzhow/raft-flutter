import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'idle_work.dart';
import 'inline_thread_surface.dart' show RaftInlineThreadRecipe;
import 'dialog_card.dart' show raftRecipeThemeOf;
import 'message_content_tokens.dart';
import 'message_row_recipe.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';
import 'tooltip.dart';

/// The engine resolves a font once per (family list, weight, slant, font
/// variations); size, line height and colour reuse that result. Resolving a
/// list that names system families (`Noto Sans CJK *`, `sans-serif`) asks
/// fontconfig for each of them, which on Linux takes 60-80 ms the first time
/// a combination is laid out — a visible stall when, say, the first
/// "Back to bottom" button or a bold run scrolls in.
///
/// [RaftFontWarmUp] lays out one short sample (Latin, CJK and emoji) per
/// distinct combination the message list and its chrome use. Samples run in
/// short event-loop turns (one cold lookup, or a millisecond of warm ones),
/// only while the user is not interacting (no pointer or key input for
/// [quietPeriod]) and no watched list is scrolling; ambient
/// animations such as a spinner do not hold them back. Already-resolved
/// combinations cost a fraction of a millisecond.
abstract final class RaftFontWarmUp {
  /// Debug builds (widget tests, hot reload) skip the warm-up: it only moves
  /// work in time and would leave idle timers behind in fake-async tests.
  static bool enabled = !kDebugMode;

  /// Input-free time required before a sample may run.
  static Duration quietPeriod = const Duration(milliseconds: 250);

  static final _done = <_FontKey>{};
  static final _queue = Queue<TextStyle>();
  static final _themes = <(bool, bool, Locale?)>{};
  static final _positions = <WeakReference<ScrollPosition>>[];
  static final _watched = Expando<bool>('raftFontWarmUp');
  // Ambient animation does not hold the warm-up back (see the class comment),
  // but every step still waits a positive delay so the platform event loop
  // (native input on Windows) runs between steps.
  static final _idle = RaftIdleTimer(yieldToAnimation: false);
  static bool _inputHooked = false;
  static final _sinceInput = Stopwatch();

  /// Whether input and watched scrolling are quiet enough for preparation.
  static bool get isIdle => _sinceInput.elapsed >= quietPeriod && !_scrolling;

  /// Pending samples (for tests and diagnostics).
  @visibleForTesting
  static int get pending => _queue.length;

  @visibleForTesting
  static void reset() {
    _idle.cancel();
    _queue.clear();
    _done.clear();
    _themes.clear();
    _positions.clear();
  }

  /// Schedules the samples for [context]'s theme once per
  /// brightness and font mode, and pauses them while [context]'s scrollable moves. Cheap
  /// to call from every build.
  static void schedule(BuildContext context) {
    if (!enabled) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != null && _watched[position] == null) {
      _watched[position] = true;
      _positions
        ..removeWhere((p) => p.target == null)
        ..add(WeakReference(position));
    }
    final theme = Theme.of(context);
    final tokens = theme.extension<RaftTokens>();
    if (!_themes.add((
      tokens?.dark ?? theme.brightness == Brightness.dark,
      tokens?.systemFonts ?? false,
      tokens?.textLocale,
    ))) {
      return;
    }
    final keys = <_FontKey>{};
    for (final style in raftFontWarmUpStyles(theme)) {
      final key = _FontKey(style);
      if (!_done.contains(key) && keys.add(key)) _queue.add(style);
    }
    _hookInput();
    _arm();
  }

  static void _hookInput() {
    if (_inputHooked) return;
    _inputHooked = true;
    _sinceInput.start();
    void input() => _sinceInput
      ..reset()
      ..start();
    GestureBinding.instance.pointerRouter.addGlobalRoute((_) => input());
    HardwareKeyboard.instance.addHandler((_) {
      input();
      return false;
    });
  }

  static bool get _scrolling => _positions.any((p) {
    final position = p.target;
    return position != null && position.isScrollingNotifier.value;
  });

  static void _arm([Duration delay = RaftIdleWork.minDelay]) {
    if (_queue.isEmpty || _idle.isActive) return;
    _idle.start(delay, _run);
  }

  /// Longest a turn may keep resolving already-warm combinations (fractions of
  /// a millisecond each). A cold fontconfig lookup blows the budget and ends
  /// the turn after that one sample.
  static const _turnBudget = Duration(microseconds: 1500);

  static void _run() {
    final wait = quietPeriod - _sinceInput.elapsed;
    if (wait > Duration.zero || _scrolling) {
      _arm(wait > const Duration(milliseconds: 50) ? wait : quietPeriod);
      return;
    }
    final turn = Stopwatch()..start();
    do {
      final style = _queue.removeFirst();
      if (_done.add(_FontKey(style))) _layOut(style);
    } while (_queue.isNotEmpty && turn.elapsed < _turnBudget);
    _arm(); // Then yield to the event loop with a positive delay.
  }

  static void _layOut(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag 中文 日本語 👍', style: style),
      textDirection: TextDirection.ltr,
      locale: style.locale,
    )..layout();
    painter.dispose();
  }
}

/// Starts the warm-up for the app's theme after its first frame.
class RaftFontWarmUpScope extends StatelessWidget {
  const RaftFontWarmUpScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    RaftFontWarmUp.schedule(context);
    return child;
  }
}

/// Families, weights, slants and variations used by message rows, Markdown,
/// code blocks, row chrome (toolbar tooltips, the floating timeline buttons)
/// and the theme's text styles — each both as declared and as merged into
/// the ambient text style (which supplies the fallback list when a style
/// names only a family). Chrome comes first: row text is usually already
/// resolved by the first frame of the list.
List<TextStyle> raftFontWarmUpStyles(ThemeData theme) {
  final t =
      theme.extension<RaftTokens>() ??
      RaftTokens.theme(dark: theme.brightness == Brightness.dark);
  final ambient = theme.textTheme.bodyMedium ?? const TextStyle();
  final recipeTokens = RaftRecipeTokens(t);
  final recipeTheme = raftRecipeThemeOf(t);
  const bold = TextStyle(fontWeight: FontWeight.w700);
  const italic = TextStyle(fontStyle: FontStyle.italic);
  final row = RaftMessageRowRecipe(t, viewportWidth: 1280);
  final declared = <TextStyle>[
    for (final variant in RaftButtonRecipeVariant.values)
      for (final size in RaftButtonRecipeSize.values)
        RaftButtonRecipe.resolve(
          theme: recipeTheme,
          variant: variant,
          size: size,
          tokens: recipeTokens,
        ).root.textStyle(recipeTokens),
    RaftTooltipRecipe(t).text,
    // Inline thread replies under a message (the first one scrolled in used
    // to resolve these combinations during layout).
    RaftInlineThreadRecipe(t).summary,
    RaftInlineThreadRecipe(t).sender,
    RaftInlineThreadRecipe(t).preview,
    RaftInlineThreadRecipe(t).clock,
    // Transfer chips over images, and the headings task cards and the composer
    // place in the heading family (each optical size is its own instance).
    RaftTypography.mono(
      t,
      size: 11,
      line: 14,
    ).copyWith(fontWeight: FontWeight.w600),
    for (final size in const [14.0, 16.0, 18.0]) ...[
      RaftTypography.heading(t, size: size, line: size + 6),
      RaftTypography.heading(
        t,
        size: size,
        line: size + 6,
        weight: FontWeight.w400,
      ),
    ],
    row.body,
    row.author,
    row.time,
    row.continuationTime,
    for (final document in [false, true]) ...[
      for (final recipe in [
        MessageContentRecipe(t, document: document, mountedMessage: true),
      ]) ...[
        recipe.body,
        recipe.body.merge(bold),
        recipe.body.merge(italic),
        recipe.body.merge(bold).merge(italic),
        recipe.body.merge(RaftTypography.mono(t)),
        recipe.toggle,
        for (var level = 1; level <= 6; level++) recipe.heading(level),
      ],
    ],
    RaftCodeRecipe(t).textStyle,
    RaftCodeRecipe(t).textStyle.merge(bold),
    RaftCodeRecipe(t).textStyle.merge(italic),
    t.fieldStyle,
    for (final style in [
      theme.textTheme.displayLarge,
      theme.textTheme.displayMedium,
      theme.textTheme.displaySmall,
      theme.textTheme.headlineLarge,
      theme.textTheme.headlineMedium,
      theme.textTheme.headlineSmall,
      theme.textTheme.titleLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.titleSmall,
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.bodySmall,
      theme.textTheme.labelLarge,
      theme.textTheme.labelMedium,
      theme.textTheme.labelSmall,
    ])
      ?style,
  ];
  // Markdown and the page merge a declared style into the Material text
  // style they sit in (a heading into titleLarge, ...), and whatever that
  // supplies (fallback list, optical-size axis) is part of the engine's key.
  final parents = <TextStyle>[
    ambient,
    for (final parent in [
      theme.textTheme.headlineSmall,
      theme.textTheme.titleLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.bodyLarge,
    ])
      ?parent,
  ];
  return [
    for (final style in declared) ...[
      style,
      for (final parent in parents) parent.merge(style),
    ],
  ];
}

/// The engine's font cache key: everything else in a style is irrelevant.
@immutable
class _FontKey {
  _FontKey(TextStyle style)
    : family = style.fontFamily,
      fallback = style.fontFamilyFallback,
      weight = style.fontWeight,
      slant = style.fontStyle,
      variations = style.fontVariations,
      locale = style.locale;
  final String? family;
  final List<String>? fallback;
  final FontWeight? weight;
  final FontStyle? slant;
  final List<FontVariation>? variations;
  final Locale? locale;
  @override
  bool operator ==(Object other) =>
      other is _FontKey &&
      other.family == family &&
      listEquals(other.fallback, fallback) &&
      other.weight == weight &&
      other.slant == slant &&
      other.locale == locale &&
      listEquals(other.variations, variations);
  @override
  int get hashCode => Object.hash(
    family,
    fallback == null ? null : Object.hashAll(fallback!),
    weight,
    slant,
    locale,
    variations == null ? null : Object.hashAll(variations!),
  );
}
