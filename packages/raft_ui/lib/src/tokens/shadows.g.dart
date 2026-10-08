// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: raft-ui-0.5.27/foundation.css, raft-web-26f77ef/index.css, tailwindcss-4.2.2/theme.css
// dart format off
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

/// One layer of a CSS `box-shadow` list, in CSS units.
///
/// Flutter's [BoxShadow] has no `inset`. Outer layers convert with
/// [toBoxShadow]; inset layers must be painted by the component inside its
/// padding box (clip to the inner rounded rect, draw an even-odd ring offset by
/// [offset], deflated by [spread], blurred with [blurSigma]) — see
/// `RaftFieldBorder` for the reference painter and docs/design-tokens.md.
@immutable
class RaftCssShadow {
  const RaftCssShadow({
    required this.inset,
    required this.offset,
    required this.blur,
    required this.spread,
    required this.color,
  });
  final bool inset;
  final Offset offset;

  /// CSS blur radius (px). CSS blurs with a Gaussian of sigma = blur / 2.
  final double blur;
  final double spread;
  final Color color;

  /// Gaussian sigma the browser uses for this layer.
  double get blurSigma => blur / 2;

  /// Outer layer as a Flutter [BoxShadow]. `blurRadius` carries the CSS blur
  /// value verbatim (the repository-wide convention); Flutter derives sigma as
  /// `0.57735 * blurRadius + 0.5`, slightly softer than CSS `blur / 2`.
  BoxShadow toBoxShadow() {
    assert(!inset, 'inset shadows cannot be expressed as BoxShadow');
    return BoxShadow(color: color, offset: offset, blurRadius: blur, spreadRadius: spread);
  }

  @override
  bool operator ==(Object other) =>
      other is RaftCssShadow &&
      other.inset == inset &&
      other.offset == offset &&
      other.blur == blur &&
      other.spread == spread &&
      other.color == color;

  @override
  int get hashCode => Object.hash(inset, offset, blur, spread, color);
}

/// A full CSS `box-shadow` value. [layers] keeps CSS order (first = top-most).
@immutable
class RaftShadow {
  const RaftShadow(this.layers);
  final List<RaftCssShadow> layers;

  /// Outer layers as BoxShadows in CSS declaration order.
  List<BoxShadow> get outer => [
    for (final l in layers)
      if (!l.inset) l.toBoxShadow(),
  ];

  /// Outer layers in Flutter paint order: BoxDecoration paints index 0 first
  /// (bottom-most) while CSS paints the first layer on top, so this reverses.
  List<BoxShadow> get paintOrder => outer.reversed.toList(growable: false);

  /// Inset layers in CSS order; paint inside the padding box (see class docs).
  List<RaftCssShadow> get inset => [
    for (final l in layers)
      if (l.inset) l,
  ];
  bool get hasInset => layers.any((l) => l.inset);
}

/// `--theme-shadow-*` (Tailwind `shadow-raft-*`) per theme.
@immutable
class RaftThemeShadows {
  const RaftThemeShadows({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });
  /// `--theme-shadow-xs`
  final RaftShadow xs;
  /// `--theme-shadow-sm`
  final RaftShadow sm;
  /// `--theme-shadow-md`
  final RaftShadow md;
  /// `--theme-shadow-lg`
  final RaftShadow lg;
  /// `--theme-shadow-xl`
  final RaftShadow xl;

