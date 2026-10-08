// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: raft-ui-0.5.27/foundation.css, raft-ui-0.5.27/styles.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'dart:ui';

/// Tier 1: raw brutal ramps (`--color-brutal-{hue}-{step}`) and the Tailwind
/// `--color-black` / `--color-white` atoms. Names are the CSS names in lowerCamel
/// without the `color-` prefix. Theme-scoped colours (ink ramp, families) live in
/// [RaftSemanticColors]; never reach for a ramp where a semantic token exists.
abstract final class RaftPrimitiveColors {
  /// `--color-brutal-yellow-50: oklch(0.984 0.017 84.56)`
  static const brutalYellow50 = Color(0xfffff9ed);
  /// `--color-brutal-yellow-100: oklch(0.975 0.027 85.64)`
  static const brutalYellow100 = Color(0xfffff6e3);
  /// `--color-brutal-yellow-200: oklch(0.94 0.066 86.23)`
  static const brutalYellow200 = Color(0xffffe9b9);
  /// `--color-brutal-yellow-300: oklch(0.913 0.103 88.02)`
  static const brutalYellow300 = Color(0xffffdf91);
  /// `--color-brutal-yellow-400: oklch(0.883 0.162 91.89)`
  static const brutalYellow400 = Color(0xffffd441);
  /// `--color-brutal-yellow-500: oklch(0.759 0.155 92.93)`
  static const brutalYellow500 = Color(0xffd3ad03);
  /// `--color-brutal-yellow-600: oklch(0.637 0.13 92.64)`
  static const brutalYellow600 = Color(0xffa78802);
  /// `--color-brutal-yellow-700: oklch(0.508 0.104 92.9)`
  static const brutalYellow700 = Color(0xff7a6300);
  /// `--color-brutal-yellow-800: oklch(0.388 0.08 93.41)`
  static const brutalYellow800 = Color(0xff534300);
  /// `--color-brutal-yellow-900: oklch(0.26 0.053 92.86)`
  static const brutalYellow900 = Color(0xff2d2300);
  /// `--color-brutal-yellow-950: oklch(0.199 0.041 93.21)`
  static const brutalYellow950 = Color(0xff1c1500);
  /// `--color-brutal-purple-50: oklch(0.976 0.008 294.09)`
  static const brutalPurple50 = Color(0xfff7f6fc);
  /// `--color-brutal-purple-100: oklch(0.949 0.018 296.72)`
  static const brutalPurple100 = Color(0xffefecf9);
  /// `--color-brutal-purple-200: oklch(0.891 0.037 294.17)`
  static const brutalPurple200 = Color(0xffdcd7f2);
  /// `--color-brutal-purple-300: oklch(0.84 0.056 294.36)`
  static const brutalPurple300 = Color(0xffccc4ec);
  /// `--color-brutal-purple-400: oklch(0.783 0.078 294.55)`
  static const brutalPurple400 = Color(0xffbbafe6);
  /// `--color-brutal-purple-500: oklch(0.682 0.117 294)`
  static const brutalPurple500 = Color(0xff9d8ada);
  /// `--color-brutal-purple-600: oklch(0.575 0.157 293.61)`
  static const brutalPurple600 = Color(0xff7f62cb);
  /// `--color-brutal-purple-700: oklch(0.475 0.168 293)`
  static const brutalPurple700 = Color(0xff6341b0);
  /// `--color-brutal-purple-800: oklch(0.367 0.131 293.06)`
  static const brutalPurple800 = Color(0xff442b7c);
  /// `--color-brutal-purple-900: oklch(0.25 0.09 293.19)`
  static const brutalPurple900 = Color(0xff251548);
  /// `--color-brutal-purple-950: oklch(0.195 0.07 292.41)`
  static const brutalPurple950 = Color(0xff170c31);
  /// `--color-brutal-pink-50: oklch(0.968 0.017 359.4)`
  static const brutalPink50 = Color(0xfffff0f4);
  /// `--color-brutal-pink-100: oklch(0.936 0.034 2.02)`
  static const brutalPink100 = Color(0xffffe1e8);
  /// `--color-brutal-pink-200: oklch(0.871 0.073 0.34)`
  static const brutalPink200 = Color(0xfffec1d2);
  /// `--color-brutal-pink-300: oklch(0.808 0.116 0.76)`
  static const brutalPink300 = Color(0xfffea0bc);
  /// `--color-brutal-pink-400: oklch(0.749 0.162 0.71)`
  static const brutalPink400 = Color(0xfffe7da8);
  /// `--color-brutal-pink-500: oklch(0.662 0.244 0.59)`
  static const brutalPink500 = Color(0xfffe2f8b);
  /// `--color-brutal-pink-600: oklch(0.565 0.226 0.56)`
  static const brutalPink600 = Color(0xffd4086f);
  /// `--color-brutal-pink-700: oklch(0.456 0.182 0.91)`
  static const brutalPink700 = Color(0xff9f0551);
  /// `--color-brutal-pink-800: oklch(0.354 0.142 0.38)`
  static const brutalPink800 = Color(0xff700238);
  /// `--color-brutal-pink-900: oklch(0.246 0.098 0.96)`
  static const brutalPink900 = Color(0xff42011e);
  /// `--color-brutal-pink-950: oklch(0.198 0.08 359.99)`
  static const brutalPink950 = Color(0xff2f0014);
  /// `--color-brutal-cyan-50: oklch(0.974 0.016 226.9)`
  static const brutalCyan50 = Color(0xffecf9ff);
  /// `--color-brutal-cyan-100: oklch(0.945 0.033 226.27)`
  static const brutalCyan100 = Color(0xffd7f2fe);
  /// `--color-brutal-cyan-200: oklch(0.892 0.07 224.23)`
  static const brutalCyan200 = Color(0xffa9e6fe);
  /// `--color-brutal-cyan-300: oklch(0.835 0.114 220.86)`
  static const brutalCyan300 = Color(0xff68dafd);
  /// `--color-brutal-cyan-400: oklch(0.783 0.135 219.2)`
  static const brutalCyan400 = Color(0xff28ccf3);
  /// `--color-brutal-cyan-500: oklch(0.672 0.116 219.07)`
  static const brutalCyan500 = Color(0xff1ea6c6);
  /// `--color-brutal-cyan-600: oklch(0.569 0.099 219.95)`
  static const brutalCyan600 = Color(0xff15849f);
  /// `--color-brutal-cyan-700: oklch(0.46 0.079 219.13)`
  static const brutalCyan700 = Color(0xff0e6276);
  /// `--color-brutal-cyan-800: oklch(0.348 0.06 219.02)`
  static const brutalCyan800 = Color(0xff06414f);
  /// `--color-brutal-cyan-900: oklch(0.246 0.043 221.18)`
  static const brutalCyan900 = Color(0xff02252f);
  /// `--color-brutal-cyan-950: oklch(0.185 0.032 217.82)`
  static const brutalCyan950 = Color(0xff01161c);
  /// `--color-brutal-orange-50: oklch(0.976 0.011 45.81)`
  static const brutalOrange50 = Color(0xfffef5f1);
  /// `--color-brutal-orange-100: oklch(0.941 0.028 40.23)`
  static const brutalOrange100 = Color(0xfffde6de);
  /// `--color-brutal-orange-200: oklch(0.892 0.053 43.23)`
  static const brutalOrange200 = Color(0xfffbd1c0);
  /// `--color-brutal-orange-300: oklch(0.835 0.087 46.56)`
  static const brutalOrange300 = Color(0xfff9b899);
  /// `--color-brutal-orange-400: oklch(0.785 0.123 50.11)`
  static const brutalOrange400 = Color(0xfff8a16f);
  /// `--color-brutal-orange-500: oklch(0.685 0.145 54.68)`
  static const brutalOrange500 = Color(0xffdd7e34);
  /// `--color-brutal-orange-600: oklch(0.57 0.121 54.53)`
  static const brutalOrange600 = Color(0xffad6127);
  /// `--color-brutal-orange-700: oklch(0.465 0.099 54.58)`
  static const brutalOrange700 = Color(0xff83481a);
  /// `--color-brutal-orange-800: oklch(0.361 0.076 55.55)`
  static const brutalOrange800 = Color(0xff5b310f);
  /// `--color-brutal-orange-900: oklch(0.246 0.052 55.54)`
  static const brutalOrange900 = Color(0xff331905);
  /// `--color-brutal-orange-950: oklch(0.191 0.042 54.31)`
  static const brutalOrange950 = Color(0xff220e02);
  /// `--color-brutal-lime-50: oklch(0.98 0.029 132.52)`
  static const brutalLime50 = Color(0xfff1fde9);
  /// `--color-brutal-lime-100: oklch(0.949 0.081 130.41)`
  static const brutalLime100 = Color(0xffdcfac1);
  /// `--color-brutal-lime-200: oklch(0.91 0.149 130.12)`
  static const brutalLime200 = Color(0xffc0f588);
  /// `--color-brutal-lime-300: oklch(0.867 0.142 130.1)`
  static const brutalLime300 = Color(0xffb4e67f);
  /// `--color-brutal-lime-400: oklch(0.827 0.135 130.07)`
  static const brutalLime400 = Color(0xffa9d877);
  /// `--color-brutal-lime-500: oklch(0.715 0.118 130.4)`
  static const brutalLime500 = Color(0xff8ab261);
  /// `--color-brutal-lime-600: oklch(0.596 0.099 130.36)`
  static const brutalLime600 = Color(0xff6b8b4a);
  /// `--color-brutal-lime-700: oklch(0.485 0.08 129.92)`
  static const brutalLime700 = Color(0xff506836);
  /// `--color-brutal-lime-800: oklch(0.366 0.06 130.11)`
  static const brutalLime800 = Color(0xff344522);
  /// `--color-brutal-lime-900: oklch(0.256 0.041 130.57)`
  static const brutalLime900 = Color(0xff1c2711);
  /// `--color-brutal-lime-950: oklch(0.196 0.032 130.49)`
  static const brutalLime950 = Color(0xff101808);
  /// `--color-brutal-red-50: oklch(0.968 0.014 22.88)`
  static const brutalRed50 = Color(0xfffef1f0);
  /// `--color-brutal-red-100: oklch(0.926 0.034 20.05)`
  static const brutalRed100 = Color(0xfffddedd);
  /// `--color-brutal-red-200: oklch(0.854 0.072 22.92)`
  static const brutalRed200 = Color(0xfffbbdb9);
  /// `--color-brutal-red-300: oklch(0.781 0.118 25.18)`
  static const brutalRed300 = Color(0xfffa9991);
  /// `--color-brutal-red-400: oklch(0.711 0.168 28.04)`
  static const brutalRed400 = Color(0xfff97264);
  /// `--color-brutal-red-500: oklch(0.627 0.209 32.98)`
  static const brutalRed500 = Color(0xffeb4423);
  /// `--color-brutal-red-600: oklch(0.528 0.176 33.04)`
  static const brutalRed600 = Color(0xffbb3419);
  /// `--color-brutal-red-700: oklch(0.431 0.144 33.03)`
  static const brutalRed700 = Color(0xff8e2510);
  /// `--color-brutal-red-800: oklch(0.331 0.11 33.1)`
  static const brutalRed800 = Color(0xff621708);
  /// `--color-brutal-red-900: oklch(0.243 0.081 33.19)`
  static const brutalRed900 = Color(0xff3e0b03);
  /// `--color-brutal-red-950: oklch(0.185 0.061 34.2)`
  static const brutalRed950 = Color(0xff280501);
  /// `--color-brutal-stone-50: oklch(0.974 0.002 67.9)`
  static const brutalStone50 = Color(0xfff7f6f5);
  /// `--color-brutal-stone-100: oklch(0.947 0.003 67.83)`
  static const brutalStone100 = Color(0xffefedeb);
  /// `--color-brutal-stone-200: oklch(0.896 0.008 73.73)`
  static const brutalStone200 = Color(0xffe0dcd7);
  /// `--color-brutal-stone-300: oklch(0.845 0.014 71.31)`
  static const brutalStone300 = Color(0xffd2cbc2);
  /// `--color-brutal-stone-400: oklch(0.789 0.014 71.29)`
  static const brutalStone400 = Color(0xffc0b9b1);
  /// `--color-brutal-stone-500: oklch(0.682 0.012 76.55)`
  static const brutalStone500 = Color(0xff9d9891);
  /// `--color-brutal-stone-600: oklch(0.569 0.01 67.63)`
  static const brutalStone600 = Color(0xff7b7671);
  /// `--color-brutal-stone-700: oklch(0.466 0.008 67.63)`
  static const brutalStone700 = Color(0xff5d5955);
  /// `--color-brutal-stone-800: oklch(0.354 0.007 67.62)`
  static const brutalStone800 = Color(0xff3e3b38);
  /// `--color-brutal-stone-900: oklch(0.249 0.005 67.61)`
  static const brutalStone900 = Color(0xff23211f);
  /// `--color-brutal-stone-950: oklch(0.187 0.003 67.68)`
  static const brutalStone950 = Color(0xff141312);
  /// `--color-brutal-cream-50: oklch(0.995 0.006 87.5)`
  static const brutalCream50 = Color(0xfffffdf9);
  /// `--color-brutal-cream-100: oklch(0.991 0.01 87.41)`
  static const brutalCream100 = Color(0xfffffcf5);
  /// `--color-brutal-cream-200: oklch(0.986 0.015 86.39)`
  static const brutalCream200 = Color(0xfffffaef);
  /// `--color-brutal-cream-300: oklch(0.946 0.041 88)`
  static const brutalCream300 = Color(0xfff9eccf);
  /// `--color-brutal-cream-400: oklch(0.871 0.09 91)`
  static const brutalCream400 = Color(0xffebd38f);
  /// `--color-brutal-cream-500: oklch(0.766 0.158 95.1)`
  static const brutalCream500 = Color(0xffd2b100);
  /// `--color-brutal-cream-600: oklch(0.646 0.133 95)`
  static const brutalCream600 = Color(0xffa78c00);
  /// `--color-brutal-cream-700: oklch(0.521 0.107 95.2)`
  static const brutalCream700 = Color(0xff7c6800);
  /// `--color-brutal-cream-800: oklch(0.396 0.082 95)`
  static const brutalCream800 = Color(0xff554500);
  /// `--color-brutal-cream-900: oklch(0.276 0.057 95.1)`
  static const brutalCream900 = Color(0xff312700);
  /// `--color-brutal-cream-950: oklch(0.19 0.039 94.7)`
  static const brutalCream950 = Color(0xff191300);
  /// `--color-black: oklch(0 0 0)` (raft-ui styles.css @theme)
  static const black = Color(0xff000000);
  /// `--color-white: oklch(1 0 0)` (raft-ui styles.css @theme)
  static const white = Color(0xffffffff);

