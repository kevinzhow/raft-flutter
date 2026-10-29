import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/navigation_registry.dart';

/// State-parity guard.
///
/// `docs/state-parity.json` lists, for every screen and panel, its loading /
/// empty / error / partial states: whether Web renders a distinct one, whether
/// Flutter does, and which parity case compares it (or why none is needed).
/// Parity cases mostly cover the populated default state, and several
/// loading / empty / error cases were false passes (the React capture did not
/// show the state, or only the copy differed); this file makes an unlisted
/// state a test failure instead of a surprise. The schema is documented in the
/// `_doc` field of the JSON.
///
/// Checks (all offline, no build artifacts, no Python, a few hundred ms):
///  (a) every state entry is well formed: required fields, enum values,
///      `covered` / `fixing` need a parityCase, `intentional` / `na` need a
///      justification, `gap` needs justification + size S|M|L; screen ids are
///      unique and no (screen, state, variant) repeats;
///  (b) every parityCase of a `covered` entry resolves to a known case. The case
///      manifest (build/parity-ext/cases.json) is generated at run time and
///      git-ignored, and case ids are f-string templates in
///      tool/parity-ext/build-*.py, so ids cannot be enumerated statically.
///      Resolution is therefore a typo guard over committed sources: the id
///      (theme suffix dropped) is split on '.', and every literal chunk of
///      every segment (a '*' splits a segment into chunks) must occur, bounded
///      by non-identifier characters, in the concatenated text of
///      tool/parity-ext/build-*.py and apps/raft_flutter/test/parity/cases/**/*.dart
///      (official ids are literal keys in the Flutter case files), and the
///      first two segments must occur together as `a.b`. `fixing` entries
///      (ids that do not exist yet) only need that two-segment family to
///      resolve; flip them to `covered` when the cases land and the full check
///      applies. For an exact check set RAFT_PARITY_MANIFEST to a generated
///      cases.json (and RAFT_WEB_SOURCE to the raft-source checkout for the
///      official ids): then each `covered` pattern must match at least one real id;
///  (c) the registry is complete: every NavigationRegistry section id and
///      settings tab id is mapped in `navigationCoverage` to existing screen ids
///      (or a justification string), so a new section or settings tab fails here
///      until its states are listed;
///  (d) every screen's `flutterEntry` file exists.
///
/// To add a screen or state: edit docs/state-parity.json (and the `status`),
/// nothing else.
const _states = {'loading', 'empty', 'error', 'partial'};
const _webValues = {'yes', 'no'};
const _flutterValues = {'yes', 'partial', 'missing'};
const _statuses = {'covered', 'gap', 'intentional', 'na', 'fixing'};
const _sizes = {'S', 'M', 'L'};
const _gapKinds = {'case-missing', 'impl-diff', 'invalid-case'};
const _validities = {'react-checked', 'invalid', 'unchecked'};
const _themes = {'brutal', 'elegant', 'elegant-dark', 'elegant-light'};

Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/packages/raft_ui').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('repository root not found');
    dir = parent;
  }
  return dir;
}

String _s(Map<String, dynamic> e, String key) => (e[key] as String?) ?? '';

List<String> _cases(Map<String, dynamic> state) => [
  for (final c in (state['parityCase'] as List<dynamic>? ?? const []))
    if (c is String) c,
];

String _readCorpus(Directory root) {
  final buffer = StringBuffer();
  final ext = Directory('${root.path}/tool/parity-ext');
  for (final f in ext.listSync()) {
    if (f is File) {
      final name = f.uri.pathSegments.last;
      if (name.startsWith('build-') && name.endsWith('.py')) {
        buffer.writeln(f.readAsStringSync());
      }
    }
  }
  final cases = Directory('${root.path}/apps/raft_flutter/test/parity/cases');
  for (final f in cases.listSync(recursive: true)) {
    if (f is File && f.path.endsWith('.dart')) {
      buffer.writeln(f.readAsStringSync());
    }
  }
  return buffer.toString();
}

List<String> _segments(String pattern) {
  final parts = pattern.split('.');
  if (parts.length > 2 && _themes.contains(parts.last)) parts.removeLast();
  return parts;
}

bool _chunkPresent(String corpus, String chunk, Map<String, bool> memo) =>
    memo.putIfAbsent(chunk, () {
      final re = RegExp(
        '(^|[^A-Za-z0-9_-])${RegExp.escape(chunk)}([^A-Za-z0-9_-]|\$)',
      );
      return re.hasMatch(corpus);
    });

/// Null when [pattern] resolves, otherwise the reason.
String? _resolve(
  String pattern,
  String corpus,
  Map<String, bool> memo, {
  required bool familyOnly,
}) {
  final parts = _segments(pattern);
  if (parts.length < 2) return 'too short';
  if (!corpus.contains('${parts[0]}.${parts[1]}')) {
    return 'family "${parts[0]}.${parts[1]}" not found in the case sources';
  }
  if (familyOnly) return null;
  for (final part in parts) {
    for (final chunk in part.split('*')) {
      if (chunk.isEmpty) continue;
      if (!_chunkPresent(corpus, chunk, memo)) {
        return 'segment "$chunk" not found in the case sources';
      }
    }
  }
  return null;
}