  Map<String, RaftShadow> toCssMap() => {
    'theme-shadow-xs': xs,
    'theme-shadow-sm': sm,
    'theme-shadow-md': md,
    'theme-shadow-lg': lg,
    'theme-shadow-xl': xl,
  };
  static const brutal = RaftThemeShadows(
    // 1px 1px 0px var(--line-strong)
    xs: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(1.0, 1.0), blur: 0.0, spread: 0.0, color: Color(0xff141110)),
    ]),
    // 2px 2px 0px var(--line-strong)
    sm: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(2.0, 2.0), blur: 0.0, spread: 0.0, color: Color(0xff141110)),
    ]),
    // 4px 4px 0px var(--line-strong)
    md: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(4.0, 4.0), blur: 0.0, spread: 0.0, color: Color(0xff141110)),
    ]),
    // 4px 4px 0px var(--color-black, oklch(0 0 0))
    lg: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(4.0, 4.0), blur: 0.0, spread: 0.0, color: Color(0xff000000)),
    ]),
    // 6px 6px 0px var(--line-strong)
    xl: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(6.0, 6.0), blur: 0.0, spread: 0.0, color: Color(0xff141110)),
    ]),
  );
  static const elegantLight = RaftThemeShadows(
    // oklch(0.145 0.002 106.42 / 0.071) 0px 0.5px 0px
    xs: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.5), blur: 0.0, spread: 0.0, color: Color.fromRGBO(10, 10, 9, 0.071)),
    ]),
    // oklch(0.145 0.002 106.42 / 0.071) 0px 0.5px 0px, oklch(0.145 0.002 106.42 / 0.012) 0px 5px 4px -2px, oklch(0.145 0.002 106.42 / 0.02) 0px 3…
    sm: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.5), blur: 0.0, spread: 0.0, color: Color.fromRGBO(10, 10, 9, 0.071)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 5.0), blur: 4.0, spread: -2.0, color: Color.fromRGBO(10, 10, 9, 0.012)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 3.0), blur: 3.0, spread: -1.0, color: Color.fromRGBO(10, 10, 9, 0.02)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 1.0), blur: 2.0, spread: -1.0, color: Color.fromRGBO(10, 10, 9, 0.039)),
    ]),
    // oklch(0.145 0.002 106.42 / 0.071) 0px 0.5px 0px, oklch(0.145 0.002 106.42 / 0.02) 0px 8px 8px -4px, oklch(0.145 0.002 106.42 / 0.027) 0px 5…
    md: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.5), blur: 0.0, spread: 0.0, color: Color.fromRGBO(10, 10, 9, 0.071)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 8.0), blur: 8.0, spread: -4.0, color: Color.fromRGBO(10, 10, 9, 0.02)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 5.0), blur: 5.0, spread: -2.0, color: Color.fromRGBO(10, 10, 9, 0.027)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 2.0), blur: 3.0, spread: -1.0, color: Color.fromRGBO(10, 10, 9, 0.039)),
    ]),
    // 0px 1px 1px oklch(0.21 0.006 106.42 / 0.1), 0px 0px 0px 1px oklch(0.21 0.006 106.42 / 0.04), 0px 2px 12px -4px oklch(0.21 0.006 106.42 / 0.…
    lg: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(0.0, 1.0), blur: 1.0, spread: 0.0, color: Color.fromRGBO(25, 24, 21, 0.1)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(25, 24, 21, 0.04)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 2.0), blur: 12.0, spread: -4.0, color: Color.fromRGBO(25, 24, 21, 0.16)),
    ]),
    // oklch(0.145 0.002 106.42 / 0.071) 0px 0.5px 0px, 0px 0px 0px 1px oklch(0.21 0.006 106.42 / 0.08), oklch(0.145 0.002 106.42 / 0.031) 0px 18p…
    xl: RaftShadow([
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.5), blur: 0.0, spread: 0.0, color: Color.fromRGBO(10, 10, 9, 0.071)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(25, 24, 21, 0.08)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 18.0), blur: 24.0, spread: -12.0, color: Color.fromRGBO(10, 10, 9, 0.031)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 12.0), blur: 12.0, spread: -6.0, color: Color.fromRGBO(10, 10, 9, 0.039)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 4.0), blur: 6.0, spread: -3.0, color: Color.fromRGBO(10, 10, 9, 0.039)),
    ]),
  );
  static const elegantDark = RaftThemeShadows(
    // inset 0 1px 0 oklch(0.985 0.004 106.42 / 0.045), 0 0 0 1px oklch(0 0 0 / 0.4), 0 1px 3px oklch(0 0 0 / 0.22)
    xs: RaftShadow([
      RaftCssShadow(inset: true, offset: Offset(0.0, 1.0), blur: 0.0, spread: 0.0, color: Color.fromRGBO(250, 250, 247, 0.045)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(0, 0, 0, 0.4)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 1.0), blur: 3.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.22)),
    ]),
    // inset 0 1px 0 oklch(0.985 0.004 106.42 / 0.05), inset 0 0 0 1px oklch(0.985 0.004 106.42 / 0.03), 0 0 0 1px oklch(0 0 0 / 0.45), 0 6px 6px …
    sm: RaftShadow([
      RaftCssShadow(inset: true, offset: Offset(0.0, 1.0), blur: 0.0, spread: 0.0, color: Color.fromRGBO(250, 250, 247, 0.05)),
      RaftCssShadow(inset: true, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(250, 250, 247, 0.03)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(0, 0, 0, 0.45)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 6.0), blur: 6.0, spread: -2.0, color: Color.fromRGBO(0, 0, 0, 0.15)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 2.0), blur: 4.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.25)),
    ]),
    // inset 0 1px 0 oklch(0.985 0.004 106.42 / 0.05), inset 0 0 0 1px oklch(0.985 0.004 106.42 / 0.03), 0 0 0 1px oklch(0 0 0 / 0.45), 0 10px 10p…
    md: RaftShadow([
      RaftCssShadow(inset: true, offset: Offset(0.0, 1.0), blur: 0.0, spread: 0.0, color: Color.fromRGBO(250, 250, 247, 0.05)),
      RaftCssShadow(inset: true, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(250, 250, 247, 0.03)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(0, 0, 0, 0.45)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 10.0), blur: 10.0, spread: -4.0, color: Color.fromRGBO(0, 0, 0, 0.16)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 4.0), blur: 6.0, spread: -2.0, color: Color.fromRGBO(0, 0, 0, 0.2)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 1.0), blur: 2.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.25)),
    ]),
    // inset 0 1px 0 oklch(0.985 0.004 106.42 / 0.06), inset 0 0 0 1px oklch(0.985 0.004 106.42 / 0.04), 0 0 0 1px oklch(0 0 0 / 0.55), 0 10px 20p…
    lg: RaftShadow([
      RaftCssShadow(inset: true, offset: Offset(0.0, 1.0), blur: 0.0, spread: 0.0, color: Color.fromRGBO(250, 250, 247, 0.06)),
      RaftCssShadow(inset: true, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(250, 250, 247, 0.04)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(0, 0, 0, 0.55)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 10.0), blur: 20.0, spread: -6.0, color: Color.fromRGBO(0, 0, 0, 0.45)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 4.0), blur: 8.0, spread: -3.0, color: Color.fromRGBO(0, 0, 0, 0.35)),
    ]),
    // inset 0 1px 0 oklch(0.985 0.004 106.42 / 0.06), inset 0 0 0 1px oklch(0.985 0.004 106.42 / 0.04), 0 0 0 1px oklch(0 0 0 / 0.6), 0 24px 44px…
    xl: RaftShadow([
      RaftCssShadow(inset: true, offset: Offset(0.0, 1.0), blur: 0.0, spread: 0.0, color: Color.fromRGBO(250, 250, 247, 0.06)),
      RaftCssShadow(inset: true, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(250, 250, 247, 0.04)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 0.0), blur: 0.0, spread: 1.0, color: Color.fromRGBO(0, 0, 0, 0.6)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 24.0), blur: 44.0, spread: -12.0, color: Color.fromRGBO(0, 0, 0, 0.5)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 10.0), blur: 16.0, spread: -6.0, color: Color.fromRGBO(0, 0, 0, 0.45)),
      RaftCssShadow(inset: false, offset: Offset(0.0, 4.0), blur: 6.0, spread: -3.0, color: Color.fromRGBO(0, 0, 0, 0.4)),
    ]),
  );
}

