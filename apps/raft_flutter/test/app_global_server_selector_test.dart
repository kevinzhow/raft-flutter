import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/app_root_router.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;

class RootAdapter extends MessageAdapter {
  final statuses = <String, int>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final key = '${options.method} ${options.path}',
        route = routes['${options.method} ${options.path}'];
    return ResponseBody.fromString(
      jsonEncode(
        route == null ? {'error': 'Unexpected endpoint'} : await route(options),
      ),
      route == null ? 404 : statuses[key] ?? 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class RootCache implements WorkspaceCache {
  final rows = <String, dynamic>{};
  String key(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) => '$origin|$principal|$server|$kind|$id';
  @override
  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async => rows[key(origin, principal, server, kind, id)];
  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    rows[key(origin, principal, server, kind, id)] = value;
  }

  /// `origin|principal|server` → message id → entry, least recently used
  /// first.
  final translations = <String, Map<String, Map<String, dynamic>>>{};

  @override
  Future<void> clearAccount(String origin, String principal) async {
    rows.removeWhere((k, _) => k.startsWith('$origin|$principal|'));
    translations.removeWhere((k, _) => k.startsWith('$origin|$principal|'));
  }

  @override
  Future<void> revokeServer(
    String origin,
    String principal,
    String server,
  ) async {
    rows.removeWhere((k, _) => k.startsWith('$origin|$principal|$server|'));
    translations.remove('$origin|$principal|$server');
  }

  @override
  Future<void> revokeChannel(
    String origin,
    String principal,
    String server,
    String channel,
  ) async {
    rows.removeWhere(
      (k, _) =>
          k.startsWith('$origin|$principal|$server|') &&
          k.endsWith('|$channel'),
    );
    translations['$origin|$principal|$server']?.removeWhere(
      (_, e) => e['channelId'] == channel,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String origin,
    String principal,
    String server,
  ) async => [
    ...?translations['$origin|$principal|$server']?.values.toList().reversed,
  ];

  @override
  Future<void> writeTranslations(
    String origin,
    String principal,
    String server,
    List<Map<String, dynamic>> entries,
  ) async {
    final scope = translations.putIfAbsent(
      '$origin|$principal|$server',
      () => {},
    );
    for (final entry in entries) {
      scope
        ..remove('${entry['messageId']}')
        ..['${entry['messageId']}'] = Map<String, dynamic>.from(entry);
    }
  }

  @override
  Future<void> close() async {}
}

class RootContent extends NativeContentCoordinator {
  WorkspaceController? bound;
  final bindings = <WorkspaceController?>[];
  @override
  Future<void> init({List<String> initialArguments = const []}) async {}
  @override
  void bindWorkspace(WorkspaceController? workspace) {
    bound = workspace;
    bindings.add(workspace);
  }

  @override
  Future<void> dispose() async {
    notifications.dispose();
  }
}

class RootClient extends RaftClient {
  RootClient(
    String origin,
    SessionStore store,
    String kind,
    MessageAdapter adapter,
  ) : super(
        origin: origin,
        sessionStore: store,
        clientKind: kind,
        transport: Dio()..httpClientAdapter = adapter,
      ) {
    forwardedEvents = super.events.listen(injectedEvents.add);
  }
  final injectedEvents = StreamController<RaftEvent>.broadcast();
  late final StreamSubscription<RaftEvent> forwardedEvents;
  int disposalCount = 0;
  @override
  Stream<RaftEvent> get events => injectedEvents.stream;
  @override
  void connect() {}
  void event(String name, dynamic payload) =>
      injectedEvents.add(RaftEvent(name, payload));
  @override
  Future<void> dispose() async {
    if (disposalCount > 0) return;
    disposalCount++;
    await super.dispose();
    await forwardedEvents.cancel();
    await injectedEvents.close();
  }
}

class RootFixture {
  RootFixture({RootCache? cache}) : cache = cache ?? RootCache();
  final RootCache cache;
  final engineRoutes = <Map<dynamic, dynamic>>[];
  final adapter = RootAdapter(),
      content = RootContent(),
      sessions = MemorySessionStore();
  late RootClient client;
  final servers = <Map<String, dynamic>>[
    {'id': 'a', 'name': 'Alpha', 'slug': 'alpha', 'role': 'owner'},
    {'id': 'b', 'name': 'Beta', 'slug': 'beta', 'role': 'owner'},
  ];
  FutureOr<dynamic> Function()? serverDirectory;

  /// Routes held by a test (`'GET /servers'`, ...): installed after the
  /// defaults, so the response arrives only when the test completes it.
  final holds = <String, Completer<dynamic>>{};

  /// Routes replacing the defaults (installed before [holds]).
  final overrides = <String, FutureOr<dynamic> Function(RequestOptions)>{};
  Future<void> mount(
    WidgetTester t,
    String theme,
    double width, {
    Uri? uri,
    bool offlineRestore = false,
    bool cachedSession = false,
    String principal = 'alice',
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      'raft.origin': 'https://fixture.invalid',
      'raft.mode': theme == 'elegant-dark' ? 'dark' : 'light',
      'raft.light': theme == 'brutal' ? 'brutal' : 'elegant',
      ...preferences,
    });
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          engineRoutes.add(Map<dynamic, dynamic>.from(call.arguments));
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
    t.view.resetPhysicalSize();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 900);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await sessions.write(
      'https://fixture.invalid',
      Session(
        accessToken: 'fixture-only',
        refreshToken: 'fixture-only',
        cachedUser: offlineRestore || cachedSession
            ? {
                'id': principal,
                'name': principal,
                'email': '$principal@example.invalid',
                'emailVerified': true,
              }
            : null,
      ),
    );
    adapter.routes['GET /auth/me'] = (_) => {
      'id': principal,
      'name': principal,
      'email': '$principal@example.invalid',
      'emailVerified': true,
    };
    if (offlineRestore) adapter.statuses['GET /auth/me'] = 503;
    adapter.routes['GET /servers'] = (_) => serverDirectory?.call() ?? servers;
    adapter.routes['GET /channels'] = (o) {
      final id = o.headers['X-Server-Id'];
      return [
        {
          'id': 'c$id',
          'name': 'general-$id',
          'type': 'channel',
          'serverId': id,
          'joined': true,
          'latestSeq': '1',
        },
      ];
    };
    adapter.routes['GET /channels/dm'] = (_) => [];
    adapter.routes['GET /channels/unread'] = (_) => {'channels': {}};
    adapter.routes['GET /channels/inbox'] = (_) => {
      'items': [],
      'hasMore': false,
      'totalUnreadCount': 0,
    };
    adapter.routes['GET /agents'] = (_) => [];
    adapter.routes['GET /machines'] = (_) => [];
    adapter.routes['GET /channels/public'] = (_) => [];
    adapter.routes['POST /auth/logout'] = (_) => {};
    for (final id in ['a', 'b', 'new']) {
      adapter.routes['GET /servers/$id/members'] = (_) => [];
      adapter.routes['GET /servers/$id/setup'] = (_) => {
        'phase': 'ready',
        'blocksChat': false,
      };
      adapter.routes['GET /messages/channel/c$id'] = (_) => {
        'messages': [
          {
            'id': 'm$id',
            'channelId': 'c$id',
            'seq': '1',
            'senderId': 'alice',
            'senderName': 'Alice',
            'content': 'Accepted $id',
            'createdAt': '2026-10-10T00:00:00Z',
          },
        ],
        'hasMore': false,
        'hasNewer': false,
      };
      adapter.routes['POST /channels/c$id/read'] = (_) => {};
      adapter.routes['GET /channels/c$id/members'] = (_) => [];
    }
    adapter.routes.addAll(overrides);
    for (final held in holds.entries) {
      final ordinary = adapter.routes[held.key];
      adapter.routes[held.key] = (o) async {
        final value = await held.value.future;
        return value ?? await ordinary?.call(o);
      };
    }
    await t.pumpWidget(
      RaftApp(
        sessionStore: sessions,
        initialLocation: uri ?? Uri(path: '/'),
        nativeContent: content,
        nativeSharing: NativeSharing(supported: false),
        openWorkspaceCache: () async => cache,
        createClient: (origin, store, kind) =>
            client = RootClient(origin, store, kind, adapter),
      ),
    );
    await flush(t);
  }

