// Web AgentConnections (v1.24): "Connected accounts" of a cloud agent
// (GitHub): the state chip and the reconnect and scope banners, the account
// picker, Connect / Reconnect through the browser, Remove with Undo, the
// revoke-on-GitHub hint and what each refusal says. Every notice has its test:
// its action resolves it, it is gone after a reopen, and it is absent when it
// should not show.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool? assignable,
  String? oauthStatus,
  String? lastCheckError,
  String? lastCheckedAt,
  List<String>? scopes,
  List<String>? requestedScopes,
}) => {
  'id': id,
  'account': account,
  'createdAt': '2026-10-20T08:00:00.000Z',
  'creator': creator == null
      ? null
      : {'id': 'u-$creator', 'name': creator, 'displayName': null},
  'current': current,
  'canManage': canManage,
  'assignable': ?assignable,
  'oauthStatus': ?oauthStatus,
  'lastCheckError': ?lastCheckError,
  'lastCheckedAt': ?lastCheckedAt,
  'scopes': ?scopes,
  'requestedScopes': ?requestedScopes,
};

Map<String, dynamic> _status({
  bool connected = false,
  String? account,
  String? connectorId,
  List<Map<String, dynamic>> connectors = const [],
  List<String> scopes = const [],
  bool? canConnectNew,
  String? oauthStatus,
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
  'canConnectNew': ?canConnectNew,
  'oauthStatus': ?oauthStatus,
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

  /// A failure thrown once for the call (then cleared) when [sticky] is false.
  final failures = <String, Object>{};
  final sticky = <String>{};

  /// What a successful call answers, and what it does to the status.
  final answers = <String, Object?>{};
  final effects = <String, void Function()>{};
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
    final failure = sticky.contains(key) ? failures[key] : failures.remove(key);
    if (failure != null) throw failure;
    effects[key]?.call();
    if (key == 'GET /agents/a1/connections/github') {
      final out = status;
      if (out is Exception) throw out;
      return out;
    }
    if (key == 'POST /agents/a1/connections/github') return start;
    return answers.containsKey(key) ? answers[key] : {'ok': true};
  }
}

RaftApiException _fail(
  int status, {
  String? code,
  String? providerMessage,
  String error = 'failed',
  Map<String, dynamic> extra = const {},
}) => RaftApiException.response(
  error,
  status: status,
  body: {
    'error': error,
    'code': ?code,
    'providerMessage': ?providerMessage,
    ...extra,
  },
);

const _github = 'https://github.com/settings/applications';

/// A connected, healthy card with one connector the viewer manages.
Map<String, dynamic> _healthy({
  bool canManage = true,
  bool? assignable,
  List<String>? scopes = const ['public_repo'],
  List<String>? requested,
  String? oauthStatus,
  String? lastCheckError,
  String? lastCheckedAt,
}) => _status(
  connected: true,
  account: 'octocat',
  connectorId: 'k1',
  connectors: [
    _connector(
      'k1',
      'octocat',
      creator: 'bob',
      current: true,
      canManage: canManage,
      assignable: assignable,
      scopes: scopes,
      requestedScopes: requested,
      oauthStatus: oauthStatus,
      lastCheckError: lastCheckError,
      lastCheckedAt: lastCheckedAt,
    ),
  ],
);

