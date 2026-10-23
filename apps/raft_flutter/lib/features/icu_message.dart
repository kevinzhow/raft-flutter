// Web catalog messages with ICU plural arms (`{count, plural, one {# turn} other
// {# turns}}`). `raftFormat` fills simple `{name}` placeholders only, so the
// Activity overview expands the plural arms here: the catalog key is the English
// ICU message and its zh value the zh-cn one, which is how Web's `formatMessage`
// reads them.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

/// The localized [source] with its `{n, plural, ...}` arms and `{name}`
/// placeholders filled from [values].
String icuText(
  BuildContext context,
  String source,
  Map<String, Object?> values,
) => expandIcuMessage(
  raftText(context, source),
  values,
  oneForm: Localizations.localeOf(context).languageCode != 'zh',
);

/// [oneForm]: the language has a distinct `one` plural (English); zh has only
/// `other`.
String expandIcuMessage(
  String message,
  Map<String, Object?> values, {
  bool oneForm = true,
  num? hash,
}) {
  final out = StringBuffer();
  var i = 0;
  while (i < message.length) {
    final c = message[i];
    if (c != '{') {
      out.write(
        c == '#' && hash != null
            ? (hash == hash.roundToDouble() ? '${hash.toInt()}' : '$hash')
            : c,
      );
      i++;
      continue;
    }
    final end = _close(message, i);
    if (end < 0) {
      out.write(message.substring(i));
      break;
    }
    final inner = message.substring(i + 1, end);
    out.write(_placeholder(inner, values, oneForm, hash));
    i = end + 1;
  }
  return out.toString();
}

/// Index of the `}` matching the `{` at [open], or -1.
int _close(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}' && --depth == 0) return i;
  }
  return -1;
}

String _placeholder(
  String inner,
  Map<String, Object?> values,
  bool oneForm,
  num? hash,
) {
  final parts = RegExp(
    r'^\s*([A-Za-z0-9_]+)\s*(?:,\s*plural\s*,(.*))?$',
    dotAll: true,
  ).firstMatch(inner);
  if (parts == null) return '{$inner}';
  final name = parts[1]!;
  final arms = parts[2];
  final value = values[name];
  if (arms == null) return value == null ? '{$name}' : '$value';
  final n = value is num ? value : num.tryParse('$value') ?? 0;
  final bodies = <String, String>{};
  var i = 0;
  while (i < arms.length) {
    while (i < arms.length && arms[i].trim().isEmpty) {
      i++;
    }
    final brace = arms.indexOf('{', i);
    if (brace < 0) break;
    final selector = arms.substring(i, brace).trim();
    final end = _close(arms, brace);
    if (end < 0) break;
    bodies[selector] = arms.substring(brace + 1, end);
    i = end + 1;
  }
  final body =
      bodies['=${n is int ? n : n.toInt()}'] ??
      (oneForm && n == 1 ? bodies['one'] : null) ??
      bodies['other'] ??
      '';
  return expandIcuMessage(body, values, oneForm: oneForm, hash: n);
}
