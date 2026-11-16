import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _agent = <String, dynamic>{
  'id': 'a',
  'name': 'alpha',
  'displayName': 'Alpha Agent',
  'status': 'active',
  'runtime': 'codex',
  'model': 'alpha-model-1',
  'activity': 'offline',
  'machineId': 'm1',
  'creatorType': 'user',
  'creatorId': 'alice',
  'createdAt': '2026-10-13T08:00:00.000Z',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, {required this.agent, this.startRefusal});
  final Map<String, dynamic> agent;

  /// What `POST /agents/a/start` answers with (null: it succeeds).
  final RaftApiException? startRefusal;
  var machineStatus = 'online';
  final calls = <(String, String)>[];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/agents') return [agent];
    if (path == '/agents/a') return agent;
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'm1',
            'name': 'Studio Mac',
            'status': machineStatus,
            'isComputer': true,
          },
        ],
      };
    }
    if (path == '/agents/a/skills') return {'global': [], 'workspace': []};
    return [];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    calls.add((method, path));
    if (path == '/agents/a/start' && startRefusal != null) {
      // The server refused because the Computer is offline: its own list says
      // so from here on.
      if (startRefusal!.details['code'] == 'machine_offline') {
        machineStatus = 'offline';
      }
      throw startRefusal!;
    }
    return {};
  }
}

Future<_Workspace> _open(
  WidgetTester tester, {
  Map<String, dynamic> agent = _agent,
  RaftApiException? refusal,
  String role = 'owner',
  Size size = const Size(900, 1600),
  TargetPlatform platform = TargetPlatform.linux,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = _Client()..selectServer('s');
  final w = _Workspace(client, agent: agent, startRefusal: refusal)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': role});
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(
        body: FleetDetail(
          controller: w,
          computers: false,
          initial: const {'id': 'a'},
          onClose: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return w;
}

Future<void> _tap(WidgetTester tester, String text) async {
  // Start sits in a lazily built list below the fold: scroll the panel until
  // it is built, then bring it fully into view through every enclosing
  // scrollable (the first pass can stop with it just past the screen edge).
  final finder = find.text(text);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('fleet-detail')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

const _inlineStartStop = Key('agent-profile-inline-start-stop');
const _inlineRestart = Key('agent-profile-inline-restart-reset');

/// Web `noteMachineOfflineRefusal` / `handleStartSettled`: a Start the server
/// refuses with `machine_offline` marks that Computer offline, so the profile's
/// offline card takes Start's place and no error strip shows; any other refusal
/// says why in the strip, with the server's words or "Couldn't start the agent.
/// Try again."
void main() {
  for (final (label, size, platform) in [
    ('fold 856x944', const Size(856, 944), TargetPlatform.android),
    ('fold 944x856', const Size(944, 856), TargetPlatform.android),
    ('narrow desktop 390x844', const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('a Start refused as machine_offline shows the card ($label)', (
      tester,
    ) async {
      final w = await _open(
        tester,
        size: size,
        platform: platform,
        refusal: RaftApiException.response(
          'raw refusal',
          status: 409,
          body: {'error': 'raw refusal', 'code': 'machine_offline'},
        ),
      );
      expect(
        find.byKey(const ValueKey('agent-computer-offline-card')),
        findsNothing,
      );
      await _tap(tester, 'Start agent');
      expect(w.calls, contains(('POST', '/agents/a/start')));

      // The card replaces Start; no strip says anything.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('agent-computer-offline-card')),
        -200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('fleet-detail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.byKey(const ValueKey('agent-computer-offline-card')),
        findsOneWidget,
      );
      expect(find.text('Start agent'), findsNothing);
      expect(find.byKey(_inlineRestart), findsNothing);
      // The agent was not stopped by a person: it waits for its Computer, so
      // the header offers Stop (never Start) while it is offline.
      expect(find.byTooltip('Start agent'), findsNothing);
      // (Inline buttons fold into the menu on a narrow window.)
      if (size.width > 600) {
        expect(find.byTooltip('Stop agent'), findsOneWidget);
      }
      expect(find.text('raw refusal'), findsNothing);
      expect(find.textContaining('is offline'), findsWidgets);
    });
  }

  testWidgets('any other refusal says why in the strip', (tester) async {
    await _open(
      tester,
      refusal: RaftApiException.response(
        'Quota reached',
        status: 409,
        body: {'error': 'Quota reached', 'code': 'quota'},
      ),
    );
    await _tap(tester, 'Start agent');
    expect(find.text('Quota reached'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-computer-offline-card')),
      findsNothing,
    );
    expect(find.text('Start agent'), findsWidgets);
  });

  testWidgets('a member sees Start and Restart, never Stop', (tester) async {
    await _open(
      tester,
      role: 'member',
      agent: {
        ..._agent,
        'creatorId': 'bob',
        'activity': 'online',
        'status': 'active',
      },
    );
    expect(find.byKey(_inlineRestart), findsOneWidget);
    // Online: Start is not offered, and without stopAgents neither is Stop.
    expect(find.byKey(_inlineStartStop), findsNothing);
  });

  testWidgets('the creator of an online agent can Stop it', (tester) async {
    await _open(tester, agent: {..._agent, 'activity': 'online'});
    expect(find.byKey(_inlineStartStop), findsOneWidget);
    await _tap(tester, 'Stop agent');
    expect(
      find.text('Stop "Alpha Agent"? The agent will stop processing messages.'),
      findsOneWidget,
    );
  });
}
