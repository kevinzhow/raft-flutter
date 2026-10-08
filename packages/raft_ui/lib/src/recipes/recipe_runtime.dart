// Runtime for generated raft-ui component recipes (`*.g.dart` in this folder).
//
// The generator (tool/recipes/gen_dart.mjs) emits, per tailwind-variants
// recipe, the exact class lists produced by tailwind-variants + raft-ui `cn`
// for every variant combination, and one global table of Tailwind utilities
// compiled to CSS declarations. This file applies the CSS cascade for a set of
// interaction states, resolves `var()` / `calc()`, and projects the result onto
// Flutter types. Colours and shadows that come from foundation tokens stay
// symbolic ([TokenRef]) until resolved with a [RaftTokenResolver].
//
// The algorithms mirror tool/recipes/lib/{css-value,cascade}.mjs; parity is
// checked by test/recipes/recipe_parity_test.dart.
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

// ---------------------------------------------------------------- CSS values

/// Parsed CSS value (see tool/recipes/lib/css-value.mjs for the grammar).
sealed class CssValue {
  const CssValue();

  /// JSON form identical to the generator's AST (used by parity tests).
  Object? toJson();
}

final class CssNum extends CssValue {
  const CssNum(this.value, [this.unit = '']);
  final double value;

  /// '' (unitless), 'px', 'em', '%', 'ms', 'deg', 'vh', ...
  final String unit;
  @override
  Object? toJson() => {'t': 'num', 'v': value, 'u': unit};
  @override
  String toString() => '${_fmt(value)}$unit';
}

final class CssKeyword extends CssValue {
  const CssKeyword(this.value);
  final String value;
  @override
  Object? toJson() => {'t': 'kw', 'v': value};
  @override
  String toString() => value;
}

final class CssString extends CssValue {
  const CssString(this.value);
  final String value;
  @override
  Object? toJson() => {'t': 'str', 'v': value};
  @override
  String toString() => '"$value"';
}

final class CssColor extends CssValue {
  const CssColor(this.argb, [this.source]);
  final int argb;
  final String? source;
  Color get color => Color(argb);
  @override
  Object? toJson() => {'t': 'color', 'argb': argb};
  @override
  String toString() => source ?? '#${argb.toRadixString(16).padLeft(8, '0')}';
}

/// `var(--name, fallback)`. [token] is set when `--name` is a raft-ui
/// foundation token (lowerCamelCase name, e.g. `primary400`).
final class CssVar extends CssValue {
  const CssVar(this.name, [this.fallback, this.token]);
  final String name;
  final CssValue? fallback;
  final String? token;
  @override
  Object? toJson() => {'t': 'var', 'name': name, 'fb': fallback?.toJson(), if (token != null) 'token': token};
  @override
  String toString() => token != null
      ? 'token($token${fallback != null ? ', $fallback' : ''})'
      : 'var($name${fallback != null ? ', $fallback' : ''})';
}

final class CssFunction extends CssValue {
  const CssFunction(this.name, this.args);
  final String name;
  final List<CssValue> args;
  @override
  Object? toJson() => {'t': 'fn', 'name': name, 'args': [for (final a in args) a.toJson()]};
  @override
  String toString() => '$name(${args.join(', ')})';
}

final class CssCalc extends CssValue {
  const CssCalc(this.expr);
  final CssValue expr;
  @override
  Object? toJson() => {'t': 'calc', 'e': expr.toJson()};
  @override
  String toString() => 'calc($expr)';
}

final class CssOp extends CssValue {
  const CssOp(this.op, this.a, this.b);
  final String op;
  final CssValue a;
  final CssValue b;
  @override
  Object? toJson() => {'t': 'op', 'op': op, 'a': a.toJson(), 'b': b.toJson()};
  @override
  String toString() => '($a $op $b)';
}

final class CssSeq extends CssValue {
  const CssSeq(this.items);
  final List<CssValue> items;
  @override
  Object? toJson() => {'t': 'seq', 'items': [for (final a in items) a.toJson()]};
  @override
  String toString() => items.join(' ');
}

final class CssList extends CssValue {
  const CssList(this.items);
  final List<CssValue> items;
  @override
  Object? toJson() => {'t': 'list', 'items': [for (final a in items) a.toJson()]};
  @override
  String toString() => items.join(', ');
}

final class CssSlash extends CssValue {
  const CssSlash();
  @override
  Object? toJson() => {'t': 'slash'};
  @override
  String toString() => '/';
}

/// Guaranteed-invalid value (unresolvable `var()` without fallback).
final class CssUnset extends CssValue {
  const CssUnset();
  @override
  Object? toJson() => {'t': 'unset'};
  @override
  String toString() => 'unset';
}

/// Canonical text form of a value (mirrors `canon()` in tool/recipes/gen_dart.mjs;
/// used by the JS/Dart parity test).
String raftCssCanonical(CssValue v) => switch (v) {
      CssNum(:final value, :final unit) => '${_canonNum(value)}$unit',
      CssKeyword(:final value) => value,
      CssString(:final value) => '"$value"',
      CssColor(:final argb) => '#${argb.toRadixString(16).padLeft(8, '0')}',
      CssVar(:final name, :final fallback, :final token) =>
        '${token != null ? 'token' : 'var'}(${token ?? name}${fallback != null ? '|${raftCssCanonical(fallback)}' : ''})',
      CssFunction(:final name, :final args) => '$name(${args.map(raftCssCanonical).join(', ')})',
      CssCalc(:final expr) => 'calc(${raftCssCanonical(expr)})',
      CssOp(:final op, :final a, :final b) => '(${raftCssCanonical(a)} $op ${raftCssCanonical(b)})',
      CssSeq(:final items) => items.map(raftCssCanonical).join(' '),
      CssList(:final items) => items.map(raftCssCanonical).join(', '),
      CssSlash() => '/',
      CssUnset() => 'unset',
    };

