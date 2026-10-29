import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';

// Static half of the tap-target guard (the widget half is
// tap_target_matrix_test.dart): a file under lib/ that builds a message
// container must be listed in TapTargetRegistry, and docs/tap-targets.md must
// carry the registry's generated matrix.
const _start = '<!-- tap-matrix:start -->';
const _end = '<!-- tap-matrix:end -->';

void main() {
  final lib = Directory('lib');
  final docs = File('../../docs/tap-targets.md');

  Map<String, String> sources() => {
    for (final f in lib.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart') &&
          !f.path.endsWith('data/tap_target_registry.dart'))
        f.path.substring('lib/'.length): f.readAsStringSync(),
  };

  test('every file that builds a message container is registered', () {
    final registered = {for (final c in TapTargetRegistry.containers) c.file};
    final building = <String>{
      for (final e in sources().entries)
        if (TapTargetRegistry.guardedConstructs.any(e.value.contains)) e.key,
    };
    expect(
      building.difference(registered),
      isEmpty,
      reason:
          'These files build a message container (or a tappable message / '
          'row) that TapTargetRegistry does not list. Add the container with '
          'the test that taps it, and give it a complete handler set: a '
          'missing onThread / onProfile / onTask is a silent dead tap.',
    );
    expect(
      registered.difference(building),
      isEmpty,
      reason: 'Registered container no longer builds a guarded widget.',
    );
  });

  test('registered containers build only the widgets they declare', () {
    final src = sources();
    for (final c in TapTargetRegistry.containers) {
      final text = src[c.file];
      expect(text, isNotNull, reason: '${c.file} does not exist');
      for (final construct in c.constructs) {
        expect(
          text!.contains('$construct('),
          isTrue,
          reason: '${c.file} does not build $construct',
        );
      }
    }
  });

  // A host that builds a message container must say what its taps do. The
  // handlers are optional on the widgets (previews and unit tests build bare
  // timelines), so a new host could silently omit one and ship a dead link:
  // every call in lib/ must name them, `null` being an explicit decision (the
  // affordance is then drawn inert or hidden, never dead).
  const required = <String, List<String>>{
    'RaftChatView': ['onTask', 'onViewBilling'],
    'ConversationPanel': [
      'onMessageTask',
      'onViewBilling',
      'onOpenChannelSettings',
    ],
    'SourceTaskSurface': ['onTask', 'onViewBilling'],
    'WorkspaceTaskHost': ['onTask', 'onViewBilling'],
  };

  /// Source of each `Name(...)` call (not the definition) in [text].
  Iterable<String> calls(String text, String name) sync* {
    final pattern = RegExp('(?<![A-Za-z_])$name\\(');
    for (final m in pattern.allMatches(text)) {
      var depth = 0, i = m.end - 1;
      for (; i < text.length; i++) {
        if (text[i] == '(') depth++;
        if (text[i] == ')' && --depth == 0) break;
      }
      final body = text.substring(m.end, i);
      // `const Name({...})` is the constructor definition.
      if (!body.trimLeft().startsWith('{') &&
          !body.trimLeft().startsWith('super')) {
        yield body;
      }
    }
  }

  test('every host passes the complete handler set explicitly', () {
    final missing = <String>[];
    for (final entry in sources().entries) {
      for (final MapEntry(key: widget, value: names) in required.entries) {
        for (final body in calls(entry.value, widget)) {
          for (final name in names) {
            if (!RegExp('(?<![A-Za-z_])$name:').hasMatch(body)) {
              missing.add('lib/${entry.key}: $widget(...) has no `$name:`');
            }
          }
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Pass the host action, or `null` when this host has none (the '
          'affordance is then inert / hidden), so the omission is visible.',
    );
  });

  test('every host x element cell has an expectation', () {
    for (final host in TapTargetRegistry.hosts) {
      for (final element in TapElement.values) {
        expect(TapTargetRegistry.expectation(host, element), isNotNull);
      }
    }
    // A host that opens a column-4 panel must say so for the three reply
    // entry points and both profile entry points.
    for (final host in TapTargetRegistry.hosts.where((h) => !h.threadDetail)) {
      for (final e in [TapElement.inlineThreadCard, TapElement.repliesBadge]) {
        expect(
          TapTargetRegistry.expectation(host, e).kind,
          TapEffect.threadPanel,
          reason: '${host.id} x ${e.name}',
        );
      }
      for (final e in [TapElement.avatar, TapElement.mention]) {
        expect(
          TapTargetRegistry.expectation(host, e).kind,
          TapEffect.profilePanel,
          reason: '${host.id} x ${e.name}',
        );
      }
    }
  });

  test('docs/tap-targets.md carries the generated matrix', () {
    final generated = '$_start\n${TapTargetRegistry.matrixMarkdown()}$_end';
    final text = docs.readAsStringSync();
    final from = text.indexOf(_start), to = text.indexOf(_end);
    expect(from >= 0 && to > from, isTrue, reason: 'markers missing');
    final current = text.substring(from, to + _end.length);
    if (Platform.environment['UPDATE_TAP_DOCS'] == '1' &&
        current != generated) {
      docs.writeAsStringSync(
        text.replaceRange(from, to + _end.length, generated),
      );
      return;
    }
    expect(
      current,
      generated,
      reason:
          'Run UPDATE_TAP_DOCS=1 tool/flutter test test/tap_target_registry_test.dart',
    );
  });
}