RegExp _glob(String pattern) {
  final parts = _segments(pattern);
  final body = parts
      .map((p) => p.split('*').map(RegExp.escape).join('.*'))
      .join(r'\.');
  return RegExp('^$body\$');
}

void main() {
  final root = _repoRoot();
  final file = File('${root.path}/docs/state-parity.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final screens = [
    for (final s in decoded['screens'] as List<dynamic>)
      Map<String, dynamic>.from(s as Map),
  ];

  test(
    'design-system coverage registers ownership without inventing passes',
    () {
      final coverage = decoded['designSystemCoverage'] as Map<String, dynamic>;
      expect(coverage['schemaVersion'], 1);
      expect(coverage['canonicalRegistry'], 'tool/ds-audit-families.json');
      final declarations = coverage['declarations'] as Map<String, dynamic>;
      final entries = coverage['entries'] as Map<String, dynamic>;
      expect(declarations, isNotEmpty);
      expect(entries, isNotEmpty);
      const roles = {
        'canonical_component',
        'internal_wrapper',
        'internal_part',
        'entry_composition',
        'frozen_legacy',
        'preview_fixture',
        'proven_unused',
        'unresolved',
      };
      for (final item in declarations.entries) {
        final row = item.value as Map<String, dynamic>;
        expect(roles, contains(row['role']), reason: item.key);
        expect(row['owner'], isNotEmpty, reason: item.key);
        expect(row['pass'], isNot(true), reason: item.key);
        if (row['role'] == 'unresolved') {
          expect(row['reason'], isNotEmpty, reason: item.key);
        }
      }
      final mappedScreens = {
        for (final row in entries.values.cast<Map<String, dynamic>>())
          if (row['lifecycleScreenId'] != null) row['lifecycleScreenId'],
      };
      for (final screen in screens) {
        expect(mappedScreens, contains(screen['id']), reason: _s(screen, 'id'));
      }
      for (final raw in (coverage['requirements'] as Map).values) {
        final row = raw as Map<String, dynamic>;
        expect(const {
          'required',
          'not_applicable',
          'unknown',
        }, contains(row['applicability']));
        expect(entries.containsKey(row['entryId']), isTrue);
        if (row['applicability'] != 'required') {
          expect(row['owner'], isNotEmpty);
          expect(row['reason'], isNotEmpty);
        }
        if (row['applicability'] == 'not_applicable') {
          expect(row['sourceBindings'], isNotEmpty);
        }
      }
      // Resolved completeness and evidence hashes are checked by ds-audit once,
      // not by launching an analyzer from each standalone Dart guard test.
    },
  );

  test('every screen and state is well formed and carries its reasons', () {
    final problems = <String>[];
    if (decoded['version'] != 1) problems.add('version must be 1');
    if (_s(decoded, '_doc').isEmpty) problems.add('_doc is empty');
    final ids = <String>{};
    for (final screen in screens) {
      final id = _s(screen, 'id');
      if (id.isEmpty) problems.add('screen without id: $screen');
      if (!ids.add(id)) problems.add('duplicate screen id: $id');
      for (final key in const ['title', 'webEntry', 'flutterEntry']) {
        if (_s(screen, key).isEmpty) problems.add('$id: $key empty');
      }
      final states = (screen['states'] as List<dynamic>? ?? const []);
      if (states.isEmpty) problems.add('$id: no states listed');
      final seen = <String>{};
      for (final raw in states) {
        final state = Map<String, dynamic>.from(raw as Map);
        final name = _s(state, 'state');
        final variant = _s(state, 'variant');
        final label = '$id/$name${variant.isEmpty ? '' : '/$variant'}';
        if (!seen.add('$name|$variant')) problems.add('$label: duplicate');
        if (!_states.contains(name)) problems.add('$label: unknown state');
        if (!_webValues.contains(state['web'])) {
          problems.add('$label: web must be yes|no');
        }
        if (!_flutterValues.contains(state['flutter'])) {
          problems.add('$label: flutter must be yes|partial|missing');
        }
        final status = _s(state, 'status');
        if (!_statuses.contains(status)) {
          problems.add('$label: unknown status "$status"');
        }
        final cases = state['parityCase'];
        if (cases is! List || cases.any((c) => c is! String)) {
          problems.add('$label: parityCase must be a list of strings');
        } else if (cases.any((c) => (c as String).trim().isEmpty)) {
          problems.add('$label: empty parityCase entry');
        }
        final list = _cases(state);
        final justification = _s(state, 'justification').trim();
        if ((status == 'covered' || status == 'fixing') && list.isEmpty) {
          problems.add('$label: $status without a parityCase');
        }
        if (status != 'covered' && justification.isEmpty) {
          problems.add('$label: $status without a justification');
        }
        if (status == 'gap' && !_sizes.contains(state['size'])) {
          problems.add('$label: gap without size S|M|L');
        }
        if (state['gapKind'] != null && !_gapKinds.contains(state['gapKind'])) {
          problems.add('$label: unknown gapKind');
        }
        if (status == 'gap' && state['gapKind'] == null) {
          problems.add('$label: gap without gapKind');
        }
        if (state['caseValidity'] != null &&
            !_validities.contains(state['caseValidity'])) {
          problems.add('$label: unknown caseValidity');
        }
        if (status == 'covered' &&
            state['flutter'] == 'missing' &&
            justification.isEmpty) {
          problems.add(
            '$label: covered but Flutter missing needs a justification',
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every covered parityCase resolves to a known parity case', () {
    final corpus = _readCorpus(root);
    final memo = <String, bool>{};
    final manifestPath = Platform.environment['RAFT_PARITY_MANIFEST'];
    List<String>? manifestIds;
    if (manifestPath != null && manifestPath.isNotEmpty) {
      final manifest = jsonDecode(
        File(manifestPath).readAsStringSync(),
      ) as Map<String, dynamic>;
      manifestIds = [
        for (final c in manifest['cases'] as List<dynamic>)
          (c as Map)['id'] as String,
      ];
      // Official (phone) case ids live in the Web source checkout.
      final web = Platform.environment['RAFT_WEB_SOURCE'];
      if (web != null && web.isNotEmpty) {
        final shared = File(
          '$web/packages/visual-testing/shared/sharedCases.json',
        );
        if (shared.existsSync()) {
          final official =
              jsonDecode(shared.readAsStringSync()) as Map<String, dynamic>;
          manifestIds.addAll([
            for (final c in official['cases'] as List<dynamic>)
              (c as Map)['id'] as String,
          ]);
        }
      }
    }
    final problems = <String>[];
    for (final screen in screens) {
      for (final raw in screen['states'] as List<dynamic>) {
        final state = Map<String, dynamic>.from(raw as Map);
        final status = _s(state, 'status');
        if (status != 'covered' && status != 'fixing') continue;
        for (final pattern in _cases(state)) {
          final label = '${screen['id']}/${state['state']}: $pattern';
          final why = _resolve(
            pattern,
            corpus,
            memo,
            familyOnly: status == 'fixing',
          );
          if (why != null) {
            problems.add('$label -> $why');
            continue;
          }
          if (manifestIds != null && status == 'covered') {
            final re = _glob(pattern);
            final hit = manifestIds.any((id) {
              final parts = id.split('.');
              final bare = parts.length > 2 && _themes.contains(parts.last)
                  ? parts.sublist(0, parts.length - 1).join('.')
                  : id;
              return re.hasMatch(bare);
            });
            if (!hit) problems.add('$label -> no id in $manifestPath');
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every navigation section and settings tab is mapped to screens', () {
    final screenIds = {for (final s in screens) _s(s, 'id')};
    final coverage = Map<String, dynamic>.from(
      decoded['navigationCoverage'] as Map? ?? const {},
    );
    final sections = Map<String, dynamic>.from(
      coverage['sections'] as Map? ?? {},
    );
    final tabs = Map<String, dynamic>.from(
      coverage['settingsTabs'] as Map? ?? {},
    );
    final problems = <String>[];

    void check(String kind, String id, Map<String, dynamic> map) {
      final value = map[id];
      if (value == null) {
        problems.add(
          '$kind "$id" is in NavigationRegistry but not in '
          'docs/state-parity.json navigationCoverage.$kind; list its screens '
          '(with their loading / empty / error states) and map it',
        );
      } else if (value is String) {
        if (value.trim().isEmpty) {
          problems.add('$kind "$id": empty justification');
        }
      } else if (value is List) {
        if (value.isEmpty) problems.add('$kind "$id": empty screen list');
        for (final screen in value) {
          if (!screenIds.contains(screen)) {
            problems.add('$kind "$id": unknown screen "$screen"');
          }
        }
      } else {
        problems.add('$kind "$id": value must be a list or a string');
      }
    }

    final sectionIds = {for (final s in NavigationRegistry.sections) s.id};
    final tabIds = {for (final t in NavigationRegistry.settingsTabs) t.id};
    for (final id in sectionIds) {
      check('sections', id, sections);
    }
    for (final id in tabIds) {
      check('settingsTabs', id, tabs);
    }
    for (final id in sections.keys) {
      if (!sectionIds.contains(id)) {
        problems.add(
          'sections "$id" is not a NavigationRegistry section (stale)',
        );
      }
    }
    for (final id in tabs.keys) {
      if (!tabIds.contains(id)) {
        problems.add(
          'settingsTabs "$id" is not a NavigationRegistry tab (stale)',
        );
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every screen points at an existing Flutter entry file', () {
    final problems = <String>[];
    for (final screen in screens) {
      final path = _s(screen, 'flutterEntry');
      if (!File('${root.path}/$path').existsSync()) {
        problems.add('${screen['id']}: $path does not exist');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
