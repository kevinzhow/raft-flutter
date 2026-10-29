import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart' show RaftServerAccessDeniedPage;
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart';

const _public = '/public/servers/gamma';
Object _readback() => {
  'server': {'id': 'g', 'name': 'Gamma', 'slug': 'gamma', 'avatarUrl': null},
  'channels': [
    {'id': 'pc', 'name': 'general', 'description': 'Hello'},
  ],
  'canJoinAsGuest': true,
};

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<RootFixture> _signedOut(WidgetTester t, String path) async {
  SharedPreferences.setMockInitialValues({
    'raft.origin': 'https://fixture.invalid',
    'raft.mode': 'light',
    'raft.light': 'light',
  });
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1280, 900);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final f = RootFixture();
  f.adapter.routes['GET $_public'] = (_) => _readback();
  f.adapter.routes['GET $_public/channels/pc/messages'] = (_) => {
    'messages': [
      {
        'id': 'm1',
        'senderType': 'user',
        'sender': {'displayName': 'Wenyi', 'avatarUrl': null, 'description': null},
        'messageType': 'chat',
        'content': 'Welcome to Gamma',
        'createdAt': '2026-06-18T09:12:00.000Z',
        'threadId': null,
        'replyCount': 0,
      },
    ],
  };
  await t.pumpWidget(
    RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: f.sessions,
      initialLocation: Uri(path: path),
      nativeContent: f.content,
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async => f.cache,
      createClient: (origin, store, kind) =>
          f.client = RootClient(origin, store, kind, f.adapter),
    ),
  );
  await _settle(t);
  return f;
}

void main() {
  testWidgets('signed out: /s/<slug> opens the public server, not the sign-in form', (
    t,
  ) async {
    final f = await _signedOut(t, '/s/gamma');
    expect(find.byType(PublicServerView), findsOneWidget);
    expect(find.byType(AuthView), findsNothing);
    expect(find.text('Welcome to Gamma'), findsOneWidget);
    expect(
      f.adapter.calls.map((c) => '${c.method} ${c.path}'),
      containsAll(['GET $_public', 'GET $_public/channels/pc/messages']),
    );
  });

  testWidgets('signed out: a channel deep link selects that public channel', (t) async {
    await _signedOut(t, '/s/gamma/channel/pc/message/x');
    expect(find.byType(PublicServerView), findsOneWidget);
    expect(find.text('Welcome to Gamma'), findsOneWidget);
  });

  testWidgets(
    'signed out: Sign in and Create account open the matching auth form',
    (t) async {
      await _signedOut(t, '/s/gamma');
      await t.tap(find.text('Create Account'));
      await _settle(t);
      expect(find.byType(PublicServerView), findsNothing);
      expect(t.widget<AuthView>(find.byType(AuthView)).initialMode, 'register');
    },
  );

  testWidgets('signed out: an unavailable server (404) falls through to sign in', (t) async {
    SharedPreferences.setMockInitialValues({'raft.origin': 'https://fixture.invalid'});
    final f = RootFixture();
    // No route for the readback: the adapter answers 404.
    await t.pumpWidget(
      RaftApp(
        services: const AppServices.updatesDisabledForTestOrPreview(),
        sessionStore: f.sessions,
        initialLocation: Uri(path: '/s/gone'),
        nativeContent: f.content,
        nativeSharing: NativeSharing(supported: false),
        openWorkspaceCache: () async => f.cache,
        createClient: (origin, store, kind) =>
            f.client = RootClient(origin, store, kind, f.adapter),
      ),
    );
    await _settle(t);
    expect(find.byType(PublicServerView), findsNothing);
    expect(find.byType(AuthView), findsOneWidget);
  });

  testWidgets('signed out: other paths still open sign in', (t) async {
    await _signedOut(t, '/');
    expect(find.byType(PublicServerView), findsNothing);
    expect(find.byType(AuthView), findsOneWidget);
  });

  testWidgets('signed in member: a server the account has opens as before', (t) async {
    final f = RootFixture();
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/alpha'));
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(find.byType(PublicServerView), findsNothing);
    expect(f.adapter.calls.where((c) => c.path.startsWith('/public/')), isEmpty);
  });

  testWidgets('signed in nonmember: a public server shows Join as Guest, joining opens it', (
    t,
  ) async {
    final f = RootFixture();
    f.overrides['GET $_public'] = (_) => _readback();
    f.overrides['GET $_public/channels/pc/messages'] = (_) => {'messages': []};
    f.overrides['POST $_public/join-as-guest'] = (_) {
      f.servers.add({'id': 'new', 'name': 'Gamma', 'slug': 'gamma', 'role': 'guest'});
      return {'joined': true};
    };
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/gamma'));
    expect(find.byType(PublicServerView), findsOneWidget);
    expect(find.byKey(const ValueKey('public-join-guest')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('public-join-guest')));
    await f.flush(t);
    await t.tap(find.byKey(const ValueKey('public-join-confirm')));
    await f.flush(t);
    expect(find.byType(PublicServerView), findsNothing);
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(f.workspace(t).server?.string('slug'), 'gamma');
  });

  testWidgets('signed in nonmember: a server that is not public shows the server-not-found page', (t) async {
    final f = RootFixture();
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/private-one'));
    expect(find.byType(PublicServerView), findsNothing);
    expect(find.byType(GlobalServerSelector), findsNothing);
    expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
    await f.close(t);
  });
}
