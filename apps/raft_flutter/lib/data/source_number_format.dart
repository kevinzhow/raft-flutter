import 'package:intl/intl.dart';

/// `Intl.NumberFormat` as Web's `formatMessage` applies it to an ICU `number`
/// argument.
///
/// Spanish is the one language that differs from CLDR's plain decimal pattern
/// here: it does not group a four-digit number, so 1000 stays `1000` while
/// 10000 is `10.000`. Match on the primary subtag, not the whole tag, so a
/// regional tag (`es-MX`, `es_ES`) behaves the same as the shipped `es` — a
/// caller that formats with a device locale rather than a display locale would
/// otherwise silently group where Web does not.
String sourceDecimal(num value, String? locale) {
  final format = NumberFormat.decimalPattern(locale);
  // Split on both separators without a RegExp: this runs per formatted
  // number, and a literal pattern here is a hot-path allocation
  // (perf.regexp_in_hot_method).
  final language = locale?.split('-').first.split('_').first.toLowerCase();
  if (language == 'es' && value.abs() < 10000) {
    format.turnOffGrouping();
  }
  return format.format(value);
}