  /// Every primitive keyed by its CSS custom-property name.
  static const Map<String, Color> byCssName = {
    '--color-brutal-yellow-50': brutalYellow50,
    '--color-brutal-yellow-100': brutalYellow100,
    '--color-brutal-yellow-200': brutalYellow200,
    '--color-brutal-yellow-300': brutalYellow300,
    '--color-brutal-yellow-400': brutalYellow400,
    '--color-brutal-yellow-500': brutalYellow500,
    '--color-brutal-yellow-600': brutalYellow600,
    '--color-brutal-yellow-700': brutalYellow700,
    '--color-brutal-yellow-800': brutalYellow800,
    '--color-brutal-yellow-900': brutalYellow900,
    '--color-brutal-yellow-950': brutalYellow950,
    '--color-brutal-purple-50': brutalPurple50,
    '--color-brutal-purple-100': brutalPurple100,
    '--color-brutal-purple-200': brutalPurple200,
    '--color-brutal-purple-300': brutalPurple300,
    '--color-brutal-purple-400': brutalPurple400,
    '--color-brutal-purple-500': brutalPurple500,
    '--color-brutal-purple-600': brutalPurple600,
    '--color-brutal-purple-700': brutalPurple700,
    '--color-brutal-purple-800': brutalPurple800,
    '--color-brutal-purple-900': brutalPurple900,
    '--color-brutal-purple-950': brutalPurple950,
    '--color-brutal-pink-50': brutalPink50,
    '--color-brutal-pink-100': brutalPink100,
    '--color-brutal-pink-200': brutalPink200,
    '--color-brutal-pink-300': brutalPink300,
    '--color-brutal-pink-400': brutalPink400,
    '--color-brutal-pink-500': brutalPink500,
    '--color-brutal-pink-600': brutalPink600,
    '--color-brutal-pink-700': brutalPink700,
    '--color-brutal-pink-800': brutalPink800,
    '--color-brutal-pink-900': brutalPink900,
    '--color-brutal-pink-950': brutalPink950,
    '--color-brutal-cyan-50': brutalCyan50,
    '--color-brutal-cyan-100': brutalCyan100,
    '--color-brutal-cyan-200': brutalCyan200,
    '--color-brutal-cyan-300': brutalCyan300,
    '--color-brutal-cyan-400': brutalCyan400,
    '--color-brutal-cyan-500': brutalCyan500,
    '--color-brutal-cyan-600': brutalCyan600,
    '--color-brutal-cyan-700': brutalCyan700,
    '--color-brutal-cyan-800': brutalCyan800,
    '--color-brutal-cyan-900': brutalCyan900,
    '--color-brutal-cyan-950': brutalCyan950,
    '--color-brutal-orange-50': brutalOrange50,
    '--color-brutal-orange-100': brutalOrange100,
    '--color-brutal-orange-200': brutalOrange200,
    '--color-brutal-orange-300': brutalOrange300,
    '--color-brutal-orange-400': brutalOrange400,
    '--color-brutal-orange-500': brutalOrange500,
    '--color-brutal-orange-600': brutalOrange600,
    '--color-brutal-orange-700': brutalOrange700,
    '--color-brutal-orange-800': brutalOrange800,
    '--color-brutal-orange-900': brutalOrange900,
    '--color-brutal-orange-950': brutalOrange950,
    '--color-brutal-lime-50': brutalLime50,
    '--color-brutal-lime-100': brutalLime100,
    '--color-brutal-lime-200': brutalLime200,
    '--color-brutal-lime-300': brutalLime300,
    '--color-brutal-lime-400': brutalLime400,
    '--color-brutal-lime-500': brutalLime500,
    '--color-brutal-lime-600': brutalLime600,
    '--color-brutal-lime-700': brutalLime700,
    '--color-brutal-lime-800': brutalLime800,
    '--color-brutal-lime-900': brutalLime900,
    '--color-brutal-lime-950': brutalLime950,
    '--color-brutal-red-50': brutalRed50,
    '--color-brutal-red-100': brutalRed100,
    '--color-brutal-red-200': brutalRed200,
    '--color-brutal-red-300': brutalRed300,
    '--color-brutal-red-400': brutalRed400,
    '--color-brutal-red-500': brutalRed500,
    '--color-brutal-red-600': brutalRed600,
    '--color-brutal-red-700': brutalRed700,
    '--color-brutal-red-800': brutalRed800,
    '--color-brutal-red-900': brutalRed900,
    '--color-brutal-red-950': brutalRed950,
    '--color-brutal-stone-50': brutalStone50,
    '--color-brutal-stone-100': brutalStone100,
    '--color-brutal-stone-200': brutalStone200,
    '--color-brutal-stone-300': brutalStone300,
    '--color-brutal-stone-400': brutalStone400,
    '--color-brutal-stone-500': brutalStone500,
    '--color-brutal-stone-600': brutalStone600,
    '--color-brutal-stone-700': brutalStone700,
    '--color-brutal-stone-800': brutalStone800,
    '--color-brutal-stone-900': brutalStone900,
    '--color-brutal-stone-950': brutalStone950,
    '--color-brutal-cream-50': brutalCream50,
    '--color-brutal-cream-100': brutalCream100,
    '--color-brutal-cream-200': brutalCream200,
    '--color-brutal-cream-300': brutalCream300,
    '--color-brutal-cream-400': brutalCream400,
    '--color-brutal-cream-500': brutalCream500,
    '--color-brutal-cream-600': brutalCream600,
    '--color-brutal-cream-700': brutalCream700,
    '--color-brutal-cream-800': brutalCream800,
    '--color-brutal-cream-900': brutalCream900,
    '--color-brutal-cream-950': brutalCream950,
    '--color-black': black,
    '--color-white': white,
  };
}
