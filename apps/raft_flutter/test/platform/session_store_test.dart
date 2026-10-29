import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const origin = 'https://keychain.fixture.invalid';
  final session = Session(
    accessToken: 'fixture-access',
    refreshToken: 'fixture-refresh',
    installationId: 'fixture-installation',
    cachedUser: {'id': 'fixture-user'},
  );
  final encoded = jsonEncode(session.toJson());
  late Map<String, String> legacy, primary;
  late List<String> calls;
  String? fail;
  bool corruptWrite = false;
  Completer<void>? pauseRead, reading;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    legacy = {};
    primary = {};
    calls = [];
    fail = null;
    corruptWrite = false;
    pauseRead = null;
    reading = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final options = args['options'] as Map;
          final isPrimary = options['usesDataProtectionKeychain'] == 'true';
          final operation =
              '${isPrimary ? 'primary' : 'legacy'}.${call.method}';
          calls.add(operation);
          if (operation == fail) {
            throw PlatformException(code: 'fixture-keychain-denied');
          }
          final data = isPrimary ? primary : legacy;
          final key = args['key'] as String;
          switch (call.method) {
            case 'read':
              if (!isPrimary && pauseRead != null) {
                final wait = pauseRead!;
                pauseRead = null;
                reading!.complete();
                await wait.future;
              }
              return data[key];
            case 'write':
              if (!corruptWrite) data[key] = args['value'] as String;
            case 'delete':
              data.remove(key);
            default:
              throw StateError('Unexpected keychain operation');
          }
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'migration preserves the complete session and stops legacy reads',
    () async {
      final store = SecureSessionStore(useDataProtectionKeychain: true);
      legacy[store.key(origin)] = encoded;
      expect((await store.read(origin))!.toJson(), session.toJson());
      expect(primary[store.key(origin)], encoded);
      expect(legacy, isEmpty);
      calls.clear();
      expect((await store.read(origin))!.toJson(), session.toJson());
      expect(calls, ['primary.read']);
    },
  );

  test('an existing modern session wins over an old legacy session', () async {
    final store = SecureSessionStore(useDataProtectionKeychain: true);
    primary[store.key(origin)] = encoded;
    legacy[store.key(origin)] = 'outdated-fixture';
    expect((await store.read(origin))!.toJson(), session.toJson());
    expect(calls, ['primary.read']);
  });

  for (final operation in ['primary.read', 'legacy.read', 'primary.write']) {
    test(
      '$operation failure preserves the old session and surfaces the error',
      () async {
        final store = SecureSessionStore(useDataProtectionKeychain: true);
        legacy[store.key(origin)] = encoded;
        fail = operation;
        await expectLater(
          store.read(origin),
          throwsA(isA<PlatformException>()),
        );
        expect(legacy[store.key(origin)], encoded);
        expect(calls, isNot(contains('legacy.delete')));
      },
    );
  }

  test('an unverified copy cannot delete the legacy session', () async {
    final store = SecureSessionStore(useDataProtectionKeychain: true);
    legacy[store.key(origin)] = encoded;
    corruptWrite = true;
    await expectLater(store.read(origin), throwsA(isA<StateError>()));
    expect(legacy[store.key(origin)], encoded);
    expect(calls, isNot(contains('legacy.delete')));
  });

  test('invalid legacy data stays untouched', () async {
    final store = SecureSessionStore(useDataProtectionKeychain: true);
    legacy[store.key(origin)] = 'invalid-fixture';
    await expectLater(store.read(origin), throwsA(isA<FormatException>()));
    expect(legacy[store.key(origin)], 'invalid-fixture');
    expect(primary, isEmpty);
  });

  test('logout queued during migration clears both copies', () async {
    final store = SecureSessionStore(useDataProtectionKeychain: true);
    legacy[store.key(origin)] = encoded;
    final gate = Completer<void>();
    pauseRead = gate;
    reading = Completer<void>();
    final restore = store.read(origin);
    await reading!.future;
    final logout = store.write(origin, null);
    gate.complete();
    await restore;
    await logout;
    expect(primary, isEmpty);
    expect(legacy, isEmpty);
    expect(await store.read(origin), isNull);
  });

  test(
    'failed legacy cleanup does not destroy the verified modern copy',
    () async {
      final store = SecureSessionStore(useDataProtectionKeychain: true);
      legacy[store.key(origin)] = encoded;
      fail = 'legacy.delete';
      await expectLater(store.read(origin), throwsA(isA<PlatformException>()));
      expect(primary[store.key(origin)], encoded);
      expect(legacy[store.key(origin)], encoded);
      expect((await store.read(origin))!.toJson(), session.toJson());
    },
  );

  test('unprovisioned local builds keep the legacy backend', () async {
    final store = SecureSessionStore(useDataProtectionKeychain: false);
    legacy[store.key(origin)] = encoded;
    expect((await store.read(origin))!.toJson(), session.toJson());
    expect(calls, ['legacy.read']);
  });

  test('iOS keeps first-unlock storage without a macOS migration', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final store = SecureSessionStore(useDataProtectionKeychain: true);
    expect(
      store.storage.iOptions.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
    await store.write(origin, session);
    expect(calls, ['legacy.write']);
    await store.write(origin, null);
    expect(calls, ['legacy.write', 'legacy.delete']);
  });
}
