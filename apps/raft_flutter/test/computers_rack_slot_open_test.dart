// Rack rows (Web v1.24 components/machine/rack/AgentRackSlot.tsx,
// features/computer/ComputerRackRow.tsx): an agent slot is a button of its
// own that opens that agent (the side panel beside the rack on desktop, the
// agent's page on a phone) and shows the profile preview card on hover; the
// computer's name button is the row's one tab stop, while a pointer press
// anywhere else on the row still opens the computer.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/profile_preview.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'mobile_computer_navigation_test.dart' show computer;

const _agent = <String, dynamic>{
  'id': 'agent-1',
  'name': 'builder',
  'displayName': 'Builder Bot',
  'status': 'active',
  'runtime': 'codex',
  'machineId': 'computer-a',
  'activity': 'online',
  'creatorType': 'user',
  'creatorId': 'alice',
};

/// A desktop pointer and keyboard (Linux), as Web's desktop is.
final _desktop = TargetPlatformVariant.only(TargetPlatform.linux);

RootFixture _fixture() => RootFixture()
  ..overrides['GET /announcements/active'] = ((_) => {'announcements': []})
  ..overrides['GET /agents'] = ((_) => [_agent])
  ..overrides['GET /servers/a/machines'] = (_) => {
    'machines': [computer],
    'latestComputerVersion': '1.0.45',
  };

Future<RootFixture> _openRack(WidgetTester t, double width) async {
  final f = _fixture();
  await f.mount(t, 'light', width, uri: Uri.parse('/s/alpha/computers'));
  await f.flush(t);
  await t.pump(const Duration(milliseconds: 500));
  expect(find.byKey(const ValueKey('rack-slot-agent-1')), findsOneWidget);
  return f;
}

void main() {
  testWidgets('desktop: a slot opens its agent beside the rack, not the '
      'computer', (t) async {
    final f = await _openRack(t, 1400);
    await t.tap(find.byKey(const ValueKey('rack-slot-agent-1')));
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    final w = f.workspace(t);
    // Web /computers?profile=agent:<id>: the page stays Computers.
    expect(w.location.route, RaftRoute.computers);
    expect(w.location.query('open'), 'agent:agent-1');
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsOneWidget,
      reason: 'Web openProfile("agent") fills the ProfilePanel beside the rack',
    );
    expect(
      find.byKey(const ValueKey('computers-rack-overview')),
      findsOneWidget,
      reason: 'the rack stays',
    );
    // Escape closes it back to the bare rack (the ProfilePanel layer).
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsNothing,
    );
    expect(w.location.route, RaftRoute.computers);
    expect(w.location.query('open'), isNull);
    await f.close(t);
  });

  testWidgets('phone: a slot opens the agent\'s profile, not the computer', (
    t,
  ) async {
    final f = await _openRack(t, 390);
    await t.tap(find.byKey(const ValueKey('rack-slot-agent-1')));
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 500));
    final w = f.workspace(t);
    // Web AgentRackSlot openProfile("agent"): the profile, over the page.
    expect(w.location.entityId, isNot('computer-a'));
    expect(w.location.query('profile'), contains('agent-1'));
    await f.close(t);
  });

  testWidgets('hovering a slot shows the profile preview card', (t) async {
    final f = await _openRack(t, 1400);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.byKey(const ValueKey('rack-slot-agent-1'))));
    // The card waits for the pointer to move over the trigger, then 200ms.
    await mouse.moveBy(const Offset(2, 0));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(ProfilePreviewContent), findsNothing, reason: '200ms');
    await t.pump(const Duration(milliseconds: 200));
    await t.pump();
    expect(find.byType(ProfilePreviewContent), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await t.pump(const Duration(milliseconds: 300));
    await f.close(t);
  }, variant: _desktop);

  testWidgets('the name button is the row\'s tab stop, then the agent slot', (
    t,
  ) async {
    final f = await _openRack(t, 1400);
    const row = ValueKey('rack-row-computer-a');
    const name = ValueKey('rack-row-name-computer-a');
    const slot = ValueKey('rack-slot-agent-1');
    const menu = ValueKey('rack-row-menu-computer-a');
    // Which of the row's parts holds focus (the innermost keyed one).
    Key? holder() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return null;
      Key? found;
      void check(Element e) {
        if (found == null && {row, name, slot, menu}.contains(e.widget.key)) {
          found = e.widget.key;
        }
      }
      check(context as Element);
      context.visitAncestorElements((e) {
        check(e);
        return found == null;
      });
      return found;
    }

    // From the page header's controls, Tab walks into the list.
    FocusManager.instance.primaryFocus?.unfocus();
    final seen = <Key?>[];
    for (var i = 0; i < 40 && !seen.contains(slot); i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final k = holder();
      if (k != null && (seen.isEmpty || seen.last != k)) seen.add(k);
    }
    expect(seen, contains(name));
    expect(seen, contains(slot));
    expect(seen, isNot(contains(row)), reason: 'the row itself is no tab stop');
    expect(seen.indexOf(name), lessThan(seen.indexOf(slot)));
    await f.close(t);
  }, variant: _desktop);

  testWidgets('semantics: the name is a button named after the computer and '
      'the slot a button named after the agent', (t) async {
    final handle = t.ensureSemantics();
    final f = await _openRack(t, 1400);
    expect(
      t.getSemantics(find.byKey(const ValueKey('rack-row-name-computer-a'))),
      isSemantics(
        label: 'Build Computer',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    expect(
      t.getSemantics(find.byKey(const ValueKey('rack-slot-agent-1'))),
      isSemantics(label: 'Builder Bot', isButton: true, hasTapAction: true),
    );
    await f.close(t);
    handle.dispose();
  });

  testWidgets('a press on the row outside the name still opens the computer', (
    t,
  ) async {
    final f = await _openRack(t, 1400);
    final row = find.byKey(const ValueKey('rack-row-computer-a'));
    // The card's lower-left corner: no name, slot, action or menu there.
    await t.tapAt(t.getBottomLeft(row) + const Offset(24, -8));
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(f.workspace(t).location.entityId, 'computer-a');
    await f.close(t);
  });
}
