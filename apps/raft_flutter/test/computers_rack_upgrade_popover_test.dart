// The rack row's manual-upgrade popover and the failure / repair hint popover
// (Web v1.24 features/computer/RackRowAction.tsx:96-150): the command to run on
// that machine opens in a popover under the button, not the Computer's page;
// Esc and a press outside close it and focus goes back to the trigger.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
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
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) {
      return {
        'machines': machines.map(Map<String, dynamic>.from).toList(),
        'latestComputerVersion': '1.0.47',
      };
    }
    if (path == '/agents') return <dynamic>[];
    return <dynamic>[];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method, path, data));
    return <String, dynamic>{};
  }
}

Map<String, dynamic> _computer({
  bool supported = true,
  Map<String, dynamic>? request,
  bool repair = false,
  bool manager = true,
}) => {
  'id': 'm1',
  'name': 'Studio',
  'status': 'online',
  'isComputer': true,
  'computerVersion': '1.0.46',
  'os': 'linux',
  'hostname': 'studio.host',
  'runtimes': ['claude'],
  'userId': 'alice',
  if (manager) 'computerAttachedByCurrentUser': true,
  'remoteUpgradeSupported': supported,
  'computerUpgradeAvailable': true,
  'computerBroadcastPolicy': {
    'eligibility': 'eligible',
    'targetVersion': '1.0.47',
  },
  'upgradeRequest': ?request,
  if (repair) 'installerRepairHint': {'reason': 'unrecovered_operation'},
};

const _failed = {
  'id': 'r1',
  'state': 'failed',
  'targetVersion': '1.0.47',
  'observedVersion': '1.0.46',
  'failureHint': {
    'reason': 'unsafe_kill_mode',
    'unit': 'raft.service',
    'scope': 'system',
    'killMode': 'process',
  },
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

  Future<List<String>> openRack(
    WidgetTester t,
    Map<String, dynamic> machine, {
    Size size = const Size(1400, 900),
    bool phone = false,
    String role = 'owner',
  }) async {
    c = _Client();
    w = _Workspace(c)
      ..server = RaftRecord({'id': 's', 'role': role, 'slug': 'fixture'})
      ..machines = [machine];
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final opened = <String>[];
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
            onOpenComputer: (row) => opened.add('${row['id']}'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return opened;
  }

  final manualButton = find.byKey(const ValueKey('rack-manual-upgrade-m1'));
  final manualPopover = find.byKey(
    const ValueKey('rack-manual-upgrade-popover'),
  );

  void expectFocusOn(Finder trigger) {
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused, isNotNull);
    expect(
      find.ancestor(
        of: find.byElementPredicate((e) => e == focused),
        matching: trigger,
      ),
      findsWidgets,
    );
  }

  for (final (name, size, phone) in [
    ('desktop', const Size(1400, 900), false),
    ('narrow desktop window', const Size(390, 844), false),
    ('phone', const Size(390, 844), true),
  ]) {
    testWidgets('manual upgrade opens the command in a popover, not the page '
        '($name)', (t) async {
      final opened = await openRack(
        t,
        _computer(supported: false),
        size: size,
        phone: phone,
      );
      expect(manualButton, findsOneWidget);
      expect(manualPopover, findsNothing);
      await t.ensureVisible(manualButton);
      await t.tap(manualButton);
      await t.pumpAndSettle();
      expect(opened, isEmpty);
      expect(manualPopover, findsOneWidget);
      expect(
        find.descendant(
          of: manualPopover,
          matching: find.textContaining(
            "v1.0.47 is available. This computer can't be upgraded from the web",
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: manualPopover,
          matching: find.byType(RaftCopyableCode),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: manualPopover,
          matching: find.text('Install guide'),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('Esc closes the manual upgrade popover and focus returns to its '
      'button', (t) async {
    await openRack(t, _computer(supported: false));
    await t.tap(manualButton);
    await t.pumpAndSettle();
    expect(manualPopover, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(manualPopover, findsNothing);
    expectFocusOn(manualButton);
  });

  testWidgets('a press outside closes the manual upgrade popover', (t) async {
    final opened = await openRack(t, _computer(supported: false));
    await t.tap(manualButton);
    await t.pumpAndSettle();
    await t.tapAt(const Offset(4, 880));
    await t.pumpAndSettle();
    expect(manualPopover, findsNothing);
    expect(opened, isEmpty);
  });

  final failureHint = find.byKey(
    const ValueKey('rack-upgrade-failure-hint-m1'),
  );
  final failurePopover = find.byKey(
    const ValueKey('rack-upgrade-failure-hint-popover'),
  );
  final repairHint = find.byKey(const ValueKey('rack-repair-hint-m1'));
  final repairPopover = find.byKey(const ValueKey('rack-repair-hint-popover'));
  final upgrade = find.byKey(const ValueKey('rack-upgrade-m1'));

  testWidgets('a failed web upgrade puts a hint button before Upgrade; its '
      'popover names the unit and the install command', (t) async {
    await openRack(t, _computer(request: _failed));
    expect(upgrade, findsOneWidget);
    expect(failureHint, findsOneWidget);
    expect(repairHint, findsNothing);
    expect(t.getTopLeft(failureHint).dx, lessThan(t.getTopLeft(upgrade).dx));
    await t.tap(failureHint);
    await t.pumpAndSettle();
    expect(failurePopover, findsOneWidget);
    expect(find.textContaining('raft.service'), findsWidgets);
    expect(
      find.descendant(
        of: failurePopover,
        matching: find.byType(RaftCopyableCode),
      ),
      findsWidgets,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(failurePopover, findsNothing);
    expectFocusOn(failureHint);
  });

  testWidgets('a repair recommendation puts its hint button before Upgrade', (
    t,
  ) async {
    await openRack(t, _computer(repair: true));
    expect(upgrade, findsOneWidget);
    expect(repairHint, findsOneWidget);
    expect(failureHint, findsNothing);
    await t.tap(repairHint);
    await t.pumpAndSettle();
    expect(repairPopover, findsOneWidget);
    expect(
      find.descendant(
        of: repairPopover,
        matching: find.textContaining('Recommended: run the install command'),
      ),
      findsOneWidget,
    );
    await t.tapAt(const Offset(4, 880));
    await t.pumpAndSettle();
    expect(repairPopover, findsNothing);
  });

  testWidgets('the failure hint wins when both apply', (t) async {
    await openRack(t, _computer(request: _failed, repair: true));
    expect(failureHint, findsOneWidget);
    expect(repairHint, findsNothing);
  });

  testWidgets('no hint button without a failure or a repair recommendation', (
    t,
  ) async {
    await openRack(t, _computer());
    expect(upgrade, findsOneWidget);
    expect(failureHint, findsNothing);
    expect(repairHint, findsNothing);
  });

  testWidgets('whoever may not manage the computer sees neither', (t) async {
    await openRack(
      t,
      _computer(supported: false, manager: false),
      role: 'member',
    );
    expect(manualButton, findsNothing);
    expect(failureHint, findsNothing);
  });
}
