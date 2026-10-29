import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/administration_view.dart';
import 'package:raft_flutter/features/connected_app_editor.dart';
import 'package:raft_flutter/features/invite_accept_view.dart';
import 'package:raft_flutter/features/management_support.dart';
import 'package:raft_flutter/features/notification_settings_view.dart';
import 'package:raft_flutter/features/provider_views.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_flutter/features/sidebar_preferences_view.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/client_release_notes.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'notification_settings_view_test.dart' as notif;
import 'support/close_support.dart' show frames;
import 'support/memory_storage.dart';
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'flutter_test_config.dart' show leakDebt;

/// Settings, account, integrations and public pages open from what the app
/// already holds (a previous visit, the workspace directory, the sidebar the
/// rail loaded), with a network that never answers.
Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// For pages that scroll themselves.
Widget _fullPage(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: SizedBox.expand(child: child)),
);

Future<(WorkspaceController, MessageAdapter)> _workspace(WidgetTester t) async {
  t.view.physicalSize = const Size(1280, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final (w, api) = await pageFixture(t);
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  return (w, api);
}

/// Visits [page] with the network answering, leaves it, then comes back with a
/// network that never answers. [seen] runs at the first revisit frames.
Future<void> _revisit(
  WidgetTester t,
  MessageAdapter api,
  Widget Function() page,
  void Function() seen, {
  Widget Function(Widget) host = _host,
}) async {
  await t.pumpWidget(host(page()));
  await frames(t, 20);
  await t.pumpWidget(host(const SizedBox()));
  await frames(t, 2);
  api.hangAll = true;
  await t.pumpWidget(host(page()));
  await frames(t, 3);
  seen();
  api.hangAll = false;
}

void main() {
  // Leak debt (app root, dialog notifier): see docs/development.md, Leak tracking.
  leakDebt(const ['Service', 'ValueNotifier<ConnectedAppSecret?>']);
  setUp(() {
    PublicServerMemory.clear();
    InviteInfoMemory.clear();
  });

  group('administration sections revisit', () {
    final cases = <(String, void Function(MessageAdapter), void Function())>[
      (
        'pending invites keep their empty line',
        (api) => api.routes['GET /servers/s1/invites'] = (_) => [],
        () => expect(find.text('No pending invites.'), findsOneWidget),
      ),
      (
        'invite links keep their rows',
        (api) => api.routes['GET /servers/s1/join-links'] = (_) => [
          {'id': 'l1', 'token': 'tok1', 'useCount': 2},
        ],
        () => expect(find.textContaining('/join/tok1'), findsOneWidget),
      ),
      (
        'the agreement keeps its text',
        (api) => api.routes['GET /servers/s1/agreement'] = (_) => {
          'enabled': true,
          'agreement': {'title': 'House rules', 'bodyMarkdown': 'Be kind'},
        },
        () => expect(find.text('House rules'), findsOneWidget),
      ),
    ];
    for (final (name, route, seen) in cases) {
      testWidgets(name, (t) async {
        final (w, api) = await _workspace(t);
        route(api);
        await _revisit(t, api, () => AdministrationView(controller: w), seen);
      });
    }
  });

  testWidgets('release notes keep their list on a revisit', (t) async {
    final (w, api) = await _workspace(t);
    final source = ClientReleaseNotes(
      storage: MemoryStorage(),
      fetch: (_) async => jsonEncode({
        'items': [
          {
            'releaseId': 'v1.0.0+1',
            'date': '2026-10-01',
            'state': 'published',
            'version': '1.0',
            'entries': [
              {
                'type': 'feature',
                'text': 'Instant settings',
                'emphasis': false,
              },
            ],
          },
        ],
        'nextCursor': null,
      }),
    );
    await _revisit(
      t,
      api,
      () => ReleaseNotesView(controller: w, source: source),
      () => expect(find.text('Instant settings'), findsOneWidget),
      // The view scrolls itself (pull to refresh).
      host: _fullPage,
    );
  });

  testWidgets('sidebar preferences open from the rail order and the agent '
      'directory on the very first visit', (t) async {
    final (w, api) = await _workspace(t);
    api.routes['GET /agents'] = (_) => [
      {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy'},
    ];
    await t.runAsync(
      () => w.entityDirectory.refresh(WorkspaceEntityKind.agents, force: true),
    );
    w.sidebarOrder = {
      'sectionsVersion': 1,
      'customSections': [
        {'id': 'sec', 'name': 'Reading list', 'sortMode': 'manual'},
      ],
      'sectionPlacements': [],
      'channelOrder': [],
      'dmOrder': [],
    };
    api.hangAll = true;
    await t.pumpWidget(_fullPage(SidebarPreferencesView(controller: w)));
    await frames(t, 3);
    expect(
      find.byKey(const ValueKey('sidebar-custom-section-sec')),
      findsOneWidget,
    );
    expect(find.text('Cindy', skipOffstage: false), findsWidgets);
    expect(find.byType(RaftProgressBar), findsNothing);
  });

  group('provider dialogs open before their data arrives', () {
    final cases = <(String, String, String, String)>[
      (
        'Assigned Agents',
        'Agents using Provider fixture',
        'agents',
        'Loading agents…',
      ),
      (
        'Verification History',
        'Provider verification history',
        'history',
        'Loading verification history…',
      ),
      (
        'Verify on Computer',
        'Verify on Computer',
        'verify',
        'Loading computers…',
      ),
    ];
    for (final (action, title, name, loading) in cases) {
      testWidgets(name, (t) async {
        final (w, api) = await _workspace(t);
        api.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [
            {'key': 'provider_connections_v0', 'enabled': true},
          ],
        };
        api.routes['GET /provider-connections'] = (_) => {
          'connections': [
            {
              'id': 'p1',
              'name': 'Provider fixture',
              'providerId': 'openai',
              'status': 'configured',
              'enabled': true,
              'assignedAgentCount': 0,
            },
          ],
          'providerOptions': <dynamic>[],
        };
        api.routes['GET /servers/s1/machines'] = (_) => {
          'machines': [
            {
              'id': 'computer1',
              'name': 'Computer fixture',
              'status': 'online',
              'runtimes': ['builtin'],
            },
          ],
        };
        api.routes['GET /provider-connections/p1/models'] = (_) => {
          'models': ['fixture-model'],
        };
        await t.runAsync(
          () => w.entityDirectory.refresh(
            WorkspaceEntityKind.computers,
            force: true,
          ),
        );
        await t.pumpWidget(_fullPage(ProviderConnectionsView(controller: w)));
        await frames(t, 20);
        api.hangAll = true;
        await t.ensureVisible(find.text(action));
        await t.tap(find.text(action));
        await frames(t, 4);
        expect(find.text(title), findsNWidgets(action == title ? 2 : 1));
        expect(find.text(loading), findsOneWidget);
        // Closing never waits for the held request either.
        await t.tap(
          find.text('Close').evaluate().isNotEmpty
              ? find.text('Close')
              : find.byType(RaftDialogClose),
        );
        await frames(t, 20);
        expect(find.text(title), findsNWidgets(action == title ? 1 : 0));
        api.hangAll = false;
      });
    }
  });

  testWidgets('the app editor keeps its App Notifications settings on a '
      'revisit', (t) async {
    final (w, api) = await _workspace(t);
    api.routes['GET /integrations/clients/app-1/share-link'] = (_) => {};
    api.routes['GET /integrations/clients/app-1/app-notifications'] = (_) => {
      'request_revision': 0,
      'current_groups': ['server'],
      'current_events': <String>[],
      'pending_revision': null,
      'webhook': {'enabled': false, 'signing_secret': 'whsec_never_cached'},
    };
    final secret = ValueNotifier<ConnectedAppSecret?>(null);
    Widget editor() => ConnectedAppEditor(
      controller: w,
      secret: secret,
      app: const {
        'id': 'app-1',
        'clientId': 'db9',
        'name': 'db9 Drive',
        'allowedScopes': ['openid', 'profile', 'identity'],
        'category': 'Other',
        'publishStatus': 'private',
        'appType': 'server_local',
      },
      onSaved: ({created}) async {},
      onClose: () {},
      onDenied: (_) => false,
    );
    await _revisit(t, api, editor, () {
      expect(find.text('Loading'), findsNothing);
      expect(find.text('Off'), findsWidgets);
    });
    // Nothing secret is kept for the next visit.
    final kept = readPageSnapshot(w, 'integrations:app-notifications:app-1');
    expect(kept, isNotNull);
    expect(jsonEncode(kept), isNot(contains('whsec_never_cached')));
  });

  testWidgets('notification settings keep the accepted mute switch on a '
      'revisit', (t) async {
    final (w, a, service) = await t.runAsync(notif.fixture) as dynamic;
    addTearDown(w.dispose);
    Widget page() => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: NotificationSettingsView(
            controller: w as WorkspaceController,
            service: service,
          ),
        ),
      ),
    );
    await t.pumpWidget(page());
    await frames(t, 10);
    await t.pumpWidget(const SizedBox());
    final never = Completer<Map<String, dynamic>>();
    (a as notif.Adapter).settings = (_) => never.future;
    await t.pumpWidget(page());
    await frames(t, 3);
    final card = t.widget<RaftNotificationSettingsCard>(
      find.byType(RaftNotificationSettingsCard),
    );
    expect(card.onMutedChanged, isNotNull, reason: 'the switch is live');
  });

  testWidgets('the invite page returns with its details after sign-in', (
    t,
  ) async {
    final calls = <int>[];
    var hang = false;
    Widget page() => MaterialApp(
      theme: raftTheme(),
      home: InviteAcceptView(
        token: 'tok',
        signedIn: false,
        loadInfo: () {
          calls.add(1);
          if (hang) return Completer<Map<String, dynamic>>().future;
          return Future.value({
            'kind': 'email',
            'serverName': 'Raft Design',
            'inviterName': 'Wenyi',
            'memberCount': 3,
            'agentCount': 1,
          });
        },
        accept: (_) async => const InviteJoined('s1', 'Raft Design'),
        onEnter: (_) async => true,
        onSignIn: () {},
        onCreateAccount: () {},
        onGoToRaft: () {},
      ),
    );
    await t.pumpWidget(page());
    await frames(t, 5);
    expect(find.textContaining('Raft Design'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    hang = true;
    await t.pumpWidget(page());
    await frames(t, 3);
    expect(find.text('Loading invite…'), findsNothing);
    expect(find.textContaining('Raft Design'), findsWidgets);
    expect(calls.length, 2, reason: 'it still revalidates quietly');
  });

  group('public server', () {
    const base = '/public/servers/raft-design';
    Map<String, dynamic> message(String id, String content) => {
      'id': id,
      'senderType': 'user',
      'sender': {'displayName': 'Wenyi'},
      'messageType': 'chat',
      'content': content,
      'createdAt': '2026-06-18T09:12:00.000Z',
    };
    late _Client client;
    setUp(() {
      client = _Client({
        'GET $base': () => {
          'server': {'id': 's', 'name': 'Raft Design', 'slug': 'raft-design'},
          'channels': [
            {'id': 'c1', 'name': 'general'},
            {'id': 'c2', 'name': 'help'},
          ],
          'canJoinAsGuest': true,
        },
        'GET $base/channels/c1/messages': () => {
          'messages': [message('m1', 'Welcome to the community')],
        },
        'GET $base/channels/c2/messages': () => {
          'messages': [message('m2', 'Ask anything here')],
        },
      });
    });
    Widget page() => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: PublicServerView(
          client: client,
          slug: 'raft-design',
          onSignIn: () {},
          onRegister: () {},
          onUnavailable: () {},
        ),
      ),
    );

    testWidgets('a revisit shows the server and its messages at once', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(page());
      await frames(t, 10);
      await t.pumpWidget(const SizedBox());
      client.hang = true;
      await t.pumpWidget(page());
      await frames(t, 3);
      expect(find.text('Welcome to the community'), findsOneWidget);
      expect(find.text('Loading…'), findsNothing);
    });

    testWidgets('going back to a channel shows what was read', (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(page());
      await frames(t, 10);
      await t.tap(find.byKey(const ValueKey('public-channel-c2')));
      await frames(t, 10);
      expect(find.text('Ask anything here'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('public-channel-c1')));
      await frames(t, 10);
      client.hang = true;
      await t.tap(find.byKey(const ValueKey('public-channel-c2')));
      await frames(t, 2);
      expect(find.text('Ask anything here'), findsOneWidget);
    });
  });
}

class _Client extends RaftClient {
  _Client(this.routes)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final Map<String, Object? Function()> routes;
  bool hang = false;
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
    if (hang) return Completer<dynamic>().future;
    final route = routes['$method $path'];
    if (route == null) throw RaftApiException('Not found', status: 404);
    return route();
  }
}
