import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/resource_snapshot_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_scopes_view.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_flutter/features/joint_channel_views.dart';
import 'package:raft_flutter/features/management_support.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_flutter/features/sidebar_preferences_view.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_ui/raft_ui.dart';

/// Routes answer at once unless [gate] is set; then every GET/POST waits for
/// it, so a test can observe the frames before any response lands.
class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, FutureOr<dynamic> Function(RequestOptions)>{};
  final statuses = <String, int>{};
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    final key = '${o.method} ${o.path}', route = routes[key];
    if (!o.path.startsWith('/auth/')) await gate?.future;
    return ResponseBody.fromString(
      jsonEncode(route == null ? {'error': 'Unexpected'} : await route(o)),
      statuses[key] ?? (route == null ? 404 : 200),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client({
    required super.origin,
    required super.sessionStore,
    required super.transport,
  });
  final forwarded = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => forwarded.stream;
  @override
  Future<void> dispose() async {
    await forwarded.close();
    await super.dispose();
  }
}

Future<(WorkspaceController, _Adapter)> _fixture([
  String role = 'owner',
]) async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture',
    'refreshToken': 'fixture',
    'user': {'id': 'alice'},
  };
  final client = _Client(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'name': 'Fixture', 'role': role});
  w.servers = [w.server!];
  return (w, a);
}

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: child),
);

/// Leave the page (its State disposes), as a route change does.
Future<void> _leave(WidgetTester t) async {
  await t.pumpWidget(_host(const SizedBox()));
  await t.pumpAndSettle();
}

Finder get _anySpinner => find.byWidgetPredicate(
  (w) =>
      w is LinearProgressIndicator ||
      w is CircularProgressIndicator ||
      w is RaftSpinner,
);