/// Product (`packages/web/src/index.css` @theme) shadows and the Tailwind default
/// shadow scale. Theme-invariant.
abstract final class RaftProductShadows {
  /// `--shadow-brutal: 4px 4px 0px #141111`
  static const shadowBrutal = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(4.0, 4.0), blur: 0.0, spread: 0.0, color: Color(0xff141111)),
  ]);
  /// `--shadow-brutal-sm: 2px 2px 0px #141111`
  static const shadowBrutalSm = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(2.0, 2.0), blur: 0.0, spread: 0.0, color: Color(0xff141111)),
  ]);
  /// `--shadow-brutal-lg: 6px 6px 0px #141111`
  static const shadowBrutalLg = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(6.0, 6.0), blur: 0.0, spread: 0.0, color: Color(0xff141111)),
  ]);
  /// `--shadow-brutal-hover: 2px 2px 0px #141111`
  static const shadowBrutalHover = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(2.0, 2.0), blur: 0.0, spread: 0.0, color: Color(0xff141111)),
  ]);
  /// `--shadow-brutal-active: 1px 1px 0px #141111`
  static const shadowBrutalActive = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(1.0, 1.0), blur: 0.0, spread: 0.0, color: Color(0xff141111)),
  ]);
  /// `--shadow-workspace-mode-active: inset 3px 3px 0px rgb(20 17 17 / 35%)`
  static const shadowWorkspaceModeActive = RaftShadow([
    RaftCssShadow(inset: true, offset: Offset(3.0, 3.0), blur: 0.0, spread: 0.0, color: Color.fromRGBO(20, 17, 17, 0.35)),
  ]);
  /// `--shadow-soft-popover: 0 4px 12px rgba(0, 0, 0, 0.08)`
  static const shadowSoftPopover = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(0.0, 4.0), blur: 12.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.08)),
  ]);
  /// `--shadow-2xs: 0 1px rgb(0 0 0 / 0.05)`
  static const shadow2xs = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(0.0, 1.0), blur: 0.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.05)),
  ]);
  /// `--shadow-xs: 0 1px 2px 0 rgb(0 0 0 / 0.05)`
  static const shadowXs = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(0.0, 1.0), blur: 2.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.05)),
  ]);
  /// `--shadow-sm: 0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)`
  static const shadowSm = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(0.0, 1.0), blur: 3.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.1)),
    RaftCssShadow(inset: false, offset: Offset(0.0, 1.0), blur: 2.0, spread: -1.0, color: Color.fromRGBO(0, 0, 0, 0.1)),
  ]);
  /// `--shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)`
  static const shadowMd = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(0.0, 4.0), blur: 6.0, spread: -1.0, color: Color.fromRGBO(0, 0, 0, 0.1)),
    RaftCssShadow(inset: false, offset: Offset(0.0, 2.0), blur: 4.0, spread: -2.0, color: Color.fromRGBO(0, 0, 0, 0.1)),
  ]);
  /// `--shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)`
  static const shadowLg = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(0.0, 10.0), blur: 15.0, spread: -3.0, color: Color.fromRGBO(0, 0, 0, 0.1)),
    RaftCssShadow(inset: false, offset: Offset(0.0, 4.0), blur: 6.0, spread: -4.0, color: Color.fromRGBO(0, 0, 0, 0.1)),
  ]);
  /// `--shadow-xl: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)`
  static const shadowXl = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(0.0, 20.0), blur: 25.0, spread: -5.0, color: Color.fromRGBO(0, 0, 0, 0.1)),
    RaftCssShadow(inset: false, offset: Offset(0.0, 8.0), blur: 10.0, spread: -6.0, color: Color.fromRGBO(0, 0, 0, 0.1)),
  ]);
  /// `--shadow-2xl: 0 25px 50px -12px rgb(0 0 0 / 0.25)`
  static const shadow2xl = RaftShadow([
    RaftCssShadow(inset: false, offset: Offset(0.0, 25.0), blur: 50.0, spread: -12.0, color: Color.fromRGBO(0, 0, 0, 0.25)),
  ]);
  /// `--inset-shadow-2xs: inset 0 1px rgb(0 0 0 / 0.05)`
  static const insetShadow2xs = RaftShadow([
    RaftCssShadow(inset: true, offset: Offset(0.0, 1.0), blur: 0.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.05)),
  ]);
  /// `--inset-shadow-xs: inset 0 1px 1px rgb(0 0 0 / 0.05)`
  static const insetShadowXs = RaftShadow([
    RaftCssShadow(inset: true, offset: Offset(0.0, 1.0), blur: 1.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.05)),
  ]);
  /// `--inset-shadow-sm: inset 0 2px 4px rgb(0 0 0 / 0.05)`
  static const insetShadowSm = RaftShadow([
    RaftCssShadow(inset: true, offset: Offset(0.0, 2.0), blur: 4.0, spread: 0.0, color: Color.fromRGBO(0, 0, 0, 0.05)),
  ]);
}
