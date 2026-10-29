import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/server_error_code.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/local_network_access.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://shell-errors.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final channelRows = [
    RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
  ];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? [] : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {'messages': [], 'threadSummariesByParentMessageId': {}};
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/c') {
      return {'id': 'c', 'serverId': 's', 'name': 'design', 'joined': true};
    }
    if (path == '/channels/unread') return {'channels': {}};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    if (path == '/auth/providers') return {'providers': []};
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '2', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

const _joinFailed = 'Failed to join community server';

class _Cache implements WorkspaceCache {
  bool fail = false;
  @override
  Future<dynamic> read(o, p, s, String kind, String id) async => null;
  @override
  Future<void> write(o, p, s, String kind, String id, value) async {
    if (fail) throw StateError('secret-payload');
  }

  @override
  Future<void> revokeChannel(o, p, s, String channel) async {}
  @override
  Future<void> clearAccount(o, p) async {}
  @override
  Future<void> revokeServer(o, p, s) async {}
  @override
  Future<List<Map<String, dynamic>>> readTranslations(o, p, s) async => [];
  @override
  Future<void> writeTranslations(o, p, s, entries) async {}
  @override
  Future<void> close() async {}
}

void main() {
  group('workspace error is a toast, not a Material banner', () {
    for (final (name, size) in [
      ('mobile', const Size(390, 844)),
      ('desktop', const Size(1280, 800)),
    ]) {
      testWidgets('$name: w.error shows once in the toast and is cleared', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = _Client()..selectServer('s');
        final cache = _Cache();
        final w =
            WorkspaceController(
                c,
                cache: cache,
                mobileNavigation: size.width < 600,
              )
              ..server = RaftRecord({
                'id': 's',
                'name': 'Fixture',
                'role': 'owner',
              })
              ..channels = [...c.channelRows]
              ..channel = c.channelRows.first;
        w.messageDomain.ledger.switchServer('s');
        addTearDown(() async {
          w.dispose();
          await cache.close();
          await c.stream.close();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            builder: (context, child) => RaftToastHost(child: child!),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: const RaftAppearance(mode: ThemeMode.light),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(_joinFailed), findsNothing);

        w.setError(_joinFailed);
        await tester.pump();
        await tester.pump();
        expect(find.text(_joinFailed), findsOneWidget);
        expect(find.byType(MaterialBanner), findsNothing);
        expect(find.text('Dismiss'), findsNothing);
        expect(w.error, isNull, reason: 'cleared so it is not shown twice');

        // A second failure replaces the first one in the same toast.
        w.setError('Could not join this channel.');
        await tester.pump();
        await tester.pump();
        expect(find.text('Could not join this channel.'), findsOneWidget);
        expect(find.text(_joinFailed), findsNothing);
        expect(w.error, isNull);
        // The toast closes by itself after Web's 5 s.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.text('Could not join this channel.'), findsNothing);

        // A local-storage failure offers a diagnostic copy without exposing
        // the exception's payload or pretending that copying repairs storage.
        String? clipboard;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        cache.fail = true;
        await w.deviceStore.write('draft', 'c', {'text': 'private-draft'});
        await tester.pump();
        await tester.pump();
        expect(find.text('Copy'), findsOneWidget);
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();
        expect(clipboard, contains('local-storage'));
        expect(clipboard, isNot(contains('secret-payload')));
        expect(clipboard, isNot(contains('private-draft')));
        expect(clipboard, contains('deviceWrite'));
        expect(clipboard, contains('workspace_device_store.dart'));
        expect(find.text('Diagnostics copied'), findsOneWidget);
        expect(find.text('Copy'), findsNothing);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.text('Diagnostics copied'), findsNothing);
        w.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.text('Copy'), findsNothing);
      });
    }
  });

  group('auth failures never print an exception', () {
    test(
      'the server text is shown, the Web fallback replaces anything else',
      () {
        expect(
          authFailureText(
            RaftApiException.response(
              'Email already registered',
              status: 409,
              body: {'error': 'Email already registered'},
            ),
            'Registration failed',
          ),
          'Email already registered',
        );
        for (final raw in <Object>[
          const FormatException('Unexpected character (at line 1)'),
          StateError('Bad state: no element'),
          const RaftApiException(
            'Cannot connect to https://x.invalid?token=abc',
          ),
          Exception('SocketException: Connection refused, port = 443'),
        ]) {
          expect(authFailureText(raw, 'Login failed'), 'Login failed');
        }
      },
    );

    test('bad credentials use the localized sentence', () {
      expect(
        authFailureText(
          RaftApiException.response(
            'Invalid email or password',
            status: 401,
            body: {'error': 'Invalid email or password'},
          ),
          'Login failed',
        ),
        'Incorrect email or password.',
      );
      expect(
        authFailureText(
          RaftApiException.response(
            'Nope',
            status: 401,
            body: {'error': 'Nope', 'code': 'AUTH_INVALID_CREDENTIALS'},
          ),
          'Login failed',
        ),
        'Incorrect email or password.',
      );
    });

    test('the local-network permission prompt stays actionable', () {
      expect(
        authFailureText(
          const RaftApiException(localNetworkPermissionError),
          'Login failed',
        ),
        localNetworkPermissionError,
      );
    });

    test('a server error code is compared, never shown', () {
      final changed = RaftApiException.response(
        'agreement_changed',
        status: 409,
        body: {'error': 'agreement_changed'},
      );
      expect(serverErrorIs(changed, 'agreement_changed'), isTrue);
      expect(
        serverErrorIs(StateError('agreement_changed'), 'agreement_changed'),
        isFalse,
      );
      expect(serverErrorCode(null), isNull);
    });
  });
}
