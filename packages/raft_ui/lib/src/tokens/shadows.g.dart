// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: raft-ui-0.5.52/foundation.css, raft-web-a98ae00/index.css, tailwindcss-4.3.3/theme.css
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

/// `--theme-shadow-*` (Tailwind `shadow-raft-*`): the field schema of the 0.5.52 control and
/// overlay shadows. Raft 0.7.1 has no control shadows; raft_token_mapping.dart fills these
/// from [RaftLight] / [RaftDark] (`xs`/`sm`/`md` empty, `lg`/`xl` the float elevation).
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

  /// Every CSS name, in field order (without the leading `--`).
  static const List<String> cssNames = [
    'theme-shadow-xs',
    'theme-shadow-sm',
    'theme-shadow-md',
    'theme-shadow-lg',
    'theme-shadow-xl',
  ];

  Map<String, RaftShadow> toCssMap() => {
    'theme-shadow-xs': xs,
    'theme-shadow-sm': sm,
    'theme-shadow-md': md,
    'theme-shadow-lg': lg,
    'theme-shadow-xl': xl,
  };
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
