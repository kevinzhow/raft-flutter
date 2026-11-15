// Rack drag-to-move (Web ComputersRackList drag rules, RackMoveDialog): an
// agent slot dropped on another online computer opens the Move dialog with
// that computer preselected; invalid drops do nothing.
import 'dart:async';

import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> agents = [];
  final commands = <(String, String, dynamic)>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) {
      return {'machines': machines.map(Map<String, dynamic>.from).toList()};
    }
    if (path == '/agents') {
      return agents.map(Map<String, dynamic>.from).toList();
    }
    return <dynamic>[];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method, path, data));
    return <String, dynamic>{};
  }
}

Map<String, dynamic> computer(
  String id, [
  Map<String, dynamic> extra = const {},
]) => {
  'id': id,
  'name': id,
  'status': 'online',
  'isComputer': true,
  'computerVersion': '1.0.60',
  'os': 'linux',
  'osRelease': 'Ubuntu 26.04',
  'hostname': '$id.host',
  'runtimes': ['claude'],
  'userId': 'bob',
  ...extra,
};

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    ComputersRackPreferences.instance.resetForTests();
    c = _Client();
    w = _Workspace(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
  });
  tearDown(() async {
    ComputersRackPreferences.instance.resetForTests();
    DevicePreferences.reset();
  });

  Future<List<String>> open(
    WidgetTester t, {
    double width = 1400,
    bool phone = false,
  }) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final opened = <String>[];
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
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

  Future<void> drag(WidgetTester t, String agent, String onto) async {
    final from = t.getCenter(find.byKey(ValueKey('rack-slot-$agent')));
    final to = t.getCenter(find.byKey(ValueKey('rack-row-$onto')));
    final g = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 100));
    await g.moveTo(from + const Offset(20, 20));
    await t.pump(const Duration(milliseconds: 100));
    await g.moveTo(to);
    await t.pump(const Duration(milliseconds: 100));
    await g.up();
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
  }

  Map<String, dynamic> agent(String id, String machine) => {
    'id': id,
    'name': id,
    'machineId': machine,
    'runtime': 'claude',
    'creatorType': 'user',
    'creatorId': 'alice',
  };

  testWidgets('dropping an agent on another online computer opens the move', (
    t,
  ) async {
    w.machines = [computer('alpha'), computer('beta')];
    w.agents = [agent('a1', 'alpha')];
    ComputersRackPreferences.instance.setView(RackView.list);
    await open(t);
    await drag(t, 'a1', 'beta');
    expect(find.text('Move to Another Computer'), findsWidgets);
    // The dropped computer is the chosen target (the only other one here).
    expect(find.text('beta'), findsWidgets);
    expect(w.commands.where((c) => c.$1 == 'POST'), isEmpty);
  });

  testWidgets('an offline computer, or the agent\'s own, takes no drop', (
    t,
  ) async {
    w.machines = [
      computer('alpha'),
      computer('beta', {'status': 'offline'}),
    ];
    w.agents = [agent('a1', 'alpha')];
    ComputersRackPreferences.instance.setView(RackView.list);
    await open(t);
    await t.tap(find.byKey(const ValueKey('rack-group-offline')));
    await t.pumpAndSettle();
    await drag(t, 'a1', 'beta');
    expect(find.text('Move to Another Computer'), findsNothing);
    await drag(t, 'a1', 'alpha');
    expect(find.text('Move to Another Computer'), findsNothing);
  });

  testWidgets('an agent the viewer cannot manage is not draggable', (t) async {
    w.machines = [computer('alpha'), computer('beta')];
    w.agents = [
      {...agent('a1', 'alpha'), 'creatorId': 'someone-else'},
    ];
    w.server = RaftRecord({'id': 's', 'role': 'member', 'slug': 'fixture'});
    ComputersRackPreferences.instance.setView(RackView.list);
    await open(t);
    await drag(t, 'a1', 'beta');
    expect(find.text('Move to Another Computer'), findsNothing);
  });
}
