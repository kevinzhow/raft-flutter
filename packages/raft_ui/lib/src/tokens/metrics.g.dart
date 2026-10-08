// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: raft-ui-0.5.27/foundation.css, raft-ui-0.5.27/fonts.css, raft-ui-0.5.27/styles.css, tailwindcss-4.2.2/theme.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Per-theme non-colour axes: field + card-title metrics (foundation.css) and
/// font stacks (fonts.css). [headingFont]/[sansFont]/[monoFont] are the bundled
/// Flutter asset families for the first face of each CSS stack.
@immutable
class RaftThemeMetrics {
  const RaftThemeMetrics({
    required this.fieldFontSize,
    required this.fieldFontWeight,
    required this.fieldLineHeight,
    required this.cardTitleFontSize,
    required this.cardTitleFontWeight,
    required this.cardTitleLineHeight,
    required this.headingFontStack,
    required this.sansFontStack,
    required this.monoFontStack,
    required this.headingFont,
    required this.sansFont,
    required this.monoFont,
  });
  /// `--field-font-size` (px)
  final double fieldFontSize;
  /// `--field-font-weight` (CSS weight)
  final double fieldFontWeight;
  /// `--field-line-height` (px)
  final double fieldLineHeight;
  /// `--card-title-font-size` (px)
  final double cardTitleFontSize;
  /// `--card-title-font-weight` (CSS weight)
  final double cardTitleFontWeight;
  /// `--card-title-line-height` (px)
  final double cardTitleLineHeight;
  /// `--heading-font` CSS stack.
  final List<String> headingFontStack;
  /// `--sans-font` CSS stack.
  final List<String> sansFontStack;
  /// `--mono-font` CSS stack.
  final List<String> monoFontStack;
  final String headingFont;
  final String sansFont;
  final String monoFont;
  static const brutal = RaftThemeMetrics(
    fieldFontSize: 16.0, // 16px
    fieldFontWeight: 400.0, // 400
    fieldLineHeight: 24.0, // 24px
    cardTitleFontSize: 18.0, // 18px
    cardTitleFontWeight: 700.0, // 700
    cardTitleLineHeight: 20.0, // 20px
    headingFontStack: ['Hanken Grotesk', 'system-ui', 'sans-serif'],
    sansFontStack: ['Hanken Grotesk', 'system-ui', 'sans-serif'],
    monoFontStack: ['Geist Mono', 'ui-monospace', 'monospace'],
    headingFont: 'packages/raft_ui/HankenGrotesk',
    sansFont: 'packages/raft_ui/HankenGrotesk',
    monoFont: 'packages/raft_ui/GeistMono',
  );
  static const elegantLight = RaftThemeMetrics(
    fieldFontSize: 14.0, // 14px
    fieldFontWeight: 400.0, // 400
    fieldLineHeight: 20.0, // 20px
    cardTitleFontSize: 16.0, // 16px
    cardTitleFontWeight: 500.0, // 500
    cardTitleLineHeight: 22.0, // 22px
    headingFontStack: ['Inter', 'system-ui', 'sans-serif'],
    sansFontStack: ['Geist', 'system-ui', 'sans-serif'],
    monoFontStack: ['Geist Mono', 'ui-monospace', 'monospace'],
    headingFont: 'packages/raft_ui/Inter',
    sansFont: 'packages/raft_ui/Geist',
    monoFont: 'packages/raft_ui/GeistMono',
  );
  static const elegantDark = RaftThemeMetrics(
    fieldFontSize: 14.0, // 14px
    fieldFontWeight: 400.0, // 400
    fieldLineHeight: 20.0, // 20px
    cardTitleFontSize: 16.0, // 16px
    cardTitleFontWeight: 500.0, // 500
    cardTitleLineHeight: 22.0, // 22px
    headingFontStack: ['Inter', 'system-ui', 'sans-serif'],
    sansFontStack: ['Geist', 'system-ui', 'sans-serif'],
    monoFontStack: ['Geist Mono', 'ui-monospace', 'monospace'],
    headingFont: 'packages/raft_ui/Inter',
    sansFont: 'packages/raft_ui/Geist',
    monoFont: 'packages/raft_ui/GeistMono',
  );
}

/// Tailwind 4 @theme scale (tailwindcss 4.2.2 theme.css + raft-ui/product @theme),
/// converted to logical px at a 16px root font size.
abstract final class RaftScale {
  /// `--spacing: 0.25rem`. Utility `p-N` = N * spacing.
  static const double spacing = 4.0;
  static double space(num step) => spacing * step;

