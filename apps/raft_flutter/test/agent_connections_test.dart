// Web AgentConnections: "Connected accounts" of a cloud agent (GitHub): status,
// the start through the browser, switching connectors, detaching and
// disconnecting, and what each refusal says.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/agent_connections.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_connections_section.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, dynamic> _connector(
  String id,
  String account, {
  String? creator,
  bool current = false,
  bool canManage = true,
}) => {
  'id': id,
  'account': account,
  'createdAt': '2026-10-20T08:00:00.000Z',
  'creator': creator == null
      ? null
      : {'id': 'u-$creator', 'name': creator, 'displayName': null},
  'current': current,
  'canManage': canManage,
};

Map<String, dynamic> _status({
  bool connected = false,
  String? account,
  String? connectorId,
  List<Map<String, dynamic>> connectors = const [],
  List<String> scopes = const [],
}) => {
  'provider': 'github',
  'supported': true,
  'connected': connected,
  'account': account,
  'connectedAt': connected ? '2026-10-21T08:00:00.000Z' : null,
  'connectedBy': connected ? {'id': 'u1', 'name': 'alice'} : null,
  'scopes': scopes,
  'connectorId': connectorId,
  'connectors': connectors,
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
  }
  Object? status = _status();
  Object? start = {
    'url': 'https://provider.example.test/oauth/start?x=1',
    'expiresAt': '2026-10-24T09:10:00.000Z',
    'scopes': ['public_repo'],
  };
  final failures = <String, Object>{};
  final calls = <String>[];
  final bodies = <String, Object?>{};
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
    final key = '$method $path';
    calls.add(key);
    bodies[key] = data;
    final failure = failures[key];
    if (failure != null) throw failure;
    if (key == 'GET /agents/a1/connections/github') {
      final out = status;
      if (out is Exception) throw out;
      return out;
    }
    if (key == 'POST /agents/a1/connections/github') return start;
    return {'ok': true};
  }
}

RaftApiException _fail(int status, {String? code, String? providerMessage}) =>
    RaftApiException.response(
      'failed',
      status: status,
      body: {
        'error': 'failed',
        'code': ?code,
        'providerMessage': ?providerMessage,
      },
    );