String _canonNum(double v) {
  final x = double.parse(v.toStringAsFixed(6));
  if (x == x.roundToDouble() && x.abs() < 1e15) return x.toInt().toString();
  return x.toString();
}

String _fmt(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return double.parse(v.toStringAsFixed(6)).toString();
}

// ------------------------------------------------------------ table records

/// One CSS declaration of a utility (longhand, physical LTR sides).
final class RaftDecl {
  const RaftDecl(this.property, this.value, [this.important = false]);
  final String property;
  final CssValue value;
  final bool important;
}

/// Declarations of a utility that apply under [atoms] to [target]
/// ('self', '::before', '::after', '::placeholder', or a descendant selector
/// where `&` stands for the element).
final class RaftLayer {
  const RaftLayer(this.target, this.atoms, this.specificity, this.decls);
  final String target;
  final List<String> atoms;

  /// a * 1e6 + b * 1e3 + c.
  final int specificity;
  final List<RaftDecl> decls;
}

enum RaftUtilityStatus { resolved, descendant, marker, noCss }

/// A Tailwind class compiled by Tailwind v4 (`order` = position in the
/// compiled stylesheet, i.e. the cascade order among equal specificity).
final class RaftUtility {
  const RaftUtility(this.name, this.order, this.status, this.layers);
  final String name;
  final int order;
  final RaftUtilityStatus status;
  final List<RaftLayer> layers;
}

// -------------------------------------------------------------------- states

/// Interaction / environment state for recipe resolution.
///
/// [flags] are condition atoms; the common ones are constants on this class.
/// Attribute atoms follow `name=value` (`data-loading=true`) or `name`
/// (`data-open`); group/peer atoms are `group/<name>:<atom>`; `:has()` atoms
/// are `has:<relative selector>`. Media queries match against
/// [viewportWidth] / [viewportHeight] / [containerWidth] (logical px); when
/// those are null, width/height-conditioned rules do not apply.
class RaftRecipeStates {
  const RaftRecipeStates([this.flags = const <String>{}, this.viewportWidth, this.viewportHeight, this.containerWidth]);

  static const RaftRecipeStates none = RaftRecipeStates();

  static const String hover = 'hover';
  static const String active = 'active';
  static const String focus = 'focus';
  static const String focusVisible = 'focus-visible';
  static const String focusWithin = 'focus-within';
  static const String disabled = 'disabled';
  static const String ariaDisabled = 'aria-disabled=true';
  static const String loading = 'data-loading=true';
  static const String checked = 'data-checked';
  static const String dark = 'dark';
  static const String motionReduce = 'motion-reduce';

  /// Touch-only device (`@media (hover: none)`); hover rules assume a hover
  /// capable pointer, so simply never pass [hover] on touch.
  static const String hoverNone = 'hover-none';

  /// Button-style `has-data-[icon=inline-start|end]:` padding adjustments.
  static const String iconInlineStart = 'has:data-icon=inline-start';
  static const String iconInlineEnd = 'has:data-icon=inline-end';

  final Set<String> flags;
  final double? viewportWidth;
  final double? viewportHeight;
  final double? containerWidth;

  RaftRecipeStates copyWith({Set<String>? flags, double? viewportWidth, double? viewportHeight, double? containerWidth}) =>
      RaftRecipeStates(flags ?? this.flags, viewportWidth ?? this.viewportWidth, viewportHeight ?? this.viewportHeight,
          containerWidth ?? this.containerWidth);

  static final RegExp _media = RegExp(r'^(width|height|container-width)(>=|<=|<|>)([\d.]+)$');

  bool matches(String atom) {
    if (atom.startsWith('not:')) return !matches(atom.substring(4));
    final m = _media.firstMatch(atom);
    if (m != null) {
      final v = switch (m.group(1)) { 'width' => viewportWidth, 'height' => viewportHeight, _ => containerWidth };
      if (v == null) return false;
      final n = double.parse(m.group(3)!);
      return switch (m.group(2)) { '>=' => v >= n, '<=' => v <= n, '<' => v < n, _ => v > n };
    }
    return flags.contains(atom);
  }
}

// --------------------------------------------------------------- token refs

/// Reference to a raft-ui foundation token by its lowerCamelCase name
/// (`--primary-400` -> `primary400`, `--theme-shadow-sm` -> `themeShadowSm`).
@immutable
final class TokenRef {
  const TokenRef(this.name);
  final String name;

  /// CSS custom property name.
  String get cssName => '--${name.replaceAllMapped(RegExp(r'([A-Z]|(?<=[a-z])[0-9]+)'), (m) => '-${m[0]!.toLowerCase()}')}';
  @override
  bool operator ==(Object other) => other is TokenRef && other.name == name;
  @override
  int get hashCode => name.hashCode;
  @override
  String toString() => 'TokenRef($name)';
}

