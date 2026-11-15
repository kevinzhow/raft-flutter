// Computers page odds and ends (Web v1.24): the rack search's clear button is
// "Clear search" and Escape empties a search that holds text without closing
// the computer open beside the rack (raft-ui FitToolbarSearch); on the phone's
// "needs attention" list, Add computer's Done opens the new computer
// (MobileComputersPanel's AddMachineDialog, as from the rack).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_preferences.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'mobile_computer_navigation_test.dart' show fixture;

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> machines = [];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) {
      return {'machines': machines.map(Map<String, dynamic>.from).toList()};
    }
    return <dynamic>[];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async =>
      <String, dynamic>{};
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}


void main() {
  testWidgets('the search clear button says Clear search; Escape empties the '
      'search first, then closes the computer beside the rack', (t) async {
    final f = fixture();
    await f.mount(t, 'light', 1400, uri: Uri.parse('/s/alpha/computers'));
    await f.flush(t);
    await t.tap(find.byKey(const ValueKey('rack-row-computer-a')));
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsOneWidget,
    );
    final search = find.descendant(
      of: find.byKey(const ValueKey('computers-rack-search')),
      matching: find.byType(EditableText),
    );
    await t.tap(search);
    await t.enterText(search, 'build');
    await t.pump(const Duration(milliseconds: 300));
    // The field's own X (the toolbar's Clear all is a separate control).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('computers-rack-search')),
        matching: find.bySemanticsLabel('Clear search'),
      ),
      findsOneWidget,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(ComputersRackPreferences.instance.query, isEmpty);
    expect(t.widget<EditableText>(search).controller.text, isEmpty);
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsOneWidget,
      reason: 'Escape only cleared the search',
    );
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await f.flush(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computers-rack-side-panel')),
      findsNothing,
    );
    await f.close(t);
  });

  testWidgets('phone attention list: Add computer, Done opens the new one', (
    t,
  ) async {
    final c = _Client();
    final w = _Workspace(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    final opened = <String>[];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: FleetView(
            controller: w,
            computers: true,
            attentionOnly: true,
            onOpenDetail: (row) => opened.add('${row['id']}'),
          ),
        ),
      ),
    );
    await _settle(t);
    await t.tap(find.text('Add computer').first);
    await _settle(t);
    w.machines = [
      {
        'id': 'actual',
        'name': 'actual',
        'hostname': 'actual-host',
        'os': 'linux',
        'status': 'online',
        'isComputer': true,
        'computerAttachedByCurrentUser': true,
      },
    ];
    c.stream.add(const RaftEvent('machine:created', {'machineId': 'actual'}));
    await t.pump(const Duration(milliseconds: 200));
    await _settle(t);
    await t.tap(find.widgetWithText(RaftRecipeButton, 'Done'));
    await _settle(t);
    expect(opened, ['actual']);
  });
}