/// Release the gated responses and pump frame by frame until [done], checking
/// that every rect in [rects] holds still and no loading state appears.
Future<void> _settleStable(
  WidgetTester t,
  _Adapter a,
  Map<Finder, Rect> rects, {
  required bool Function() done,
}) async {
  a.gate!.complete();
  a.gate = null;
  for (var frame = 0; frame < 40; frame++) {
    await t.pump(const Duration(milliseconds: 16));
    expect(_anySpinner, findsNothing, reason: 'frame $frame');
    for (final entry in rects.entries) {
      expect(t.getRect(entry.key), entry.value, reason: 'frame $frame');
    }
    if (done() && frame > 4) break;
  }
  expect(done(), isTrue);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Map<Finder, Rect> _rects(WidgetTester t, Iterable<Finder> finders) => {
  for (final f in finders) f: t.getRect(f),
};

int _requests(_Adapter a, String path) =>
    a.calls.where((c) => c.path == path).length;

void main() {
  group('management pages', () {
    void appRoutes(_Adapter a, String beta) {
      a.routes['GET /integrations/clients'] = (_) => [
        {'id': 'a1', 'name': 'Alpha app', 'allowedScopes': []},
        {'id': 'a2', 'name': beta, 'allowedScopes': []},
      ];
      a.routes['GET /integrations/marketplace'] = (_) => <dynamic>[];
      a.routes['GET /integrations/overview'] = (_) => <dynamic>[];
    }

    testWidgets(
      'revisit renders the snapshot at the first frame and revalidates in place',
      (t) async {
        final (w, a) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        appRoutes(a, 'Beta app');
        await t.pumpWidget(_host(IntegrationsView(controller: w)));
        expect(_anySpinner, findsOneWidget, reason: 'true cold load');
        await t.pumpAndSettle();
        await _leave(t);

        appRoutes(a, 'Beta app v2');
        a.gate = Completer<void>();
        final before = _requests(a, '/integrations/clients');
        await t.pumpWidget(_host(IntegrationsView(controller: w)));
        // First frame: accepted rows, no loading state, request in flight.
        expect(find.text('Alpha app'), findsOneWidget);
        expect(find.text('Beta app'), findsOneWidget);
        expect(_anySpinner, findsNothing);
        for (
          var i = 0;
          i < 10 && _requests(a, '/integrations/clients') == before;
          i++
        ) {
          await t.pump(const Duration(milliseconds: 1));
        }
        expect(_requests(a, '/integrations/clients'), before + 1);
        expect(find.text('Beta app'), findsOneWidget);
        final alpha = find.text('Alpha app');
        await _settleStable(
          t,
          a,
          _rects(t, [alpha, find.text('Marketplace')]),
          done: () => find.text('Beta app v2').evaluate().isNotEmpty,
        );
        expect(find.text('Beta app'), findsNothing);
      },
    );

    testWidgets('unchanged rows keep their accepted objects', (t) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      appRoutes(a, 'Beta app');
      await t.pumpWidget(_host(IntegrationsView(controller: w)));
      await t.pumpAndSettle();
      final identity = pageIdentity(w);
      List<Map<String, dynamic>> rows() =>
          w.resourceSnapshots
                  .read<FieldSnapshot>('management:integrations', identity)!
                  .fields['apps']
              as List<Map<String, dynamic>>;
      final first = rows();
      appRoutes(a, 'Beta app v2');
      await t.tap(find.byTooltip('Refresh'));
      await t.pumpAndSettle();
      final second = rows();
      expect(second.first, same(first.first));
      expect(second.last, isNot(same(first.last)));
      expect(second.last['name'], 'Beta app v2');
    });

    testWidgets('a failed revalidation keeps the accepted rows', (t) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      appRoutes(a, 'Beta app');
      await t.pumpWidget(_host(IntegrationsView(controller: w)));
      await t.pumpAndSettle();
      await _leave(t);
      a.statuses['GET /integrations/clients'] = 500;
      await t.pumpWidget(_host(IntegrationsView(controller: w)));
      expect(find.text('Alpha app'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('Alpha app'), findsOneWidget);
      expect(find.text('Beta app'), findsOneWidget);
      expect(_anySpinner, findsNothing);
      // The page's own non-destructive error line.
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsWidgets,
      );
    });

    testWidgets(
      'a page mutation updates the snapshot without its one-time secret',
      (t) async {
        final (w, a) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        final apps = <Map<String, dynamic>>[];
        a.routes['GET /integrations/clients'] = (_) => apps;
        a.routes['GET /integrations/marketplace'] = (_) => <dynamic>[];
        a.routes['GET /integrations/overview'] = (_) => <dynamic>[];
        a.routes['POST /integrations/clients'] = (o) {
          final app = <String, dynamic>{
            'id': 'created',
            'name': o.data['name'],
            'allowedScopes': o.data['allowedScopes'],
          };
          apps.add(app);
          return {'client': app, 'clientSecret': 'one-time-secret'};
        };
        await t.pumpWidget(_host(IntegrationsView(controller: w)));
        await t.pumpAndSettle();
        await t.tap(find.text('Register app'));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('field-name')),
          'Created app',
        );
        await t.tap(find.text('Register'));
        await t.pumpAndSettle();
        await t.tap(find.text('Close'));
        await t.pumpAndSettle();
        await _leave(t);
        final snapshot = w.resourceSnapshots.read<FieldSnapshot>(
          'management:integrations',
          pageIdentity(w),
        )!;
        expect(jsonEncode(snapshot.fields), isNot(contains('one-time-secret')));
        a.gate = Completer<void>();
        await t.pumpWidget(_host(IntegrationsView(controller: w)));
        expect(find.text('Created app'), findsOneWidget);
        expect(_anySpinner, findsNothing);
        a.gate!.complete();
        await t.pumpAndSettle();
      },
    );

    for (final change in ['role', 'server', 'principal']) {
      testWidgets('$change change never shows the other identity snapshot', (
        t,
      ) async {
        final (w, a) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        appRoutes(a, 'Beta app');
        await t.pumpWidget(_host(IntegrationsView(controller: w)));
        await t.pumpAndSettle();
        await _leave(t);
        switch (change) {
          case 'role':
            w.server = RaftRecord({'id': 's1', 'role': 'admin'});
          case 'server':
            w.client.selectServer('s2');
            w.server = RaftRecord({'id': 's2', 'role': 'owner'});
          case 'principal':
            w.client.user = RaftRecord({'id': 'bob'});
        }
        a.gate = Completer<void>();
        await t.pumpWidget(_host(IntegrationsView(controller: w)));
        expect(find.text('Alpha app'), findsNothing);
        expect(_anySpinner, findsOneWidget);
        a.gate!.complete();
        await t.pumpAndSettle();
      });
    }

    testWidgets(
      'a live identity change blanks the page and drops its snapshot',
      (t) async {
        final (w, a) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        appRoutes(a, 'Beta app');
        await t.pumpWidget(_host(IntegrationsView(controller: w)));
        await t.pumpAndSettle();
        final owner = pageIdentity(w);
        a.gate = Completer<void>();
        w.server = RaftRecord({'id': 's1', 'role': 'member'});
        w.notifyListeners();
        await t.pump();
        expect(find.text('Alpha app'), findsNothing);
        expect(_anySpinner, findsOneWidget);
        expect(
          w.resourceSnapshots.read<FieldSnapshot>(
            'management:integrations',
            owner,
          ),
          isNull,
        );
        a.gate!.complete();
        await t.pumpAndSettle();
      },
    );

    for (final changed in [false, true]) {
      testWidgets(
        changed
            ? 'joint channels reject a snapshot accepted before an access change'
            : 'joint channels revisit renders the snapshot at once',
        (t) async {
          final (w, a) = (await t.runAsync(_fixture))!;
          addTearDown(w.dispose);
          final shared = {
            'id': 'j1',
            'name': 'shared',
            'type': 'joint',
            'joined': true,
          };
          w.channels = [RaftChannel(shared)];
          a.routes['GET /channels/joint-invites'] = (_) => {'invites': []};
          a.routes['GET /channels'] = (_) => [shared];
          await t.pumpWidget(_host(JointChannelsView(controller: w)));
          await t.pumpAndSettle();
          expect(find.text('#shared'), findsOneWidget);
          await _leave(t);
          if (changed) {
            w.channels = [
              RaftChannel({...shared, 'joined': false}),
            ];
          }
          a.gate = Completer<void>();
          await t.pumpWidget(_host(JointChannelsView(controller: w)));
          expect(find.text('#shared'), changed ? findsNothing : findsOneWidget);
          expect(_anySpinner, changed ? findsOneWidget : findsNothing);
          a.gate!.complete();
          await t.pumpAndSettle();
        },
      );
    }

    testWidgets('sidebar preferences revisit skips its full-page spinner', (
      t,
    ) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /servers/s1/sidebar-order'] = (_) => {
        'customSections': [
          {'id': 'x', 'name': 'Focus', 'sortMode': 'manual'},
        ],
      };
      a.routes['GET /agents'] = (_) => [
        {'id': 'g1', 'name': 'Cindy'},
      ];
      await t.pumpWidget(_host(SidebarPreferencesView(controller: w)));
      expect(_anySpinner, findsOneWidget);
      await t.pumpAndSettle();
      await _leave(t);
      a.gate = Completer<void>();
      await t.pumpWidget(_host(SidebarPreferencesView(controller: w)));
      expect(_anySpinner, findsNothing);
      final section = find.text(' Focus');
      expect(section, findsOneWidget);
      await _settleStable(
        t,
        a,
        _rects(t, [section, find.text('Sidebar preferences')]),
        done: () => true,
      );
    });
  });

  group('settings views', () {
    Future<void> revisit(
      WidgetTester t,
      _Adapter a,
      Widget Function() page,
      Finder content,
    ) async {
      await t.pumpWidget(_host(page()));
      expect(_anySpinner, findsOneWidget, reason: 'true cold load');
      await t.pumpAndSettle();
      expect(content, findsWidgets);
      await _leave(t);
      a.gate = Completer<void>();
      await t.pumpWidget(_host(page()));
      expect(_anySpinner, findsNothing);
      expect(content, findsWidgets);
      await _settleStable(t, a, _rects(t, [content.first]), done: () => true);
    }

    testWidgets('release notes', (t) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /release-notes'] = (_) => {
        'items': [
          {
            'version': '1.2.0',
            'date': '2026-10-01',
            'entries': [
              {'text': 'Faster revisits'},
            ],
          },
        ],
      };
      await revisit(
        t,
        a,
        () => SingleChildScrollView(child: ReleaseNotesView(controller: w)),
        find.text('Faster revisits'),
      );
    });

    testWidgets('workspace access', (t) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /servers/s1'] = (_) => {'id': 's1', 'name': 'Fixture'};
      a.routes['GET /servers/s1/notification-settings'] = (_) => {
        'serverPushMode': 'mentions',
      };
      a.routes['GET /servers/s1/invites'] = (_) => <dynamic>[];
      a.routes['GET /servers/s1/join-links'] = (_) => <dynamic>[];
      await revisit(
        t,
        a,
        () => SingleChildScrollView(
          child: WorkspaceAccessSettings(controller: w),
        ),
        find.text('Mentions only'),
      );
    });

    testWidgets('agent permissions', (t) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /agents/g1/scopes'] = (_) => {
        'granted': ['message:read'],
        'mode': 'custom',
      };
      await revisit(
        t,
        a,
        () => AgentScopesView(controller: w, agentId: 'g1'),
        find.text('Custom permissions'),
      );
    });

    testWidgets('fleet inspection', (t) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /agents/g1/channels'] = (_) => [
        {'name': 'general', 'detail': 'joined'},
      ];
      await revisit(
        t,
        a,
        () => FleetInspection(
          controller: w,
          base: '/agents/g1',
          kind: 'channels',
          computers: false,
        ),
        find.text('general'),
      );
    });
  });

  group('channel settings', () {
    RaftChannel channel(String id, String name) => RaftChannel({
      'id': id,
      'name': name,
      'type': 'channel',
      'joined': true,
      'activityMuteSupported': true,
    });

    void routes(_Adapter a, String id, {bool collapse = true}) {
      a.routes['GET /channels/$id/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      a.routes['GET /servers/s1/sidebar-order'] = (_) => {
        'pinned': [
          {'kind': 'channel', 'id': 'c1'},
        ],
      };
      a.routes['GET /channels/$id/message-display-settings'] = (_) => {
        'collapseLongMessages': collapse,
      };
      a.routes['GET /channels/$id/notification-settings'] = (_) => {
        'activityMuted': false,
      };
      a.routes['GET /channels/$id'] = (_) => {
        'id': id,
        'name': id == 'c1' ? 'work' : 'play',
        'type': 'channel',
      };
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'server_guest_v0', 'enabled': true},
          {'key': channelConversionFlag, 'enabled': true},
        ],
      };
    }

    Widget sheet(WorkspaceController w, RaftChannel c) =>
        ChannelSettings(controller: w, channel: c, isPanel: true);

    Finder rowSwitch(String label) => find.byWidgetPredicate(
      (w) => w is RaftSwitch && w.semanticLabel == label,
    );
    bool switchShown(WidgetTester t, String label) => t
        .widget<Visibility>(
          find.ancestor(
            of: rowSwitch(label),
            matching: find.byType(Visibility),
          ),
        )
        .visible;

    List<Finder> layout() => [
      find.text('Chat with members from other servers'),
      find.byType(RaftDialogTextInput).first,
      find.text('Guest access'),
      find.text('Pin channel'),
      find.text('Mute activity'),
      find.text('Collapse long messages'),
      find.text('Leave Channel'),
    ];

    Future<(WorkspaceController, _Adapter)> opened(WidgetTester t) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final c1 = channel('c1', 'work');
      w.channels = [c1, channel('c2', 'play')];
      routes(a, 'c1');
      routes(a, 'c2', collapse: false);
      t.view.physicalSize = const Size(1200, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_host(sheet(w, c1)));
      // True cold load: no flags for this server identity yet.
      expect(find.byType(RaftSpinner), findsOneWidget);
      await t.pumpAndSettle();
      for (final f in layout()) {
        expect(f, findsOneWidget);
      }
      return (w, a);
    }

    testWidgets('revisit opens final with no spinner or layout shift', (
      t,
    ) async {
      final (w, a) = await opened(t);
      final settled = _rects(t, layout());
      await _leave(t);
      a.gate = Completer<void>();
      await t.pumpWidget(_host(sheet(w, w.channels.first)));
      expect(find.byType(RaftSpinner), findsNothing);
      expect(_rects(t, layout()).values.toList(), settled.values.toList());
      expect(switchShown(t, 'Pin channel'), isTrue);
      expect(t.widget<RaftSwitch>(rowSwitch('Pin channel')).value, isTrue);
      expect(switchShown(t, 'Collapse long messages'), isTrue);
      await _settleStable(t, a, settled, done: () => true);
    });

    testWidgets(
      'first open of another channel reserves its rows and never shifts',
      (t) async {
        final (w, a) = await opened(t);
        await _leave(t);
        a.gate = Completer<void>();
        await t.pumpWidget(_host(sheet(w, w.channels.last)));
        expect(find.byType(RaftSpinner), findsNothing);
        // Flags are server-level: guest and conversion sections are final.
        expect(find.text('Guest access'), findsOneWidget);
        expect(
          find.text('Chat with members from other servers'),
          findsOneWidget,
        );
        // Per-channel values are in flight: rows hold their space.
        expect(switchShown(t, 'Mute activity'), isFalse);
        expect(switchShown(t, 'Collapse long messages'), isFalse);
        final reserved = _rects(t, layout());
        await _settleStable(
          t,
          a,
          reserved,
          done: () => switchShown(t, 'Collapse long messages'),
        );
        expect(switchShown(t, 'Mute activity'), isTrue);
        expect(
          t.widget<RaftSwitch>(rowSwitch('Collapse long messages')).value,
          isFalse,
        );
      },
    );

    testWidgets('a member event refreshes only the roster, in place', (
      t,
    ) async {
      final (w, a) = await opened(t);
      final settled = _rects(t, layout());
      final calls = a.calls.length;
      (w.client as _Client).forwarded.add(
        const RaftEvent('channel:members-updated', {'channelId': 'c1'}),
      );
      for (var frame = 0; frame < 20; frame++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(find.byType(RaftSpinner), findsNothing);
        expect(
          _rects(t, layout()).values.toList(),
          settled.values.toList(),
          reason: 'frame $frame',
        );
      }
      await t.pumpAndSettle();
      final after = a.calls.skip(calls).map((c) => c.path).toList();
      expect(after, contains('/channels/c1/members'));
      for (final path in [
        '/servers/s1/sidebar-order',
        '/channels/c1/message-display-settings',
        '/channels/c1/notification-settings',
      ]) {
        expect(after, isNot(contains(path)));
      }
      expect(_rects(t, layout()).values.toList(), settled.values.toList());
    });

    for (final change in ['role', 'server']) {
      testWidgets('$change change never reuses the channel snapshot', (
        t,
      ) async {
        final (w, a) = await opened(t);
        await _leave(t);
        if (change == 'role') {
          w.server = RaftRecord({'id': 's1', 'role': 'admin'});
        } else {
          w.client.selectServer('s2');
          w.server = RaftRecord({'id': 's2', 'role': 'owner'});
        }
        a.gate = Completer<void>();
        await t.pumpWidget(_host(sheet(w, w.channels.first)));
        // Nothing from the other identity: flags are cold again.
        expect(find.byType(RaftSpinner), findsOneWidget);
        expect(find.text('Guest access'), findsNothing);
        a.gate!.complete();
        await t.pumpAndSettle();
      });
    }
  });
}