/// Resolves foundation tokens for the active theme (brutal / elegant light /
/// elegant dark). Bind this to the generated token ThemeExtension.
abstract class RaftTokenResolver {
  const RaftTokenResolver();

  Color color(String name);

  /// Shadow token (e.g. `themeShadowSm`) in Flutter paint order.
  List<BoxShadow> shadow(String name);

  /// Numeric token in logical px for lengths, raw for unitless values
  /// (e.g. `fieldFontSize`, `fieldFontWeight`). Null when unknown.
  double? number(String name) => null;

  /// Font family token (e.g. `headingFont`): the primary family name.
  String? fontFamily(String name) => null;
}

/// A colour that may depend on foundation tokens.
sealed class RaftColorRef {
  const RaftColorRef();

  /// Name of the token when this is a plain token reference.
  String? get tokenName => null;

  Color resolve(RaftTokenResolver tokens, {Color? currentColor});

  static RaftColorRef? fromCss(CssValue? v) {
    switch (v) {
      case CssColor(:final argb):
        return RaftLiteralColor(Color(argb));
      case CssVar(:final token?, :final fallback):
        return RaftTokenColor(TokenRef(token), fromCss(fallback));
      case CssKeyword(value: 'currentcolor'):
        return const RaftCurrentColor();
      case CssFunction(name: 'color-mix', :final args) when args.length == 3:
        final space = args[0] is CssSeq ? (args[0] as CssSeq).items.elementAtOrNull(1) : null;
        final a = _mixPart(args[1]);
        final b = _mixPart(args[2]);
        if (space is! CssKeyword || a == null || b == null) return null;
        return RaftMixedColor(space.value, a.$1, a.$2, b.$1, b.$2);
      default:
        return null;
    }
  }

  static (RaftColorRef, double?)? _mixPart(CssValue v) {
    final items = v is CssSeq ? v.items : [v];
    CssValue? color;
    double? pct;
    for (final x in items) {
      if (x is CssNum && x.unit == '%') {
        pct = x.value / 100;
      } else {
        color ??= x;
      }
    }
    final ref = fromCss(color);
    return ref == null ? null : (ref, pct);
  }
}

final class RaftLiteralColor extends RaftColorRef {
  const RaftLiteralColor(this.value);
  final Color value;
  @override
  Color resolve(RaftTokenResolver tokens, {Color? currentColor}) => value;
  @override
  bool operator ==(Object other) => other is RaftLiteralColor && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'RaftLiteralColor(0x${value.toARGB32().toRadixString(16)})';
}

final class RaftTokenColor extends RaftColorRef {
  const RaftTokenColor(this.token, [this.fallback]);
  final TokenRef token;
  final RaftColorRef? fallback;
  @override
  String? get tokenName => token.name;
  @override
  Color resolve(RaftTokenResolver tokens, {Color? currentColor}) => tokens.color(token.name);
  @override
  bool operator ==(Object other) => other is RaftTokenColor && other.token == token;
  @override
  int get hashCode => token.hashCode;
  @override
  String toString() => 'RaftTokenColor(${token.name})';
}

final class RaftCurrentColor extends RaftColorRef {
  const RaftCurrentColor();
  @override
  Color resolve(RaftTokenResolver tokens, {Color? currentColor}) => currentColor ?? const Color(0xFF000000);
}

/// CSS `color-mix(in <space>, a pa, b pb)` (oklab / oklch).
final class RaftMixedColor extends RaftColorRef {
  const RaftMixedColor(this.space, this.a, this.pa, this.b, this.pb);
  final String space;
  final RaftColorRef a;
  final double? pa;
  final RaftColorRef b;
  final double? pb;
  @override
  Color resolve(RaftTokenResolver tokens, {Color? currentColor}) {
    final x = a.resolve(tokens, currentColor: currentColor).toARGB32();
    final y = b.resolve(tokens, currentColor: currentColor).toARGB32();
    return Color(raftMixColors(space, x, pa, y, pb) ?? x);
  }

  @override
  String toString() => 'RaftMixedColor($space, $a ${pa ?? ''}, $b ${pb ?? ''})';
}

/// One `box-shadow` layer.
sealed class RaftShadowLayer {
  const RaftShadowLayer();
}

/// A shadow token (`--theme-shadow-sm`), resolved by [RaftTokenResolver.shadow].
final class RaftTokenShadow extends RaftShadowLayer {
  const RaftTokenShadow(this.token);
  final TokenRef token;
  @override
  bool operator ==(Object other) => other is RaftTokenShadow && other.token == token;
  @override
  int get hashCode => token.hashCode;
  @override
  String toString() => 'RaftTokenShadow(${token.name})';
}

final class RaftLiteralShadow extends RaftShadowLayer {
  const RaftLiteralShadow({required this.offset, required this.blur, required this.spread, required this.color, this.inset = false});
  final bool inset;
  final Offset offset;
  final double blur;
  final double spread;
  final RaftColorRef color;
  @override
  String toString() => 'RaftLiteralShadow(${inset ? 'inset ' : ''}$offset blur $blur spread $spread $color)';
}

