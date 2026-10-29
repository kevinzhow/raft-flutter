// Shared driver of the text-scale audit tests (see tool/testing/text_scale_audit.dart
// for what is detected).
//
// The audit is a ratchet. Every (font set, surface, mode) has a recorded set
// of known failures in text_scale_audit_baseline.json. A test fails when a
// surface gains a failure that is not recorded (a regression) and also when a
// recorded failure no longer occurs (so the entry is deleted and the ratchet
// tightens). 1.0x should be clean (parity runs at 1.0); its entries are the
// Elegant-structure defects the audit never saw while it only ran Brutal.
//
//   RAFT_TEXT_SCALE_UPDATE=1  rewrite the baseline from the current results
//   RAFT_TEXT_SCALE_SWEEP=1   also run the non-representative previews
//   RAFT_TEXT_SCALE_OUT=dir   write screenshots (failing ones marked .FAIL) and
//                             per-surface JSON reports under dir
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/material.dart' show Locale, TargetPlatform;
import 'package:flutter/widgets.dart' show Scrollable, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/text_scale_audit.dart';
import 'text_scale_audit_surfaces.dart';

/// Interactions that open a surface's interesting state.
final _actions = <String, Future<void> Function(WidgetTester)>{
  'choiceDialogPreview': (t) async {
    await t.tap(find.text('Choose workspace'));
    await t.pumpAndSettle();
  },
  'largeChoiceDialogPreview': (t) async {
    await t.tap(find.text('Choose workspace'));
    await t.pumpAndSettle();
  },
  'menuPopupBackendPreview': (t) async {
    await t.tap(find.text('Choose a language'));
    await t.pumpAndSettle();
  },
  'dropdownMenuRolePreview': (t) async {
    await t.tap(find.text('Open published menu'));
    await t.pumpAndSettle();
  },
  'dropdownViewportPreview': (t) async {
    await t.tap(find.byType(RaftAgentSelect<String>));
    await t.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const ValueKey('raft-select-popup')),
      matching: find.byType(Scrollable),
    );
    expect(list, findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Choice 39'),
      180,
      scrollable: list,
      maxScrolls: 40,
    );
    expect(find.text('Choice 39').hitTestable(), findsOneWidget);
  },
  'selectionCopyToastPreview': (t) async {
    final en = find.text('Copy MD');
    await t.tap(en.evaluate().isNotEmpty ? en : find.text('复制 Markdown'));
    await t.pump(const Duration(milliseconds: 300));
  },
};

File _baselineFile() {
  const rel = 'test/text_scale_audit_baseline.json';
  for (var d = Directory.current.absolute; ; d = d.parent) {
    for (final c in ['${d.path}/$rel', '${d.path}/packages/raft_ui/$rel']) {
      if (File(c).existsSync() || File(c).parent.existsSync()) {
        if (File(c).parent.path.endsWith('raft_ui/test')) return File(c);
      }
    }
    if (d.parent.path == d.path) return File(rel);
  }
}

Map<String, List<String>> _readBaseline() {
  final f = _baselineFile();
  if (!f.existsSync()) return {};
  final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in raw.entries) e.key: [for (final v in e.value as List) '$v'],
  };
}

/// A preview frame under 500px tall (a component in a small test box, not a
/// screen) grows with the text scale: it stands for a slot in a scrolling page,
/// so only the component itself may fail, not the box around it. Screens keep
/// their device size.
Size _frame(Size size, AuditMode mode) =>
    size.height < 500 && mode.textScale > 1
    ? Size(size.width, size.height * mode.textScale)
    : size;

/// Stable identity of a failure: what broke, on which text.
Set<String> signatures(AuditReport r, {Set<String> ignore = const {}}) => {
  for (final f in r.failures)
    if (!ignore.contains(f.kind)) '${f.kind}: ${f.text}',
};

