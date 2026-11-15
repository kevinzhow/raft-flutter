// The computer opened beside the rack on desktop closes (Web MachinePanelHeader
// X, ProfilePanel Escape layer): the header's Close, Escape, and Escape inside
// a rename field only cancelling the rename.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';

import 'mobile_computer_navigation_test.dart' show fixture;

void main() {
  Future<dynamic> openPanel(WidgetTester t) async {
    final f = fixture();
    // From another section through the rail, so the history is the app's own.
    await f.mount(t, 'light', 1400, uri: Uri.parse('/s/alpha/settings'));
    await f.flush(t);
    await t.tap(find.byKey(const ValueKey('rail-computers')));
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('rack-row-computer-a')));
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsOneWidget,
    );
    return f;
  }

  testWidgets('the header X closes the panel and deselects the row', (t) async {
    final f = await openPanel(t);
    expect(find.byKey(const ValueKey('machine-panel-close')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('machine-panel-close')));
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsNothing,
    );
    expect(f.workspace(t).location.route, RaftRoute.computers);
    expect(f.workspace(t).location.entityId, isNull);
    await f.close(t);
  });

  testWidgets('Escape closes the panel', (t) async {
    final f = await openPanel(t);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsNothing,
    );
    await f.close(t);
  });

  testWidgets('Escape in the rename field cancels the rename only', (t) async {
    final f = await openPanel(t);
    await t.ensureVisible(find.byKey(const ValueKey('computer-edit-name')));
    await t.tap(find.byKey(const ValueKey('computer-edit-name')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('computer-name-field')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('computer-name-field')), findsNothing);
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsOneWidget,
      reason: 'the panel stays; only the rename was cancelled',
    );
    // A second Escape, with nothing editing, closes it.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsNothing,
    );
    await f.close(t);
  });

  bool focusInPanel() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    var inside = false;
    context.visitAncestorElements((e) {
      if (e.widget.key == const ValueKey('computers-rack-side-panel')) {
        inside = true;
      }
      return !inside;
    });
    return inside;
  }

  testWidgets('focus moves into the panel on open and out of it on close', (
    t,
  ) async {
    final f = await openPanel(t);
    await t.pump(const Duration(milliseconds: 100));
    expect(focusInPanel(), isTrue, reason: 'Web ProfilePanel moves focus in');
    await t.tap(find.byKey(const ValueKey('machine-panel-close')));
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsNothing,
    );
    expect(focusInPanel(), isFalse);
    await f.close(t);
  });

  testWidgets('Ctrl+Enter saves the description from its field', (t) async {
    final f = await openPanel(t);
    await t.ensureVisible(
      find.byKey(const ValueKey('computer-edit-description')),
    );
    await t.tap(find.byKey(const ValueKey('computer-edit-description')));
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(
      find.byKey(const ValueKey('computer-description-field')),
      'Build box',
    );
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    final saves = f.adapter.calls.where(
      (o) => o.method == 'PATCH' && o.path == '/servers/a/machines/computer-a',
    );
    expect(saves, hasLength(1), reason: 'Ctrl+Enter saved the description');
    expect(saves.single.data, {'description': 'Build box'});
    await f.close(t);
  });
}
