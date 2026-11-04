import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/raft_app_links.dart';

import 'message_presentation_test.dart' show fixture;

class _Notifications extends NativeNotificationService {
  @override
  TargetPlatform get platform => TargetPlatform.android;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final owned = <NativeContentCoordinator>[];
  NativeContentCoordinator make({bool on = true, Stream<Uri>? events}) {
    final owner = NativeContentCoordinator(
      notifications: _Notifications(),
      appLinks: on,
      links: events ?? const Stream.empty(),
    );
    owned.add(owner);
    return owner;
  }

  tearDown(() async {
    for (final owner in owned) {
      await owner.dispose();
    }
    owned.clear();
  });
  const web = 'https://app.raft.build/integration-invites/token_123';

  test(
    'cold HTTPS invite reaches a later root handler without an account',
    () async {
      final owner = make();
      await owner.init(initialArguments: [web]);
      final opened = <Uri>[];
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      await Future<void>.delayed(Duration.zero);
      expect(opened, [Uri.parse(web)]);
      expect(
        owner.pendingLink,
        isNull,
        reason: 'a private invite does not wait for workspace binding',
      );
    },
  );

  test(
    'native invitation keeps working with HTTPS receiving switched off',
    () async {
      final owner = make(on: false);
      await owner.init(
        initialArguments: ['raft://v1/integration-invites/native_token'],
      );
      final opened = <Uri>[];
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      owner.receiveLink(Uri.parse(web));
      await Future<void>.delayed(Duration.zero);
      expect(opened.map((uri) => uri.scheme), ['raft']);
    },
  );

  test(
    'foreground stream hands an invite to root from an existing workspace',
    () async {
      final events = StreamController<Uri>.broadcast(sync: true);
      addTearDown(events.close);
      final owner = make(events: events.stream);
      final (w, _) = await fixture('owner');
      addTearDown(() async {
        await owner.dispose();
        w.dispose();
        await w.client.dispose();
      });
      await owner.init();
      owner.bindWorkspace(w);
      final opened = <Uri>[];
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      events.add(Uri.parse(web));
      await Future<void>.delayed(Duration.zero);
      expect(opened, [Uri.parse(web)]);
      expect(w.channel?.id, 'c1');
    },
  );

  test(
    'before root attaches, only the latest bounded invite is retained',
    () async {
      final owner = make();
      owner.receiveLink(Uri.parse(web));
      final latest = Uri.parse(
        'https://app.raft.build/integration-invites/latest',
      );
      owner.receiveLink(latest);
      final opened = <Uri>[];
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      await Future<void>.delayed(Duration.zero);
      expect(opened, [latest]);
    },
  );

  test(
    'foreign origins and malformed invites never reach the root callback',
    () async {
      final owner = make();
      final opened = <Uri>[];
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      for (final location in [
        'https://foreign.example/integration-invites/token',
        'https:integration-invites/token',
        'https:///integration-invites/token',
        'https://app.raft.build:8443/integration-invites/token',
        'https://user@app.raft.build/integration-invites/token',
        '$web?token=other',
        '$web#anchor',
        '$web/extra',
        'https://app.raft.build/integration-invites/a%2Fb',
        'raft://v1:123/integration-invites/token',
        'raft://user@v1/integration-invites/token',
        'raft://v1/integration-invites/${'a' * 257}',
      ]) {
        owner.receiveLink(Uri.parse(location));
      }
      await Future<void>.delayed(Duration.zero);
      expect(opened, isEmpty);
      expect(owner.pendingLink, isNull);
    },
  );

  test(
    'root unregistration retains one new entry for the next attachment',
    () async {
      final owner = make();
      final opened = <Uri>[];
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      owner.onPrivateAppInvite = null;
      owner.receiveLink(Uri.parse(web));
      expect(opened, isEmpty);
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      await Future<void>.delayed(Duration.zero);
      expect(opened, [Uri.parse(web)]);
    },
  );

  test(
    'dispose drops pending entries and ignores later OS events/handlers',
    () async {
      final owner = make();
      owner.receiveLink(Uri.parse(web));
      await owner.dispose();
      final opened = <Uri>[];
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      owner.receiveLink(Uri.parse(web));
      await Future<void>.delayed(Duration.zero);
      expect(opened, isEmpty);
      expect(owner.pendingLink, isNull);
    },
  );

  test(
    'a failed root handler does not block the following invitation',
    () async {
      final owner = make();
      owner.onPrivateAppInvite = (_) => throw StateError('fixture refusal');
      owner.receiveLink(Uri.parse(web));
      await Future<void>.delayed(Duration.zero);
      final opened = <Uri>[];
      owner.onPrivateAppInvite = (uri) async {
        opened.add(uri);
      };
      owner.receiveLink(Uri.parse(web));
      await Future<void>.delayed(Duration.zero);
      expect(opened, [Uri.parse(web)]);
    },
  );

  test(
    'configured frontend is bound to a plain API origin, without wildcards',
    () {
      bool allowed(
        String uri, {
        String frontend = 'https://web.fixture.test',
        String api = 'https://api.fixture.test',
      }) => RaftAppLinks.accepts(
        Uri.parse(uri),
        on: true,
        frontend: frontend,
        api: api,
      );
      const uri = 'https://web.fixture.test/integration-invites/token';
      expect(allowed(uri), isTrue);
      expect(
        allowed('https://web.fixture.test.evil.test/integration-invites/token'),
        isFalse,
      );
      expect(allowed(uri, api: 'https://user@api.fixture.test'), isFalse);
      expect(allowed(uri, api: 'https://api.fixture.test/path'), isFalse);
      expect(allowed(uri, api: 'https://'), isFalse);
      expect(allowed(uri, frontend: 'https://user@web.fixture.test'), isFalse);
      expect(allowed(uri, frontend: 'https://web.fixture.test/path'), isFalse);
      expect(allowed(uri, frontend: 'http://web.fixture.test'), isFalse);
      expect(
        allowed(
          'https://api.fixture.test/integration-invites/token',
          frontend: '',
        ),
        isTrue,
      );
    },
  );
}
