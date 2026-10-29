import 'dart:ui' show Color, Offset;

import 'color_value.dart';

/// One layer of a box shadow, in CSS terms: `offset`, `blur`, `spread`, a
/// colour, and whether it is drawn inside the box.
///
/// A pack writes shadows as CSS text (`0 1px 0 0 #1411110a, inset 0 0 0 1px
/// #ffffff14`), because that is the one form both designers and CSS tooling
/// already read. `none` means "this role paints nothing".
class RaftShadowSpec {
  const RaftShadowSpec({
    required this.offset,
    required this.blur,
    required this.spread,
    required this.color,
    this.inset = false,
  });

  final Offset offset;
  final double blur;
  final double spread;
  final Color color;
  final bool inset;

  @override
  String toString() =>
      '${inset ? 'inset ' : ''}${_px(offset.dx)} ${_px(offset.dy)} '
      '${_px(blur)} ${_px(spread)} ${color.toARGB32().toRadixString(16)}';

  /// CSS-style length: whole numbers lose the fraction and the trailing zero.
  static String _px(double value) =>
      '${value == value.roundToDouble() ? value.round() : value}px';

  @override
  bool operator ==(Object other) =>
      other is RaftShadowSpec &&
      other.offset == offset &&
      other.blur == blur &&
      other.spread == spread &&
      other.color == color &&
      other.inset == inset;

  @override
  int get hashCode => Object.hash(offset, blur, spread, color, inset);
}

/// Parse the shadow syntax a theme pack uses.
///
/// Accepted: `none`, or one or more comma-separated layers, each
/// `[inset] <x>px <y>px [blur] [spread] <colour>`. Lengths may omit `px`
/// (`0 1px`), because CSS does.
List<RaftShadowSpec> parseShadowList(Object? value, {required String where}) {
  if (value == null) return const [];
  if (value is! String) {
    throw FormatException('$where: a shadow is CSS text or "none"', value);
  }
  final text = value.trim();
  if (text.isEmpty || text.toLowerCase() == 'none') return const [];
  return [
    for (final layer in _splitLayers(text)) _parseLayer(layer, where: where),
  ];
}

/// Split on commas that are not inside `rgb()`/`oklch()`/`$value` braces.
List<String> _splitLayers(String text) {
  final out = <String>[];
  var depth = 0;
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (char == '(') depth++;
    if (char == ')') depth--;
    if (char == ',' && depth == 0) {
      out.add(buffer.toString().trim());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  final last = buffer.toString().trim();
  if (last.isNotEmpty) out.add(last);
  return out;
}

RaftShadowSpec _parseLayer(String layer, {required String where}) {
  var text = layer.trim();
  var inset = false;
  if (text.toLowerCase().startsWith('inset ')) {
    inset = true;
    text = text.substring(6).trim();
  }
  // The colour is the first token that starts like a colour; everything before
  // it is a length.
  final colourStart = RegExp(r'(#|rgb\(|rgba\(|oklch\(|hsl\()')
      .firstMatch(text);
  if (colourStart == null) {
    throw FormatException(
      '$where: shadow layer "${layer.trim()}" has no colour',
      layer,
    );
  }
  final lengths = text.substring(0, colourStart.start).trim();
  final colourText = text.substring(colourStart.start).trim();
  final color = parseThemeColor(colourText, where: '$where shadow colour');
  final numbers = RegExp(r'[-+]?[0-9]*\.?[0-9]+')
      .allMatches(lengths)
      .map((m) => double.parse(m.group(0)!))
      .toList();
  if (numbers.length < 2) {
    throw FormatException('$where: shadow layer needs x and y offsets', layer);
  }
  return RaftShadowSpec(
    offset: Offset(numbers[0], numbers[1]),
    blur: numbers.length > 2 ? numbers[2] : 0,
    spread: numbers.length > 3 ? numbers[3] : 0,
    color: color,
    inset: inset,
  );
}
