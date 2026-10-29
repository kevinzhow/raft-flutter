// Android 17 local network permission: "don't ask again" must lead to the
// app's settings page (the sign-in error used to be text with no way to act),
// and a saved session for a local server must not silently hang without it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/session_recovery_view.dart';
import 'package:raft_flutter/platform/android_permissions.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/local_network_access.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _System extends AndroidPermissions {
  _System();
  AndroidPermissionStatus? answer;
  int settingsOpened = 0;
  @override
  Future<AndroidPermissionStatus?> status(String permission) async => answer;
  @override
  Future<bool> openAppSettings() async => ++settingsOpened > 0;
}

AndroidPermissionStatus _status({
  int sdk = 37,
  bool granted = false,
  bool rationale = false,
}) => AndroidPermissionStatus(sdk: sdk, granted: granted, rationale: rationale);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.raft/local-network');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  var granted = false;
  late _System system;
  late LocalNetworkAccess access;
  group('local network permission', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      calls.clear();
      granted = false;
      system = _System();
      access = LocalNetworkAccess(permissions: system);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return granted;
      });
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('first request prompts and is recorded', () async {
      system.answer = _status();
      await expectLater(
        access.ensure('http://192.168.1.2', request: true),
        throwsA(isA<RaftApiException>()),
      );
      expect(calls.single.arguments, {'request': true});
      expect(system.settingsOpened, 0);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          LocalNetworkAccess.askedKey,
        ),
        isTrue,
      );
    });

    test('after one refusal the system asks again', () async {
      SharedPreferences.setMockInitialValues({
        LocalNetworkAccess.askedKey: true,
      });
      system.answer = _status(rationale: true);
      granted = true;
      await access.ensure('http://192.168.1.2', request: true);
      expect(calls.single.arguments, {'request': true});
      expect(system.settingsOpened, 0);
    });

    test('after "don\'t ask again" an explicit request opens the settings page instead of a prompt that never shows', () async {
      SharedPreferences.setMockInitialValues({
        LocalNetworkAccess.askedKey: true,
      });
      system.answer = _status();
      await expectLater(
        access.ensure('http://192.168.1.2', request: true),
        throwsA(
          isA<RaftApiException>().having(
            (e) => e.message,
            'message',
            localNetworkPermissionError,
          ),
        ),
      );
      expect(calls, isEmpty);
      expect(system.settingsOpened, 1);
    });

    test('a passive check never opens settings or prompts', () async {
      SharedPreferences.setMockInitialValues({
        LocalNetworkAccess.askedKey: true,
      });
      system.answer = _status();
      await expectLater(
        access.ensure('http://192.168.1.2'),
        throwsA(isA<RaftApiException>()),
      );
      expect(calls.single.arguments, {'request': false});
      expect(system.settingsOpened, 0);
    });

    test('before Android 17 there is nothing to ask', () async {
      system.answer = _status(sdk: 36);
      granted = true;
      await access.ensure('http://192.168.1.2', request: true);
      expect(system.settingsOpened, 0);
    });

    group('restore gate', () {
      Future<RaftClient> client({bool stored = true}) async {
        final store = MemorySessionStore();
        if (stored) {
          await store.write(
            'http://192.168.1.2:8793',
            Session(accessToken: 'fixture-only', refreshToken: 'fixture-only'),
          );
        }
        return RaftClient(
          origin: 'http://192.168.1.2:8793',
          sessionStore: store,
        );
      }

      test(
        'saved session, local server, no permission: localNetwork',
        () async {
          final c = await client();
          addTearDown(c.dispose);
          await expectLater(
            access.gateRestore(c),
            throwsA(
              isA<SessionRestoreException>().having(
                (e) => e.kind,
                'kind',
                SessionRestoreFailureKind.localNetwork,
              ),
            ),
          );
          expect(calls.single.arguments, {
            'request': false,
          }, reason: 'no prompt');
        },
      );

      test('permission granted: restore proceeds', () async {
        granted = true;
        final c = await client();
        addTearDown(c.dispose);
        await access.gateRestore(c);
      });

      test(
        'no saved session: the sign-in form, not a recovery screen',
        () async {
          final c = await client(stored: false);
          addTearDown(c.dispose);
          await access.gateRestore(c);
          expect(calls, isEmpty);
        },
      );

      test('other platforms never gate', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final c = await client();
        addTearDown(c.dispose);
        await access.gateRestore(c);
        expect(calls, isEmpty);
      });
    });
  });

  testWidgets(
    'recovery screen for a blocked local network offers the permission, then retries',
    (t) async {
      final events = <String>[];
      final scoped = _Allow(events);
      await t.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: AppServices.updatesDisabledForTestOrPreview(
              localNetwork: scoped,
            ),
            child: SessionRecoveryView(
              failure: const SessionRestoreException(
                SessionRestoreFailureKind.localNetwork,
              ),
              busy: false,
              onRetry: () => events.add('retry'),
              onSignInAgain: () {},
            ),
          ),
        ),
      );
      expect(find.text('Local network access is off'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
      await t.tap(find.text('Allow local network access'));
      await t.pump();
      expect(events, ['allow', 'retry']);
    },
  );
}

class _Allow extends LocalNetworkAccess {
  _Allow(this.events);
  final List<String> events;
  @override
  Future<bool> allow() async {
    events.add('allow');
    return true;
  }
}