extension RaftShadowLayers on List<RaftShadowLayer> {
  /// Outer shadows as Flutter [BoxShadow]s in Flutter paint order (CSS lists
  /// the top-most shadow first; Flutter paints the first entry first).
  /// Inset layers are skipped — see [insetLayers].
  List<BoxShadow> toBoxShadows(RaftTokenResolver tokens, {Color? currentColor}) {
    final out = <BoxShadow>[];
    for (final layer in reversed) {
      switch (layer) {
        case RaftTokenShadow(:final token):
          out.addAll(tokens.shadow(token.name));
        case RaftLiteralShadow(inset: false):
          out.add(BoxShadow(
            color: layer.color.resolve(tokens, currentColor: currentColor),
            offset: layer.offset,
            blurRadius: layer.blur,
            spreadRadius: layer.spread,
          ));
        case RaftLiteralShadow():
          break;
      }
    }
    return out;
  }

  List<RaftLiteralShadow> get insetLayers => [for (final l in this) if (l is RaftLiteralShadow && l.inset) l];
}

enum RaftRecipeTheme { brutal, elegant }

// ------------------------------------------------------------ recipe tables

/// A tailwind-variants variant axis. Combination tables are laid out in
/// mixed radix over the axes (first axis most significant); an axis that
/// [allowsUnset] reserves option 0 for "prop omitted".
final class RaftRecipeAxis {
  const RaftRecipeAxis(this.name, this.values, this.defaultValue, this.allowsUnset);
  final String name;
  final List<String> values;
  final String? defaultValue;
  final bool allowsUnset;

  int optionIndex(String? value) {
    final v = value ?? (allowsUnset ? null : defaultValue);
    if (v == null) {
      if (allowsUnset) return 0;
      throw ArgumentError('Recipe axis "$name" requires a value');
    }
    final i = values.indexOf(v);
    if (i < 0) throw ArgumentError.value(value, name, 'expected one of $values');
    return allowsUnset ? i + 1 : i;
  }

  int get optionCount => values.length + (allowsUnset ? 1 : 0);
}

/// Resolves every slot of a generated recipe for one combination.
List<RaftSlotStyle> raftResolveRecipe(
  RaftRecipeEngine engine,
  List<RaftRecipeAxis> axes,
  List<List<int>> lists,
  List<List<int>> combos,
  List<String?> values,
  RaftRecipeStates states,
  RaftTokenResolver? tokens,
) {
  var index = 0;
  for (var k = 0; k < axes.length; k++) {
    index = index * axes[k].optionCount + axes[k].optionIndex(values[k]);
  }
  return [for (final list in combos[index]) engine.resolveSlot(lists[list], states, tokens)];
}

// -------------------------------------------------------------------- engine

class _Entry {
  _Entry(this.specificity, this.order, this.layerIndex, this.layer);
  final int specificity;
  final int order;
  final int layerIndex;
  final RaftLayer layer;
}

/// Cascade + value resolution over the generated utility table.
final class RaftRecipeEngine {
  const RaftRecipeEngine(this.utilities, this.registered);
  final List<RaftUtility> utilities;

  /// `@property` registered (non-inheriting) custom properties and their
  /// initial values (null when the registration has no initial value).
  final Map<String, CssValue?> registered;

  RaftSlotStyle resolveSlot(List<int> classIndices, RaftRecipeStates states, [RaftTokenResolver? tokens]) {
    final byTarget = <String, List<_Entry>>{};
    for (final ci in classIndices) {
      final u = utilities[ci];
      for (var li = 0; li < u.layers.length; li++) {
        final layer = u.layers[li];
        if (!layer.atoms.every(states.matches)) continue;
        (byTarget[layer.target] ??= []).add(_Entry(layer.specificity, u.order, li, layer));
      }
    }
    final declared = <String, Map<String, CssValue>>{};
    for (final MapEntry(key: target, value: entries) in byTarget.entries) {
      entries.sort((a, b) {
        final s = a.specificity.compareTo(b.specificity);
        if (s != 0) return s;
        final o = a.order.compareTo(b.order);
        return o != 0 ? o : a.layerIndex.compareTo(b.layerIndex);
      });
      final props = <String, CssValue>{};
      for (final important in const [false, true]) {
        for (final e in entries) {
          for (final d in e.layer.decls) {
            if (d.important == important) props[d.property] = d.value;
          }
        }
      }
      declared[target] = props;
    }
    final self = declared.putIfAbsent('self', () => {});
    final evaluated = <String, Map<String, CssValue>>{};
    for (final MapEntry(key: target, value: props) in declared.entries) {
      CssValue? lookup(String name) {
        final own = props[name];
        if (own != null) return own;
        if (target != 'self' && !registered.containsKey(name)) return self[name];
        return null;
      }

      final ctx = _EvalContext(lookup, registered);
      evaluated[target] = {for (final e in props.entries) e.key: ctx.evaluate(e.value, 0)};
    }
    final classes = [for (final ci in classIndices) utilities[ci].name];
    return RaftSlotStyle(
      evaluated['self']!,
      {for (final e in evaluated.entries) if (e.key != 'self') e.key: e.value},
      classes,
      tokens,
    );
  }
}

class _EvalContext {
  _EvalContext(this.lookup, this.registered);
  final CssValue? Function(String name) lookup;
  final Map<String, CssValue?> registered;

