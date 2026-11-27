// The in-place cells of the tap-target matrix (TapTargetRegistry
// .inPlaceOpeners, docs/tap-targets.md): each taps the real row, hit, card
// or link at its width and asserts what TapEffect.besideList promises. The
// viewer is painted in the workspace's own page beside what was tapped,
// which stays on screen and tappable, and the location carries `?artifact=`
// exactly where that place is addressed. An opener with no cell here fails.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/quick_switcher.dart' show QuickSwitcher;

import 'list_detail_artifact_slot_test.dart' show artifactListFixture;
import 'shell_artifact_place_test.dart'
    show artifactLink, card, mountArtifactThread, serveArtifact, viewer;
import 'support/artifact_fake_client.dart';
import 'tap_target_matrix_test.dart' show channelMessages, mount, msg;
import 'task_surface_test.dart' show flush;

/// What a cell tapped: the location to read and what must stay beside it.
typedef Tapped = ({RaftLocation Function() location, Finder origin});

Future<Tapped> _list(WidgetTester t, String uri, Finder origin) async {
  final fixture = artifactListFixture(search: true);
  addTearDown(() => fixture.close(t));
  await fixture.mount(t, 'light', 1280, uri: Uri.parse(uri));
  await t.pump(const Duration(milliseconds: 250));
  await fixture.flush(t);
  expect(origin, findsOneWidget);
  await t.tap(origin);
  await fixture.flush(t);
  await t.pumpAndSettle();
  final w = fixture.workspace(t);
  return (location: () => w.location, origin: origin);
}

Future<Tapped> _chat(WidgetTester t, {required bool chip}) async {
  channelMessages.add(msg('art', 'c1', 6, artifactLink));
  final c = await mount(
    t,
    TapTargetRegistry.hosts.firstWhere((h) => h.id == 'chat-1280'),
  );
  serveArtifact(c);
  ArtifactSession.of(c.w).debugSetEnabled(true);
  await flush(t);
  await t.pumpAndSettle();
  final origin = c.row('art');
  if (chip) {
    // The link in the text, not the card under it.
    await t.tapOnText(find.textRange.ofSubstring('raftusercontent.com'));
  } else {
    await t.tap(find.descendant(of: origin, matching: card));
  }
  await flush(t);
  await t.pumpAndSettle();
  return (location: () => c.w.location, origin: origin);
}

final Map<String, Future<Tapped> Function(WidgetTester)> _cells = {
  'activity-artifact-row': (t) => _list(
    t,
    '/s/alpha/activity',
    find.byKey(const ValueKey('activity-object-$artifactId')),
  ),
  'search-artifact-hit': (t) => _list(
    t,
    '/s/alpha/search?q=plan',
    find.byKey(const ValueKey('app:artifacts:$artifactId')),
  ),
  'quick-switcher-artifact-hit': (t) async {
    final fixture = artifactListFixture(search: true);
    addTearDown(() => fixture.close(t));
    await fixture.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/activity'));
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await fixture.flush(t);
    await t.enterText(
      find.descendant(
        of: find.byType(QuickSwitcher),
        matching: find.byType(TextField),
      ),
      'plan',
    );
    await t.pump(const Duration(milliseconds: 250));
    await fixture.flush(t);
    await t.tap(
      find.descendant(
        of: find.byType(QuickSwitcher),
        matching: find.byKey(const ValueKey('app:artifacts:$artifactId')),
      ),
    );
    await fixture.flush(t);
    await t.pumpAndSettle();
    final w = fixture.workspace(t);
    return (
      location: () => w.location,
      origin: find.byKey(const ValueKey('app:artifacts:$artifactId')).first,
    );
  },
  'message-artifact-card': (t) => _chat(t, chip: false),
  'message-artifact-chip': (t) => _chat(t, chip: true),
  'thread-artifact-card': (t) async {
    final c = await mountArtifactThread(t);
    await t.tap(card);
    await flush(t);
    await t.pumpAndSettle();
    return (location: () => c.w.location, origin: c.threadView.first);
  },
};

void main() {
  test('every in-place opener has a cell', () {
    expect({
      for (final o in TapTargetRegistry.inPlaceOpeners) o.id,
    }, _cells.keys.toSet());
  });

  for (final opener in TapTargetRegistry.inPlaceOpeners) {
    testWidgets('${opener.id} @ ${opener.width.toInt()}: '
        '${opener.expectation.kind.name}', (t) async {
      expect(opener.expectation.kind, TapEffect.besideList);
      final tapped = await _cells[opener.id]!(t);
      expect(viewer, findsOneWidget);
      expect(
        ModalRoute.of(t.element(viewer)),
        same(ModalRoute.of(t.element(tapped.origin))),
        reason: 'in the workspace, not on a window over it',
      );
      expect(tapped.origin.hitTestable(), findsOneWidget, reason: 'it stays');
      expect(
        t.getRect(viewer).left,
        greaterThanOrEqualTo(t.getRect(tapped.origin).right - 1),
        reason: 'beside what was tapped',
      );
      expect(
        tapped.location().query('artifact'),
        opener.addressed ? artifactShort : isNull,
      );
    });
  }
}
