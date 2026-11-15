// Restart progress is shared per computer (Web v1.24 useComputerRestart /
// machineStore.computerOperationProgress): a restart started from the rack
// row's menu replaces the row action with its progress text, hides Restart in
// the menu, ends on `computer:restart:done` (matching requestId only), and the
// Computer page shows the same progress.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_preferences.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final commands = <(String, String, dynamic)>[];
  Object? restartError;
  Map<String, dynamic> restartAnswer = {'requestId': 'req-1'};
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) {
      return {'machines': machines.map(Map<String, dynamic>.from).toList()};
    }
    if (path == '/agents') return <dynamic>[];
    return <dynamic>[];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method, path, data));
    if (path.endsWith('/computer/restart')) {
      if (restartError != null) throw restartError!;
      return restartAnswer;
    }
    return <String, dynamic>{};
  }
}

Map<String, dynamic> _computer(String id) => {
  'id': id,
  'name': id,
  'status': 'online',
  'isComputer': true,
  'computerVersion': '1.0.60',
  'os': 'linux',
  'hostname': '$id.host',
  'runtimes': ['claude'],
  'userId': 'alice',
  'computerAttachedByCurrentUser': true,
};

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    ComputersRackPreferences.instance.resetForTests();
    ComputersRackPreferences.instance.setView(RackView.list);
  });
  tearDown(() async {
    ComputersRackPreferences.instance.resetForTests();
    DevicePreferences.reset();
  });

  Future<void> openRack(
    WidgetTester t, {
    bool phone = false,
    Object? restartError,
  }) async {
    // Made inside the test body: the directory's timers must run on the
    // test's fake clock.
    c = _Client();
    w = _Workspace(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'})
      ..machines = [_computer('alpha')]
      ..restartError = restartError;
    t.view.physicalSize = phone ? const Size(390, 844) : const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.services.entityDirectory.dispose();
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ComputersRackView(
            controller: w,
            phone: phone,
            onOpenComputer: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> restartFromMenu(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('rack-row-menu-alpha')));
    await t.pumpAndSettle();
    await t.tap(find.text('Restart'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('computer-restart-confirm')),
        matching: find.widgetWithText(RaftButton, 'Restart'),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  final progress = find.byKey(const ValueKey('rack-restart-progress-alpha'));
  String progressText(WidgetTester t) =>
      t
          .widget<Text>(
            find.descendant(of: progress, matching: find.byType(Text)),
          )
          .data ??
      '';

  Future<void> expectRestartHiddenInMenu(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('rack-row-menu-alpha')));
    await t.pumpAndSettle();
    expect(find.text('Create agent'), findsOneWidget);
    expect(find.text('Restart'), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
  }

  testWidgets('a restart from the row menu shows its progress in the row and '
      'takes Restart out of the menu', (t) async {
    await openRack(t);
    expect(progress, findsNothing);
    await restartFromMenu(t);
    expect(progress, findsOneWidget);
    expect(progressText(t), 'Restarting…');
    expect(
      w.commands.where((x) => x.$2.endsWith('/computer/restart')),
      hasLength(1),
    );
    await expectRestartHiddenInMenu(t);
    await t.pump(const Duration(seconds: 61));
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('the same progress replaces the action on a phone row', (
    t,
  ) async {
    await openRack(t, phone: true);
    w.services.entityDirectory.computerRestartProgress.begin('alpha');
    await t.pump();
    expect(progress, findsOneWidget);
    expect(progressText(t), 'Restarting…');
    await t.pump(const Duration(seconds: 61));
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('computer:restart:done with the request id says Restarted. and '
      'then clears; another request id is ignored', (t) async {
    await openRack(t);
    await restartFromMenu(t);
    c.stream.add(
      const RaftEvent('computer:restart:done', {
        'machineId': 'alpha',
        'requestId': 'other',
        'ok': true,
      }),
    );
    await t.pump();
    expect(progressText(t), 'Restarting…');
    c.stream.add(
      const RaftEvent('computer:restart:done', {
        'machineId': 'alpha',
        'requestId': 'req-1',
        'ok': true,
      }),
    );
    await t.pump();
    expect(progressText(t), 'Restarted.');
    await t.pump(const Duration(seconds: 3, milliseconds: 600));
    expect(progress, findsNothing);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('a failed restart:done says Restart failed. in the warning '
      'colour, then clears', (t) async {
    await openRack(t);
    await restartFromMenu(t);
    c.stream.add(
      const RaftEvent('computer:restart:done', {
        'machineId': 'alpha',
        'requestId': 'req-1',
        'ok': false,
      }),
    );
    await t.pump();
    expect(progressText(t), 'Restart failed.');
    await t.pump(const Duration(seconds: 3, milliseconds: 600));
    expect(progress, findsNothing);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('a POST that fails shows the error, then the action returns', (
    t,
  ) async {
    await openRack(t, restartError: StateError('boom'));
    await restartFromMenu(t);
    expect(progress, findsOneWidget);
    expect(
      progressText(t),
      'Failed to request restart. The Computer must be online.',
    );
    await t.pump(const Duration(seconds: 4, milliseconds: 100));
    expect(progress, findsNothing);
    await t.tap(find.byKey(const ValueKey('rack-row-menu-alpha')));
    await t.pumpAndSettle();
    expect(find.text('Restart'), findsOneWidget);
  });

  testWidgets('without done the progress gives up after 60 seconds', (t) async {
    await openRack(t);
    await restartFromMenu(t);
    await t.pump(const Duration(seconds: 59));
    expect(progressText(t), 'Restarting…');
    await t.pump(const Duration(seconds: 2));
    expect(
      progressText(t),
      'Restart timed out. Check that the Computer is online and retry.',
    );
    await t.pump(const Duration(seconds: 4));
    expect(progress, findsNothing);
  });

  testWidgets('the Computer page shows a restart started from the row', (
    t,
  ) async {
    await openRack(t);
    await restartFromMenu(t);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ComputerDetailPanel(controller: w, machine: w.machines.first),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(RaftProgressBar), findsOneWidget);
    expect(find.byKey(const ValueKey('computer-restart')), findsNothing);
    c.stream.add(
      const RaftEvent('computer:restart:done', {
        'machineId': 'alpha',
        'requestId': 'req-1',
        'ok': true,
      }),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Restarted.'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    expect(find.text('Restarted.'), findsNothing);
    expect(find.byType(RaftProgressBar), findsNothing);
  });

  testWidgets('a restart started on the Computer page shows in the row', (
    t,
  ) async {
    await openRack(t);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ComputerDetailPanel(controller: w, machine: w.machines.first),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    await t.ensureVisible(find.byKey(const ValueKey('computer-restart')));
    await t.tap(find.byKey(const ValueKey('computer-restart')));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('computer-restart-confirm')),
        matching: find.widgetWithText(RaftButton, 'Restart'),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(
      w.services.entityDirectory.computerRestartProgress
          .progress('alpha')
          ?.done,
      false,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ComputersRackView(controller: w, onOpenComputer: (_) {}),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(progress, findsOneWidget);
    await t.pump(const Duration(seconds: 61));
    await t.pump(const Duration(seconds: 4));
  });
}
