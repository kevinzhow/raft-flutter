import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_password_editor.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/create_agent_dialog.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_flutter/features/external_agent_setup.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;
import 'message_presentation_test.dart' show MessageAdapter, fixture;

/// Slice B of the transient-notice audit (dialogs and forms): every notice
/// must end with its cause. Each test fails on the code before its fix.

class _PasswordClient extends RaftClient {
  _PasswordClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
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
  }) async => {};
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final commands = <(String, String, dynamic)>[];
  Object? commandError;
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      <dynamic>[];
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method, path, data));
    if (commandError != null) throw commandError!;
    return <String, dynamic>{};
  }
}

const _ownerCaps = {
  'editChannelMetadata': true,
  'archiveChannels': true,
  'deleteChannels': true,
  'changeChannelVisibility': true,
  'manageGuestAccess': true,
  'federateChannels': false,
  'addChannelMembers': true,
  'removeChannelMembers': true,
  'changeChannelMemberRoles': true,
};

Map<String, dynamic> _channelRow() => {
  'id': 'c1',
  'name': 'work',
  'type': 'channel',
  'description': 'Release gates',
  'joined': true,
  'activityMuteSupported': true,
  'channelCapabilities': _ownerCaps,
};

void _channelRoutes(MessageAdapter api) {
  api.routes['GET /channels/c1/members'] = (_) => {
    'humans': [
      {'id': 'u1', 'userId': 'u1', 'name': 'ana', 'displayName': 'Ana'},
    ],
    'agents': <dynamic>[],
  };
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {
    'collapseLongMessages': true,
  };
  api.routes['GET /channels/c1/notification-settings'] = (_) => {
    'activityMuted': false,
  };
  api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'server_guest_v0', 'enabled': true},
    ],
  };
  api.routes['GET /channels'] = (_) => [_channelRow()];
  api.routes['GET /channels/dm'] = (_) => <dynamic>[];
  api.routes['GET /agents'] = (_) => <dynamic>[];
  api.routes['GET /servers/s1/members'] = (_) => [
    {'userId': 'u1', 'name': 'ana', 'displayName': 'Ana'},
    {'userId': 'u3', 'name': 'cy', 'displayName': 'Cy'},
  ];
}

Future<(WorkspaceController, MessageAdapter)> _openChannelSurface(
  WidgetTester t,
  void Function(BuildContext, WorkspaceController, RaftChannel) open, {
  void Function(MessageAdapter)? routes,
}) async {
  final (w, api) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  _channelRoutes(api);
  routes?.call(api);
  final channel = RaftChannel(_channelRow());
  w.channels = [channel];
  t.view.physicalSize = const Size(1280, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('host-open'),
            onPressed: () => open(context, w, channel),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const ValueKey('host-open')));
  await t.pumpAndSettle();
  return (w, api);
}

class _Adapter implements HttpClientAdapter {
  final statuses = <String, int>{};
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    final route = routes['${o.method} ${o.path}'];
    final data = route == null
        ? {'error': 'Unexpected endpoint'}
        : await route(o);
    return ResponseBody.fromString(
      jsonEncode(data),
      statuses['${o.method} ${o.path}'] ?? (route == null ? 404 : 200),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(WorkspaceController, _Adapter)> _integrationsFixture() async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({
    'id': 's1',
    'name': 'Test workspace',
    'role': 'owner',
  });
  w.servers = [w.server!];
  return (w, a);
}

class _ExternalClient extends RaftClient {
  _ExternalClient()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
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
    if (path == '/agents/ext-1/credentials' && method == 'GET') {
      return {
        'agentId': 'ext-1',
        'credentials': [
          {
            'id': 'cred-1',
            'maskedToken': 'sk_agent_ab12***9f3e',
            'createdAt': '2026-06-18T09:00:00.000Z',
          },
        ],
      };
    }
    // Generating and revoking both fail.
    throw const RaftApiException('boom', status: 500);
  }
}

/// The server projects the deprecated Copilot CLI as selectable.
class _CopilotWorkspace extends _Workspace {
  _CopilotWorkspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          {'runtimeId': 'copilot', 'canSelectInThisContext': true},
          {'runtimeId': 'codex', 'canSelectInThisContext': true},
        ],
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }
}