void main() {
  late _Client c;
  late WorkspaceController w;
  late List<Uri> opened;
  late List<String> clipboard;

  Future<void> mount(
    WidgetTester t, {
    Size size = const Size(900, 2400),
    TargetPlatform? platform,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final client = c..selectServer('s');
    final controller = w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'acme'});
    addTearDown(() async {
      controller.dispose();
      await client.stream.close();
    });
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentConnectionsSection(
              controller: w,
              agentId: 'a1',
              agentName: 'Alpha',
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

  /// Leaves and opens the section again on the same server answers.
  Future<void> reopen(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await mount(t);
  }

  setUp(() {
    c = _Client();
    opened = [];
    clipboard = [];
  });

  Finder k(String key) => find.byKey(ValueKey(key));
  Future<void> settle(WidgetTester t) => t.pumpAndSettle();
  Future<void> tapKey(WidgetTester t, String key) async {
    await t.tap(k(key));
    await settle(t);
  }

  Future<void> openMenu(WidgetTester t) =>
      tapKey(t, 'agent-connection-github-menu');
  Future<void> tapText(WidgetTester t, String text) async {
    await t.tap(find.text(text).last);
    await settle(t);
  }

  Finder access(String kind) => k('agent-connection-github-access-$kind');

  group('the state chip', () {
    testWidgets('Not connected, with Connect new account', (t) async {
      await mount(t);
      expect(find.text('Connected accounts'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      expect(k('agent-connection-github-state-notConnected'), findsOneWidget);
      expect(find.text('Connect new account'), findsOneWidget);
      expect(k('agent-connection-github-menu'), findsNothing);
      expect(
        find.text(
          'Alpha works on repos, issues and pull requests as the GitHub account you choose.',
        ),
        findsOneWidget,
      );
      // Nothing is wrong, so nothing warns.
      expect(k('agent-connection-github-health'), findsNothing);
      expect(k('agent-connection-github-scopes-short'), findsNothing);
      expect(k('agent-connection-github-error'), findsNothing);
      expect(k('agent-connection-github-revoke-hint'), findsNothing);
    });

    testWidgets('Connected, quiet: no banner on a healthy connection', (
      t,
    ) async {
      c.status = _healthy(requested: ['public_repo']);
      await mount(t);
      expect(find.text('Connected'), findsOneWidget);
      expect(k('agent-connection-github-state-connected'), findsOneWidget);
      expect(find.textContaining('Created by bob · Oct 20'), findsOneWidget);
      expect(k('agent-connection-github-health'), findsNothing);
      expect(k('agent-connection-github-scopes-short'), findsNothing);
    });

    testWidgets('Needs reconnecting is the provider\'s oauthStatus', (t) async {
      c.status = _healthy(oauthStatus: 'error');
      await mount(t);
      expect(find.text('Needs reconnecting'), findsWidgets);
      expect(k('agent-connection-github-state-needsReconnect'), findsOneWidget);
      expect(k('agent-connection-github-state-connected'), findsNothing);
    });

    testWidgets('the status itself saying error also needs reconnecting', (
      t,
    ) async {
      c.status = _status(oauthStatus: 'error');
      await mount(t);
      expect(k('agent-connection-github-state-needsReconnect'), findsOneWidget);
      expect(k('agent-connection-github-health'), findsOneWidget);
      // No second "Connect new account" next to the Reconnect.
      expect(k('agent-connection-connect'), findsNothing);
    });
  });

  group('the reconnect banner', () {
    testWidgets('says why, when it last checked, and Reconnect resolves it', (
      t,
    ) async {
      final checked = DateTime.now()
          .subtract(const Duration(hours: 2))
          .toUtc()
          .toIso8601String();
      c.status = _healthy(
        oauthStatus: 'error',
        lastCheckError: 'Bad credentials',
        lastCheckedAt: checked,
        requested: ['repo'],
        scopes: ['public_repo'],
      );
      await mount(t);
      expect(
        find.text(
          'octocat needs reconnecting before Alpha can use GitHub again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Bad credentials'), findsOneWidget);
      expect(find.textContaining('Last checked '), findsOneWidget);
      // The scope-short banner waits while the connection is not healthy.
      expect(k('agent-connection-github-scopes-short'), findsNothing);
      await t.tap(find.text('Reconnect'));
      await settle(t);
      expect(find.text('Reconnect octocat'), findsOneWidget);
      // Requested private repositories last time: asked again.
      await tapText(t, 'Continue to GitHub');
      expect(c.bodies['POST /agents/a1/connections/github'], {
        'access': 'private',
        'connectorId': 'k1',
      });
      expect(opened.single.host, 'provider.example.test');
      expect(find.text('Reconnect octocat'), findsNothing);
      // Back from the browser the status says it is healthy: the banner is gone.
      c.status = _healthy(requested: ['repo'], scopes: ['repo']);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(k('agent-connection-github-health'), findsNothing);
      expect(find.text('Connected'), findsOneWidget);
      await reopen(t);
      expect(k('agent-connection-github-health'), findsNothing);
    });

    testWidgets('without the right to reconnect it says so and offers none', (
      t,
    ) async {
      c.status = _healthy(oauthStatus: 'error', canManage: false);
      await mount(t);
      expect(
        find.text(
          'octocat needs reconnecting before Alpha can use GitHub again. Only its creator or a server owner or admin can reconnect it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reconnect'), findsNothing);
    });
  });

  group('the scope-short banner', () {
    testWidgets('shows when GitHub granted less; Reconnect asks again', (
      t,
    ) async {
      c.status = _healthy(requested: ['repo'], scopes: ['public_repo']);
      await mount(t);
      expect(
        find.text(
          'GitHub granted less access than was requested. Reconnect to ask again.',
        ),
        findsOneWidget,
      );
      // The line that would contradict it is not shown.
      expect(access('public'), findsNothing);
      await t.tap(find.text('Reconnect'));
      await settle(t);
      await tapText(t, 'Continue to GitHub');
      expect(
        (c.bodies['POST /agents/a1/connections/github'] as Map)['access'],
        'private',
      );
      c.status = _healthy(requested: ['repo'], scopes: ['repo']);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(k('agent-connection-github-scopes-short'), findsNothing);
      await reopen(t);
      expect(k('agent-connection-github-scopes-short'), findsNothing);
    });

    testWidgets('never when nothing is missing or the lists are unknown', (
      t,
    ) async {
      for (final status in [
        _healthy(requested: ['public_repo'], scopes: ['repo']),
        _healthy(requested: ['repo'], scopes: []),
        _healthy(requested: null, scopes: ['public_repo']),
        _healthy(requested: ['repo'], scopes: null),
      ]) {
        c = _Client()..status = status;
        await mount(t);
        expect(
          k('agent-connection-github-scopes-short'),
          findsNothing,
          reason: '$status',
        );
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('no Reconnect for a connection the viewer does not manage', (
      t,
    ) async {
      c.status = _healthy(
        requested: ['repo'],
        scopes: ['public_repo'],
        canManage: false,
      );
      await mount(t);
      expect(k('agent-connection-github-scopes-short'), findsOneWidget);
      expect(find.text('Reconnect'), findsNothing);
    });
  });

  group('the access line', () {
    testWidgets('says what the connection can use, scopes in a tooltip', (
      t,
    ) async {
      c.status = _healthy(scopes: ['public_repo']);
      await mount(t);
      expect(find.text('Can use public repos only'), findsOneWidget);
      final tip = t.widget<RaftTooltip>(
        find.ancestor(of: access('public'), matching: find.byType(RaftTooltip)),
      );
      expect(tip.message, 'GitHub scopes: public_repo');
      await reopen(t);
      c.status = _healthy(scopes: ['repo', 'read:user']);
      await reopen(t);
      expect(find.text('Can use public and private repos'), findsOneWidget);
    });

    testWidgets('says nothing when the scopes are not recorded or empty', (
      t,
    ) async {
      for (final scopes in <List<String>?>[null, []]) {
        c = _Client()..status = _healthy(scopes: scopes);
        await mount(t);
        expect(find.textContaining('Can use'), findsNothing);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('the account picker', () {
    testWidgets('rows say state, access, creator and the forbidden reason', (
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
            scopes: ['repo'],
          ),
          _connector(
            'k2',
            'hubot',
            creator: 'carol',
            canManage: false,
            oauthStatus: 'error',
          ),
        ],
      );
      await mount(t);
      await t.tap(k('agent-connection-select'));
      await settle(t);
      expect(
        find.textContaining(
          'Can use public and private repos · Created by bob · Oct 20',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining("Needs reconnecting · Created by carol · Oct 20"),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          "Only the connection's creator or a server admin can assign it",
        ),
        findsOneWidget,
      );
    });

    testWidgets('a connector the viewer may not assign is never sent', (
      t,
    ) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector('k1', 'octocat', current: true),
          _connector('k2', 'hubot', canManage: false),
          _connector('k3', 'ghost', assignable: false),
        ],
      );
      await mount(t);
      for (final name in ['hubot', 'ghost']) {
        await t.tap(k('agent-connection-select'));
        await settle(t);
        await t.tap(find.text(name).last);
        await settle(t);
      }
      expect(c.calls.where((x) => x.startsWith('PUT')), isEmpty);
    });

    testWidgets('picking another connector switches the agent', (t) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector('k1', 'octocat', current: true),
          _connector('k2', 'hubot'),
        ],
      );
      await mount(t);
      c.status = _status(
        connected: true,
        account: 'hubot',
        connectorId: 'k2',
        connectors: [
          _connector('k1', 'octocat'),
          _connector('k2', 'hubot', current: true),
        ],
      );
      await t.tap(k('agent-connection-select'));
      await settle(t);
      await t.tap(find.text('hubot').last);
      await settle(t);
      expect(c.bodies['PUT /agents/a1/connections/github'], {
        'connectorId': 'k2',
      });
      expect(find.text('hubot'), findsOneWidget);
    });

    testWidgets('a refused switch says so, and Retry is not offered', (
      t,
    ) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector('k1', 'octocat', current: true),
          _connector('k2', 'hubot'),
        ],
      );
      c.failures['PUT /agents/a1/connections/github'] = _fail(500);
      await mount(t);
      await t.tap(k('agent-connection-select'));
      await settle(t);
      await t.tap(find.text('hubot').last);
      await settle(t);
      expect(
        find.text('Could not switch the connection. Try again.'),
        findsOneWidget,
      );
      // The next action clears it.
      await t.tap(k('agent-connection-select'));
      await settle(t);
      await t.tap(find.text('hubot').last);
      await settle(t);
      expect(k('agent-connection-github-error'), findsNothing);
    });
  });

  group('Connect new account', () {
    testWidgets('canConnectNew false: only the owner may; no button', (
      t,
    ) async {
      c.status = _status(canConnectNew: false);
      await mount(t);
      expect(
        find.text(
          "Only this agent's owner can connect a GitHub account to it.",
        ),
        findsOneWidget,
      );
      expect(find.text('Connect new account'), findsNothing);
    });

    testWidgets('the owner sees no such sentence', (t) async {
      c.status = _status(canConnectNew: true);
      await mount(t);
      expect(k('agent-connection-github-owner-only'), findsNothing);
      expect(find.text('Connect new account'), findsOneWidget);
    });

    testWidgets('connected: it sits in the menu, and the dialog continues', (
      t,
    ) async {
      c.status = _healthy();
      await mount(t);
      expect(k('agent-connection-connect'), findsNothing);
      await openMenu(t);
      await tapText(t, 'Connect new account');
      expect(
        find.text(
          'After you approve on GitHub, Alpha switches to the new connection.',
        ),
        findsOneWidget,
      );
      expect(find.text('Public repos only'), findsOneWidget);
      await t.tap(find.text('Public and private repos'));
      await settle(t);
      await tapText(t, 'Continue to GitHub');
      expect(c.bodies['POST /agents/a1/connections/github'], {
        'access': 'private',
      });
      expect(opened.single.toString(), startsWith('https://provider'));
      expect(k('agent-connection-connect-dialog'), findsNothing);
    });

    testWidgets('owner only: the menu has no Connect new account', (t) async {
      c.status = _healthy()..['canConnectNew'] = false;
      await mount(t);
      await openMenu(t);
      expect(find.text('Connect new account'), findsNothing);
      expect(find.text('Remove from Alpha'), findsOneWidget);
    });

    testWidgets('an unusable start answer opens nothing and says so', (
      t,
    ) async {
      c.start = {'url': 'javascript:alert(1)'};
      await mount(t);
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      expect(opened, isEmpty);
      expect(
        find.text('Could not start the connection. Try again.'),
        findsOneWidget,
      );
      expect(k('agent-connection-connect-dialog'), findsNothing);
    });
  });

  group('Remove from this agent', () {
    Map<String, dynamic> gone() => _status();

    testWidgets('no confirm when it can be undone; Undo restores it', (
      t,
    ) async {
      c.status = _healthy();
      c.effects['DELETE /agents/a1/connections/github'] = () =>
          c.status = gone();
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Remove from Alpha');
      expect(c.calls, contains('DELETE /agents/a1/connections/github'));
      expect(k('agent-connection-detach-dialog'), findsNothing);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Removed octocat from Alpha'), findsOneWidget);
      c.effects['PUT /agents/a1/connections/github'] = () =>
          c.status = _healthy();
      await tapText(t, 'Undo');
      expect(c.bodies['PUT /agents/a1/connections/github'], {
        'connectorId': 'k1',
      });
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('Undo is skipped when another connection was picked', (
      t,
    ) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector('k1', 'octocat', current: true),
          _connector('k2', 'hubot'),
        ],
      );
      c.effects['DELETE /agents/a1/connections/github'] = () =>
          c.status = _status(
            connectors: [
              _connector('k1', 'octocat'),
              _connector('k2', 'hubot'),
            ],
          );
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Remove from Alpha');
      c.status = _status(
        connected: true,
        account: 'hubot',
        connectorId: 'k2',
        connectors: [
          _connector('k1', 'octocat'),
          _connector('k2', 'hubot', current: true),
        ],
      );
      await t.tap(k('agent-connection-select'));
      await settle(t);
      await t.tap(find.text('hubot').last);
      await settle(t);
      expect(find.text('hubot'), findsOneWidget);
      // The removal's Undo is still on screen: it must not overwrite the pick.
      await tapText(t, 'Undo');
      expect(
        find.text('Not restored: Alpha already uses another connection.'),
        findsOneWidget,
      );
      expect(c.calls.where((x) => x.startsWith('PUT')).length, 1);
    });

    testWidgets('a failed Undo says so', (t) async {
      c.status = _healthy();
      c.effects['DELETE /agents/a1/connections/github'] = () =>
          c.status = gone();
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Remove from Alpha');
      c.failures['PUT /agents/a1/connections/github'] = _fail(500);
      await tapText(t, 'Undo');
      expect(
        find.text(
          'Could not restore the connection. Choose it again from the list.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('without the right to assign it again: confirm, naming who', (
      t,
    ) async {
      c.status = _healthy(canManage: false);
      c.effects['DELETE /agents/a1/connections/github'] = () =>
          c.status = gone();
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Remove from Alpha');
      expect(c.calls, isNot(contains('DELETE /agents/a1/connections/github')));
      expect(find.text('Remove GitHub from Alpha?'), findsOneWidget);
      expect(
        find.textContaining('only bob, who created it, or a server admin'),
        findsOneWidget,
      );
      await tapKey(t, 'agent-connection-detach-confirm');
      expect(c.calls, contains('DELETE /agents/a1/connections/github'));
      expect(find.text('Removed octocat from Alpha'), findsOneWidget);
      // No Undo for a connection the viewer could not assign again.
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('unassignable also confirms first', (t) async {
      c.status = _healthy(assignable: false);
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Remove from Alpha');
      expect(find.text('Remove GitHub from Alpha?'), findsOneWidget);
    });

    testWidgets('a removal that did not take: Retry finishes it', (t) async {
      c.status = _healthy();
      c.failures['DELETE /agents/a1/connections/github'] = _fail(
        409,
        code: disconnectNotClearedCode,
        error: 'raw server words',
      );
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Remove from Alpha');
      expect(
        find.text('Could not remove the connection from Alpha.'),
        findsOneWidget,
      );
      expect(find.text('raw server words'), findsNothing);
      c.effects['DELETE /agents/a1/connections/github'] = () =>
          c.status = gone();
      await tapText(t, 'Retry');
      expect(k('agent-connection-github-error'), findsNothing);
      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('any other failure says to try again, never the raw text', (
      t,
    ) async {
      c.status = _healthy();
      c.failures['DELETE /agents/a1/connections/github'] = _fail(
        500,
        error: 'database exploded',
      );
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Remove from Alpha');
      expect(
        find.text('Could not remove the connection from Alpha. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('exploded'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('the revoke-on-GitHub hint', () {
    Future<void> remove(WidgetTester t) async {
      await openMenu(t);
      await tapText(t, 'Remove from Alpha');
    }

    testWidgets('only on the server\'s word; its link opens GitHub', (t) async {
      c.status = _healthy();
      c.answers['DELETE /agents/a1/connections/github'] = {
        'revokeOnGithub': true,
      };
      c.effects['DELETE /agents/a1/connections/github'] = () =>
          c.status = _status();
      await mount(t);
      await remove(t);
      expect(k('agent-connection-github-revoke-hint'), findsOneWidget);
      expect(
        find.textContaining(
          "An agent still holds a copy of this GitHub credential",
        ),
        findsOneWidget,
      );
      await t.tapOnText(find.textRange.ofSubstring('your GitHub settings'));
      await settle(t);
      expect(opened.last.toString(), _github);
    });

    testWidgets('Dismiss closes it, and it does not come back on reopen', (
      t,
    ) async {
      c.status = _healthy();
      c.answers['DELETE /agents/a1/connections/github'] = {
        'revokeOnGithub': true,
      };
      c.effects['DELETE /agents/a1/connections/github'] = () =>
          c.status = _status();
      await mount(t);
      await remove(t);
      await tapKey(t, 'agent-connection-github-revoke-close');
      expect(k('agent-connection-github-revoke-hint'), findsNothing);
      await reopen(t);
      expect(k('agent-connection-github-revoke-hint'), findsNothing);
    });

    testWidgets('a plain 204 or an empty 200 shows nothing', (t) async {
      for (final answer in <Object?>[
        null,
        {'ok': true},
        {'revokeOnGithub': false},
      ]) {
        c = _Client()..status = _healthy();
        c.answers['DELETE /agents/a1/connections/github'] = answer;
        await mount(t);
        await remove(t);
        expect(
          k('agent-connection-github-revoke-hint'),
          findsNothing,
          reason: '$answer',
        );
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the next action clears it', (t) async {
      c.status = _healthy();
      c.answers['DELETE /agents/a1/connections/github'] = {
        'revokeOnGithub': true,
      };
      c.effects['DELETE /agents/a1/connections/github'] = () =>
          c.status = _status();
      await mount(t);
      await remove(t);
      expect(k('agent-connection-github-revoke-hint'), findsOneWidget);
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      expect(k('agent-connection-github-revoke-hint'), findsNothing);
    });
  });

  group('Disconnect for all agents', () {
    testWidgets('asks first and names every agent it affects', (t) async {
      c.status = _healthy();
      c.effects['DELETE /agents/a1/connections/github/connectors/k1'] = () =>
          c.status = _status();
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Disconnect for all agents');
      expect(
        find.textContaining('octocat (created by bob on Oct 20'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'is disconnected for every agent on this server that uses it, not only Alpha.',
        ),
        findsOneWidget,
      );
      expect(
        c.calls,
        isNot(contains('DELETE /agents/a1/connections/github/connectors/k1')),
      );
      await tapKey(t, 'agent-connection-disconnect-confirm');
      expect(
        c.calls,
        contains('DELETE /agents/a1/connections/github/connectors/k1'),
      );
      expect(find.text('Not connected'), findsOneWidget);
      expect(k('agent-connection-github-revoke-hint'), findsNothing);
    });

    testWidgets('only for who may manage the connector', (t) async {
      c.status = _healthy(canManage: false);
      await mount(t);
      await openMenu(t);
      expect(find.text('Disconnect for all agents'), findsNothing);
      expect(find.text('Remove from Alpha'), findsOneWidget);
    });

    testWidgets('a partial disconnect is not a success; Retry finishes it', (
      t,
    ) async {
      c.status = _healthy();
      const key = 'DELETE /agents/a1/connections/github/connectors/k1';
      c.failures[key] = _fail(502, code: connectorDisconnectPartialCode);
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Disconnect for all agents');
      await tapKey(t, 'agent-connection-disconnect-confirm');
      expect(k('agent-connection-disconnect-partial'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      c.effects[key] = () => c.status = _status();
      await t.tap(find.text('Retry'));
      await settle(t);
      expect(k('agent-connection-disconnect-partial'), findsNothing);
      expect(find.text('Not connected'), findsOneWidget);
      await reopen(t);
      expect(k('agent-connection-disconnect-partial'), findsNothing);
    });

    testWidgets(
      'a partial 502 that says revoke: the hint waits for the retry',
      (t) async {
        c.status = _healthy();
        const key = 'DELETE /agents/a1/connections/github/connectors/k1';
        c.failures[key] = _fail(
          502,
          code: connectorDisconnectPartialCode,
          extra: {'revokeOnGithub': true},
        );
        await mount(t);
        await openMenu(t);
        await tapText(t, 'Disconnect for all agents');
        await tapKey(t, 'agent-connection-disconnect-confirm');
        expect(k('agent-connection-disconnect-partial'), findsOneWidget);
        // Not while it is only partial.
        expect(k('agent-connection-github-revoke-hint'), findsNothing);
        c.effects[key] = () => c.status = _status();
        await t.tap(find.text('Retry'));
        await settle(t);
        expect(k('agent-connection-github-revoke-hint'), findsOneWidget);
      },
    );

    testWidgets('a partial 502 with no such word never shows the hint', (
      t,
    ) async {
      c.status = _healthy();
      const key = 'DELETE /agents/a1/connections/github/connectors/k1';
      c.failures[key] = _fail(502, code: connectorDisconnectPartialCode);
      await mount(t);
      await openMenu(t);
      await tapText(t, 'Disconnect for all agents');
      await tapKey(t, 'agent-connection-disconnect-confirm');
      c.effects[key] = () => c.status = _status();
      await t.tap(find.text('Retry'));
      await settle(t);
      expect(k('agent-connection-github-revoke-hint'), findsNothing);
    });
  });

  group('refusals', () {
    testWidgets('connector not found: an info notice, and it leaves the list', (
      t,
    ) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector('k1', 'octocat', current: true),
          _connector('k2', 'hubot'),
        ],
      );
      c.failures['PUT /agents/a1/connections/github'] = _fail(
        404,
        code: connectorNotFoundCode,
      );
      await mount(t);
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [_connector('k1', 'octocat', current: true)],
      );
      await t.tap(k('agent-connection-select'));
      await settle(t);
      await t.tap(find.text('hubot').last);
      await settle(t);
      expect(
        find.text(
          'hubot was disconnected in the meantime, so it was removed from the list.',
        ),
        findsOneWidget,
      );
      await t.tap(k('agent-connection-select'));
      await settle(t);
      expect(find.text('hubot'), findsNothing);
      await reopen(t);
      expect(k('agent-connection-github-error'), findsNothing);
    });

    testWidgets('forbidden: names the creator, and reloads canManage', (
      t,
    ) async {
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector('k1', 'octocat', current: true),
          _connector('k2', 'hubot', creator: 'carol'),
        ],
      );
      c.failures['PUT /agents/a1/connections/github'] = _fail(
        403,
        code: connectorForbiddenCode,
      );
      await mount(t);
      c.status = _status(
        connected: true,
        account: 'octocat',
        connectorId: 'k1',
        connectors: [
          _connector('k1', 'octocat', current: true),
          _connector('k2', 'hubot', creator: 'carol', canManage: false),
        ],
      );
      await t.tap(k('agent-connection-select'));
      await settle(t);
      await t.tap(find.text('hubot').last);
      await settle(t);
      expect(
        find.text(
          'Only carol, who created hubot, or a server owner or admin can change this connection.',
        ),
        findsOneWidget,
      );
      // The reload made the row unselectable, so it is not offered again.
      await t.tap(k('agent-connection-select'));
      await settle(t);
      await t.tap(find.text('hubot').last);
      await settle(t);
      expect(c.calls.where((x) => x.startsWith('PUT')).length, 1);
    });

    testWidgets('owner required reads as a failed action, then reloads', (
      t,
    ) async {
      c.status = _status();
      c.failures['POST /agents/a1/connections/github'] = _fail(
        403,
        code: connectionOwnerRequiredCode,
        error: 'owner_required raw',
      );
      await mount(t);
      final reads = c.calls.where((x) => x.startsWith('GET')).length;
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      expect(
        find.text('Could not start the connection. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('raw'), findsNothing);
      expect(c.calls.where((x) => x.startsWith('GET')).length, reads + 1);
    });

    testWidgets('provider refused: its sentence, Retry and Copy details', (
      t,
    ) async {
      c.status = _status();
      c.failures['POST /agents/a1/connections/github'] = _fail(
        409,
        code: providerRefusedCode,
        error: 'The agent needs exactly one GitHub plugin mount.',
        extra: {
          'details': {
            'providerCode': 'bad_mount',
            'providerStatus': 422,
            'providerMessage': 'one mount only',
          },
        },
      );
      await mount(t);
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      expect(
        find.text('The agent needs exactly one GitHub plugin mount.'),
        findsOneWidget,
      );
      await t.tap(find.text('Copy details'));
      await settle(t);
      expect(clipboard.single, '422 bad_mount: one mount only');
      expect(find.text('Details copied'), findsOneWidget);
      // Retry repeats the start, and a success resolves the notice.
      await t.tap(find.text('Retry'));
      await settle(t);
      expect(opened.single.host, 'provider.example.test');
      expect(k('agent-connection-github-error'), findsNothing);
      await reopen(t);
      expect(k('agent-connection-github-error'), findsNothing);
    });

    testWidgets('provider refused with no details: no Copy details', (t) async {
      c.status = _status();
      c.failures['POST /agents/a1/connections/github'] = _fail(
        409,
        code: providerRefusedCode,
        error: '  ',
      );
      await mount(t);
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      expect(
        find.textContaining(
          "The agent's provider refused this GitHub request.",
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Copy details'), findsNothing);
    });

    testWidgets('legacy top-level provider fields still copy', (t) async {
      c.status = _status();
      c.failures['POST /agents/a1/connections/github'] = _fail(
        409,
        code: providerRefusedCode,
        error: 'No.',
        providerMessage: 'why',
        extra: {'providerCode': 'x', 'providerStatus': 400},
      );
      await mount(t);
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      await tapText(t, 'Copy details');
      expect(clipboard.single, '400 x: why');
    });

    testWidgets('a failed Copy details says so', (t) async {
      c.status = _status();
      c.failures['POST /agents/a1/connections/github'] = _fail(
        409,
        code: providerRefusedCode,
        error: 'No.',
        providerMessage: 'why',
      );
      await mount(t);
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => throw PlatformException(code: 'denied'),
      );
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      await tapText(t, 'Copy details');
      expect(find.text('Could not copy the details'), findsOneWidget);
    });

    testWidgets('a refusal with no code never shows the server\'s words', (
      t,
    ) async {
      c.status = _status();
      c.failures['POST /agents/a1/connections/github'] = _fail(
        500,
        error: 'secret internal trace',
      );
      await mount(t);
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      expect(find.textContaining('secret'), findsNothing);
      expect(
        find.text('Could not start the connection. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('loading', () {
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

    testWidgets('a 500 warns instead of hiding', (t) async {
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

    testWidgets('back from the browser, the status is read again', (t) async {
      await mount(t);
      await tapKey(t, 'agent-connection-connect');
      await tapText(t, 'Continue to GitHub');
      final reads = c.calls.where((x) => x.startsWith('GET')).length;
      c.status = _healthy();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(c.calls.where((x) => x.startsWith('GET')).length, reads + 1);
      expect(find.text('Connected'), findsOneWidget);
    });
  });

  group('input modes', () {
    // The flow is the same on a folded phone opened up (tablet width, finger)
    // and on a narrow desktop window (mouse).
    for (final (name, size, platform) in [
      ('fold 856x944', const Size(856, 944), TargetPlatform.android),
      ('fold 944x856', const Size(944, 856), TargetPlatform.android),
      ('narrow desktop 390x844', const Size(390, 844), TargetPlatform.linux),
    ]) {
      testWidgets('reconnect and remove work at $name', (t) async {
        c.status = _healthy(
          oauthStatus: 'error',
          lastCheckError: 'Bad credentials',
        );
        await mount(t, size: size, platform: platform);
        expect(find.text('Bad credentials'), findsOneWidget);
        await t.ensureVisible(find.text('Reconnect'));
        await t.tap(find.text('Reconnect'));
        await settle(t);
        await tapText(t, 'Continue to GitHub');
        expect(opened, hasLength(1));
        c.status = _healthy();
        c.effects['DELETE /agents/a1/connections/github'] = () =>
            c.status = _status();
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(t);
        expect(k('agent-connection-github-health'), findsNothing);
        await openMenu(t);
        await tapText(t, 'Remove from Alpha');
        expect(find.text('Removed octocat from Alpha'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  test('the connection paths, refusals and access words', () {
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
    expect(refusalDetails(_fail(409)), isNull);
    expect(saysRevokeOnGithub({'revokeOnGithub': true}), isTrue);
    expect(saysRevokeOnGithub({'revokeOnGithub': 'true'}), isFalse);
    expect(saysRevokeOnGithub(null), isFalse);
    // repo covers public_repo; write:x covers read:x; [] says nothing.
    expect(describeGithubAccess(['repo'], ['public_repo']).short, isEmpty);
    expect(describeGithubAccess(['write:org'], ['read:org']).short, isEmpty);
    expect(describeGithubAccess(['public_repo'], ['repo']).short, ['repo']);
    expect(describeGithubAccess([], ['repo']).short, isEmpty);
    expect(describeGithubAccess(null, ['repo']).access, isNull);
    expect(describeGithubAccess(['read:user'], null).access, isNull);
    final status = AgentConnectionStatus.parse({
      'supported': true,
      'connected': true,
      'connectors': [
        {'id': 'k1', 'current': true, 'canManage': true},
      ],
    })!;
    expect(status.canConnectNew, isTrue);
    expect(status.current?.assignable, isNull);
    expect(status.current?.canAssign, isTrue);
  });
}