  /// The root surface painted by each [flush] frame, in order.
  final surfaces = <String>[];

  /// Runs after every [flush] frame (per-frame assertions).
  void Function()? onFrame;
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await t.pump(const Duration(milliseconds: 50));
      surfaces.add(
        find.byType(WorkspaceView).evaluate().isNotEmpty
            ? 'workspace'
            : find.byType(GlobalServerSelector).evaluate().isNotEmpty
            ? 'selector'
            : 'other',
      );
      onFrame?.call();
    }
  }

  Future<void> pushUri(WidgetTester t, String location) async {
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': location,
          'state': null,
        }),
      ),
      (_) {},
    );
    await flush(t);
  }

  RaftAppRouter router(WidgetTester t) =>
      t.widget<MaterialApp>(find.byType(MaterialApp)).routerDelegate!
          as RaftAppRouter;
  WorkspaceController workspace(WidgetTester t) =>
      t.widget<WorkspaceView>(find.byType(WorkspaceView)).controller;
  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await flush(t);
    expect(t.takeException(), isNull);
  }
}

void main() {
  for (final theme in ['brutal', 'elegant-light', 'elegant-dark']) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        'actual RaftApp $theme/$width root selection, URI, return and draft',
        (t) async {
          final f = RootFixture();
          await f.mount(t, theme, width);
          expect(find.byType(GlobalServerSelector), findsOneWidget);
          expect(f.router(t).currentConfiguration.toString(), '/');
          expect(f.adapter.calls.where((c) => c.path == '/channels'), isEmpty);
          await t.tap(find.byKey(const ValueKey('global-server-a')));
          await f.flush(t);
          expect(find.byType(WorkspaceView), findsOneWidget);
          final w = f.workspace(t);
          if (width < 768) {
            await t.tap(find.text('general-a').last);
            await f.flush(t);
          }
          final editor = find.descendant(
            of: find.byType(RaftComposer),
            matching: find.byType(TextField),
          );
          await t.enterText(editor, 'Keep Alpha draft');
          await t.pump();
          final before = w.location.uri;
          final view = t.widget<WorkspaceView>(find.byType(WorkspaceView));
          view.onChooseServer!();
          await f.flush(t);
          expect(find.byType(WorkspaceView), findsNothing);
          expect(f.router(t).currentConfiguration.toString(), '/');
          expect(w.foreground, isFalse);
          expect(f.content.bound, isNull);
          expect(f.client.disposalCount, 0);
          expect(await f.router(t).popRoute(), isTrue);
          await f.flush(t);
          expect(identical(f.workspace(t), w), isTrue);
          expect(f.router(t).currentConfiguration, before);
          expect(
            t.widget<TextField>(editor).controller!.text,
            'Keep Alpha draft',
          );
          t.widget<WorkspaceView>(find.byType(WorkspaceView)).onChooseServer!();
          await f.flush(t);
          await t.tap(find.byKey(const ValueKey('global-server-b')));
          await f.flush(t);
          expect(f.workspace(t).server!.id, 'b');
          expect(f.router(t).currentConfiguration.path, startsWith('/s/beta'));
          t.widget<WorkspaceView>(find.byType(WorkspaceView)).onChooseServer!();
          await f.flush(t);
          await t.tap(find.byKey(const ValueKey('global-server-a')));
          await f.flush(t);
          expect(f.workspace(t).server!.id, 'a');
          expect(
            t.widget<TextField>(editor).controller!.text,
            'Keep Alpha draft',
          );
          await f.close(t);
        },
      );
    }
    testWidgets(
      'actual RaftApp $theme selector keyboard create and account fence',
      (t) async {
        final f = RootFixture();
        final pending = Completer<dynamic>();
        await f.mount(t, theme, 390);
        f.adapter.routes['POST /servers'] = (_) => pending.future;
        await t.tap(find.text('+ Create New Server'));
        await t.pump();
        await t.enterText(
          find.byKey(const ValueKey('global-server-name')),
          'New Team',
        );
        await t.pump();
        expect(
          t
              .widget<RaftSlugInput>(
                find.byKey(const ValueKey('global-server-slug')),
              )
              .controller!
              .text,
          'new-team',
        );
        await t.tap(find.byKey(const ValueKey('global-server-slug')));
        await t.testTextInput.receiveAction(TextInputAction.done);
        await f.flush(t);
        expect(
          f.adapter.calls.where(
            (c) => c.method == 'POST' && c.path == '/servers',
          ),
          hasLength(1),
        );
        await t.tap(find.text('Log out'));
        await f.flush(t);
        pending.complete({
          'id': 'new',
          'name': 'New Team',
          'slug': 'new-team',
          'role': 'owner',
        });
        await f.flush(t);
        expect(find.byType(WorkspaceView), findsNothing);
        expect(find.byType(GlobalServerSelector), findsNothing);
        expect(f.router(t).currentConfiguration.toString(), '/');
        expect(f.adapter.calls.where((c) => c.path == '/channels'), isEmpty);
        await f.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme keyboard selection and incoming global URI',
      (t) async {
        final f = RootFixture();
        await f.mount(t, theme, 1280);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await f.flush(t);
        expect(find.byType(WorkspaceView), findsOneWidget);
        final w = f.workspace(t);
        expect(w.server!.id, 'a');
        await f.pushUri(t, '/servers');
        await f.flush(t);
        expect(find.byType(GlobalServerSelector), findsOneWidget);
        expect(f.router(t).currentConfiguration.toString(), '/servers');
        await f.pushUri(t, '/s/beta/settings/account');
        await f.flush(t);
        expect(f.workspace(t).server!.id, 'b');
        expect(
          f.router(t).currentConfiguration.toString(),
          '/s/beta/settings/account',
        );
        await f.pushUri(t, '/s/unauthorized/settings/account');
        await f.flush(t);
        expect(find.byType(WorkspaceView), findsNothing);
        expect(f.router(t).currentConfiguration.toString(), '/');
        expect(w.server!.id, 'b');
        await f.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme Back retires held server selection and hidden read',
      (t) async {
        final f = RootFixture();
        await f.mount(t, theme, 1280);
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await f.flush(t);
        final w = f.workspace(t), uri = w.location.uri;
        t.widget<WorkspaceView>(find.byType(WorkspaceView)).onChooseServer!();
        await f.flush(t);
        final readBefore = f.adapter.calls
            .where((c) => c.method == 'POST' && c.path.endsWith('/read'))
            .length;
        f.client.event('message:new', {
          'id': 'hidden-new',
          'channelId': 'ca',
          'seq': '2',
          'senderId': 'alice',
          'content': 'Hidden while choosing',
        });
        await f.flush(t);
        expect(
          f.adapter.calls.where(
            (c) => c.method == 'POST' && c.path.endsWith('/read'),
          ),
          hasLength(readBefore),
        );
        final held = Completer<dynamic>();
        final ordinary = f.adapter.routes['GET /channels']!;
        f.adapter.routes['GET /channels'] = (o) =>
            o.headers['X-Server-Id'] == 'b' ? held.future : ordinary(o);
        await t.tap(find.byKey(const ValueKey('global-server-b')));
        await f.flush(t);
        expect(find.byType(GlobalServerSelector), findsOneWidget);
        expect(w.server!.id, 'b');
        final back = t.binding.handlePopRoute();
        await f.flush(t);
        await back;
        await f.flush(t);
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(w.server!.id, 'a');
        expect(f.router(t).currentConfiguration, uri);
        held.complete([
          {'id': 'cb', 'name': 'stale-beta', 'serverId': 'b', 'joined': true},
        ]);
        await f.flush(t);
        expect(w.server!.id, 'a');
        expect(w.channels.any((c) => c.id == 'cb'), isFalse);
        expect(f.router(t).currentConfiguration, uri);
        await f.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme pending selection rejects membership removal',
      (t) async {
        final f = RootFixture();
        await f.mount(t, theme, 390);
        final held = Completer<dynamic>();
        final ordinary = f.adapter.routes['GET /channels']!;
        f.adapter.routes['GET /channels'] = (o) =>
            o.headers['X-Server-Id'] == 'b' ? held.future : ordinary(o);
        await t.tap(find.byKey(const ValueKey('global-server-b')));
        await f.flush(t);
        f.servers.removeWhere((s) => s['id'] == 'b');
        f.client.event('server:membership-removed', {
          'serverId': 'b',
          'userId': 'alice',
        });
        await f.flush(t);
        held.complete([
          {
            'id': 'cb',
            'name': 'stale-private-beta',
            'serverId': 'b',
            'joined': true,
          },
        ]);
        await f.flush(t);
        expect(find.byType(GlobalServerSelector), findsOneWidget);
        expect(find.byKey(const ValueKey('global-server-b')), findsNothing);
        expect(f.router(t).currentConfiguration.toString(), '/');
        expect(find.text('stale-private-beta'), findsNothing);
        await f.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme account replacement clears original scope and retires selection',
      (t) async {
        final f = RootFixture();
        await f.mount(t, theme, 390);
        final held = Completer<dynamic>();
        f.adapter.routes['GET /channels'] = (_) => held.future;
        await t.tap(find.byKey(const ValueKey('global-server-b')));
        await f.flush(t);
        await f.cache.write(f.client.origin, 'alice', 'a', 'draft', 'ca', {
          'text': 'Old private draft',
        });
        await f.cache.write(
          f.client.origin,
          'other-principal',
          'a',
          'draft',
          'ca',
          {'text': 'Other account draft'},
        );
        f.adapter.routes['GET /auth/me'] = (_) => {
          'id': 'bob',
          'name': 'bob',
          'email': 'bob@example.invalid',
          'emailVerified': true,
        };
        final reloading = f.client.reloadUser();
        await f.flush(t);
        await reloading;
        await f.flush(t);
        held.complete([
          {'id': 'cb', 'name': 'stale-alice-private', 'joined': true},
        ]);
        await f.flush(t);
        expect(find.byType(WorkspaceView), findsNothing);
        expect(find.byType(GlobalServerSelector), findsNothing);
        expect(f.router(t).currentConfiguration.toString(), '/');
        expect(await f.sessions.read(f.client.origin), isNull);
        expect(
          await f.cache.read(f.client.origin, 'alice', 'a', 'draft', 'ca'),
          isNull,
        );
        expect(
          await f.cache.read(
            f.client.origin,
            'other-principal',
            'a',
            'draft',
            'ca',
          ),
          {'text': 'Other account draft'},
        );
        expect(find.text('stale-alice-private'), findsNothing);
        await f.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme preserves accepted account-scoped offline server directory',
      (t) async {
        final online = RootFixture();
        await online.mount(t, theme, 1280);
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await online.flush(t);
        await online.close(t);
        final offline = RootFixture(cache: online.cache);
        offline.adapter.statuses['GET /servers'] = 503;
        await offline.mount(t, theme, 1280, offlineRestore: true);
        expect(offline.client.restoredOffline, isTrue);
        expect(find.byType(GlobalServerSelector), findsOneWidget);
        expect(find.byKey(const ValueKey('global-server-a')), findsOneWidget);
        expect(
          offline.adapter.calls.where((c) => c.path == '/servers'),
          isEmpty,
        );
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await offline.flush(t);
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(offline.workspace(t).server!.id, 'a');
        await offline.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme global root replacement and explicit servers push reach engine',
      (t) async {
        final f = RootFixture();
        final memory =
            'raft.server-surface.${Uri.encodeComponent('https://fixture.invalid')}.alice';
        await f.mount(
          t,
          theme,
          1280,
          preferences: {
            '$memory.last': 'beta',
            '$memory.b': '/s/beta/settings/account',
          },
        );
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(
          f.router(t).currentConfiguration.toString(),
          '/s/beta/settings/account',
        );
        final restored = f.engineRoutes.lastWhere(
          (r) => r['uri'] == '/s/beta/settings/account',
        );
        expect(restored['replace'], isTrue);
        t.widget<WorkspaceView>(find.byType(WorkspaceView)).onChooseServer!();
        await f.flush(t);
        expect(
          f.engineRoutes.lastWhere((r) => r['uri'] == '/')['replace'],
          isFalse,
        );
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await f.flush(t);
        expect(
          f.engineRoutes.lastWhere(
            (r) => (r['uri'] as String).startsWith('/s/alpha'),
          )['replace'],
          isTrue,
        );
        await f.pushUri(t, '/servers');
        final chosen = f.engineRoutes.length;
        await t.tap(find.byKey(const ValueKey('global-server-b')));
        await f.flush(t);
        // Leaving the chooser is one PUSH. Beta's cached workspace opens
        // before its revalidation, which may then only REPLACE that entry.
        final entered = f.engineRoutes
            .skip(chosen)
            .where((r) => (r['uri'] as String).startsWith('/s/beta'))
            .toList();
        expect(entered.first['replace'], isFalse);
        expect(entered.skip(1).every((r) => r['replace'] == true), isTrue);
        await f.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme initial directory loading cannot flash first-server form',
      (t) async {
        final f = RootFixture(), held = Completer<dynamic>();
        f.serverDirectory = () => held.future;
        await f.mount(t, theme, 390);
        expect(find.text('Loading servers…'), findsOneWidget);
        expect(find.byKey(const ValueKey('global-server-name')), findsNothing);
        expect(find.byType(WorkspaceView), findsNothing);
        held.complete([]);
        await f.flush(t);
        expect(find.text('Create your first server'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('global-server-name')),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsNothing);
        expect(f.adapter.calls.where((c) => c.path == '/channels'), isEmpty);
        await f.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme shared form required fields, slug prefix and touched value',
      (t) async {
        final f = RootFixture();
        await f.mount(t, theme, 390);
        await t.tap(find.text('+ Create New Server'));
        await t.pump();
        final name = find.byKey(const ValueKey('global-server-name'));
        final slug = find.byKey(const ValueKey('global-server-slug'));
        expect(
          t
              .widget<EditableText>(
                find.descendant(of: name, matching: find.byType(EditableText)),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        expect(
          find.descendant(of: slug, matching: find.text('/')),
          findsOneWidget,
        );
        await t.tap(
          find.descendant(
            of: find.byType(RaftAuthSubmit),
            matching: find.text('Create server'),
          ),
        );
        await t.pump();
        expect(find.text('Required'), findsNWidgets(2));
        expect(
          f.adapter.calls.where(
            (c) => c.method == 'POST' && c.path == '/servers',
          ),
          isEmpty,
        );
        await t.enterText(name, 'First Team');
        await t.enterText(slug, 'My Custom URL');
        await t.enterText(name, 'Second Team');
        expect(t.widget<RaftSlugInput>(slug).controller!.text, 'my-custom-url');
        await t.tap(find.text('Cancel'));
        await t.pump();
        expect(find.byKey(const ValueKey('global-server-a')), findsOneWidget);
        await f.close(t);
      },
    );
    testWidgets(
      'actual RaftApp $theme successful creation uses authorized returned directory',
      (t) async {
        final f = RootFixture();
        await f.mount(t, theme, 390);
        f.adapter.routes['POST /servers'] = (o) {
          expect(o.data, {'name': 'New Team', 'slug': 'new-team'});
          f.servers.add({
            'id': 'new',
            'name': 'New Team',
            'slug': 'new-team',
            'role': 'owner',
          });
          return {'id': 'new', 'name': 'New Team', 'slug': 'new-team'};
        };
        await t.tap(find.text('+ Create New Server'));
        await t.pump();
        await t.enterText(
          find.byKey(const ValueKey('global-server-name')),
          'New Team',
        );
        await t.tap(find.byKey(const ValueKey('global-server-slug')));
        await t.testTextInput.receiveAction(TextInputAction.done);
        await f.flush(t);
        expect(f.workspace(t).server!.id, 'new');
        expect(f.workspace(t).server!.string('role'), 'owner');
        expect(
          f.router(t).currentConfiguration.path,
          startsWith('/s/new-team'),
        );
        expect(
          f.adapter.calls.where(
            (c) => c.path == '/servers' && c.method == 'GET',
          ),
          hasLength(2),
        );
        await f.close(t);
      },
    );
  }
  testWidgets(
    'actual RaftApp creation denial does not open a fabricated workspace',
    (t) async {
      final f = RootFixture();
      await f.mount(t, 'elegant-light', 390);
      // Deliver the actual 403 body through RaftClient's HTTP error path.
      final held = Completer<dynamic>();
      f.adapter.routes['POST /servers'] = (_) => held.future;
      f.adapter.statuses['POST /servers'] = 403;
      await t.tap(find.text('+ Create New Server'));
      await t.pump();
      await t.enterText(
        find.byKey(const ValueKey('global-server-name')),
        'Failed Team',
      );
      await t.tap(find.byKey(const ValueKey('global-server-slug')));
      await t.testTextInput.receiveAction(TextInputAction.done);
      await f.flush(t);
      held.complete({'error': 'Create denied'});
      await f.flush(t);
      expect(find.textContaining('Create denied'), findsOneWidget);
      expect(find.byType(WorkspaceView), findsNothing);
      expect(f.adapter.calls.where((c) => c.path == '/channels'), isEmpty);
      await f.close(t);
    },
  );
  testWidgets(
    'actual RaftApp discovery failure is not empty membership success',
    (t) async {
      final f = RootFixture();
      f.serverDirectory = () => {'error': 'Directory unavailable'};
      f.adapter.statuses['GET /servers'] = 503;
      await f.mount(t, 'elegant-light', 390);
      expect(find.textContaining('Directory unavailable'), findsOneWidget);
      expect(find.text('Create your first server'), findsNothing);
      expect(find.byKey(const ValueKey('global-server-name')), findsNothing);
      expect(f.adapter.calls.where((c) => c.path == '/channels'), isEmpty);
      f.serverDirectory = null;
      f.adapter.statuses.remove('GET /servers');
      await t.tap(find.text('Retry'));
      await f.flush(t);
      expect(find.byKey(const ValueKey('global-server-a')), findsOneWidget);
      expect(f.router(t).currentConfiguration.toString(), '/');
      await f.close(t);
    },
  );
}
