import 'dart:math' as math;
import 'dart:ui' show Color;

/// A theme file writes colours in one of four ways; all four are read into a
/// [Color] here so a pack never carries a string the app has to interpret.
///
/// * `#rgb`, `#rrggbb`, `#rrggbbaa` — sRGB.
/// * `rgb(12 34 56)`, `rgba(12, 34, 56, 0.5)`, also with `/ alpha`.
/// * `oklch(0.68 0.16 91.9)`, `oklch(0.68 0.16 91.9 / 0.5)`.
/// * The Design Tokens Community Group form an official `tokens.json` uses:
///   `{"$value": {"colorSpace": "oklch", "components": [l, c, h]}}`
///   (a `$value` string such as `"#ffd440"` or an `{palette.x.y}` reference is
///   also accepted; references are resolved by the importer, not here).
///
/// Anything else is a [FormatException] naming the offending value — a typo in
/// a theme must fail loudly, not fall back to a default.
Color parseThemeColor(Object? value, {required String where}) {
  if (value is String) return _parseColorString(value, where: where);
  if (value is Map) {
    final inner = value[r'$value'];
    if (inner is Map) {
      final space = inner['colorSpace'];
      final components = inner['components'];
      final alpha = inner['alpha'];
      if (components is List && components.length >= 3) {
        final values = components.map((c) => _toDouble(c, where)).toList();
        return _fromComponents(
          '$space',
          values,
          _toDouble(alpha ?? 1, where),
          where,
        );
      }
    }
    if (inner is String) return _parseColorString(inner, where: where);
  }
  throw FormatException('$where: not a colour', value);
}

Color _parseColorString(String text, {required String where}) {
  final value = text.trim().toLowerCase();
  if (value.startsWith('#')) return _parseHex(value, where: where);
  final call = RegExp(r'^([a-z]+)\((.*)\)$').firstMatch(value);
  if (call == null) throw FormatException('$where: not a colour', text);
  final name = call.group(1)!;
  final body = call.group(2)!.trim();
  final parts = body.split('/');
  final numbers = parts[0]
      .trim()
      .split(RegExp(r'[\s,]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  final alpha = parts.length > 1
      ? _parseAlpha(parts[1].trim(), where)
      : (numbers.length > 3 ? _parseAlpha(numbers.removeLast(), where) : 1.0);
  switch (name) {
    case 'rgb':
    case 'rgba':
      if (numbers.length < 3)
        throw FormatException('$where: rgb() needs 3 components', text);
      // Built from floats, so a fractional alpha survives exactly: a theme must
      // not lose precision that the design tokens carry.
      return Color.from(
        alpha: alpha.clamp(0, 1),
        red: _parseUnit(numbers[0], where),
        green: _parseUnit(numbers[1], where),
        blue: _parseUnit(numbers[2], where),
      );
    case 'oklch':
      if (numbers.length < 3)
        throw FormatException('$where: oklch() needs 3 components', text);
      return _fromComponents(
        'oklch',
        numbers.map((n) => _toDouble(n, where)).toList(),
        alpha,
        where,
      );
    default:
      throw FormatException(
        '$where: unsupported colour function "$name"',
        text,
      );
  }
}

Color _parseHex(String value, {required String where}) {
  final digits = value.substring(1);
  String expand(String d) => d.length == 1 ? '$d$d' : d;
  switch (digits.length) {
    case 3:
    case 4:
      final r = expand(digits[0]), g = expand(digits[1]), b = expand(digits[2]);
      final a = digits.length == 4 ? expand(digits[3]) : 'ff';
      return _fromHex('$r$g$b', a);
    case 6:
      return _fromHex(digits, 'ff');
    case 8:
      // CSS order is #rrggbbaa.
      return _fromHex(digits.substring(0, 6), digits.substring(6));
    default:
      throw FormatException(
        '$where: hex colours are #rgb, #rrggbb or #rrggbbaa',
        value,
      );
  }
}

/// A CSS sRGB channel as 0…1, keeping 8-bit inputs exact (20 -> 20/255).
double _parseUnit(String text, String where) {
  if (text.endsWith('%')) {
    return (_toDouble(text.substring(0, text.length - 1), where) / 100).clamp(
      0,
      1,
    );
  }
  return (_toDouble(text, where) / 255).clamp(0, 1);
}

double _parseAlpha(String text, String where) {
  if (text.endsWith('%'))
    return _toDouble(text.substring(0, text.length - 1), where) / 100;
  return _toDouble(text, where);
}

double _toDouble(Object? value, String where) {
  if (value is num) return value.toDouble();
  if (value is String) {
    if (value.endsWith('%'))
      return _toDouble(value.substring(0, value.length - 1), where) / 100;
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('$where: expected a number', value);
}

Color _fromComponents(
  String space,
  List<double> components,
  double alpha,
  String where,
) {
  switch (space) {
    case 'oklch':
      final l = _unit(components[0], where),
          c = components[1],
          h = components[2];
      final rgb = _oklchToSrgb(l, c, h);
      return Color.from(
        alpha: alpha.clamp(0, 1),
        red: rgb[0],
        green: rgb[1],
        blue: rgb[2],
      );
    case 'srgb':
      return Color.from(
        alpha: alpha.clamp(0, 1),
        red: _unit(components[0], where),
        green: _unit(components[1], where),
        blue: _unit(components[2], where),
      );
    default:
      throw FormatException(
        '$where: unsupported colour space "$space"',
        components,
      );
  }
}

/// DTCG writes sRGB components as 0…1 and oklch lightness as 0…1, but authors
/// (and CSS) write 0…100 for lightness; accept both.
double _unit(double value, String where) => value > 1 ? value / 100 : value;

/// `#rrggbb` + `#aa` digits as a colour with an exact 8-bit channel and alpha.
Color _fromHex(String rgb, String alpha) {
  final red = int.parse(rgb.substring(0, 2), radix: 16) / 255;
  final green = int.parse(rgb.substring(2, 4), radix: 16) / 255;
  final blue = int.parse(rgb.substring(4, 6), radix: 16) / 255;
  return Color.from(
    alpha: int.parse(alpha, radix: 16) / 255,
    red: red,
    green: green,
    blue: blue,
  );
}

/// OKLCH -> linear sRGB -> sRGB, the CSS Color 4 matrices.
List<double> _oklchToSrgb(double lightness, double chroma, double hueDegrees) {
  final h = hueDegrees * math.pi / 180;
  final a = chroma * math.cos(h);
  final b = chroma * math.sin(h);
  final lPrime = lightness + 0.3963377774 * a + 0.2158037573 * b;
  final mPrime = lightness - 0.1055613458 * a - 0.0638541728 * b;
  final sPrime = lightness - 0.0894841775 * a - 1.2914855480 * b;
  final l = lPrime * lPrime * lPrime;
  final m = mPrime * mPrime * mPrime;
  final s = sPrime * sPrime * sPrime;
  final linear = <double>[
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  ];
  return [for (final channel in linear) _gamma(channel)];
}

double _gamma(double linear) {
  final value = linear.clamp(0.0, 1.0);
  return value <= 0.0031308
      ? 12.92 * value
      : 1.055 * math.pow(value, 1 / 2.4) - 0.055;
}
