// The Chinese catalog is split into l10n/zh_<feature>.dart files merged by the
// generated l10n/zh_index.g.dart (tool/gen_l10n_index.py). A const map spread
// silently lets a later catalog win a duplicate key, so this test is the
// duplicate-key detector: every key lives in exactly one catalog.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart'
    show raftChinese, raftChineseLateAdditions, raftFormat;
import 'package:raft_ui/src/l10n/zh_index.g.dart'
    show zhCatalogAll, zhCatalogParts;

/// Chinese values that use a placeholder their key does not have, because the
/// call site passes that value too (so the user sees the number, not `{count}`).
/// Any other difference between the placeholders of a key and its value is a
/// bug: the user would see a literal `{name}` or lose the value.
const _extraValuePlaceholders = <String, Set<String>>{
  // apps/raft_flutter/lib/features/billing_view.dart `usingSeats` passes
  // {'count': people, 'seats': ...} to every singular/plural variant.
  '1 human using {seats} seat': {'count'},
  '1 human using {seats} seats': {'count'},
  '1 agent using {seats} seat': {'count'},
  '1 agent using {seats} seats': {'count'},
  // apps/raft_flutter/lib/features/system_notification_copy.dart passes
  // {'count': ...} (and 'names') to machine-offline / machine-disk-low titles.
  '{names} is offline': {'count'},
  '{names} are offline': {'count'},
  'A computer you added is low on disk space': {'count'},
};

/// The argument names of an ICU message: `{name}` and the `name` of
/// `{name, plural|select|selectordinal, ...}`, including arguments nested in
/// plural/select arms. Arm selectors and arm text (`one {# step}`, `{once}`)
/// are not arguments.
Set<String> _icuArguments(String message) =>
    (_IcuArguments(message)..text(0)).out;

class _IcuArguments {
  _IcuArguments(this.message);
  final String message;
  final out = <String>{};
  var i = 0;
  static final _ident = RegExp(r'^\s*([a-zA-Z0-9_]+)\s*([,}])');

  /// Message text up to an unmatched `}` (or the end); returns its index.
  int text(int from) {
    i = from;
    while (i < message.length) {
      final c = message[i];
      if (c == '}') return i;
      if (c == '{') {
        argument();
      } else {
        i++;
      }
    }
    return i;
  }

  /// A `{...}` that is not an argument (an arm body or `{# step}`): its text
  /// may still hold arguments.
  void block() => i = text(i + 1) + 1;

  void argument() {
    final m = _ident.firstMatch(message.substring(i + 1));
    if (m == null) return block();
    out.add(m[1]!);
    i += 1 + m.end;
    if (m[2] == '}') return;
    // `{name, type}` or `{name, type, selector {arm} ...}`.
    final comma = message.indexOf(',', i);
    final close = message.indexOf('}', i);
    if (comma < 0 || (close >= 0 && close < comma)) {
      i = close < 0 ? message.length : close + 1;
      return;
    }
    i = comma + 1;
    while (i < message.length) {
      final c = message[i];
      if (c == '}') {
        i++;
        return;
      }
      if (c == '{') {
        block();
      } else {
        i++;
      }
    }
  }
}

void main() {
  test('every catalog file is merged and no key is declared twice', () {
    final owner = <String, String>{};
    final duplicates = <String>[];
    void add(String catalog, Map<String, String> entries) {
      for (final key in entries.keys) {
        final previous = owner[key];
        if (previous != null) {
          duplicates.add('"$key" is in both $previous and $catalog');
        }
        owner[key] = catalog;
      }
    }

    zhCatalogParts.forEach(add);
    add('raftChineseLateAdditions', raftChineseLateAdditions);
    expect(
      duplicates,
      isEmpty,
      reason:
          'A key must live in one l10n/zh_*.dart catalog only:\n'
          '${duplicates.join('\n')}',
    );
    expect(raftChinese.length, owner.length);
    expect(
      zhCatalogAll.length,
      zhCatalogParts.values.fold<int>(0, (n, m) => n + m.length),
    );
  });

  test('the generated index lists every zh_*.dart catalog file', () {
    // check-project runs every test from apps/raft_flutter; package tests run from raft_ui.
    final dir = [
      Directory('lib/src/l10n'),
      Directory('../../packages/raft_ui/lib/src/l10n'),
    ].firstWhere((d) => d.existsSync());
    final files =
        dir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.startsWith('zh_') && !n.endsWith('.g.dart'))
            .toList()
          ..sort();
    final index = File('${dir.path}/zh_index.g.dart').readAsStringSync();
    for (final file in files) {
      expect(index, contains("import '$file' show"), reason: file);
    }
    expect(zhCatalogParts.length, greaterThanOrEqualTo(files.length));
  });

  test('a Chinese value uses the placeholders of its key', () {
    Set<String> names(String s) => _icuArguments(s);
    final broken = <String>[];
    final used = <String>{};
    for (final e in raftChinese.entries) {
      final key = names(e.key), value = names(e.value);
      final extra = _extraValuePlaceholders[e.key];
      if (extra != null) used.add(e.key);
      final allowed = {...key, ...?extra};
      if (!value.containsAll(key) || !allowed.containsAll(value)) {
        broken.add(
          '"${e.key}" -> "${e.value}": key has $key, value has $value'
          '${extra == null ? '' : ' (allowed extra $extra)'}',
        );
      }
    }
    expect(
      broken,
      isEmpty,
      reason:
          'Use the key\'s placeholder names in the Chinese value (or, only if '
          'the call site passes the extra value, list it in '
          '_extraValuePlaceholders with the call site):\n${broken.join('\n')}',
    );
    expect(
      _extraValuePlaceholders.keys.toSet().difference(used),
      isEmpty,
      reason:
          'stale _extraValuePlaceholders entry (key no longer in the catalog)',
    );
    // An allowlisted entry must really differ, otherwise drop it from the list.
    final unneeded = [
      for (final k in used)
        if (names(raftChinese[k]!).difference(names(k)).isEmpty) k,
    ];
    expect(unneeded, isEmpty, reason: 'no longer needed: $unneeded');
  });

  testWidgets(
    'zh "Committed by {name}" leaves the committer slot for the card',
    (tester) async {
      late String text;
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('zh'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              // ActionCard splits this on U+FFFC and styles the name itself.
              text = raftFormat(context, 'Committed by {name}', {
                'name': '\uFFFC',
              });
              return const SizedBox();
            },
          ),
        ),
      );
      expect(text, '由 \uFFFC 提交');
      expect(text.split('\uFFFC'), ['由 ', ' 提交']);
    },
  );
}