  CssValue evaluate(CssValue node, int depth) {
    if (depth > 64) return const CssUnset();
    switch (node) {
      case CssVar():
        return _evalVar(node, depth);
      case CssCalc(:final expr):
        final e = _evalMath(expr, depth);
        return e is CssNum ? e : CssCalc(e);
      case CssFunction(:final name, args: final rawArgs):
        final args = [for (final a in rawArgs) evaluate(a, depth + 1)];
        if (args.any((a) => a is CssUnset)) return const CssUnset();
        if (name == 'min' || name == 'max' || name == 'clamp') {
          if (args.every((a) => a is CssNum && a.unit == (args[0] as CssNum).unit)) {
            final vs = [for (final a in args) (a as CssNum).value];
            final unit = (args[0] as CssNum).unit;
            final v = name == 'min'
                ? vs.reduce(math.min)
                : name == 'max'
                    ? vs.reduce(math.max)
                    : math.min(math.max(vs[0], vs[1]), vs[2]);
            return CssNum(v, unit);
          }
        }
        if (name == 'color-mix') return _evalColorMix(args) ?? CssFunction(name, args);
        return CssFunction(name, args);
      case CssSeq(:final items):
        final evaluated = [for (final x in items) evaluate(x, depth + 1)];
        if (evaluated.any((a) => a is CssUnset)) return const CssUnset();
        final flat = [for (final x in evaluated) ...(x is CssSeq ? x.items : [x])];
        if (flat.length == 1) return flat.single;
        if (flat.any((x) => x is CssList)) return _resplit(flat);
        return CssSeq(flat);
      case CssList(:final items):
        final evaluated = [for (final x in items) evaluate(x, depth + 1)];
        if (evaluated.any((a) => a is CssUnset)) return const CssUnset();
        return CssList([for (final x in evaluated) ...(x is CssList ? x.items : [x])]);
      default:
        return node;
    }
  }

  CssValue _resplit(List<CssValue> items) {
    final out = <List<CssValue>>[[]];
    for (final x in items) {
      if (x is CssList) {
        for (var i = 0; i < x.items.length; i++) {
          if (i > 0) out.add([]);
          final y = x.items[i];
          out.last.addAll(y is CssSeq ? y.items : [y]);
        }
      } else {
        out.last.add(x);
      }
    }
    return CssList([for (final s in out) s.length == 1 ? s.single : CssSeq(s)]);
  }

  CssValue _evalVar(CssVar node, int depth) {
    final set = lookup(node.name);
    if (set != null) return evaluate(set, depth + 1);
    final fb = node.fallback == null ? null : evaluate(node.fallback!, depth + 1);
    if (node.token != null) return CssVar(node.name, fb, node.token);
    if (registered.containsKey(node.name)) {
      final init = registered[node.name];
      if (init != null) return evaluate(init, depth + 1);
    }
    return fb ?? const CssUnset();
  }

  CssValue _evalMath(CssValue e, int depth) {
    if (e is CssOp) {
      final a = _evalMath(e.a, depth + 1);
      final b = _evalMath(e.b, depth + 1);
      return _arith(e.op, a, b) ?? CssOp(e.op, a, b);
    }
    if (e is CssCalc) return _evalMath(e.expr, depth + 1);
    if (e is CssKeyword && e.value == 'infinity') return const CssNum(3.4028234663852886e38);
    final v = evaluate(e, depth + 1);
    if (v is CssCalc) return v.expr;
    if (v is CssSeq && v.items.isEmpty) return const CssNum(0);
    return v;
  }

  static CssValue? _arith(String op, CssValue a, CssValue b) {
    if (a is! CssNum || b is! CssNum) return null;
    switch (op) {
      case '+':
      case '-':
        var unit = a.unit;
        if (a.unit != b.unit) {
          if (a.value == 0 && a.unit != '%') {
            unit = b.unit;
          } else if (b.value == 0 && b.unit != '%') {
            unit = a.unit;
          } else {
            return null;
          }
        }
        return CssNum(op == '+' ? a.value + b.value : a.value - b.value, unit);
      case '*':
        if (a.unit.isNotEmpty && b.unit.isNotEmpty) return null;
        return CssNum(a.value * b.value, a.unit.isNotEmpty ? a.unit : b.unit);
      case '/':
        if (b.unit.isNotEmpty && a.unit != b.unit) return null;
        if (b.value == 0) return null;
        return CssNum(a.value / b.value, b.unit.isNotEmpty ? '' : a.unit);
    }
    return null;
  }

  static CssValue? _evalColorMix(List<CssValue> args) {
    if (args.length != 3) return null;
    final spaceSeq = args[0] is CssSeq ? (args[0] as CssSeq).items : [args[0]];
    final space = spaceSeq.length > 1 && spaceSeq[1] is CssKeyword ? (spaceSeq[1] as CssKeyword).value : null;
    (CssValue?, double?) part(CssValue n) {
      final items = n is CssSeq ? n.items : [n];
      final color = items.where((x) => x is! CssNum).firstOrNull;
      final pct = items.whereType<CssNum>().where((x) => x.unit == '%').firstOrNull;
      return (color, pct == null ? null : pct.value / 100);
    }

    final (ca, pa) = part(args[1]);
    final (cb, pb) = part(args[2]);
    if (ca is! CssColor || cb is! CssColor) return null;
    if (space != 'oklab' && space != 'oklch') return null;
    final argb = raftMixColors(space!, ca.argb, pa, cb.argb, pb);
    return argb == null ? null : CssColor(argb);
  }
}

