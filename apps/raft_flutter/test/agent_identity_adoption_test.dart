// Web AgentDetailPanel "Update official identity": the onboarding agent can
// adopt Raft's official identity after a review; admin role is called out.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _preview({
  bool canAdopt = true,
  List<Map<String, dynamic>>? changes,
}) => {
  'canAdopt': canAdopt,
  'changes':
      changes ??
      [
        {
          'field': 'displayName',
          'label': 'Display name',
          'before': 'Helper',
          'after': 'Cindy',
        },
        {
          'field': 'role',
          'label': 'Role',
          'before': '',
          'after': 'Onboarding Assistant',
        },
      ],
  'currentIdentity': <String, dynamic>{},
  'officialIdentity': <String, dynamic>{},
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  Object? preview = _preview();
  Object? adopted;
  final calls = <String>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final row = <String, dynamic>{
    'id': 'cindy-1',
    'name': 'Helper',
    'displayName': 'Helper',
    'description': 'Helps',
    'status': 'active',
    'runtime': 'codex',
    'model': 'gpt-5',
    'machineId': 'm1',
    'creatorType': 'user',
    'creatorId': 'alice',
  };
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    calls.add('$method $path');
    if (path == '/agents') return [row];
    if (path == '/agents/cindy-1') return row;
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    if (path == '/agents/cindy-1/onboarding-identity-adoption') {
      if (method == 'POST') {
        final out =
            adopted ??
            {
              ..._preview(canAdopt: false, changes: []),
              'appliedChanges': [],
              'agent': row,
            };
        if (out is Exception) throw out;
        return out;
      }
      final out = preview;
      if (out is Exception) throw out;
      return out;
    }
    return [];
  }
}

Future<_Client> _pump(
  WidgetTester tester, {
  _Client? client,
  String? onboardingAgentId = 'cindy-1',
  String role = 'owner',
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = (client ?? _Client())..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({
      'id': 's',
      'name': 'Fixture',
      'role': role,
      'onboardingAgentId': ?onboardingAgentId,
    });
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: FleetDetail(
          key: UniqueKey(),
          controller: w,
          computers: false,
          initial: c.row,
          onClose: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  const adoption = 'GET /agents/cindy-1/onboarding-identity-adoption';
  final button = find.byKey(const ValueKey('agent-identity-adoption-button'));

  testWidgets('only the onboarding agent reads the preview', (t) async {
    final c = await _pump(t, onboardingAgentId: 'someone-else');
    expect(button, findsNothing);
    expect(c.calls, isNot(contains(adoption)));
    final none = await _pump(t, onboardingAgentId: null);
    expect(none.calls, isNot(contains(adoption)));
  });

  testWidgets('a manager of the onboarding agent can update its identity', (
    t,
  ) async {
    final c = await _pump(t);
    expect(c.calls, contains(adoption));
    expect(find.text('Update official identity'), findsOneWidget);
  });

  testWidgets('nothing to adopt shows no button', (t) async {
    final c = _Client()..preview = _preview(canAdopt: false, changes: []);
    await _pump(t, client: c);
    expect(button, findsNothing);
  });

  testWidgets('a viewer who cannot manage the agent reads nothing', (t) async {
    final c = _Client()..row['creatorId'] = 'bob';
    await _pump(t, client: c, role: 'member');
    expect(button, findsNothing);
    expect(c.calls, isNot(contains(adoption)));
  });

  testWidgets('a failed read says so', (t) async {
    final c = _Client()..preview = RaftApiException('down', status: 500);
    await _pump(t, client: c);
    expect(button, findsNothing);
    expect(find.text('Failed to load official identity'), findsOneWidget);
  });

  testWidgets('the review lists each field, before to after, and Blank', (
    t,
  ) async {
    await _pump(t);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-identity-adoption-dialog')),
        matching: find.text('Update official identity'),
      ),
      findsOneWidget,
    );
    expect(find.text('Review official identity changes'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Helper'), findsWidgets);
    expect(find.text('Cindy'), findsOneWidget);
    expect(find.text('Blank'), findsOneWidget, reason: 'an empty before');
    expect(find.text('Onboarding Assistant'), findsOneWidget);
    expect(
      find.text(
        'You can customize the agent again after updating its identity.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('identity-grants-admin')), findsNothing);
    expect(find.text('Update identity'), findsOneWidget);
  });

  testWidgets('Confirm applies it and the button goes away', (t) async {
    final c = await _pump(t);
    await t.tap(button);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('agent-identity-adoption-confirm')));
    await t.pumpAndSettle();
    expect(
      c.calls,
      contains('POST /agents/cindy-1/onboarding-identity-adoption'),
    );
    expect(find.text('Update official identity'), findsNothing);
    expect(button, findsNothing);
  });

  testWidgets('Cancel applies nothing', (t) async {
    final c = await _pump(t);
    await t.tap(button);
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(
      c.calls,
      isNot(contains('POST /agents/cindy-1/onboarding-identity-adoption')),
    );
    expect(button, findsOneWidget);
  });

  testWidgets('granting the admin role is called out and named', (t) async {
    final c = _Client()
      ..preview = _preview(
        changes: [
          {
            'field': 'serverRole',
            'label': 'Server role',
            'before': 'member',
            'after': 'admin',
          },
        ],
      );
    await _pump(t, client: c);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Update identity and admin role'), findsOneWidget);
    expect(find.byKey(const ValueKey('identity-grants-admin')), findsOneWidget);
    expect(
      find.text('This will grant the onboarding agent admin permissions.'),
      findsOneWidget,
    );
    expect(find.text('Update identity and role'), findsOneWidget);
  });
}
