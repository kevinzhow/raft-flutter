// Web catalog messages with ICU plural arms (`{count, plural, one {# turn} other
// {# turns}}`). `raftFormat` fills simple `{name}` placeholders only, so the
// Activity overview expands the plural arms here: the catalog key is the English
// ICU message and its zh value the zh-cn one, which is how Web's `formatMessage`
// reads them.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_number_format.dart';

/// The localized [source] with its `{n, plural, ...}` arms and `{name}`
/// placeholders filled from [values].
String icuText(
  BuildContext context,
  String source,
  Map<String, Object?> values,
) {
  final locale = Localizations.localeOf(context);
  final language = raftDisplayLanguageId(locale);
  final message = raftText(context, source);
  return expandIcuMessage(
    message,
    values,
    oneForm: language != 'zh-cn',
    locale: language == 'en' || language == 'zh-cn' || message == source
        ? null
        : locale.toLanguageTag(),
  );
}

/// [oneForm]: the language has a distinct `one` plural (English); zh has only
/// `other`.
String expandIcuMessage(
  String message,
  Map<String, Object?> values, {
  bool oneForm = true,
  String? locale,
  num? hash,
}) {
  final out = StringBuffer();
  var i = 0;
  while (i < message.length) {
    final c = message[i];
    if (c != '{') {
      out.write(c == '#' && hash != null ? _formatNumber(hash, locale) : c);
      i++;
      continue;
    }
    final end = _close(message, i);
    if (end < 0) {
      out.write(message.substring(i));
      break;
    }
    final inner = message.substring(i + 1, end);
    out.write(_placeholder(inner, values, oneForm, locale));
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

String _formatNumber(num value, String? locale) => locale != null
    ? sourceDecimal(value, locale)
    : value == value.roundToDouble()
    ? '${value.toInt()}'
    : '$value';

String _placeholder(
  String inner,
  Map<String, Object?> values,
  bool oneForm,
  String? locale,
) {
  final parts = RegExp(
    r'^\s*([A-Za-z0-9_]+)\s*(?:,\s*(?:plural\s*,(.*)|number\s*))?$',
    dotAll: true,
  ).firstMatch(inner);
  if (parts == null) return '{$inner}';
  final name = parts[1]!;
  final arms = parts[2];
  final value = values[name];
  if (arms == null) {
    if (value == null) return '{$name}';
    return value is num && inner.contains(',')
        ? _formatNumber(value, locale)
        : '$value';
  }
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
  final other = bodies['other'] ?? '';
  final explicit = n == n.toInt() ? bodies['=${n.toInt()}'] : null;
  final body =
      explicit ??
      (locale == null
          ? (oneForm && n == 1 ? bodies['one'] : null) ?? other
          : Intl.pluralLogic<String>(
              n,
              locale: locale,
              zero: bodies['zero'],
              one: bodies['one'],
              two: bodies['two'],
              few: bodies['few'],
              many: bodies['many'],
              other: other,
              useExplicitNumberCases: false,
            ));
  return expandIcuMessage(
    body,
    values,
    oneForm: oneForm,
    locale: locale,
    hash: n,
  );
}

/// Web `message.inlineThreadReplies.replyCount` (en.ts:3583): the reply count
/// an inline thread, a thread outline and a task conversation all show.
///
/// It is one ICU message, not a pair of English singular/plural strings,
/// because a two-way branch cannot express Russian, which needs `one`, `few`
/// and `many` (1 ответ, 2 ответа, 5 ответов). The `#` takes the locale's digit
/// grouping with it.
String replyCountText(BuildContext context, int count) => icuText(
  context,
  '{count, plural, one {# reply} other {# replies}}',
  {'count': count},
);
