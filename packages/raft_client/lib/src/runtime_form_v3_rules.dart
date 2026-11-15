/// Runtime form protocol v3 conditions (contract `Condition`, `Rule`,
/// `ConditionalRequired`): a small JSON Schema subset, no schema engine.
///
/// Mirrors Web `packages/runtime-form/src/v3Rules.ts`. Supported keywords:
/// const, enum, pattern, not, anyOf, allOf, properties. An absent value is
/// evaluated as "". Any other keyword, or a pattern outside the portable
/// subset ([isPortableRuntimeFormV3Pattern]), makes the schema unsupported: the
/// parser then treats the whole form as unavailable (fail closed), because a
/// client must never render a form whose rules it cannot evaluate. const and
/// enum compare structurally (object key order does not count).
///
/// `test/fixtures/runtime_form/v3.conditions.conformance.json` is the shared
/// conformance table.
library;

const _supportedKeywords = {
  'const',
  'enum',
  'pattern',
  'not',
  'anyOf',
  'allOf',
  'properties',
};

bool _isRecord(Object? value) => value is Map;

/// Whether [schema] uses only the supported keywords, with well-formed
/// operands, all the way down.
bool isSupportedRuntimeFormV3Schema(Object? schema) {
  if (schema is! Map) return false;
  for (final entry in schema.entries) {
    final operand = entry.value;
    if (!_supportedKeywords.contains(entry.key)) return false;
    switch (entry.key) {
      case 'enum':
        if (operand is! List) return false;
      case 'pattern':
        if (operand is! String || !isPortableRuntimeFormV3Pattern(operand)) {
          return false;
        }
      case 'not':
        if (!isSupportedRuntimeFormV3Schema(operand)) return false;
      case 'anyOf' || 'allOf':
        if (operand is! List ||
            operand.isEmpty ||
            !operand.every(isSupportedRuntimeFormV3Schema)) {
          return false;
        }
      case 'properties':
        if (operand is! Map ||
            !operand.values.every(isSupportedRuntimeFormV3Schema)) {
          return false;
        }
    }
  }
  return true;
}

/// Characters that must be backslash-escaped to be literal (and the only ones
/// that may be).
const _syntaxCharacters = {
  '^',
  r'$',
  r'\',
  '.',
  '*',
  '+',
  '?',
  '(',
  ')',
  '[',
  ']',
  '{',
  '}',
  '|',
  '/', //
};

/// Whether [pattern] stays inside the portable regex subset that evaluates the
/// same in ECMAScript (`u` flag) and Java/Kotlin: `^`/`$`, literals and
/// backslash-escaped syntax characters, character classes, `.`, quantifiers
/// `* + ? {m} {m,} {m,n}` after an atom, groups `( )` and `|`. Everything else
/// (lookarounds, named or non-capturing groups, backreferences, `\d`/`\p{...}`
/// and other escapes, lazy or possessive quantifiers, nested classes, a bare
/// `]`, `{` or `}`) is rejected. A tiny recognizer, not a full regex parser.
bool isPortableRuntimeFormV3Pattern(String pattern) {
  final chars = pattern.runes.map(String.fromCharCode).toList();
  var i = 0, depth = 0;
  // Whether the previous token can take a quantifier.
  var quantifiable = false;

  String? escaped(bool inClass) {
    final next = i + 1 < chars.length ? chars[i + 1] : null;
    if (next == null ||
        !(_syntaxCharacters.contains(next) || (inClass && next == '-'))) {
      return null;
    }
    i += 2;
    return next;
  }

  ({int code, bool dash})? classAtom() {
    final char = i < chars.length ? chars[i] : null;
    if (char == null || char == '[' || char == ']') return null;
    if (char == r'\') {
      final literal = escaped(true);
      return literal == null ? null : (code: literal.runes.first, dash: false);
    }
    if (char == '&' && i + 1 < chars.length && chars[i + 1] == '&') {
      return null;
    }
    i += 1;
    return (code: char.runes.first, dash: char == '-');
  }

  bool characterClass() {
    i += 1;
    if (i < chars.length && chars[i] == '^') i += 1;
    var first = true;
    while (true) {
      if (i >= chars.length) return false;
      if (chars[i] == ']') break;
      final start = classAtom();
      if (start == null) return false;
      final more = i < chars.length ? chars[i] : null;
      if (start.dash) {
        // A literal "-" only first or last, never a range endpoint.
        if (!first && more != ']') return false;
      } else if (more == '-' &&
          (i + 1 < chars.length ? chars[i + 1] : null) != ']') {
        i += 1;
        final end = classAtom();
        if (end == null || end.dash || end.code < start.code) return false;
      }
      first = false;
    }
    if (first) return false; // [] / [^]
    i += 1;
    return true;
  }

  bool braceQuantifier() {
    final rest = chars.sublist(i).join();
    final match = RegExp(r'^\{(\d+)(,(\d*))?\}').firstMatch(rest);
    if (match == null) return false;
    final upper = match.group(3);
    if (upper != null &&
        upper.isNotEmpty &&
        int.parse(upper) < int.parse(match.group(1)!)) {
      return false;
    }
    i += match.group(0)!.length;
    return true;
  }

  while (i < chars.length) {
    final char = chars[i];
    switch (char) {
      case '^' || r'$' || '|':
        i += 1;
        quantifiable = false;
      case '(':
        if (i + 1 < chars.length && chars[i + 1] == '?') return false;
        i += 1;
        depth += 1;
        quantifiable = false;
      case ')':
        if (depth == 0) return false;
        i += 1;
        depth -= 1;
        quantifiable = true;
      case '*' || '+' || '?' || '{':
        if (!quantifiable) return false;
        if (char == '{') {
          if (!braceQuantifier()) return false;
        } else {
          i += 1;
        }
        // No lazy (*?), possessive (*+) or stacked quantifiers.
        quantifiable = false;
      case '[':
        if (!characterClass()) return false;
        quantifiable = true;
      case ']' || '}':
        return false;
      case r'\':
        if (escaped(false) == null) return false;
        quantifiable = true;
      default:
        i += 1;
        quantifiable = true;
    }
  }
  if (depth != 0) return false;
  try {
    RegExp(pattern, unicode: true);
  } on FormatException {
    return false;
  }
  return true;
}