void main() {
  late _Client c;
  late WorkspaceController w;
  late List<Uri> opened;

  Future<void> mount(WidgetTester t) async {
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final client = c..selectServer('s');
    final controller = w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'acme'});
    addTearDown(() async {
      controller.dispose();
      await client.stream.close();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentConnectionsSection(
              controller: w,
              agentId: 'a1',
              openExternal: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  setUp(() {
    c = _Client();
    opened = [];
  });

  Finder k(String key) => find.byKey(ValueKey(key));

  group('what is shown', () {
    testWidgets('not connected: the status line and Connect', (t) async {
      await mount(t);
      expect(find.text('Connected accounts'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(k('agent-connection-detach'), findsNothing);
      expect(k('agent-connection-github-connectors'), findsNothing);
    });

    testWidgets('connected: account, who, when and scopes', (t) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        scopes: ['public_repo', 'read:user'],
      );
      await mount(t);
      expect(find.text('Connected as octocat'), findsOneWidget);
      expect(find.text('by @alice'), findsOneWidget);
      expect(find.text('Scopes: public_repo, read:user'), findsOneWidget);
      expect(find.text('Connect a new GitHub account'), findsOneWidget);
      expect(find.text('Remove from this agent'), findsOneWidget);
    });

    testWidgets("a shared connector reads as its creator's", (t) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector('k1', 'octocat', creator: 'bob', current: true),
        ],
      );
      await mount(t);
      expect(find.text("Uses @bob's GitHub (octocat)"), findsOneWidget);
      expect(find.text('Connected as octocat'), findsNothing);
      expect(find.text('Disconnect this connection'), findsOneWidget);
    });

    testWidgets('disconnect is only for who may manage the connector', (
      t,
    ) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector(
            'k1',
            'octocat',
            creator: 'bob',
            current: true,
            canManage: false,
          ),
        ],
      );
      await mount(t);
      expect(find.text('Disconnect this connection'), findsNothing);
      expect(find.text('Remove from this agent'), findsOneWidget);
    });

    testWidgets('hidden when unsupported, forbidden, absent or disabled', (
      t,
    ) async {
      for (final out in <Object>[
        {'provider': 'github', 'supported': false},
        _fail(403),
        _fail(404),
        _fail(409),
      ]) {
        c = _Client()..status = out;
        await mount(t);
        expect(find.text('Connected accounts'), findsNothing, reason: '$out');
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a 500 or 429 warns instead of hiding', (t) async {
      c.status = _fail(500);
      await mount(t);
      expect(find.text('Could not load connections.'), findsOneWidget);
    });

    testWidgets('a provider that lost the agent says to recreate it', (
      t,
    ) async {
      c.status = _fail(409, code: agentMissingAtProviderCode);
      await mount(t);
      expect(
        find.text(
          'This cloud agent no longer exists in the cloud. Connections are unavailable; recreate the agent.',
        ),
        findsOneWidget,
      );
    });
  });

  group('connecting', () {
    testWidgets('Connect asks the server, reviews the scopes, then opens the '
        'browser', (t) async {
      await mount(t);
      await t.tap(k('agent-connection-connect'));
      await t.pumpAndSettle();
      expect(c.bodies['POST /agents/a1/connections/github'], isEmpty);
      expect(opened, isEmpty, reason: 'nothing opens before the review');
      expect(
        find.text(
          'GitHub will ask you to grant: public_repo. The link is single-use and expires in 10 minutes.',
        ),
        findsOneWidget,
      );
      expect(k('agent-connection-connect'), findsNothing);
      await t.tap(k('agent-connection-continue'));
      await t.pumpAndSettle();
      expect(opened.single.host, 'provider.example.test');
      expect(k('agent-connection-github-pending'), findsNothing);
    });

    testWidgets('private repositories are requested and said', (t) async {
      c.start = {
        'url': 'https://provider.example.test/oauth/start?x=2',
        'expiresAt': '2026-10-24T09:10:00.000Z',
        'scopes': ['repo'],
      };
      await mount(t);
      await t.tap(k('agent-connection-private'));
      await t.pumpAndSettle();
      await t.tap(k('agent-connection-connect'));
      await t.pumpAndSettle();
      expect(c.bodies['POST /agents/a1/connections/github'], {
        'access': 'private',
      });
      expect(find.textContaining('grant: repo.'), findsOneWidget);
    });

    testWidgets('Cancel drops the review and the link', (t) async {
      await mount(t);
      await t.tap(k('agent-connection-connect'));
      await t.pumpAndSettle();
      await t.tap(k('agent-connection-cancel'));
      await t.pumpAndSettle();
      expect(k('agent-connection-github-pending'), findsNothing);
      expect(opened, isEmpty);
      expect(k('agent-connection-connect'), findsOneWidget);
    });

    testWidgets('back from the browser, the status is read again', (t) async {
      await mount(t);
      await t.tap(k('agent-connection-connect'));
      await t.pumpAndSettle();
      await t.tap(k('agent-connection-continue'));
      await t.pumpAndSettle();
      final before = c.calls.where((x) => x.startsWith('GET ')).length;
      c.status = _status(connected: true, account: 'octocat');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(c.calls.where((x) => x.startsWith('GET ')).length, before + 1);
      expect(find.text('Connected as octocat'), findsOneWidget);
      // Resuming again without a round trip in flight reads nothing.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(c.calls.where((x) => x.startsWith('GET ')).length, before + 1);
    });

    testWidgets('a refused start says why, in the provider\'s words', (
      t,
    ) async {
      await mount(t);
      c.failures['POST /agents/a1/connections/github'] = _fail(
        502,
        providerMessage: 'The agent needs exactly one GitHub plugin mount',
      );
      await t.tap(k('agent-connection-connect'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'The provider refused: The agent needs exactly one GitHub plugin mount',
        ),
        findsOneWidget,
      );
      expect(opened, isEmpty);
    });

    testWidgets('a start with no reason says to try again', (t) async {
      await mount(t);
      c.failures['POST /agents/a1/connections/github'] = _fail(500);
      await t.tap(k('agent-connection-connect'));
      await t.pumpAndSettle();
      expect(
        find.text('Could not start the connection. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('an unusable start answer opens nothing', (t) async {
      c.start = {'url': 'javascript:alert(1)', 'scopes': []};
      await mount(t);
      await t.tap(k('agent-connection-connect'));
      await t.pumpAndSettle();
      expect(k('agent-connection-github-pending'), findsNothing);
      expect(opened, isEmpty);
      expect(
        find.text('Could not start the connection. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('connectors', () {
    Map<String, dynamic> two({bool secondManageable = true}) => _status(
      connected: true,
      account: 'octocat',
      connectorId: 'k1',
      connectors: [
        _connector('k1', 'octocat', creator: 'bob', current: true),
        _connector(
          'k2',
          'hubot',
          creator: 'carol',
          canManage: secondManageable,
        ),
      ],
    );

    testWidgets('picking another connector switches the agent', (t) async {
      c.status = two();
      await mount(t);
      await t.tap(k('agent-connection-select'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(RaftComboboxPanel),
          matching: find.text('hubot · created by @carol'),
        ),
      );
      await t.pumpAndSettle();
      expect(c.bodies['PUT /agents/a1/connections/github'], {
        'connectorId': 'k2',
      });
    });

    testWidgets('a connector the viewer may not assign is never sent', (
      t,
    ) async {
      c.status = two(secondManageable: false);
      await mount(t);
      await t.tap(k('agent-connection-select'));
      await t.pumpAndSettle();
      expect(
        find.text(
          "Only the connection's creator or a server admin can assign it",
        ),
        findsOneWidget,
      );
      await t.tap(
        find.descendant(
          of: find.byType(RaftComboboxPanel),
          matching: find.text('hubot · created by @carol'),
        ),
        warnIfMissed: false,
      );
      await t.pumpAndSettle();
      expect(c.calls, isNot(contains('PUT /agents/a1/connections/github')));
    });

    testWidgets('a refused switch says so', (t) async {
      c.status = two();
      await mount(t);
      c.failures['PUT /agents/a1/connections/github'] = _fail(403);
      await t.tap(k('agent-connection-select'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(RaftComboboxPanel),
          matching: find.text('hubot · created by @carol'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Could not switch the connection. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('Remove from this agent asks first, then detaches', (t) async {
      c.status = two();
      await mount(t);
      await t.tap(k('agent-connection-detach'));
      await t.pumpAndSettle();
      expect(find.text('Remove GitHub from this agent?'), findsOneWidget);
      expect(
        find.text(
          'This agent stops using GitHub as octocat. The connection stays available to other agents on this server.',
        ),
        findsOneWidget,
      );
      expect(c.calls, isNot(contains('DELETE /agents/a1/connections/github')));
      c.status = _status();
      await t.tap(k('agent-connection-detach-confirm'));
      await t.pumpAndSettle();
      expect(c.calls, contains('DELETE /agents/a1/connections/github'));
      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('Disconnect asks first and names every agent it affects', (
      t,
    ) async {
      c.status = two();
      await mount(t);
      await t.tap(k('agent-connection-disconnect'));
      await t.pumpAndSettle();
      expect(find.text('Disconnect this GitHub connection?'), findsOneWidget);
      expect(
        find.textContaining(
          'octocat is disconnected for every agent on this server that uses it',
        ),
        findsOneWidget,
      );
      c.status = _status();
      await t.tap(k('agent-connection-disconnect-confirm'));
      await t.pumpAndSettle();
      expect(
        c.calls,
        contains('DELETE /agents/a1/connections/github/connectors/k1'),
      );
      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('a partial disconnect is not a success; Retry finishes it', (
      t,
    ) async {
      c.status = two();
      await mount(t);
      c.failures['DELETE /agents/a1/connections/github/connectors/k1'] = _fail(
        502,
        code: connectorDisconnectPartialCode,
      );
      await t.tap(k('agent-connection-disconnect'));
      await t.pumpAndSettle();
      await t.tap(k('agent-connection-disconnect-confirm'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Disconnect partially completed: some agents still use this connection. Retry to finish.',
        ),
        findsOneWidget,
      );
      expect(find.text("Uses @bob's GitHub (octocat)"), findsOneWidget);
      c.failures.clear();
      c.status = _status();
      await t.tap(k('agent-connection-retry'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Disconnect partially completed: some agents still use this connection. Retry to finish.',
        ),
        findsNothing,
      );
      expect(find.text('Not connected'), findsOneWidget);
    });
  });

  test('the connection paths and the refusal reason', () {
    expect(agentConnectionPath('a/b'), '/agents/a%2Fb/connections/github');
    expect(
      agentConnectorPath('a1', 'k 1'),
      '/agents/a1/connections/github/connectors/k%201',
    );
    expect(
      providerRefusalReason(_fail(502, providerMessage: ' why ')),
      ' why ',
    );
    expect(providerRefusalReason(_fail(502, providerMessage: '  ')), isNull);
    expect(providerRefusalReason(StateError('x')), isNull);
    expect(AgentConnectionStatus.parse({'supported': false}), isNull);
  });
}
