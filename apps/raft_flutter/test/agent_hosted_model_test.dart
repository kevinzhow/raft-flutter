// Web tests/agentHostedRuntimeModel.behavior.test.tsx: the hosted agent's
// "Model" card on the agent detail (GET/PUT /agents/:id/hosted-runtime/model).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_hosted_model.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hosted = <String, dynamic>{
  'provider': 'antiproton',
  'state': 'active',
  'syncPending': false,
};

Map<String, dynamic> _agent({
  Map<String, dynamic>? hosted = _hosted,
  String creator = 'alice',
}) => {
  'id': 'ext-1',
  'name': 'Hosted-Bot',
  'displayName': 'Hosted Bot',
  'description': 'Runs on a hosted runtime.',
  'status': 'active',
  'runtime': 'external',
  'model': 'external',
  'external': true,
  'creatorType': 'user',
  'creatorId': creator,
  'hostedRuntime': ?hosted,
};

Map<String, dynamic> _view({
  String? model = 'fast',
  String? label = 'Fast',
  String source = 'chosen',
  bool locked = false,
  String? defaultLabel = 'Balanced',
}) => {
  'models': [
    {'id': 'fast', 'label': 'Fast', 'provider': 'p'},
    {'id': 'smart', 'label': 'Smart', 'provider': 'p'},
  ],
  'default': 'balanced',
  'defaultLabel': defaultLabel,
  'model': model,
  'label': label,
  'source': source,
  'locked': locked,
};

class _Client extends RaftClient {
  _Client({Map<String, dynamic>? row})
    : row = row ?? _agent(),
      super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  Map<String, dynamic> row;
  final calls = <String>[];
  final puts = <Object?>[];
  Object? getModel = _view();
  Object? putModel = _view(model: 'smart', label: 'Smart');
  Completer<void>? putGate;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
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
    if (path == '/agents/ext-1') return row;
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    if (path == '/agents/ext-1/external-status') {
      return {'setupState': 'credential_minted'};
    }
    if (path == '/agents/ext-1/credentials') {
      return {'agentId': 'ext-1', 'credentials': []};
    }
    if (path == '/agents/ext-1/hosted-runtime/model') {
      if (method == 'PUT') {
        puts.add((data as Map)['model']);
        await putGate?.future;
        final out = putModel;
        if (out is Exception) throw out;
        return out;
      }
      final out = getModel;
      if (out is Exception) throw out;
      return out;
    }
    return [];
  }
}