/// Registers one test per surface for [fonts].
///
/// [modes] are pumped in order; the 1.0x mode (named `1.0x`) must come first.
void defineSurfaceAudits(
  AuditFonts fonts, {
  required List<AuditMode> modes,

  /// A profile beyond the default Web one (e.g. `android-zh`): keys the
  /// baseline entries, picks the theme and turns the label-centring check on.
  String profile = '',
  bool dark = false,
  bool androidChinese = false,
  bool centring = false,

  /// Audit every preview, not only the representative ones.
  bool allSurfaces = false,

  /// Finding kinds that are not fit defects of the surface. The previews that
  /// are not representative include ones the harness cannot lay out under its
  /// probes (`error`: a render object without dry-baseline support).
  Set<String> ignoreKinds = const {},
}) {
  final update = Platform.environment['RAFT_TEXT_SCALE_UPDATE'] == '1';
  final sweep =
      allSurfaces || Platform.environment['RAFT_TEXT_SCALE_SWEEP'] == '1';
  final out = Platform.environment['RAFT_TEXT_SCALE_OUT'];
  final baseline = _readBaseline();
  final actual = <String, List<String>>{};
  final prefix =
      '${fonts.name}|${dark ? 'dark' : 'light'}'
      '${profile.isEmpty ? '' : '|$profile'}';

  tearDownAll(() {
    if (!update) return;
    // Re-read: another test file may have updated its own entries meanwhile
    // (run the update one test file at a time).
    final merged = <String, List<String>>{..._readBaseline(), ...actual}
      ..removeWhere((k, v) => v.isEmpty);
    final keys = merged.keys.toList()..sort();
    _baselineFile().writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({for (final k in keys) k: merged[k]})}\n',
    );
  });

  for (final s in auditSurfaces) {
    if (!s.representative && !sweep) continue;
    testWidgets('$prefix ${s.fn}', (t) async {
      await loadAuditFonts(t, fonts);
      final theme = raftTheme(
        dark: dark,
        locale: androidChinese ? const Locale('zh', 'CN') : null,
        platform: androidChinese ? TargetPlatform.android : null,
      );
      final truncation = <String, bool>{};
      final problems = <String>[];
      for (final mode in modes) {
        final report = await auditSurface(
          t,
          surface: s.fn,
          build: s.build,
          theme: theme,
          mode: mode,
          size: _frame(s.size, mode),
          truncationBaseline: truncation,
          centring: centring,
          screenshotDir: out == null
              ? null
              : '$out/${prefix.replaceAll('|', '-')}',
        );
        final key = '$prefix|${s.fn}|${mode.name}';
        final got = signatures(report, ignore: ignoreKinds).toList()..sort();
        if (update) {
          actual[key] = got;
        } else {
          final known = (baseline[key] ?? const []).toSet();
          // 1.0x should be clean (parity runs at 1.0). The baseline records the
          // defects of the Elegant structure, which the audit had never run
          // before the Raft collapse (it audited Brutal); the follow-up
          // structure changes delete them, and a fixed one fails the run until
          // it is removed.
          final added = got.toSet().difference(known);
          final fixed = known.difference(got.toSet());
          if (added.isNotEmpty) {
            problems.add(
              '${mode.name}: new failures (fix them, or record in text_scale_audit_baseline.json with RAFT_TEXT_SCALE_UPDATE=1):\n'
              '  ${report.failures.where((f) => added.contains('${f.kind}: ${f.text}')).join('\n  ')}',
            );
          }
          if (fixed.isNotEmpty) {
            problems.add(
              '${mode.name}: recorded failures no longer occur, delete them from the baseline (RAFT_TEXT_SCALE_UPDATE=1): ${fixed.join('; ')}',
            );
          }
        }
        if (_actions.containsKey(s.fn)) {
          // The action state is audited as an extra pass of the same mode.
          final acted = await auditSurface(
            t,
            surface: '${s.fn}-open',
            build: s.build,
            theme: theme,
            mode: mode,
            size: _frame(s.size, mode),
            truncationBaseline: truncation,
            centring: centring,
            screenshotDir: out == null
                ? null
                : '$out/${prefix.replaceAll('|', '-')}',
            after: _actions[s.fn],
          );
          final akey = '$prefix|${s.fn}-open|${mode.name}';
          final agot = signatures(acted, ignore: ignoreKinds).toList()..sort();
          if (update) {
            actual[akey] = agot;
          } else {
            final aknown = (baseline[akey] ?? const []).toSet();
            if (agot.toSet().difference(aknown).isNotEmpty ||
                aknown.difference(agot.toSet()).isNotEmpty) {
              problems.add(
                '${mode.name}/open: ${acted.failures.join('; ')} (baseline: $aknown)',
              );
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

/// Every preview in lib/ must be in the surface list.
void expectSurfaceListComplete() {
  test('every @RaftPreviews preview is in the audit surface list', () {
    final lib = Directory('${_baselineFile().parent.parent.path}/lib');
    final listed = {for (final s in auditSurfaces) s.fn};
    final found = <String>{};
    for (final f in lib.listSync().whereType<File>().where(
      (f) =>
          f.path.endsWith('_previews.dart') ||
          f.path.endsWith('/previews.dart'),
    )) {
      final src = f.readAsStringSync();
      for (final m in RegExp(
        r'@RaftPreviews\((?:[^()]|\([^()]*\))*\)\s*Widget\s+(\w+)\(',
      ).allMatches(src)) {
        found.add(m.group(1)!);
      }
    }
    expect(
      found.difference(listed),
      isEmpty,
      reason: 'add them to text_scale_audit_surfaces.dart',
    );
    expect(listed.difference(found), isEmpty);
  });
}
