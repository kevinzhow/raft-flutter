import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/administration_model.dart';
import 'package:raft_flutter/features/administration_view.dart';
import 'package:raft_ui/raft_ui.dart';

typedef _Route = Object? Function(dynamic data);

/// In-memory transport: `'METHOD /path'` → JSON (or a [RaftApiException]).
class _Client extends RaftClient {
  _Client(this.routes, {super.origin = 'https://raft.invalid'})
    : super(sessionStore: MemorySessionStore()) {
    user = RaftRecord({'id': 'u-owner', 'name': 'owner'});
    selectServer('s1');
  }
  final Map<String, _Route> routes;
  final calls = <(String, dynamic)>[];
  Completer<void>? gate;

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
    await gate?.future;
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

Map<String, dynamic> _agent(String id, String name, String? role) => {
  'id': id,
  'name': name,
  'displayName': null,
  'status': 'active',
  'runtime': 'codex',
  'model': 'gpt',
  'serverRole': role,
};

Map<String, _Route> _routes({
  bool analytics = false,
  bool providerAvailable = true,
  Map<String, dynamic>? projection,
}) => {
  'GET /servers/s1/members': (_) => [
    _member('u-owner', 'owner', 'owner'),
    _member('u-dana', 'dana', 'member'),
  ],
  'GET /agents': (_) => [
    _agent('a-bot', 'bot', 'admin'),
    _agent('a-helper', 'helper', 'member'),
  ],
  'GET /servers/s1/invites': (_) => [
    {
      'id': 'i1',
      'invitedEmail': 'new@raft.test',
      'createdAt': '2026-06-18T00:00:00.000Z',
    },
  ],
  'GET /servers/s1/join-links': (_) => [
    {
      'id': 'l1',
      'token': 'tok',
      'useCount': 2,
      'maxUses': 5,
      'expiresAt': null,
    },
  ],
  'GET /servers/s1/agreement': (_) => {
    'enabled': true,
    'agreement': {'title': 'Rules', 'bodyMarkdown': 'Be kind.'},
  },
  'GET /servers/s1/settings': (_) => {
    'settings': {
      'onboardSettings': {
        'onboardingAgentId': null,
        'agentAllChannelGreetingEnabled': true,
      },
    },
  },
  'GET /servers/s1/setup-projection': (_) =>
      projection ?? {'surface': 'none', 'phase': 'complete'},
  'GET /servers/s1/translation-settings': (_) => {
    'translationEnabled': false,
    'translationAvailable': providerAvailable,
    'canManageTranslation': true,
  },
  'POST /feature-flags/evaluate': (_) => {
    'evaluations': [
      {'key': 'product_analytics_settings_v0', 'enabled': analytics},
    ],
  },
  'GET /servers/s1/product-analytics-settings': (_) => {
    'productAnalyticsEnabled': true,
    'canManageProductAnalytics': true,
  },
  'GET /channels': (_) => [
    {'id': 'c-all', 'name': 'all', 'type': 'channel', 'joined': true},
  ],
  'GET /channels/dm': (_) => [],
};

(WorkspaceController, _Client) _workspace(
  Map<String, _Route> routes, {
  String role = 'owner',
  bool allVisible = true,
  String origin = 'https://raft.invalid',
}) {
  final client = _Client(routes, origin: origin);
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
  bool releaseDefaults = false,
}) async {
  t.view.physicalSize = const Size(1200, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdministrationView(
            controller: w,
            // Release builds pass no frontend define: the page then derives
            // the Web origin from the connected server.
            frontendOrigin: releaseDefaults
                ? null
                : Uri.parse('https://app.raft.test'),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Finder _section(String name) => find.byKey(ValueKey('admin-section-$name'));
Finder _in(String section, Finder f) =>
    find.descendant(of: _section(section), matching: f);

void main() {
  group('administration rules (serverAdminSettings.ts)', () {
    const owner = AdminPrincipal(
      agent: false,
      id: 'o',
      name: 'zed',
      role: 'owner',
    );
    const admin = AdminPrincipal(
      agent: false,
      id: 'a',
      name: 'amy',
      role: 'admin',
    );
    const member = AdminPrincipal(
      agent: false,
      id: 'm',
      name: 'max',
      role: 'member',
    );
    const bot = AdminPrincipal(
      agent: true,
      id: 'b',
      name: 'bot',
      role: 'member',
    );
    test('canChangeMemberRole', () {
      expect(canChangeMemberRole('owner', 'owner', 'member'), isTrue);
      expect(canChangeMemberRole('admin', 'member', 'admin'), isTrue);
      expect(canChangeMemberRole('admin', 'member', 'owner'), isFalse);
      expect(canChangeMemberRole('admin', 'admin', 'member'), isFalse);
      expect(canChangeMemberRole('member', 'member', 'admin'), isFalse);
      expect(canChangeMemberRole(null, 'member', 'admin'), isFalse);
    });
    test('owners first, then admins by label', () {
      final list = adminPrincipals(
        [member, admin, owner],
        [
          const AdminPrincipal(
            agent: true,
            id: 'x',
            name: 'ann',
            role: 'admin',
          ),
        ],
      );
      expect([for (final p in list) p.label], ['zed', '@ann', 'amy']);
    });
    test('candidates and role options follow the actor', () {
      expect(
        [
          for (final c in adminCandidates(
            [owner, admin, member],
            [bot],
            'owner',
          ))
            c.key,
        ],
        ['agent:b', 'human:a', 'human:m'],
      );
      expect(
        [
          for (final c in adminCandidates(
            [owner, admin, member],
            [bot],
            'admin',
          ))
            c.key,
        ],
        ['agent:b', 'human:m'],
      );
      expect(adminRoleOptions('owner', member), ['owner', 'admin']);
      expect(adminRoleOptions('owner', admin), ['owner']);
      expect(adminRoleOptions('admin', member), ['admin']);
      expect(adminRoleOptions('owner', bot), ['admin']);
    });
    test('removal keeps the last owner', () {
      expect(canRemoveAdmin('owner', owner, 1), isFalse);
      expect(canRemoveAdmin('owner', owner, 2), isTrue);
      expect(canRemoveAdmin('admin', admin, 2), isFalse);
      expect(canRemoveAdmin('owner', admin, 1), isTrue);
    });
    test('labels and subtitles', () {
      const human = AdminPrincipal(
        agent: false,
        id: 'h',
        name: 'dana',
        role: 'owner',
        email: 'dana@raft.test',
      );
      expect(human.optionLabel, 'dana · dana@raft.test');
      expect(human.subtitle, 'dana@raft.test · Owner');
      expect(bot.optionLabel, '@bot · Agent');
      expect(
        const AdminPrincipal(
          agent: true,
          id: 'b',
          name: 'bot',
          role: 'admin',
        ).subtitle,
        'Agent · Admin',
      );
    });
  });

  group('AdministrationView', () {
    testWidgets('owner sees every gated section in Web order', (t) async {
      final (w, _) = _workspace(_routes(analytics: true));
      addTearDown(w.dispose);
      await _pump(t, w);
      final order = [
        'admins',
        'system-channels',
        'invites',
        'join-links',
        'pre-join-agreement',
        'onboarding',
        'translation',
        'product-analytics',
        'member-permissions',
      ];
      final tops = [for (final s in order) t.getTopLeft(_section(s)).dy];
      expect(tops, [...tops]..sort());
    });

    testWidgets('member role keeps only translation and member permissions', (
      t,
    ) async {
      final (w, _) = _workspace(_routes(analytics: true), role: 'member');
      addTearDown(w.dispose);
      await _pump(t, w);
      for (final s in [
        'admins',
        'system-channels',
        'invites',
        'join-links',
        'pre-join-agreement',
        'onboarding',
        'product-analytics',
      ]) {
        expect(_section(s), findsNothing, reason: s);
      }
      expect(_section('translation'), findsOneWidget);
      expect(_section('member-permissions'), findsOneWidget);
      // No editServerSettings: no Save.
      expect(
        find.byKey(const ValueKey('admin-hide-humans-save')),
        findsNothing,
      );
    });

    testWidgets('product analytics follows its server flag', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      await _pump(t, w);
      expect(_section('product-analytics'), findsNothing);

      final (w2, c2) = _workspace(_routes(analytics: true));
      addTearDown(w2.dispose);
      c2.routes['PATCH /servers/s1/product-analytics-settings'] = (data) => {
        'productAnalyticsEnabled': false,
        'canManageProductAnalytics': true,
      };
      await _pump(t, w2);
      await t.tap(find.byKey(const ValueKey('admin-product-analytics')));
      await t.pumpAndSettle();
      expect(c2.sent('PATCH /servers/s1/product-analytics-settings'), [
        {'productAnalyticsEnabled': false},
      ]);
      expect(
        t
            .widget<RaftSwitch>(
              find.byKey(const ValueKey('admin-product-analytics')),
            )
            .value,
        isFalse,
      );
      expect(c.calls, isNotEmpty);
    });

    testWidgets('owners & admins: list, promote, remove', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1/members/u-dana'] = (_) => {};
      c.routes['PATCH /agents/a-bot'] = (_) => {};
      await _pump(t, w);
      // Sole owner: Last owner; the admin agent can be removed.
      expect(_in('admins', find.text('Last owner')), findsOneWidget);
      expect(_in('admins', find.text('Agent · Admin')), findsOneWidget);
      expect(
        _in('admins', find.text('owner@raft.test · Owner')),
        findsOneWidget,
      );
      // Update Role starts disabled.
      await t.tap(find.byKey(const ValueKey('admin-update-role')));
      await t.pumpAndSettle();
      expect(c.sent('PATCH /servers/s1/members/u-dana'), isEmpty);

      await t.tap(find.byKey(const ValueKey('admin-principal-picker')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admin-principal-popover')),
        findsOneWidget,
      );
      // Search narrows the candidates.
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('admin-principal-popover')),
          matching: find.byType(EditableText),
        ),
        'dan',
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admin-candidate-agent:a-helper')),
        findsNothing,
      );
      await t.tap(find.byKey(const ValueKey('admin-candidate-human:u-dana')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admin-principal-popover')),
        findsNothing,
      );
      expect(find.text('dana · dana@raft.test'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-update-role')));
      await t.pumpAndSettle();
      expect(c.sent('PATCH /servers/s1/members/u-dana'), [
        {'role': 'admin'},
      ]);

      await t.tap(find.byKey(const ValueKey('admin-remove-agent:a-bot')));
      await t.pumpAndSettle();
      expect(c.sent('PATCH /agents/a-bot'), [
        {'serverRole': 'member'},
      ]);
    });

    testWidgets('owners & admins: an admin sees Owner only', (t) async {
      final (w, _) = _workspace(_routes(), role: 'admin');
      addTearDown(w.dispose);
      await _pump(t, w);
      expect(_in('admins', find.text('Owner only')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-remove-agent:a-bot')),
        findsNothing,
      );
    });

    testWidgets('owners & admins: a failed change shows the server error', (
      t,
    ) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PATCH /agents/a-bot'] = (_) => RaftApiException.response(
        'Agent is busy',
        status: 409,
        body: {'error': 'Agent is busy'},
      );
      await _pump(t, w);
      await t.tap(find.byKey(const ValueKey('admin-remove-agent:a-bot')));
      await t.pumpAndSettle();
      expect(_in('admins', find.text('Agent is busy')), findsOneWidget);
    });

    testWidgets('system channels: hide #all through its endpoint', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['POST /channels/system/all/hide'] = (_) => {'id': 'c-all'};
      c.routes['GET /channels'] = (_) => [];
      await _pump(t, w);
      final save = find.byKey(const ValueKey('admin-hide-all-save'));
      await t.tap(save);
      await t.pumpAndSettle();
      expect(c.sent('POST /channels/system/all/hide'), isEmpty);
      await t.tap(find.byKey(const ValueKey('admin-hide-all')));
      await t.pump();
      await t.tap(save);
      await t.pump();
      await t.pump();
      expect(c.sent('POST /channels/system/all/hide'), hasLength(1));
      await t.pumpAndSettle();
      expect(
        find.descendant(of: save, matching: find.text('Saved')),
        findsOneWidget,
      );
      await t.pump(const Duration(seconds: 3));
      expect(
        find.descendant(of: save, matching: find.text('Save')),
        findsOneWidget,
      );
    });

    testWidgets('pending invites: revoke after confirmation', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['DELETE /servers/s1/invites/i1'] = (_) => {};
      await _pump(t, w);
      expect(_in('invites', find.text('new@raft.test')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-invite-revoke-i1')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admin-confirm-dialog')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Are you sure you want to revoke the invite to new@raft.test?',
        ),
        findsOneWidget,
      );
      c.routes['GET /servers/s1/invites'] = (_) => [];
      await t.tap(find.byKey(const ValueKey('admin-confirm')));
      await t.pumpAndSettle();
      expect(c.sent('DELETE /servers/s1/invites/i1'), hasLength(1));
      expect(find.byKey(const ValueKey('admin-confirm-dialog')), findsNothing);
      expect(_in('invites', find.text('No pending invites.')), findsOneWidget);
    });

    testWidgets('pending invites: cancel keeps the invite', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      await _pump(t, w);
      await t.tap(find.byKey(const ValueKey('admin-invite-revoke-i1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(c.sent('DELETE /servers/s1/invites/i1'), isEmpty);
      expect(_in('invites', find.text('new@raft.test')), findsOneWidget);
    });

    testWidgets('invite links of the official server use the Web app origin', (
      t,
    ) async {
      final (w, c) = _workspace(_routes(), origin: 'https://api.raft.build');
      addTearDown(w.dispose);
      final copied = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
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
      await _pump(t, w, releaseDefaults: true);
      await t.tap(find.byKey(const ValueKey('admin-join-link-copy-l1')));
      await t.pump();
      expect(copied, ['https://app.raft.build/join/tok']);
      await t.pump(const Duration(seconds: 2));
      expect(c.calls, isNotEmpty);
    });

    testWidgets('invite links: create, copy, revoke', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      final copied = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
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
      c.routes['POST /servers/s1/join-links'] = (_) => {
        'link': {
          'id': 'l2',
          'token': 'fresh',
          'useCount': 0,
          'maxUses': 3,
          'expiresAt': null,
        },
      };
      c.routes['DELETE /servers/s1/join-links/l1'] = (_) => {};
      await _pump(t, w);
      expect(
        _in('join-links', find.text('2/5 uses · no expiry')),
        findsOneWidget,
      );
      await t.enterText(
        find.byKey(const ValueKey('admin-join-link-max-uses')),
        '3',
      );
      await t.tap(find.byKey(const ValueKey('admin-join-link-create')));
      await t.pumpAndSettle();
      expect(c.sent('POST /servers/s1/join-links'), [
        {'maxUses': 3, 'expiresAt': null},
      ]);
      expect(
        t.getTopLeft(find.byKey(const ValueKey('admin-join-link-l2'))).dy,
        lessThan(
          t.getTopLeft(find.byKey(const ValueKey('admin-join-link-l1'))).dy,
        ),
      );
      await t.tap(find.byKey(const ValueKey('admin-join-link-copy-l2')));
      await t.pump();
      expect(copied, ['https://app.raft.test/join/fresh']);
      await t.pump(const Duration(seconds: 2));

      await t.tap(find.byKey(const ValueKey('admin-join-link-revoke-l1')));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Revoke this invite link? Anyone who still has the URL will stop being able to join with it.',
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('admin-confirm')));
      await t.pumpAndSettle();
      expect(c.sent('DELETE /servers/s1/join-links/l1'), hasLength(1));
      expect(find.byKey(const ValueKey('admin-join-link-l1')), findsNothing);
    });

    testWidgets('pre-join agreement: edit, limit, save', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PUT /servers/s1/agreement'] = (data) => {
        'enabled': true,
        'agreement': {
          'title': (data as Map)['title'],
          'bodyMarkdown': data['bodyMarkdown'],
        },
      };
      await _pump(t, w);
      final title = find.byKey(const ValueKey('admin-agreement-title'));
      expect(t.widget<TextField>(title).controller!.text, 'Rules');
      // Preview renders the body.
      expect(
        find.descendant(
          of: find.byType(RaftAgreementBody),
          matching: find.text('Be kind.'),
        ),
        findsOneWidget,
      );
      final save = find.byKey(const ValueKey('admin-agreement-save'));
      await t.enterText(
        find.byKey(const ValueKey('admin-agreement-body')),
        '- one\n- two',
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(RaftAgreementBody),
          matching: find.text('one'),
        ),
        findsOneWidget,
      );
      await t.tap(save);
      await t.pumpAndSettle();
      expect(c.sent('PUT /servers/s1/agreement'), [
        {'enabled': true, 'title': 'Rules', 'bodyMarkdown': '- one\n- two'},
      ]);
      expect(
        find.descendant(of: save, matching: find.text('Saved')),
        findsOneWidget,
      );
      // Unchecking hides the fields.
      await t.tap(find.byKey(const ValueKey('admin-agreement-enabled')));
      await t.pumpAndSettle();
      expect(title, findsNothing);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('onboarding: save and finish setup', (t) async {
      final (w, c) = _workspace(
        _routes(
          projection: {'surface': 'create_agent', 'phase': 'in_progress'},
        ),
      );
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1/onboarding-settings'] = (_) => {};
      c.routes['POST /servers/s1/setup-transition'] = (_) => {
        'surface': 'create_agent',
        'phase': 'in_progress',
      };
      await _pump(t, w);
      expect(
        _in('onboarding', find.text('Disabled (no automatic onboarding)')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('admin-onboarding-greeting')));
      await t.pumpAndSettle();
      await t.tap(find.text('No').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-onboarding-save')));
      await t.pumpAndSettle();
      expect(c.sent('PATCH /servers/s1/onboarding-settings'), [
        {'onboardingAgentId': null, 'agentAllChannelGreetingEnabled': false},
      ]);
      await t.tap(find.byKey(const ValueKey('finish-server-setup')));
      await t.pumpAndSettle();
      expect(c.sent('POST /servers/s1/setup-transition'), [
        {'action': 'start'},
      ]);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('onboarding: complete setup hides Finish setup', (t) async {
      final (w, _) = _workspace(_routes());
      addTearDown(w.dispose);
      await _pump(t, w);
      expect(find.byKey(const ValueKey('finish-server-setup')), findsNothing);
    });

    testWidgets('translation: provider warning and save', (t) async {
      final (w, c) = _workspace(_routes(providerAvailable: false));
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1/translation-settings'] = (_) => {
        'translationEnabled': true,
        'translationAvailable': false,
        'canManageTranslation': true,
      };
      await _pump(t, w);
      const warning =
          'Translation is enabled for this server, but no translation provider is configured.';
      expect(find.text(warning), findsNothing);
      await t.tap(find.byKey(const ValueKey('admin-translation')));
      await t.pumpAndSettle();
      expect(find.text(warning), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-translation-save')));
      await t.pumpAndSettle();
      expect(c.sent('PATCH /servers/s1/translation-settings'), [
        {'translationEnabled': true},
      ]);
      expect(w.translations.settings.serverEnabled, isTrue);
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('member permissions: save hideHumansFromMembers', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      c.routes['PATCH /servers/s1'] = (_) => {};
      c.routes['GET /servers'] = (_) => [
        {
          'id': 's1',
          'name': 'Fixture',
          'slug': 'fixture',
          'role': 'owner',
          'hideHumansFromMembers': true,
        },
      ];
      await _pump(t, w);
      await t.tap(find.byKey(const ValueKey('admin-hide-humans')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('admin-hide-humans-save')));
      await t.pumpAndSettle();
      expect(c.sent('PATCH /servers/s1'), [
        {'hideHumansFromMembers': true},
      ]);
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('revisit paints accepted invites and links at once', (t) async {
      final (w, c) = _workspace(_routes());
      addTearDown(w.dispose);
      await _pump(t, w);
      await t.pumpWidget(const SizedBox());
      c.gate = Completer<void>();
      await _pumpNoSettle(t, w);
      expect(_in('invites', find.text('new@raft.test')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-join-link-l1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-agreement-title')),
        findsOneWidget,
      );
      c.gate!.complete();
      await t.pumpAndSettle();
      expect(_in('invites', find.text('new@raft.test')), findsOneWidget);
    });
  });
}

Future<void> _pumpNoSettle(WidgetTester t, WorkspaceController w) async {
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: AdministrationView(controller: w)),
      ),
    ),
  );
  await t.pump();
}