class _RescanWorkspace extends _Workspace {
  _RescanWorkspace(super.client);
  bool rescanFails = true;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': true},
        ],
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    if (path.endsWith('/runtimes/rescan') && rescanFails) {
      throw RaftApiException.response(
        'Rescan blocked',
        status: 409,
        body: {'error': 'Rescan blocked'},
      );
    }
    return <String, dynamic>{};
  }
}

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('account password editor', () {
    late _PasswordClient client;
    late WorkspaceController w;
    setUp(() {
      client = _PasswordClient()..user = RaftRecord({'id': 'owner'});
      w = WorkspaceController(client);
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });
    Finder field(String key) => find.byKey(ValueKey('account-$key-password'));
    Future<void> open(WidgetTester t) async {
      await t.pumpWidget(_host(AccountPasswordEditor(controller: w)));
      await t.tap(find.byKey(const ValueKey('account-change-password')));
      await t.pumpAndSettle();
    }

    testWidgets('"Password updated!" hides itself after two seconds', (
      t,
    ) async {
      await open(t);
      await t.enterText(field('current'), 'old-password');
      await t.enterText(field('new'), 'new-password');
      await t.enterText(field('confirm'), 'new-password');
      await t.tap(find.byKey(const ValueKey('account-password-submit')));
      await t.pump();
      await t.pump();
      expect(find.text('Password updated!'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Password updated!'), findsNothing);
    });

    testWidgets('an incomplete form is reported live and ends when fixed', (
      t,
    ) async {
      await open(t);
      await t.enterText(field('current'), 'old-password');
      await t.enterText(field('new'), 'new-password');
      await t.enterText(field('confirm'), 'other-password');
      await t.tap(find.byKey(const ValueKey('account-password-submit')));
      await t.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
      await t.enterText(field('confirm'), 'new-password');
      await t.pump();
      expect(find.text('Passwords do not match'), findsNothing);
    });
  });

  group('dialogs', () {
    late ActivityClient activity;
    late _Workspace ws;
    setUp(() {
      activity = ActivityClient()..user = RaftRecord({'id': 'alice'});
      activity.selectServer('s');
      ws = _Workspace(activity)
        ..server = RaftRecord({'id': 's', 'role': 'owner'})
        ..channels = [
          RaftChannel({
            'id': 'c1',
            'name': 'design',
            'type': 'channel',
            'joined': true,
          }),
        ];
    });
    tearDown(() async {
      ws.dispose();
      await activity.dispose();
    });
    Future<void> open(
      WidgetTester t,
      Widget Function(BuildContext) dialog,
    ) async {
      t.view.physicalSize = const Size(1280, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showRaftModal<Object?>(context, builder: dialog),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
    }

    testWidgets('create task: "title required" ends once a title is typed', (
      t,
    ) async {
      await open(t, (_) => CreateTaskDialog(controller: ws, channelId: 'c1'));
      await t.tap(find.byKey(const ValueKey('create-task-submit')));
      await t.pump();
      expect(find.text('At least one task title is required'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('create-task-title-0')),
        'Ship it',
      );
      await t.pump();
      expect(find.text('At least one task title is required'), findsNothing);
    });

    testWidgets('create channel: name rule ends once the name is valid', (
      t,
    ) async {
      await open(t, (_) => CreateChannelDialog(controller: ws));
      await t.tap(find.text('Create Channel').last);
      await t.pump();
      expect(find.text('Channel name is required'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'launch');
      await t.pump();
      expect(find.text('Channel name is required'), findsNothing);
    });

    testWidgets('create joint channel: name rule ends once the name is valid', (
      t,
    ) async {
      await open(
        t,
        (_) => CreateJointChannelDialog(
          agents: const [],
          users: const [],
          freePlan: false,
          onCreate: (_) async => {'id': 'new'},
          onUnarchive: (_) async => {'id': 'old'},
        ),
      );
      await t.tap(find.byKey(const ValueKey('joint-create-submit')));
      await t.pump();
      expect(find.text('Channel name is required'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('joint-name')), 'launch');
      await t.pump();
      expect(find.text('Channel name is required'), findsNothing);
    });
  });

  testWidgets('channel settings: a name error ends when the name is edited', (
    t,
  ) async {
    await _openChannelSurface(
      t,
      (context, w, channel) =>
          ChannelSettings.show(context, controller: w, channel: channel),
    );
    final name = find.byKey(const ValueKey('channel-settings-name'));
    await t.enterText(name, '1bad name');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('channel-settings-save-inline')));
    await t.pumpAndSettle();
    const rule = 'Start with a letter, then letters, numbers, - or _';
    expect(find.text(rule), findsOneWidget);
    await t.enterText(name, 'fine');
    await t.pump();
    expect(find.text(rule), findsNothing);
  });

  group('channel members', () {
    Future<(WorkspaceController, MessageAdapter)> openMembers(
      WidgetTester t, {
      void Function(MessageAdapter)? routes,
      bool add = false,
    }) => _openChannelSurface(
      t,
      (context, w, channel) => ChannelMembers.show(
        context,
        controller: w,
        channel: channel,
        startInAdd: add,
      ),
      routes: routes,
    );

    testWidgets('a failed roster read ends with the next roster that loads', (
      t,
    ) async {
      final (_, api) = await openMembers(
        t,
        routes: (api) => api.routes.remove('GET /channels/c1/members'),
      );
      expect(find.text('Unexpected endpoint'), findsOneWidget);
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [
          {'id': 'u1', 'userId': 'u1', 'name': 'ana', 'displayName': 'Ana'},
        ],
        'agents': <dynamic>[],
      };
      unawaited((t.state(find.byType(ChannelMembers)) as dynamic).load());
      await t.pumpAndSettle();
      expect(find.text('Unexpected endpoint'), findsNothing);
    });

    testWidgets('an add failure ends when the selection changes', (t) async {
      await openMembers(t, add: true);
      await t.tap(find.byKey(const ValueKey('add-candidate-human:u3')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('add-member-confirm')));
      await t.pumpAndSettle();
      expect(
        find.text('None of the selected members could be added.'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('add-candidate-human:u3')));
      await t.pump();
      expect(
        find.text('None of the selected members could be added.'),
        findsNothing,
      );
    });
  });

  group('create agent', () {
    testWidgets('a failed runtime rescan ends with the next rescan', (t) async {
      final activity = ActivityClient()..user = RaftRecord({'id': 'alice'});
      activity.selectServer('s');
      final ws = _RescanWorkspace(activity)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      addTearDown(() async {
        ws.dispose();
        await activity.dispose();
      });
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _host(
          CreateAgentDialog(
            controller: ws,
            machines: const [
              {
                'id': 'm',
                'name': 'Computer',
                'status': 'online',
                'runtimes': ['codex'],
              },
            ],
            initialRuntimeId: 'codex',
            onboarding: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('cindy-rescan-runtimes')));
      await t.pumpAndSettle();
      expect(find.text('Rescan blocked'), findsOneWidget);
      ws.rescanFails = false;
      await t.tap(find.byKey(const Key('cindy-rescan-runtimes')));
      await t.pumpAndSettle();
      expect(find.text('Rescan blocked'), findsNothing);
    });
  });

  testWidgets('create agent: the deprecated Copilot CLI is not offered', (
    t,
  ) async {
    // Web v1.21.12 CreateAgentDialog intersects the server's admission options
    // with getCreatableRuntimeOptions() (supported, not deprecated).
    final activity = ActivityClient()..user = RaftRecord({'id': 'alice'});
    activity.selectServer('s');
    final ws = _CopilotWorkspace(activity)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    addTearDown(() async {
      ws.dispose();
      await activity.dispose();
    });
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        CreateAgentDialog(
          controller: ws,
          machines: const [
            {
              'id': 'm',
              'name': 'Computer',
              'status': 'online',
              'runtimes': ['codex', 'copilot'],
            },
          ],
          initialRuntimeId: 'copilot',
          onboarding: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    // Copilot was asked for but is not creatable: the first creatable runtime
    // is selected instead and Copilot appears nowhere.
    expect(find.textContaining('Copilot'), findsNothing);
    expect(find.text('Codex CLI'), findsWidgets);
    await t.pumpWidget(const SizedBox.shrink());
  });

  group('external agent setup', () {
    Future<(WorkspaceController, _ExternalClient)> mount(WidgetTester t) async {
      final c = _ExternalClient()
        ..user = RaftRecord({'id': 'alice'})
        ..selectServer('s');
      final w = WorkspaceController(c)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await c.dispose();
      });
      t.view.physicalSize = const Size(900, 3200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _host(
          ExternalAgentSetup(
            controller: w,
            agent: const {
              'id': 'ext-1',
              'name': 'Hermes',
              'creatorType': 'user',
              'creatorId': 'alice',
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      return (w, c);
    }

    testWidgets('a token failure is dropped when the account changes', (
      t,
    ) async {
      final (w, c) = await mount(t);
      await t.tap(find.byKey(const ValueKey('external-token-generate')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('external-token-error')), findsOne);
      c.user = RaftRecord({'id': 'bob'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('external-token-error')), findsNothing);
    });

    testWidgets('a revoke failure is dropped when the account changes', (
      t,
    ) async {
      final (w, c) = await mount(t);
      await t.tap(find.byKey(const ValueKey('external-token-revoke-cred-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('external-token-confirm-revoke')));
      await t.pumpAndSettle();
      const text =
          'Revocation was not confirmed. Refresh to check the token before trying again.';
      expect(find.text(text), findsOneWidget);
      c.user = RaftRecord({'id': 'bob'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.text(text), findsNothing);
    });
  });

  group('connected apps', () {
    testWidgets('an uninstall failure ends when the next action starts', (
      t,
    ) async {
      final (w, a) = (await t.runAsync(_integrationsFixture))!;
      addTearDown(w.dispose);
      final held = Completer<dynamic>();
      a.routes['GET /integrations/clients'] = (_) => <dynamic>[];
      a.routes['GET /integrations/overview'] = (_) => <dynamic>[];
      a.routes['GET /integrations/marketplace'] = (_) => [
        for (final id in ['m1', 'm2'])
          {
            'id': id,
            'clientId': id,
            'name': 'App $id',
            'category': 'Other',
            'installedAt': '2026-10-01T00:00:00Z',
          },
      ];
      a.routes['DELETE /integrations/marketplace/m1/install'] = (_) => {
        'error': 'Uninstall refused',
      };
      a.statuses['DELETE /integrations/marketplace/m1/install'] = 500;
      a.routes['DELETE /integrations/marketplace/m2/install'] = (_) =>
          held.future;
      await t.pumpWidget(
        _host(SingleChildScrollView(child: IntegrationsView(controller: w))),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-installed')));
      await t.pumpAndSettle();
      const confirm = ValueKey('connected-app-uninstall-confirm-button');
      await t.tap(find.text('Uninstall').first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(confirm));
      await t.pumpAndSettle();
      expect(find.text('Uninstall refused'), findsOneWidget);
      await t.tap(find.text('Uninstall').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(confirm));
      await t.pump();
      // The second uninstall is running: the first one's failure is over.
      expect(find.text('Uninstall refused'), findsNothing);
      held.complete({'ok': true});
      await t.pumpAndSettle();
    });

    testWidgets('a regenerate failure ends when the retry succeeds', (t) async {
      final (w, a) = (await t.runAsync(_integrationsFixture))!;
      addTearDown(w.dispose);
      const app = {
        'id': 'app-1',
        'clientId': 'db9',
        'name': 'db9 Drive',
        'description': 'Cloud drive',
        'homepageUrl': 'https://db9.example',
        'returnUrl': 'https://db9.example/cb',
        'allowedScopes': ['openid', 'profile', 'identity'],
        'category': 'Other',
        'publishStatus': 'private',
        'appType': 'server_local',
      };
      a.routes['GET /integrations/clients'] = (_) => [app];
      a.routes['GET /integrations/marketplace'] = (_) => <dynamic>[];
      a.routes['GET /integrations/overview'] = (_) => <dynamic>[];
      a.routes['GET /integrations/clients/app-1/share-link'] = (_) => {
        'error': 'none',
      };
      a.statuses['GET /integrations/clients/app-1/share-link'] = 404;
      a.routes['GET /integrations/clients/app-1/app-notifications'] = (_) => {
        'request_revision': 0,
        'current_groups': ['server'],
        'current_events': <String>[],
        'pending_revision': null,
        'webhook': null,
      };
      var attempts = 0;
      a.routes['POST /integrations/clients/app-1/regenerate-secret'] = (_) {
        attempts++;
        if (attempts == 1) return {'error': 'Rotation failed'};
        a.statuses['POST /integrations/clients/app-1/regenerate-secret'] = 200;
        return {'client': app, 'clientSecret': 'rotated-secret'};
      };
      a.statuses['POST /integrations/clients/app-1/regenerate-secret'] = 500;
      await t.pumpWidget(
        _host(SingleChildScrollView(child: IntegrationsView(controller: w))),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-my-apps')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
      await t.pumpAndSettle();
      final button = find.byKey(
        const ValueKey('connected-app-regenerate-secret-button'),
      );
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      const confirm = ValueKey(
        'connected-app-regenerate-secret-confirm-button',
      );
      await t.tap(find.byKey(confirm));
      await t.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
      await t.tap(find.byKey(confirm));
      await t.pumpAndSettle();
      expect(find.text('rotated-secret'), findsOneWidget);
      expect(find.byType(RaftConnectedAppsError), findsNothing);
    });
  });
}