  static const Map<String, double> radius = {
    'xs': 2.0, // 0.125rem
    'sm': 4.0, // 0.25rem
    'md': 6.0, // 0.375rem
    'lg': 8.0, // 0.5rem
    'xl': 12.0, // 0.75rem
    '2xl': 16.0, // 1rem
    '3xl': 24.0, // 1.5rem
    '4xl': 32.0, // 2rem
  };
  static const Map<String, double> breakpoint = {
    'sm': 640.0, // 40rem
    'md': 768.0, // 48rem
    'lg': 1024.0, // 64rem
    'xl': 1280.0, // 80rem
    '2xl': 1536.0, // 96rem
  };
  static const Map<String, double> container = {
    '3xs': 256.0, // 16rem
    '2xs': 288.0, // 18rem
    'xs': 320.0, // 20rem
    'sm': 384.0, // 24rem
    'md': 448.0, // 28rem
    'lg': 512.0, // 32rem
    'xl': 576.0, // 36rem
    '2xl': 672.0, // 42rem
    '3xl': 768.0, // 48rem
    '4xl': 896.0, // 56rem
    '5xl': 1024.0, // 64rem
    '6xl': 1152.0, // 72rem
    '7xl': 1280.0, // 80rem
  };
  static const Map<String, double> blur = {
    'xs': 4.0, // 4px
    'sm': 8.0, // 8px
    'md': 12.0, // 12px
    'lg': 16.0, // 16px
    'xl': 24.0, // 24px
    '2xl': 40.0, // 40px
    '3xl': 64.0, // 64px
  };
  /// `--text-{size}` font size and `--text-{size}--line-height` (absolute px).
  static const Map<String, RaftTextStep> text = {
    'xs': RaftTextStep(12.0, 16.0), // 0.75rem / calc(1 / 0.75)
    'sm': RaftTextStep(14.0, 20.0), // 0.875rem / calc(1.25 / 0.875)
    'base': RaftTextStep(16.0, 24.0), // 1rem / calc(1.5 / 1)
    'lg': RaftTextStep(18.0, 28.0), // 1.125rem / calc(1.75 / 1.125)
    'xl': RaftTextStep(20.0, 28.0), // 1.25rem / calc(1.75 / 1.25)
    '2xl': RaftTextStep(24.0, 32.0), // 1.5rem / calc(2 / 1.5)
    '3xl': RaftTextStep(30.0, 36.0), // 1.875rem / calc(2.25 / 1.875)
    '4xl': RaftTextStep(36.0, 40.0), // 2.25rem / calc(2.5 / 2.25)
    '5xl': RaftTextStep(48.0, 48.0), // 3rem / 1
    '6xl': RaftTextStep(60.0, 60.0), // 3.75rem / 1
    '7xl': RaftTextStep(72.0, 72.0), // 4.5rem / 1
    '8xl': RaftTextStep(96.0, 96.0), // 6rem / 1
    '9xl': RaftTextStep(128.0, 128.0), // 8rem / 1
  };
  static const Map<String, int> fontWeight = {
    'thin': 100,
    'extralight': 200,
    'light': 300,
    'normal': 400,
    'medium': 500,
    'semibold': 600,
    'bold': 700,
    'extrabold': 800,
    'black': 900,
  };
  /// `--leading-*` unitless line-height factors.
  static const Map<String, double> leading = {
    'tight': 1.25,
    'snug': 1.375,
    'normal': 1.5,
    'relaxed': 1.625,
    'loose': 2.0,
  };
  /// `--tracking-*` letter-spacing in em (multiply by font size).
  static const Map<String, double> trackingEm = {
    'tighter': -0.05,
    'tight': -0.025,
    'normal': 0.0,
    'wide': 0.025,
    'wider': 0.05,
    'widest': 0.1,
  };
  /// `--ease-*` timing functions.
  static const Map<String, Cubic> ease = {
    'in': Cubic(0.4, 0.0, 1.0, 1.0),
    'out': Cubic(0.0, 0.0, 0.2, 1.0),
    'in-out': Cubic(0.4, 0.0, 0.2, 1.0),
    'slide': Cubic(0.32, 0.72, 0.0, 1.0),
  };
  /// `--default-transition-duration: 150ms`
  static const Duration defaultTransitionDuration = Duration(milliseconds: 150);
  /// `--default-transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1)`
  static const Cubic defaultTransitionCurve = Cubic(0.4, 0.0, 0.2, 1.0);
  /// `--border-width-3: 3px` (product @theme)
  static const double borderWidth3 = 3.0;
}

/// A Tailwind text step: font size and absolute line height (px).
@immutable
class RaftTextStep {
  const RaftTextStep(this.fontSize, this.lineHeight);
  final double fontSize;
  final double? lineHeight;
  /// Flutter `TextStyle.height` factor.
  double? get height => lineHeight == null ? null : lineHeight! / fontSize;
}
