import 'dart:math' as math;

import 'search_pinyin_data.dart';

/// The source composerSuggestionSearch rank order, also used by searchEntities.
/// Field priority is part of a score; result insertion order breaks exact ties.
class SearchRankEntry<T> {
  const SearchRankEntry(this.value, this.fields);
  final T value;
  final List<({String text, int priority})> fields;
}

typedef _Score = ({int rank, int priority, int position, int gap});
final _token = RegExp(r'^\p{L}$|^\p{N}$', unicode: true);
final _ascii = RegExp(r'^[a-z0-9]$', caseSensitive: false);

List<String> _tokens(String text) {
  final result = <String>[];
  var current = '';
  for (final code in text.toLowerCase().runes) {
    final char = String.fromCharCode(code);
    if (_token.hasMatch(char) || code >= 0x4e00 && code <= 0x9fff) {
      current += char;
    } else if (current.isNotEmpty) {
      result.add(current);
      current = '';
    }
  }
  if (current.isNotEmpty) result.add(current);
  return result;
}

String _full(String text) => text.runes.map((code) {
  final char = String.fromCharCode(code);
  return searchPinyin(char) ??
      (_ascii.hasMatch(char) ? char.toLowerCase() : '');
}).join();

String _initials(String text) {
  var result = '';
  var previousToken = false;
  for (final code in text.runes) {
    final char = String.fromCharCode(code), pinyin = searchPinyin(char);
    if (pinyin != null) {
      result += pinyin[0];
      previousToken = false;
    } else if (_ascii.hasMatch(char)) {
      if (!previousToken) result += char.toLowerCase();
      previousToken = true;
    } else {
      previousToken = false;
    }
  }
  return result;
}

int _compare(_Score a, _Score b) => a.rank != b.rank
    ? a.rank.compareTo(b.rank)
    : a.priority != b.priority
    ? a.priority.compareTo(b.priority)
    : a.position != b.position
    ? a.position.compareTo(b.position)
    : a.gap.compareTo(b.gap);

int? _position(Iterable<int> positions) {
  final accepted = positions.where((n) => n >= 0).toList();
  return accepted.isEmpty ? null : accepted.reduce(math.min);
}

({int position, int gap})? _subsequence(String candidate, String query) {
  var from = 0, first = -1, last = -1;
  for (final code in query.runes) {
    final position = candidate.indexOf(String.fromCharCode(code), from);
    if (position < 0) return null;
    if (first < 0) first = position;
    last = position;
    from = position + 1;
  }
  final gap = last - first + 1 - query.length;
  return gap > math.max(2, query.length * 2)
      ? null
      : (position: first, gap: gap);
}

List<T> rankSearchEntries<T>(String query, List<SearchRankEntry<T>> entries) {
  final clean = query.trim().replaceFirst(RegExp(r'^[@#]'), '');
  if (clean.isEmpty) return entries.map((e) => e.value).toList();
  final queryTokens = _tokens(clean), compact = _tokens(clean).join();
  final variants = {compact, _full(clean)}..remove('');
  _Score? score(({String text, int priority}) field) {
    final tokens = _tokens(field.text), normalized = _tokens(field.text).join();
    final full = _full(field.text), initials = _initials(field.text);
    _Score result(int rank, int position, [int gap = 0]) =>
        (rank: rank, priority: field.priority, position: position, gap: gap);
    if (normalized.isEmpty && full.isEmpty && initials.isEmpty) return null;
    if (variants.any((v) => normalized == v || full == v)) return result(0, 0);
    final prefixes = variants.where(normalized.startsWith);
    if (prefixes.isNotEmpty) {
      return result(1, 0, normalized.length - prefixes.first.length);
    }
    if (queryTokens.isNotEmpty && tokens.isNotEmpty) {
      final start = tokens.indexWhere((t) => t.startsWith(queryTokens.first));
      if (start >= 0) {
        var cursor = start;
        var accepted = true;
        for (final q in queryTokens) {
          while (cursor < tokens.length && !tokens[cursor].startsWith(q)) {
            cursor++;
          }
          if (cursor == tokens.length) {
            accepted = false;
            break;
          }
          cursor++;
        }
        if (accepted) {
          return result(2, start, cursor - start - queryTokens.length);
        }
      }
    }
    final substring = _position(variants.map(normalized.indexOf));
    if (substring != null) return result(3, substring);
    if (field.priority <= 1 && compact.length >= 2) {
      final pinyin = _position(variants.map(full.indexOf));
      if (pinyin != null) return result(4, pinyin);
      final initial = initials.indexOf(compact);
      if (initial >= 0) return result(5, initial);
      if (compact.length >= 3) {
        final fuzzy =
            [
              _subsequence(normalized, compact),
              _subsequence(full, compact),
            ].whereType<({int position, int gap})>().toList()..sort(
              (a, b) => a.position != b.position
                  ? a.position.compareTo(b.position)
                  : a.gap.compareTo(b.gap),
            );
        if (fuzzy.isNotEmpty) {
          return result(6, fuzzy.first.position, fuzzy.first.gap);
        }
      }
    }
    final legacy = field.text.toLowerCase().indexOf(clean.toLowerCase());
    return legacy < 0 ? null : result(7, legacy);
  }

  final ranked = <({T value, int index, _Score score})>[];
  for (var i = 0; i < entries.length; i++) {
    final scores = entries[i].fields.map(score).whereType<_Score>().toList()
      ..sort(_compare);
    if (scores.isNotEmpty) {
      ranked.add((value: entries[i].value, index: i, score: scores.first));
    }
  }
  ranked.sort((a, b) {
    final compared = _compare(a.score, b.score);
    return compared != 0 ? compared : a.index.compareTo(b.index);
  });
  return ranked.take(30).map((e) => e.value).toList();
}
