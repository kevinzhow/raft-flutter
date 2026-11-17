import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/administration_model.dart';
import 'package:raft_flutter/features/administration_view.dart';
import 'package:raft_ui/raft_ui.dart';

// Web v1.24.0 features/settings/administration/*: settings that apply at once
// (hide #all, hide humans, translation, onboarding), the owner hand-over note,
// the Context access grants and the agent rules.

typedef _Route = Object? Function(dynamic data);

class _Client extends RaftClient {
  _Client(this.routes)
    : super(
        origin: 'https://raft.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'u-owner', 'name': 'owner'});
    selectServer('s1');
  }
  final Map<String, _Route> routes;
  final calls = <(String, dynamic)>[];

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
    calls.add((key, data));
    final route = routes[key];
    if (route == null) throw RaftApiException('Not found: $key', status: 404);
    final value = route(data);
    if (value is RaftApiException) throw value;
    return value;
  }

  List<dynamic> sent(String key) => [
    for (final (k, data) in calls)
      if (k == key) data,
  ];
}

Map<String, dynamic> _member(String id, String name, String role) => {
  'userId': id,
  'name': name,
  'displayName': null,
  'email': '$name@raft.test',
  'role': role,
};

Map<String, dynamic> _agent(
  String id,
  String name,
  String? role, {
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'name': name,
  'displayName': null,
  'status': 'active',
  'runtime': 'codex',
  'model': 'gpt',
  'serverRole': role,
  ...extra,
};

Map<String, _Route> _routes({
  bool translationEnabled = true,
  bool contextFlag = false,
  List<Map<String, dynamic>>? agents,
  Object? grants,
}) => {
  'GET /servers/s1/members': (_) => [
    _member('u-owner', 'owner', 'owner'),
    _member('u-dana', 'dana', 'member'),
  ],
  'GET /agents': (_) =>
      agents ??
      [_agent('a-bot', 'bot', 'admin'), _agent('a-helper', 'helper', 'member')],
  'GET /servers/s1/invites': (_) => [],
  'GET /servers/s1/join-links': (_) => [],
  'GET /servers/s1/agreement': (_) => {
    'enabled': false,
    'agreement': {'title': '', 'bodyMarkdown': ''},
  },
  'GET /servers/s1/settings': (_) => {
    'settings': {
      'onboardSettings': {
        'onboardingAgentId': null,
        'agentAllChannelGreetingEnabled': true,
      },
    },
  },
  'GET /servers/s1/setup-projection': (_) => {
    'surface': 'none',
    'phase': 'complete',
  },
  'GET /servers/s1/translation-settings': (_) => {
    'translationEnabled': translationEnabled,
    'translationAvailable': true,
    'canManageTranslation': true,
  },
  'POST /feature-flags/evaluate': (_) => {
    'evaluations': [
      {'key': 'agent_context_view_v0', 'enabled': contextFlag},
      {'key': 'product_analytics_settings_v0', 'enabled': true},
    ],
  },
  'GET /servers/s1/product-analytics-settings': (_) => {
    'productAnalyticsEnabled': true,
    'canManageProductAnalytics': true,
  },
  'GET /servers/s1/agent-context-view-grants': (_) => grants ?? {'grants': []},
  'GET /channels': (_) => [
    {'id': 'c-all', 'name': 'all', 'type': 'channel', 'joined': true},
  ],
  'GET /channels/dm': (_) => [],
};

(WorkspaceController, _Client) _workspace(
  Map<String, _Route> routes, {
  String role = 'owner',
  bool allVisible = true,
}) {
  final client = _Client(routes);
  final w = WorkspaceController(client);
  final server = RaftRecord({
    'id': 's1',
    'name': 'Fixture',
    'slug': 'fixture',
    'role': role,
  });
  w
    ..server = server
    ..servers = [server]
    ..channels = [
      if (allVisible)
        RaftChannel({'id': 'c-all', 'name': 'all', 'type': 'channel'}),
    ];
  return (w, client);
}

Future<void> _pump(
  WidgetTester t,
  WorkspaceController w, {
  Size size = const Size(1200, 4000),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: RaftToastHost(
        child: Scaffold(
          body: SingleChildScrollView(
            child: AdministrationView(
              controller: w,
              frontendOrigin: Uri.parse('https://app.raft.test'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _section(String name) => _key('admin-section-$name');

bool _switchOn(WidgetTester t, String key) =>
    t.widget<RaftSwitch>(_key(key)).value;

void main() {
  group('admin agent rules (shared canChangeAgentMemberRole)', () {
    test('an admin can demote an admin agent, not an admin person', () {
      const agent = AdminPrincipal(
        agent: true,
        id: 'b',
        name: 'bot',
        role: 'admin',
      );
      const person = AdminPrincipal(
        agent: false,
        id: 'a',
        name: 'amy',
        role: 'admin',
      );
      expect(canChangeAgentMemberRole('admin', 'admin', 'member'), isTrue);
      expect(canRemoveAdmin('admin', agent, 1), isTrue);
      expect(canRemoveAdmin('admin', person, 1), isFalse);
      expect(canChangeAgentMemberRole('member', 'admin', 'member'), isFalse);
      expect(canChangeAgentMemberRole('admin', 'member', 'owner'), isFalse);
    });
  });

  group('Hide #all (SystemChannelsSection)', () {
    testWidgets('hiding asks first and has no Save button', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['POST /channels/system/all/hide'] = (_) => {'id': 'c-all'};
      await _pump(t, w);
      expect(_key('admin-hide-all-save'), findsNothing);
      expect(_switchOn(t, 'admin-hide-all'), isFalse);
      await t.tap(_key('admin-hide-all'));
      await t.pumpAndSettle();
      // Warning confirm, the same as the channel's own settings.
      expect(find.text('Hide #all'), findsOneWidget);
      expect(c.sent('POST /channels/system/all/hide'), isEmpty);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(c.sent('POST /channels/system/all/hide'), isEmpty);
      expect(_switchOn(t, 'admin-hide-all'), isFalse);

      c.routes['GET /channels'] = (_) => [];
      await t.tap(_key('admin-hide-all'));
      await t.pumpAndSettle();
      await t.tap(_key('hide-all-channel-confirm'));
      await t.pumpAndSettle();
      expect(c.sent('POST /channels/system/all/hide'), hasLength(1));
      expect(_key('hide-all-channel-confirm'), findsNothing);
    });

    testWidgets('showing it again is immediate', (t) async {
      final (w, c) = _workspace(_routes(), allVisible: false);
      addTearDown(w.dispose);
      c.routes['POST /channels/system/all/restore'] = (_) => {'id': 'c-all'};
      await _pump(t, w);
      expect(_switchOn(t, 'admin-hide-all'), isTrue);
      await t.tap(_key('admin-hide-all'));
      await t.pumpAndSettle();
      expect(find.text('Hide #all'), findsNothing);
      expect(c.sent('POST /channels/system/all/restore'), hasLength(1));
    });

    testWidgets('a failure shows under the row and the switch snaps back', (
      t,
    ) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['POST /channels/system/all/hide'] = (_) =>
          RaftApiException.response(
            'Not allowed',
            status: 403,
            body: {'error': 'Not allowed'},
          );
      await _pump(t, w);
      await t.tap(_key('admin-hide-all'));
      await t.pumpAndSettle();
      await t.tap(_key('hide-all-channel-confirm'));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: _section('system-channels'),
          matching: find.text('Not allowed'),
        ),
        findsOneWidget,
      );
      expect(_switchOn(t, 'admin-hide-all'), isFalse);
    });
  });

  group('Hide humans and translation: applied at once with Undo', () {
    testWidgets('hide humans saves at once; Undo puts it back, once', (
      t,
    ) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1'] = (_) => {};
      c.routes['GET /servers'] = (_) => [
        {'id': 's1', 'name': 'Fixture', 'slug': 'fixture', 'role': 'owner'},
      ];
      await _pump(t, w);
      expect(_key('admin-hide-humans-save'), findsNothing);
      await t.tap(_key('admin-hide-humans'));
      await t.pumpAndSettle();
      expect(c.sent('PATCH /servers/s1'), [
        {'hideHumansFromMembers': true},
      ]);
      expect(
        find.text('Hid the human directory and counts from members'),
        findsOneWidget,
      );
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      // The toast closes with its action: Undo cannot be pressed twice.
      expect(find.text('Undo'), findsNothing);
      expect(c.sent('PATCH /servers/s1'), [
        {'hideHumansFromMembers': true},
        {'hideHumansFromMembers': false},
      ]);
      await t.pump(const Duration(seconds: 10));
    });

    testWidgets('Undo after switching server says so and saves nothing', (
      t,
    ) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1'] = (_) => {};
      c.routes['GET /servers'] = (_) => [
        {'id': 's1', 'name': 'Fixture', 'slug': 'fixture', 'role': 'owner'},
      ];
      await _pump(t, w);
      await t.tap(_key('admin-hide-humans'));
      await t.pumpAndSettle();
      w.server = RaftRecord({
        'id': 's2',
        'name': 'Other',
        'slug': 'other',
        'role': 'owner',
      });
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(
        find.text("Not undone: you've switched to another server"),
        findsOneWidget,
      );
      expect(c.sent('PATCH /servers/s1'), hasLength(1));
      await t.pump(const Duration(seconds: 10));
    });

    testWidgets('hide humans failure shows under the row', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1'] = (_) => RaftApiException.response(
        'Nope',
        status: 500,
        body: {'error': 'Nope'},
      );
      await _pump(t, w);
      await t.tap(_key('admin-hide-humans'));
      await t.pumpAndSettle();
      expect(find.text('Nope'), findsOneWidget);
      expect(_switchOn(t, 'admin-hide-humans'), isFalse);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('translation: off applies at once with Undo; on needs none', (
      t,
    ) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      var enabled = true;
      c.routes['PATCH /servers/s1/translation-settings'] = (d) {
        enabled = d['translationEnabled'] == true;
        return {
          'translationEnabled': enabled,
          'translationAvailable': true,
          'canManageTranslation': true,
        };
      };
      await _pump(t, w);
      expect(_key('admin-translation-save'), findsNothing);
      await t.tap(_key('admin-translation'));
      await t.pumpAndSettle();
      expect(enabled, isFalse);
      expect(
        find.text('Turned off message translation for this server'),
        findsOneWidget,
      );
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(enabled, isTrue);
      expect(c.sent('PATCH /servers/s1/translation-settings'), [
        {'translationEnabled': false},
        {'translationEnabled': true},
      ]);
      await t.pump(const Duration(seconds: 10));
    });
  });

  group('Onboarding (OnboardingAgentSection)', () {
    testWidgets('the agent and the greeting each save when changed', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1/onboarding-settings'] = (_) => {};
      await _pump(t, w);
      expect(_key('admin-onboarding-save'), findsNothing);
      await t.tap(_key('admin-onboarding-greeting'));
      await t.pumpAndSettle();
      expect(c.sent('PATCH /servers/s1/onboarding-settings'), [
        {'agentAllChannelGreetingEnabled': false},
      ]);
      // The settings are read again after the save (loadSettings force).
      expect(c.sent('GET /servers/s1/settings'), hasLength(2));
      await t.tap(_key('admin-onboarding-agent'));
      await t.pumpAndSettle();
      await t.tap(find.text('@bot').last);
      await t.pumpAndSettle();
      expect(c.sent('PATCH /servers/s1/onboarding-settings').last, {
        'onboardingAgentId': 'a-bot',
      });
    });

    testWidgets('a failed greeting rolls back and says so under the switch', (
      t,
    ) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1/onboarding-settings'] = (_) =>
          const RaftApiException('Boom', status: 500);
      await _pump(t, w);
      await t.tap(_key('admin-onboarding-greeting'));
      await t.pumpAndSettle();
      expect(_switchOn(t, 'admin-onboarding-greeting'), isTrue);
      expect(
        find.text('Failed to save the new agent greeting'),
        findsOneWidget,
      );
    });

    testWidgets('greeter options leave out personal assistants and App Bots', (
      t,
    ) async {
      final (w, c) = _workspace(
        _routes(
          agents: [
            _agent('a-ok', 'okbot', 'member'),
            _agent(
              'a-pa',
              'assistant',
              'member',
              extra: {'assistantOwnerUserId': 'u-dana'},
            ),
            _agent(
              'a-gone',
              'goneapp',
              'member',
              extra: {'inMemberLists': false},
            ),
            _agent(
              'a-del',
              'deleted',
              'member',
              extra: {'deletedAt': '2026-01-01T00:00:00.000Z'},
            ),
          ],
        ),
      );
      addTearDown(w.dispose);
      await _pump(t, w);
      await t.tap(_key('admin-onboarding-agent'));
      await t.pumpAndSettle();
      expect(find.text('@okbot'), findsWidgets);
      expect(find.text('@assistant'), findsNothing);
      expect(find.text('@goneapp'), findsNothing);
      expect(find.text('@deleted'), findsNothing);
      expect(c, isNotNull);
    });
  });

  group('Add owner/admin: own Computers transfer note', () {
    Future<void> pickDana(WidgetTester t) async {
      await t.tap(_key('admin-principal-picker'));
      await t.pumpAndSettle();
      await t.tap(_key('admin-candidate-human:u-dana'));
      await t.pumpAndSettle();
    }

    testWidgets('making someone owner shows what happens to my Computers', (
      t,
    ) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['GET /servers/s1/members/u-owner/removal-impact'] = (_) => {
        'computers': 2,
        'computerNames': ['Mac', 'Linux'],
        'othersAgents': 0,
      };
      await _pump(t, w);
      await pickDana(t);
      // Admin role: no read, no note.
      expect(c.sent('GET /servers/s1/members/u-owner/removal-impact'), isEmpty);
      await t.tap(_key('admin-role-select'));
      await t.pumpAndSettle();
      await t.tap(find.text('Owner').last);
      await t.pumpAndSettle();
      expect(
        c.sent('GET /servers/s1/members/u-owner/removal-impact'),
        hasLength(1),
      );
      expect(_key('owner-transfer-computers'), findsOneWidget);
      expect(find.textContaining('Mac and Linux'), findsOneWidget);
    });

    testWidgets('a failed read or no Computers says nothing', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['GET /servers/s1/members/u-owner/removal-impact'] = (_) =>
          const RaftApiException('Boom', status: 500);
      await _pump(t, w);
      await pickDana(t);
      await t.tap(_key('admin-role-select'));
      await t.pumpAndSettle();
      await t.tap(find.text('Owner').last);
      await t.pumpAndSettle();
      expect(_key('owner-transfer-computers'), findsNothing);
    });
  });

  group('Context access for agents (ContextViewGrantsSection)', () {
    Map<String, dynamic> grant(String id, String agentId, String name) => {
      'id': id,
      'agent': {'id': agentId, 'name': name},
      'granter': {'id': 'u-owner', 'name': 'owner'},
      'grantedAt': '2026-06-18T00:00:00.000Z',
    };

    testWidgets('off by the flag, and for a plain admin never asked', (
      t,
    ) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      await _pump(t, w);
      expect(_section('context-view-grants'), findsNothing);
      expect(c.sent('GET /servers/s1/agent-context-view-grants'), isEmpty);
    });

    testWidgets('a member is never shown it and sends no flag read', (t) async {
      final (w, c) = _workspace(_routes(contextFlag: true), role: 'member');
      addTearDown(w.dispose);
      await _pump(t, w);
      expect(_section('context-view-grants'), findsNothing);
      expect(c.sent('GET /servers/s1/agent-context-view-grants'), isEmpty);
    });

    testWidgets('lists grants; Grant access adds one; Revoke removes it', (
      t,
    ) async {
      final (w, c) = _workspace(
        _routes(
          contextFlag: true,
          grants: {
            'grants': [grant('g1', 'a-bot', 'bot')],
          },
        ),
      );
      addTearDown(w.dispose);
      c.routes['POST /servers/s1/agent-context-view-grants'] = (d) => {
        'grant': grant('g2', d['agentId'] as String, 'helper'),
        'created': true,
      };
      c.routes['DELETE /servers/s1/agent-context-view-grants/g1'] = (_) => {
        'ok': true,
        'revoked': true,
      };
      await _pump(t, w);
      expect(_section('context-view-grants'), findsOneWidget);
      expect(_key('context-view-grant-g1'), findsOneWidget);
      expect(find.textContaining('Granted by owner'), findsOneWidget);

      await t.tap(_key('context-view-grant-open'));
      await t.pumpAndSettle();
      // Only agents without access are offered; confirm waits for a pick.
      final confirm = _key('context-view-grant-confirm');
      expect(t.widget<RaftButton>(confirm).onPressed, isNull);
      await t.tap(_key('context-view-grant-agent'));
      await t.pumpAndSettle();
      // `bot` already has access: only its row in the list is left.
      expect(find.text('bot'), findsOneWidget);
      await t.tap(find.text('helper').last);
      await t.pumpAndSettle();
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(c.sent('POST /servers/s1/agent-context-view-grants'), [
        {'agentId': 'a-helper'},
      ]);
      expect(_key('context-view-grant-g2'), findsOneWidget);

      await t.tap(_key('context-view-revoke-g1'));
      await t.pumpAndSettle();
      expect(find.text("Revoke bot's access?"), findsOneWidget);
      await t.tap(_key('context-view-revoke-confirm'));
      await t.pumpAndSettle();
      expect(_key('context-view-grant-g1'), findsNothing);
      expect(_key('context-view-grants-note'), findsNothing);
    });

    testWidgets('a 404 on revoke reads as already revoked and reloads', (
      t,
    ) async {
      final (w, c) = _workspace(
        _routes(
          contextFlag: true,
          grants: {
            'grants': [grant('g1', 'a-bot', 'bot')],
          },
        ),
      );
      addTearDown(w.dispose);
      c.routes['DELETE /servers/s1/agent-context-view-grants/g1'] = (_) =>
          RaftApiException.response(
            'No grant',
            status: 404,
            body: {'error': 'No grant', 'code': 'context_view_grant_not_found'},
          );
      await _pump(t, w);
      await t.tap(_key('context-view-revoke-g1'));
      await t.pumpAndSettle();
      await t.tap(_key('context-view-revoke-confirm'));
      await t.pumpAndSettle();
      expect(find.text("bot's access was already revoked."), findsOneWidget);
      expect(c.sent('GET /servers/s1/agent-context-view-grants'), hasLength(2));
    });

    testWidgets('a failed load offers Retry', (t) async {
      final (w, c) = _workspace(_routes(contextFlag: true));
      addTearDown(w.dispose);
      var fail = true;
      c.routes['GET /servers/s1/agent-context-view-grants'] = (_) =>
          fail ? const RaftApiException('Boom', status: 500) : {'grants': []};
      await _pump(t, w);
      expect(
        find.text("Couldn't load which agents have access."),
        findsOneWidget,
      );
      // Grant access waits for the list.
      expect(
        t
            .widget<RaftSettingsRecipeButton>(_key('context-view-grant-open'))
            .onPressed,
        isNull,
      );
      fail = false;
      await t.tap(_key('context-view-grants-retry'));
      await t.pumpAndSettle();
      expect(
        find.text("Couldn't load which agents have access."),
        findsNothing,
      );
      expect(_key('context-view-grants-empty'), findsOneWidget);
    });
  });
}