// --------------------------------------------------------------- colour math

double _srgbToLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _linearToSrgb(double c) => c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
double _cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

List<double> _toOklab(int argb) {
  final r = _srgbToLinear(((argb >> 16) & 255) / 255);
  final g = _srgbToLinear(((argb >> 8) & 255) / 255);
  final b = _srgbToLinear((argb & 255) / 255);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
}

int _fromOklab(List<double> lab, double alpha) {
  final l = math.pow(lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2], 3).toDouble();
  final m = math.pow(lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2], 3).toDouble();
  final s = math.pow(lab[0] - 0.0894841775 * lab[1] - 1.291485548 * lab[2], 3).toDouble();
  final lin = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
  int ch(double x) => (_linearToSrgb(x).clamp(0.0, 1.0) * 255).round();
  final a = (alpha * 255).round().clamp(0, 255);
  return (a << 24) | (ch(lin[0]) << 16) | (ch(lin[1]) << 8) | ch(lin[2]);
}

/// CSS Color 5 `color-mix()` of two sRGB colours in oklab or oklch
/// (premultiplied alpha, shorter hue). Returns 0xAARRGGBB.
int? raftMixColors(String space, int c1, double? p1, int c2, double? p2) {
  if (p1 == null && p2 == null) {
    p1 = 0.5;
    p2 = 0.5;
  } else if (p1 == null) {
    p1 = 1 - p2!;
  } else {
    p2 ??= 1 - p1;
  }
  final sum = p1 + p2;
  if (sum <= 0) return null;
  final alphaMult = math.min(sum, 1.0);
  final w1 = p1 / sum;
  final w2 = p2 / sum;
  final a1 = ((c1 >> 24) & 255) / 255;
  final a2 = ((c2 >> 24) & 255) / 255;
  final x = _toOklab(c1);
  final y = _toOklab(c2);
  final alpha = a1 * w1 + a2 * w2;
  if (alpha == 0) return 0;
  List<double> lab;
  if (space == 'oklch') {
    double chroma(List<double> v) => math.sqrt(v[1] * v[1] + v[2] * v[2]);
    final cx = chroma(x);
    final cy = chroma(y);
    final hx = cx < 1e-6 ? null : math.atan2(x[2], x[1]);
    final hy = cy < 1e-6 ? null : math.atan2(y[2], y[1]);
    var h1 = hx ?? hy ?? 0;
    var h2 = hy ?? hx ?? 0;
    if (h2 - h1 > math.pi) {
      h1 += 2 * math.pi;
    } else if (h1 - h2 > math.pi) {
      h2 += 2 * math.pi;
    }
    final l = (x[0] * a1 * w1 + y[0] * a2 * w2) / alpha;
    final c = (cx * a1 * w1 + cy * a2 * w2) / alpha;
    final h = h1 * w1 + h2 * w2;
    lab = [l, c * math.cos(h), c * math.sin(h)];
  } else {
    lab = [for (var i = 0; i < 3; i++) (x[i] * a1 * w1 + y[i] * a2 * w2) / alpha];
  }
  return _fromOklab(lab, alpha * alphaMult);
}

// ---------------------------------------------------------- resolved style

/// Resolved style of one recipe slot for one variant combination and state.
///
/// [properties] holds the cascaded, `var()`-resolved CSS longhands (physical
/// sides, logical px) including custom properties. Typed getters project the
/// common properties onto Flutter types; lengths that come from tokens are
/// resolved through [tokens] when provided. [targets] holds pseudo-elements
/// (`::before`) and descendant rules (`& svg`, `:is(& *)[data-icon]`).
class RaftSlotStyle {
  RaftSlotStyle(this.properties, this.targets, this.classes, [this.tokens]);

  final Map<String, CssValue> properties;
  final Map<String, Map<String, CssValue>> targets;

  /// Final class list after tailwind-variants + tailwind-merge (for tracing).
  final List<String> classes;
  final RaftTokenResolver? tokens;

  CssValue? operator [](String property) {
    final v = properties[property];
    return v is CssUnset ? null : v;
  }

  /// Style of a pseudo-element or descendant target, e.g. `::before`.
  RaftSlotStyle? target(String selector) {
    final t = targets[selector];
    return t == null ? null : RaftSlotStyle(t, const {}, classes, tokens);
  }

  RaftSlotStyle? get before => target('::before');
  RaftSlotStyle? get after => target('::after');

  // ------------------------------------------------------------ lengths

  /// Length in logical px. Token lengths resolve through [tokens]. Returns
  /// null for keywords (auto), percentages, em and unresolved calc().
  double? length(String property) => _px(this[property]);

  double? _px(CssValue? v) => switch (v) {
        CssNum(unit: 'px', :final value) => value,
        CssNum(unit: '', value: 0) => 0,
        CssVar(:final token?, :final fallback) => tokens?.number(token) ?? _px(fallback),
        _ => null,
      };

  double? get width => length('width');
  double? get height => length('height');
  double? get minWidth => length('min-width');
  double? get minHeight => length('min-height');
  double? get maxWidth => length('max-width');
  double? get maxHeight => length('max-height');
  double? get rowGap => length('row-gap');
  double? get columnGap => length('column-gap');