/// Structural JSON equality: object key order does not count, array order
/// does.
bool _sameJson(Object? a, Object? b) {
  if (a is List || b is List) {
    return a is List &&
        b is List &&
        a.length == b.length &&
        [for (var i = 0; i < a.length; i++) _sameJson(a[i], b[i])]
            .every((x) => x);
  }
  if (a is Map || b is Map) {
    if (a is! Map || b is! Map || a.length != b.length) return false;
    return a.keys.every((k) => b.containsKey(k) && _sameJson(a[k], b[k]));
  }
  return a == b;
}

/// Evaluates a supported [schema] against [value] (absent = "").
bool evaluateRuntimeFormV3Schema(Map<dynamic, dynamic> schema, Object? value) {
  final subject = value ?? '';
  for (final entry in schema.entries) {
    final operand = entry.value;
    switch (entry.key) {
      case 'const':
        if (!_sameJson(subject, operand)) return false;
      case 'enum':
        if (!(operand as List).any((c) => _sameJson(subject, c))) return false;
      case 'pattern':
        if (subject is! String ||
            !RegExp(operand as String, unicode: true).hasMatch(subject)) {
          return false;
        }
      case 'not':
        if (evaluateRuntimeFormV3Schema(operand as Map, subject)) return false;
      case 'anyOf':
        if (!(operand as List).any(
          (item) => evaluateRuntimeFormV3Schema(item as Map, subject),
        )) {
          return false;
        }
      case 'allOf':
        if (!(operand as List).every(
          (item) => evaluateRuntimeFormV3Schema(item as Map, subject),
        )) {
          return false;
        }
      case 'properties':
        // A non-object subject has no properties: each one is absent ("").
        final record = _isRecord(subject) ? subject as Map : const {};
        for (final sub in (operand as Map).entries) {
          if (!evaluateRuntimeFormV3Schema(sub.value as Map, record[sub.key])) {
            return false;
          }
        }
      default:
        return false;
    }
  }
  return true;
}

/// The field key a scope names: `#` is the whole values object (key null),
/// `#/properties/<key>` is one field. Anything else is unsupported (null
/// record).
({String? key})? runtimeFormV3ScopeKey(Object? scope) {
  if (scope == '#') return (key: null);
  const prefix = '#/properties/';
  if (scope is! String || !scope.startsWith(prefix)) return null;
  final key = scope.substring(prefix.length);
  return key.isEmpty || key.contains('/') ? null : (key: key);
}

/// A parsed rule condition: [key] null means the whole values object.
class RuntimeFormV3Condition {
  const RuntimeFormV3Condition(this.key, this.schema);
  final String? key;
  final Map<String, dynamic> schema;

  bool evaluate(Map<String, dynamic> values) =>
      evaluateRuntimeFormV3Schema(schema, key == null ? values : values[key]);
}
