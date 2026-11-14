// The Computers page (Web v1.24 ComputersRackOverview / ComputersRackList /
// ComputersAttentionSummary / RackRowMenu / DeleteComputerDialog), on the
// app's real entity directory with a fake server.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_model.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_preferences.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
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
    if (path == '/agents')
      return agents.map(Map<String, dynamic>.from).toList();
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

  testWidgets(
    'counts, Mine first, the folded Offline section, and a row opens its computer',
    (t) async {
      w.machines = [
        computer('beta'),
        computer('alpha', {'computerAttachedByCurrentUser': true}),
        computer('gone', {'status': 'offline'}),
      ];
      w.agents = [
        {'id': 'a1', 'name': 'one', 'machineId': 'beta'},
        {'id': 'a2', 'name': 'two', 'machineId': 'beta'},
      ];
      ComputersRackPreferences.instance.setView(RackView.list);
      final opened = await open(t);
      expect(find.text('3 computers · 2 online · 2 agents'), findsOneWidget);
      // The viewer's own computer leads; the offline one waits folded.
      final alpha = t.getTopLeft(find.byKey(const ValueKey('rack-row-alpha')));
      final beta = t.getTopLeft(find.byKey(const ValueKey('rack-row-beta')));
      expect(alpha.dy, lessThan(beta.dy));
      expect(find.byKey(const ValueKey('rack-group-offline')), findsOneWidget);
      expect(find.byKey(const ValueKey('rack-row-gone')), findsNothing);
      await t.tap(find.byKey(const ValueKey('rack-group-offline')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('rack-row-gone')), findsOneWidget);
      expect(find.text('Offline'), findsWidgets);
      expect(find.text('Public (no owner)'), findsNWidgets(3));
      expect(find.byKey(const ValueKey('rack-slot-a1')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('rack-row-name-beta')));
      expect(opened, ['beta']);
    },
  );

  testWidgets(
    'a search with no match says so; Clear all brings the list back',
    (t) async {
      w.machines = [computer('alpha'), computer('beta')];
      await open(t);
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('computers-rack-search')),
          matching: find.byType(EditableText),
        ),
        'zzz',
      );
      await t.pumpAndSettle();
      expect(find.text('No computers match'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('computers-rack-empty-clear')));
      await t.pumpAndSettle();
      expect(find.text('No computers match'), findsNothing);
      expect(find.byKey(const ValueKey('rack-row-alpha')), findsOneWidget);
      expect(ComputersRackPreferences.instance.query, '');
    },
  );

  testWidgets(
    'Group by name prefix keeps a group per shared prefix and Other last',
    (t) async {
      w.machines = [computer('gpu-1'), computer('gpu-2'), computer('solo')];
      ComputersRackPreferences.instance.setGroupBy(RackGroupBy.prefix);
      await open(t);
      expect(
        find.byKey(const ValueKey('rack-group-prefix:gpu')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rack-group-fallback:prefix')),
        findsOneWidget,
      );
      expect(find.text('2 computers'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('rack-group-prefix:gpu')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('rack-row-gpu-1')), findsNothing);
      expect(find.byKey(const ValueKey('rack-row-solo')), findsOneWidget);
    },
  );

  testWidgets(
    '#68: one item reads what, where, how many and the action; its link filters to Needs attention',
    (t) async {
      w.machines = [
        computer('laptop', {
          'versionGate': {
            'reason': 'computer_version_unsupported',
            'minVersion': '1.0.47',
          },
          'attention': {
            'count': 1,
            'items': [
              {
                'code': 'computer_update_required',
                'actor': 'computer_owner',
                'action': 'update_computer',
                'agentCount': 2,
              },
            ],
            'waitingAgents': 0,
          },
        }),
        computer('fine', {
          'attention': {'count': 0, 'items': [], 'waitingAgents': 0},
        }),
      ];
      final opened = await open(t);
      expect(find.text('Update required on laptop'), findsOneWidget);
      expect(find.text('2 agents'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(find.textContaining('1 need attention'), findsOneWidget);
      await t.tap(find.text('Update'));
      expect(opened, ['laptop']);
      await t.tap(find.byKey(const ValueKey('computers-attention-filter')));
      await t.pumpAndSettle();
      expect(
        ComputersRackPreferences.instance.status,
        RackStatusFilter.attention,
      );
      expect(find.byKey(const ValueKey('rack-row-fine')), findsNothing);
      expect(find.byKey(const ValueKey('rack-row-laptop')), findsOneWidget);
    },
  );

  testWidgets(
    'a member reads who acts instead of the action; waits get their own line',
    (t) async {
      w.server = RaftRecord({'id': 's', 'role': 'member', 'slug': 'fixture'});
      w.machines = [
        computer('laptop', {
          'attention': {
            'count': 1,
            'items': [
              {
                'actor': 'computer_owner',
                'actorName': 'Olive',
                'action': 'update_computer',
                'agentCount': 1,
              },
            ],
            'waitingAgents': 3,
          },
        }),
      ];
      await open(t);
      expect(find.text('Needs attention on laptop'), findsOneWidget);
      expect(find.text("1 agent can't run"), findsOneWidget);
      expect(find.text('Olive can update this computer'), findsOneWidget);
      expect(find.text('3 agents waiting'), findsOneWidget);
    },
  );

  testWidgets('Delete computer from the row menu says the agents must go first', (
    t,
  ) async {
    w.machines = [computer('busy')];
    w.agents = [
      {'id': 'a1', 'name': 'one', 'machineId': 'busy'},
    ];
    ComputersRackPreferences.instance.setView(RackView.list);
    await open(t);
    await t.tap(find.byKey(const ValueKey('rack-row-menu-busy')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete computer'));
    await t.pumpAndSettle();
    expect(find.text('Cannot delete computer'), findsOneWidget);
    expect(
      find.text(
        'This computer has 1 agent assigned. Remove all agents before deleting the computer.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(w.commands.where((c) => c.$1 == 'DELETE'), isEmpty);
  });

  testWidgets(
    'Delete computer confirms, then DELETEs; the own computer revokes its key first',
    (t) async {
      w.machines = [
        computer('mine', {'userId': 'alice'}),
      ];
      // Another person's agent does not block the owner's own delete.
      w.agents = [
        {
          'id': 'a1',
          'name': 'theirs',
          'machineId': 'mine',
          'creator': {'type': 'human', 'id': 'bob'},
        },
      ];
      ComputersRackPreferences.instance.setView(RackView.list);
      await open(t);
      await t.tap(find.byKey(const ValueKey('rack-row-menu-mine')));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete computer'));
      await t.pumpAndSettle();
      expect(
        find.text('Are you sure you want to delete "mine"?'),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(RaftButton, 'Delete computer').last);
      await t.pumpAndSettle();
      expect(
        [for (final c in w.commands) '${c.$1} ${c.$2}'],
        [
          'POST /servers/s/machines/mine/revoke-computer-key',
          'DELETE /servers/s/machines/mine',
        ],
      );
    },
  );

  testWidgets(
    'phone Computers is the rack; the attention list keeps its rows',
    (t) async {
      w.machines = [computer('alpha')];
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        w.dispose();
        await c.stream.close();
        await c.dispose();
      });
      Widget page(bool attention) => MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: FleetView(
            key: ValueKey(attention),
            controller: w,
            computers: true,
            attentionOnly: attention,
            onOpenDetail: (_) {},
          ),
        ),
      );
      await t.pumpWidget(page(false));
      await t.pumpAndSettle();
      expect(find.byType(ComputersRackView), findsOneWidget);
      expect(find.byKey(const ValueKey('rack-row-alpha')), findsOneWidget);
      await t.pumpWidget(page(true));
      await t.pumpAndSettle();
      expect(find.byType(ComputersRackView), findsNothing);
      expect(find.byType(RaftMobileComputerList), findsOneWidget);
    },
  );
}