  EdgeInsets _box(String prefix, [String suffix = '']) => EdgeInsets.fromLTRB(
        length('$prefix-left$suffix') ?? 0,
        length('$prefix-top$suffix') ?? 0,
        length('$prefix-right$suffix') ?? 0,
        length('$prefix-bottom$suffix') ?? 0,
      );

  EdgeInsets get padding => _box('padding');
  EdgeInsets get margin => _box('margin');

  /// Border widths; a side whose border-style is none/hidden (or unset) has
  /// a used width of 0, as in CSS.
  EdgeInsets get borderWidth {
    double side(String s) {
      final style = this['border-$s-style'];
      if (style == null || (style is CssKeyword && (style.value == 'none' || style.value == 'hidden'))) return 0;
      final w = this['border-$s-width'];
      if (w == null) return 3; // CSS initial 'medium'
      if (w is CssKeyword) return switch (w.value) { 'thin' => 1, 'thick' => 5, _ => 3 };
      return _px(w) ?? 0;
    }

    return EdgeInsets.fromLTRB(side('left'), side('top'), side('right'), side('bottom'));
  }

  RaftColorRef? borderColorOf(String side) => RaftColorRef.fromCss(this['border-$side-color']) ??
      (this['border-$side-width'] != null ? const RaftCurrentColor() : null);
  RaftColorRef? get borderColor => borderColorOf('top');

  /// Corner radii in px (null when no radius is declared).
  BorderRadius? get borderRadius {
    final keys = ['top-left', 'top-right', 'bottom-right', 'bottom-left'];
    if (!keys.any((k) => properties.containsKey('border-$k-radius'))) return null;
    Radius r(String k) => Radius.circular(length('border-$k-radius') ?? 0);
    return BorderRadius.only(topLeft: r('top-left'), topRight: r('top-right'), bottomRight: r('bottom-right'), bottomLeft: r('bottom-left'));
  }

  // -------------------------------------------------------------- colours

  RaftColorRef? get color => RaftColorRef.fromCss(this['color']);
  RaftColorRef? get backgroundColor => RaftColorRef.fromCss(this['background-color']);
  RaftColorRef? get outlineColor => RaftColorRef.fromCss(this['outline-color']);

  // -------------------------------------------------------- typography

  double? get fontSize => length('font-size');

  FontWeight? get fontWeight {
    final v = this['font-weight'];
    final n = switch (v) {
      CssNum(:final value) => value,
      CssVar(:final token?) => tokens?.number(token),
      CssKeyword(value: 'bold') => 700.0,
      CssKeyword(value: 'normal') => 400.0,
      _ => null,
    };
    if (n == null) return null;
    final i = ((n / 100).round() - 1).clamp(0, FontWeight.values.length - 1);
    return FontWeight.values[i];
  }

  /// Font family from CSS: token families resolve via [RaftTokenResolver.fontFamily],
  /// otherwise the first literal family name.
  String? get fontFamily {
    final v = this['font-family'];
    if (v is CssVar && v.token != null) {
      final f = tokens?.fontFamily(v.token!);
      if (f != null) return f;
    }
    return fontFamilyFallback?.firstOrNull;
  }

  /// All literal family names of the declaration (fallback chain).
  List<String>? get fontFamilyFallback {
    var v = this['font-family'];
    if (v is CssVar) v = v.fallback;
    if (v == null) return null;
    final items = v is CssList ? v.items : [v];
    return [
      for (final x in items)
        switch (x) {
          CssString(:final value) => value,
          CssKeyword(:final value) => value,
          CssSeq(:final items) => items.join(' '),
          _ => x.toString(),
        },
    ];
  }

  /// Line height as a multiple of the font size (Flutter [TextStyle.height]).
  double? get lineHeight {
    final v = this['line-height'];
    if (v is CssNum && v.unit.isEmpty) return v.value;
    final px = _px(v);
    final fs = fontSize;
    return px != null && fs != null && fs > 0 ? px / fs : null;
  }

  /// Line height in px when declared in px.
  double? get lineHeightPx => _px(this['line-height']);

  /// Letter spacing in px (`em` values are multiplied by [fontSize]).
  double? get letterSpacing {
    final v = this['letter-spacing'];
    if (v is CssNum && v.unit == 'em') {
      final fs = fontSize;
      return fs == null ? null : v.value * fs;
    }
    return _px(v);
  }

  String? get textTransform => _kw('text-transform');

  // ------------------------------------------------------------- effects

  double? get opacity => switch (this['opacity']) {
        CssNum(unit: '%', :final value) => value / 100,
        CssNum(unit: '', :final value) => value,
        _ => null,
      };

  List<RaftShadowLayer> get boxShadow => raftShadowLayers(this['box-shadow']);

  double? get outlineWidth => length('outline-width');
  double? get outlineOffset => length('outline-offset');

  /// Uniform `scale` (x when x and y differ); `none` -> 1.
  double? get scale {
    final v = this['scale'];
    return switch (v) {
      CssNum(unit: '', :final value) => value,
      CssNum(unit: '%', :final value) => value / 100,
      CssKeyword(value: 'none') => 1,
      CssSeq(:final items) when items.first is CssNum => (items.first as CssNum).unit == '%'
          ? (items.first as CssNum).value / 100
          : (items.first as CssNum).value,
      _ => null,
    };
  }

