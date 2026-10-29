import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// The generated Raft look (RaftLight / RaftDark, raft_tokens.g.dart) must equal
// the vendored official file, tool/design-source/raft-ui-0.7.1/tokens.json,
// token by token and mode by mode. The expectation is computed here from the
// JSON with its own port of the Chromium-exact oklch conversion
// (docs/design-tokens.md), so a drifting generator, a hand edit of the
// generated file or a stale vendored file fails this test.

Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/tool/design-source/raft-ui-0.7.1/tokens.json')
      .existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('repository root not found');
    dir = parent;
  }
  return dir;
}

// ---------------------------------------------------------------- colour math
// OKLab -> LMS -> XYZ-D65 -> Bradford -> XYZ-D50 -> inverse skcms sRGB gamut,
// float32 throughout (Chromium 147), clip per channel, round to 8 bits.

final Float32List _f32 = Float32List(1);
double _f(double x) => (_f32..[0] = x)[0];

typedef _M = List<List<double>>;

_M _m32(_M m) => [
  for (final r in m) [for (final v in r) _f(v)],
];
List<double> _mul(_M m, List<double> v) => [
  for (final r in m) r[0] * v[0] + r[1] * v[1] + r[2] * v[2],
];
List<double> _mul32(_M m, List<double> v) => [
  for (final r in m)
    _f(_f(_f(r[0] * v[0]) + _f(r[1] * v[1])) + _f(r[2] * v[2])),
];
_M _matmul(_M a, _M b) => [
  for (var i = 0; i < 3; i++)
    [
      for (var j = 0; j < 3; j++)
        a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j],
    ],
];
_M _inv3(_M m) {
  final [a, b, c] = m[0];
  final [d, e, f] = m[1];
  final [g, h, i] = m[2];
  final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  return [
    [(e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det],
    [(f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det],
    [(d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det],
  ];
}

final _oklabToLms = _m32(const [
  [0.99999999845051981432, 0.39633779217376785678, 0.21580375806075880339],
  [1.0000000088817607767, -0.1055613423236563494, -0.063854174771705903402],
  [1.0000000546724109177, -0.089484182094965759684, -1.2914855378640917399],
]);
final _lmsToXyzD65 = _m32(const [
  [1.2268798758459243, -0.5578149944602171, 0.2813910456659647],
  [-0.0405757452148008, 1.1122868032803170, -0.0717110580655164],
  [-0.0763729366746601, -0.4214933324022432, 1.5869240198367816],
]);
final _xyzD65ToD50 = () {
  const bradford = [
    [0.8951, 0.2664, -0.1614],
    [-0.7502, 1.7135, 0.0367],
    [0.0389, -0.0685, 1.0296],
  ];
  const wx = 0.3127, wy = 0.3290;
  final src = _mul(bradford, [wx / wy, 1, (1 - wx - wy) / wy]);
  final dst = _mul(bradford, const [0.96422, 1.0, 0.82521]);
  final scale = [
    [dst[0] / src[0], 0.0, 0.0],
    [0.0, dst[1] / src[1], 0.0],
    [0.0, 0.0, dst[2] / src[2]],
  ];
  return _m32(_matmul(_inv3(bradford), _matmul(scale, bradford)));
}();
final _xyzD50ToLinSrgb = _m32(
  _inv3(const [
    [0.436065674, 0.385147095, 0.143066406],
    [0.222488403, 0.716873169, 0.060607910],
    [0.013916016, 0.097076416, 0.714096069],
  ]),
);

double _encode(double x) {
  final a = x.abs();
  final v = a > 0.0031308 ? 1.055 * math.pow(a, 1 / 2.4) - 0.055 : 12.92 * a;
  return _f(x < 0 ? -v : v);
}

double _decode(double x) {
  final a = x.abs();
  final v = a > 0.04045
      ? math.pow((a + 0.055) / 1.055, 2.4).toDouble()
      : a / 12.92;
  return x < 0 ? -v : v;
}

/// Unclamped gamma-encoded sRGB of an oklch colour.
List<double> _oklchToSrgb(double l, double c, double h) {
  final hr = h * (math.pi / 180.0);
  final lab = [
    _f(l),
    _f(_f(c) * _f(math.cos(hr))),
    _f(_f(c) * _f(math.sin(hr))),
  ];
  final lms = [for (final v in _mul32(_oklabToLms, lab)) _f(v * v * v)];
  final lin = _mul32(
    _xyzD50ToLinSrgb,
    _mul32(_xyzD65ToD50, _mul32(_lmsToXyzD65, lms)),
  );
  return [for (final v in lin) _encode(v)];
}

int _byte(double encoded) => (encoded.clamp(0.0, 1.0) * 255 + 0.5).floor();

/// A colour as authored: unclamped gamma sRGB plus exact alpha.
class _Rgba {
  _Rgba(this.srgb, this.alpha);
  final List<double> srgb;
  final double alpha;
  List<int> get bytes => [for (final v in srgb) _byte(v)];
}

_Rgba _oklch(List components, [num? alpha]) => _Rgba(
  _oklchToSrgb(
    (components[0] as num).toDouble(),
    (components[1] as num).toDouble(),
    (components[2] as num).toDouble(),
  ),
  (alpha ?? 1).toDouble(),
);

// ------------------------------------------------------------ tokens.json

class _Token {
  _Token(this.name, this.type, this.light, this.dark);
  final String name; // CSS custom property without `--`
  final String type; // color | shadow | dimension | fontWeight
  final Object light;
  final Object dark;
  Object raw(bool dark) => dark ? this.dark : light;
}

const _ext = 'build.botiverse.raft';

String _refName(String ref) => ref
    .substring(1, ref.length - 1)
    .split('.')
    .where((p) => p != r'$root')
    .join('-');

class _TokenFile {
  _TokenFile(Map<String, dynamic> doc) {
    for (final MapEntry(:key, :value) in doc.entries) {
      if (key.startsWith(r'$')) continue;
      if (key == 'deprecated') {
        for (final MapEntry(key: n, value: t) in (value as Map).entries) {
          if (n.startsWith(r'$')) continue;
          final v = (t as Map)[r'$value'] as String;
          deprecated[n] = v.startsWith('{') ? _refName(v) : null;
        }
      } else {
        _walk(value as Map<String, dynamic>, [key], null);
      }
    }
  }

  final Map<String, _Token> tokens = {};
  final Map<String, String?> deprecated = {}; // old -> new, null = removed

  void _walk(Map<String, dynamic> node, List<String> path, String? inherited) {
    final type = (node[r'$type'] as String?) ?? inherited;
    for (final MapEntry(:key, :value) in node.entries) {
      if (key == r'$root') {
        _add(path, node[r'$root'] as Map, type);
      } else if (key.startsWith(r'$')) {
        continue;
      } else if ((value as Map).containsKey(r'$value')) {
        _add([...path, key], value, type);
      } else {
        _walk(value as Map<String, dynamic>, [...path, key], type);
      }
    }
  }

  void _add(List<String> path, Map token, String? type) {
    final name = path.join('-');
    final light = token[r'$value'] as Object;
    final ext = (token[r'$extensions'] as Map?)?[_ext] as Map?;
    final dark = ((ext?['modes'] as Map?)?['dark'] ?? light) as Object;
    if (tokens.containsKey(name)) throw StateError('duplicate token $name');
    tokens[name] = _Token(
      name,
      (token[r'$type'] as String?) ?? type ?? 'color',
      light,
      dark,
    );
  }

  /// The colour of [name] in one mode, resolving `{aliases}` and
  /// `color-mix(in srgb, ...)` the way the CSS cascade does.
  _Rgba color(String name, {required bool dark}) =>
      _resolve(tokens[name]!.raw(dark), dark);

  _Rgba _resolve(Object raw, bool dark) {
    if (raw is Map) {
      expect(raw['colorSpace'], 'oklch');
      return _oklch(raw['components'] as List, raw['alpha'] as num?);
    }
    final text = raw as String;
    if (text.startsWith('{')) return color(_refName(text), dark: dark);
    final mix = RegExp(
      r'^color-mix\(in srgb, var\(--([a-z0-9-]+)\) (\d+)%, var\(--([a-z0-9-]+)\)\)$',
    ).firstMatch(text);
    if (mix == null) fail('unsupported colour expression: $text');
    final a = color(mix.group(1)!, dark: dark);
    final b = color(mix.group(3)!, dark: dark);
    expect(a.alpha, 1.0);
    expect(b.alpha, 1.0);
    final p = int.parse(mix.group(2)!) / 100;
    // srgb mix: gamma-space interpolation, then the paint path re-encodes.
    return _Rgba([
      for (var i = 0; i < 3; i++)
        _encode(_decode(a.srgb[i] * p + b.srgb[i] * (1 - p))),
    ], 1.0);
  }
}

// ------------------------------------------------------------------- shadows

class _Layer {
  _Layer(this.dx, this.dy, this.blur, this.spread, this.color);
  final double dx, dy, blur, spread;
  final _Rgba color;
}

List<_Layer> _shadow(String css) {
  final layers = <_Layer>[];
  for (final part in css.split(RegExp(r',\s*(?![^(]*\))'))) {
    final colour = RegExp(r'oklch\(([^)]*)\)').firstMatch(part)!;
    final lengths = [
      for (final m in RegExp(
        r'(?<![\w.(/])(-?[\d.]+)(?:px)?(?=\s)',
      ).allMatches('${part.substring(0, colour.start)} '))
        double.parse(m.group(1)!),
    ];
    final args = colour.group(1)!.split('/');
    final lch = args[0].trim().split(RegExp(r'\s+')).map(num.parse).toList();
    final alpha = args.length > 1 ? num.parse(args[1].trim()) : null;
    expect(lengths.length, anyOf(3, 4), reason: part);
    layers.add(
      _Layer(
        lengths[0],
        lengths[1],
        lengths[2],
        lengths.length > 3 ? lengths[3] : 0,
        _oklch(lch, alpha),
      ),
    );
  }
  return layers;
}

// --------------------------------------------------------------------- tests

void _expectColor(Color actual, _Rgba want, String reason) {
  expect(
    [
      for (final v in [actual.r, actual.g, actual.b]) (v * 255).round(),
    ],
    want.bytes,
    reason: '$reason rgb',
  );
  expect(actual.a, closeTo(want.alpha, 1e-9), reason: '$reason alpha');
}

void main() {
  final root = _repoRoot();
  final file = _TokenFile(
    jsonDecode(
      File('${root.path}/tool/design-source/raft-ui-0.7.1/tokens.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>,
  );
  final modes = {'light': false, 'dark': true};
  final colorNames = [
    for (final t in file.tokens.values)
      if (t.type == 'color') t.name,
  ];
  final shadowNames = [
    for (final t in file.tokens.values)
      if (t.type == 'shadow') t.name,
  ];
  final metricNames = [
    for (final t in file.tokens.values)
      if (t.type == 'dimension' || t.type == 'fontWeight') t.name,
  ];

  Map<String, Color> colorsOf(bool dark) =>
      dark ? RaftDark.colors : RaftLight.colors;
  Map<String, RaftShadow> shadowsOf(bool dark) =>
      dark ? RaftDark.shadows : RaftLight.shadows;
  Map<String, double> metricsOf(bool dark) =>
      dark ? RaftDark.metrics : RaftLight.metrics;

  test('tokens.json is the 0.7.1 file the generator was written against', () {
    // 225 colours, 3 shadows, 6 metrics, 159 former names (393 tokens).
    expect(colorNames, hasLength(225));
    expect(shadowNames, ['elevation-float', 'elevation-sticker', 'focus-ring']);
    expect(metricNames, hasLength(6));
    expect(file.deprecated, hasLength(159));
  });

  for (final MapEntry(key: mode, value: dark) in modes.entries) {
    group('$mode mode', () {
      test('maps hold exactly the tokens of tokens.json', () {
        expect(colorsOf(dark).keys.toSet(), colorNames.toSet());
        expect(shadowsOf(dark).keys.toSet(), shadowNames.toSet());
        expect(metricsOf(dark).keys.toSet(), metricNames.toSet());
      });

      test('every colour equals the Chromium-exact conversion', () {
        for (final name in colorNames) {
          _expectColor(
            colorsOf(dark)[name]!,
            file.color(name, dark: dark),
            '$mode --$name',
          );
        }
      });

      test('opaque colours are opaque, translucent ones keep their alpha', () {
        var translucent = 0;
        for (final name in colorNames) {
          final want = file.color(name, dark: dark);
          if (want.alpha < 1) translucent++;
          expect(
            colorsOf(dark)[name]!.a == 1.0,
            want.alpha == 1.0,
            reason: name,
          );
        }
        expect(translucent, greaterThan(10));
      });

      test('every shadow equals its CSS layers', () {
        for (final name in shadowNames) {
          final css = file.tokens[name]!.raw(dark) as String;
          final want = _shadow(css);
          final got = shadowsOf(dark)[name]!.layers;
          expect(got, hasLength(want.length), reason: name);
          for (var i = 0; i < want.length; i++) {
            final reason = '$mode --$name layer $i';
            expect(got[i].inset, isFalse, reason: reason);
            expect(
              got[i].offset,
              Offset(want[i].dx, want[i].dy),
              reason: reason,
            );
            expect(got[i].blur, want[i].blur, reason: reason);
            expect(got[i].spread, want[i].spread, reason: reason);
            _expectColor(got[i].color, want[i].color, reason);
          }
        }
      });

      test('every metric equals tokens.json', () {
        for (final name in metricNames) {
          final raw = file.tokens[name]!.raw(dark);
          final want = raw is Map ? raw['value'] as num : raw as num;
          if (raw is Map) expect(raw['unit'], 'px', reason: name);
          expect(metricsOf(dark)[name], want.toDouble(), reason: name);
        }
      });
    });
  }

  test('former names resolve to the current name, never by name alone', () {
    expect(
      RaftDeprecatedTokenNames.byCssName.length +
          RaftDeprecatedTokenNames.removed.length,
      file.deprecated.length,
    );
    for (final MapEntry(key: old, value: now) in file.deprecated.entries) {
      if (now == null) {
        expect(RaftDeprecatedTokenNames.removed, contains(old));
      } else {
        expect(RaftDeprecatedTokenNames.byCssName[old], now, reason: old);
        // The target is a real token (colour, shadow) of the current set.
        expect(file.tokens, contains(now), reason: '$old -> $now');
      }
    }
    // The trap: the 0.5.52 `layer-panel` is today's `layer-canvas`, and the
    // 0.5.52 `layer-canvas` has no successor.
    expect(RaftDeprecatedTokenNames.byCssName['layer-panel'], 'layer-canvas');
    expect(RaftDeprecatedTokenNames.byCssName, isNot(contains('layer-canvas')));
  });

  test('radii, type scale and easing equal styles.css', () {
    final css = File('${root.path}/tool/design-source/raft-ui-0.7.1/styles.css')
        .readAsStringSync();
    final theme = RegExp(
      r'@theme \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(css)!.group(1)!;
    final decls = {
      for (final m in RegExp(r'(--[a-z0-9-]+):\s*([^;]+);').allMatches(theme))
        m.group(1)!: m.group(2)!.trim(),
    };
    double px(String v) => double.parse(v.replaceAll(RegExp('px|em'), ''));

    final radii = {
      for (final MapEntry(:key, :value) in decls.entries)
        if (key.startsWith('--radius-')) key.substring(9): px(value),
    };
    expect(RaftRadius.byName, radii);

    final styles = {
      for (final key in decls.keys)
        if (RegExp(r'^--text-[a-z]+(-[a-z]+)*$').hasMatch(key))
          key.substring(7),
    };
    expect(RaftTypeScale.byName.keys.toSet(), styles);
    for (final name in styles) {
      final got = RaftTypeScale.byName[name]!;
      expect(got.fontSize, px(decls['--text-$name']!), reason: name);
      expect(
        got.lineHeight,
        px(decls['--text-$name--line-height']!),
        reason: name,
      );
      final weight = decls['--text-$name--font-weight'];
      expect(
        got.fontWeight,
        weight == null ? null : int.parse(weight),
        reason: name,
      );
      final tracking = decls['--text-$name--letter-spacing'];
      expect(
        got.letterSpacingEm,
        tracking == null ? null : px(tracking),
        reason: name,
      );
    }

    final slide = decls['--ease-slide']!;
    final points = RegExp(r'cubic-bezier\(([^)]*)\)')
        .firstMatch(slide)!
        .group(1)!
        .split(',')
        .map((x) => double.parse(x.trim()))
        .toList();
    final slideCurve = RaftEase.slide;
    expect([slideCurve.a, slideCurve.b, slideCurve.c, slideCurve.d], points);
  });
}