Future<_Client> _pump(
  WidgetTester tester, {
  _Client? client,
  String role = 'owner',
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = (client ?? _Client())..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': role});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.brutal),
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

/// A row of the open list (the field's own placeholder repeats the choice).
Finder _row(String text) => find.descendant(
  of: find.byType(RaftComboboxPanel),
  matching: find.text(text),
);

Finder _k(String key) => find.byKey(ValueKey(key));
Finder _input() => find.descendant(
  of: _k('agent-hosted-runtime-model-select'),
  matching: find.byType(TextField),
);
String _field(WidgetTester tester) =>
    tester.widget<TextField>(_input()).controller!.text;
String _notice(WidgetTester tester) =>
    tester.widget<RaftCssText>(_k('agent-hosted-runtime-model-notice')).data!;

const _hint =
    'The agent uses the chosen model from its next turn; it does not restart.';

void main() {
  test('the model path encodes the agent id', () {
    expect(hostedRuntimeModelPath('a/b'), '/agents/a%2Fb/hosted-runtime/model');
  });

  testWidgets('an active hosted agent shows the current model and the hint', (
    tester,
  ) async {
    final client = await _pump(tester);
    expect(find.text('MODEL'), findsOneWidget);
    expect(_field(tester), 'Fast');
    expect(_notice(tester), _hint);
    expect(client.calls, contains('GET /agents/ext-1/hosted-runtime/model'));
  });

  testWidgets('the default row reads "Default ({label})" and is first', (
    tester,
  ) async {
    final client = _Client()
      ..getModel = _view(
        model: 'balanced',
        label: 'Balanced',
        source: 'default',
      );
    await _pump(tester, client: client);
    expect(_field(tester), 'Default (Balanced)');
    await tester.tap(_input());
    await tester.pumpAndSettle();
    expect(_row('Default (Balanced)'), findsOneWidget);
    expect(_row('Fast'), findsOneWidget);
    expect(_row('Smart'), findsOneWidget);
    // The default row leads the list.
    expect(
      tester.getTopLeft(_row('Default (Balanced)')).dy,
      lessThan(tester.getTopLeft(_row('Fast')).dy),
    );
  });

  testWidgets('without a default label the row reads "Provider default"', (
    tester,
  ) async {
    final client = _Client()
      ..getModel = _view(
        model: null,
        label: null,
        source: 'default',
        defaultLabel: null,
      );
    await _pump(tester, client: client);
    expect(_field(tester), 'Provider default');
  });

  testWidgets('not shown unless the agent is hosted, active and managed', (
    tester,
  ) async {
    for (final row in [
      _agent(hosted: null),
      _agent(hosted: {..._hosted, 'state': 'provisioning'}),
    ]) {
      final client = _Client(row: row);
      await _pump(tester, client: client);
      expect(_k('agent-hosted-runtime-model'), findsNothing);
      expect(client.calls.where((c) => c.contains('hosted-runtime')), isEmpty);
    }
    // A member who did not create the agent cannot manage it.
    final client = _Client(row: _agent(creator: 'bob'));
    await _pump(tester, client: client, role: 'member');
    expect(_k('agent-hosted-runtime-model'), findsNothing);
    expect(client.calls.where((c) => c.contains('hosted-runtime')), isEmpty);
  });

  testWidgets('a pick shows at once, saves, and says so', (tester) async {
    final client = _Client()..putGate = Completer<void>();
    await _pump(tester, client: client);
    await tester.tap(_input());
    await tester.pumpAndSettle();
    await tester.tap(_row('Smart'));
    await tester.pump();
    expect(client.puts, ['smart']);
    expect(_field(tester), 'Smart');
    expect(_notice(tester), 'Saving…');
    client.putGate!.complete();
    await tester.pumpAndSettle();
    expect(_field(tester), 'Smart');
    expect(
      _notice(tester),
      'Saved. The agent uses this model from its next turn.',
    );
  });

  testWidgets('choosing the default row saves null', (tester) async {
    final client = _Client()
      ..putModel = _view(
        model: 'balanced',
        label: 'Balanced',
        source: 'default',
      );
    await _pump(tester, client: client);
    await tester.tap(_input());
    await tester.pumpAndSettle();
    await tester.tap(_row('Default (Balanced)'));
    await tester.pumpAndSettle();
    expect(client.puts, [null]);
    expect(_field(tester), 'Default (Balanced)');
  });

  testWidgets('picking the current model does not call the server', (
    tester,
  ) async {
    final client = await _pump(tester);
    await tester.tap(_input());
    await tester.pumpAndSettle();
    await tester.tap(_row('Fast'));
    await tester.pumpAndSettle();
    expect(client.puts, isEmpty);
  });

  testWidgets('422 rolls the pick back, explains, and refreshes the list', (
    tester,
  ) async {
    final client = _Client()
      ..putModel = const RaftApiException('no', status: 422);
    await _pump(tester, client: client);
    client.getModel = _view(model: 'fast', label: 'Fast');
    await tester.tap(_input());
    await tester.pumpAndSettle();
    await tester.tap(_row('Smart'));
    await tester.pumpAndSettle();
    expect(_field(tester), 'Fast');
    expect(
      _notice(tester),
      'That model is no longer offered. The list has been refreshed; pick another one.',
    );
    expect(
      client.calls.where((c) => c == 'GET /agents/ext-1/hosted-runtime/model'),
      hasLength(2),
    );
  });

  testWidgets('409 on save says an administrator decides, and reloads', (
    tester,
  ) async {
    final client = _Client()
      ..putModel = const RaftApiException('locked', status: 409);
    await _pump(tester, client: client);
    client.getModel = _view(locked: true, source: 'admin');
    await tester.tap(_input());
    await tester.pumpAndSettle();
    await tester.tap(_row('Smart'));
    await tester.pumpAndSettle();
    // The reload now shows the read-only view.
    expect(_k('agent-hosted-runtime-model-locked'), findsOneWidget);
    expect(_input(), findsNothing);
  });

  testWidgets('any other failure rolls back with a retry message', (
    tester,
  ) async {
    final client = _Client()
      ..putModel = const RaftApiException('boom', status: 500);
    await _pump(tester, client: client);
    await tester.tap(_input());
    await tester.pumpAndSettle();
    await tester.tap(_row('Smart'));
    await tester.pumpAndSettle();
    expect(_field(tester), 'Fast');
    expect(_notice(tester), 'The model could not be changed. Try again.');
    expect(
      client.calls.where((c) => c == 'GET /agents/ext-1/hosted-runtime/model'),
      hasLength(1),
    );
  });

  testWidgets('an administrator-locked model is read only', (tester) async {
    final client = _Client()
      ..getModel = _view(
        model: 'p/x',
        label: 'Admin pick',
        source: 'admin',
        locked: true,
      );
    await _pump(tester, client: client);
    expect(find.text('Admin pick'), findsOneWidget);
    expect(
      find.text(
        "An administrator has set this agent's model, so it can't be changed here.",
      ),
      findsOneWidget,
    );
    expect(_input(), findsNothing);
  });

  testWidgets('an admin-set model that is not offered stays visible, marked', (
    tester,
  ) async {
    final client = _Client()
      ..getModel = _view(model: 'p/x', label: 'Admin pick', source: 'admin');
    await _pump(tester, client: client);
    expect(_field(tester), 'p/x');
    expect(
      find.text(
        'Set by the hosting administrator for now. Pick a model to use another one.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'The saved value p/x is not in the current list. It stays selected until you pick another.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a 4xx on load hides the card; 500 and 429 show the error', (
    tester,
  ) async {
    var client = _Client()..getModel = const RaftApiException('x', status: 409);
    await _pump(tester, client: client);
    expect(_k('agent-hosted-runtime-model'), findsNothing);
    client = _Client()..getModel = const RaftApiException('x', status: 403);
    await _pump(tester, client: client);
    expect(_k('agent-hosted-runtime-model'), findsNothing);
    for (final status in [500, 429]) {
      client = _Client()..getModel = RaftApiException('x', status: status);
      await _pump(tester, client: client);
      expect(_k('agent-hosted-runtime-model'), findsOneWidget);
      expect(
        find.text('The model settings could not be loaded. Try again later.'),
        findsOneWidget,
      );
    }
  });
}