  /// `translate` in px; `none` -> Offset.zero; null for % or unresolved.
  Offset? get translate {
    final v = this['translate'];
    if (v is CssKeyword && v.value == 'none') return Offset.zero;
    final items = v is CssSeq ? v.items : (v == null ? const <CssValue>[] : [v]);
    if (items.isEmpty) return null;
    final x = _px(items[0]);
    final y = items.length > 1 ? _px(items[1]) : 0.0;
    return x == null || y == null ? null : Offset(x, y);
  }

  Duration? get transitionDuration {
    var v = this['transition-duration'];
    if (v is CssList) v = v.items.first;
    return v is CssNum && v.unit == 'ms' ? Duration(microseconds: (v.value * 1000).round()) : null;
  }

  Curve? get transitionCurve {
    var v = this['transition-timing-function'];
    if (v is CssList) v = v.items.first;
    switch (v) {
      case CssFunction(name: 'cubic-bezier', :final args) when args.length == 4 && args.every((a) => a is CssNum):
        final n = [for (final a in args) (a as CssNum).value];
        return Cubic(n[0], n[1], n[2], n[3]);
      case CssKeyword(:final value):
        return switch (value) {
          'linear' => Curves.linear,
          'ease' => Curves.ease,
          'ease-in' => Curves.easeIn,
          'ease-out' => Curves.easeOut,
          'ease-in-out' => Curves.easeInOut,
          _ => null,
        };
      default:
        return null;
    }
  }

  // --------------------------------------------------------------- layout

  String? _kw(String p) => switch (this[p]) { CssKeyword(:final value) => value, _ => null };
  String? get display => _kw('display');
  String? get position => _kw('position');
  String? get cursor => _kw('cursor');
  String? get overflowX => _kw('overflow-x');
  String? get overflowY => _kw('overflow-y');
  String? get pointerEvents => _kw('pointer-events');
  String? get visibility => _kw('visibility');
  String? get whiteSpace => _kw('white-space');
  int? get zIndex => switch (this['z-index']) { CssNum(:final value) => value.round(), _ => null };

  // ------------------------------------------------------ Flutter helpers

  /// Text style from font/colour properties (unset values are inherited).
  TextStyle textStyle(RaftTokenResolver tokens, {Color? currentColor}) => TextStyle(
        color: color?.resolve(tokens, currentColor: currentColor),
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback?.skip(1).toList(),
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: lineHeight,
        letterSpacing: letterSpacing,
      );

  Border? border(RaftTokenResolver tokens, {Color? currentColor}) {
    final w = borderWidth;
    if (w == EdgeInsets.zero) return null;
    BorderSide side(String s, double width) => width <= 0
        ? BorderSide.none
        : BorderSide(width: width, color: (borderColorOf(s) ?? const RaftCurrentColor()).resolve(tokens, currentColor: currentColor));
    return Border(top: side('top', w.top), right: side('right', w.right), bottom: side('bottom', w.bottom), left: side('left', w.left));
  }

  BoxDecoration decoration(RaftTokenResolver tokens, {Color? currentColor}) => BoxDecoration(
        color: backgroundColor?.resolve(tokens, currentColor: currentColor),
        border: border(tokens, currentColor: currentColor),
        borderRadius: borderRadius,
        boxShadow: boxShadow.toBoxShadows(tokens, currentColor: currentColor),
      );

  @override
  String toString() => 'RaftSlotStyle(${properties.entries.where((e) => !e.key.startsWith('--')).map((e) => '${e.key}: ${e.value}').join('; ')})';
}

/// Parses a resolved `box-shadow` value into layers (zero transparent layers
/// such as Tailwind's `0 0 #0000` placeholders are dropped).
List<RaftShadowLayer> raftShadowLayers(CssValue? v) {
  if (v == null || v is CssUnset || (v is CssKeyword && v.value == 'none')) return const [];
  final layers = v is CssList ? v.items : [v];
  final out = <RaftShadowLayer>[];
  for (final layer in layers) {
    final items = (layer is CssSeq ? layer.items : [layer]).where((x) => !(x is CssSeq && x.items.isEmpty)).toList();
    final zero = items.every((x) => (x is CssNum && x.value == 0) || (x is CssColor && (x.argb >>> 24) == 0));
    if (zero) continue;
    if (layer is CssVar && layer.token != null) {
      out.add(RaftTokenShadow(TokenRef(layer.token!)));
      continue;
    }
    if (layer is CssKeyword && layer.value == 'none') continue;
    final inset = items.any((x) => x is CssKeyword && x.value == 'inset');
    final lengths = [for (final x in items) if (x is CssNum) x.unit == 'px' || x.value == 0 ? x.value : null];
    final colorNode = items.where((x) => x is! CssNum && !(x is CssKeyword && x.value == 'inset')).firstOrNull;
    double at(int i) => i < lengths.length ? (lengths[i] ?? 0) : 0;
    out.add(RaftLiteralShadow(
      inset: inset,
      offset: Offset(at(0), at(1)),
      blur: at(2),
      spread: at(3),
      color: RaftColorRef.fromCss(colorNode) ?? const RaftCurrentColor(),
    ));
  }
  return out;
}
