import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/source_read_all_transport.dart';

import 'message_presentation_test.dart' show fixture;

Future<void> _dispatch() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('Source read-all same human identity and scope share the exact raw future and retire after settle', () async {
    final (w, api) = await fixture('owner');
    addTearDown(w.dispose);
    final held = Completer<dynamic>();
    api.routes['POST /channels/t/read-all'] = (_) => held.future;
    final transport = SourceReadAllTransport.of(w.client);
    expect(identical(transport, SourceReadAllTransport.of(w.client)), isTrue);
    final identity = SourceReadAllIdentity.capture(w.client);
    final first = transport.threadDone('t', identity: identity);
    final second = transport.threadDone('t', identity: identity);
    expect(identical(first, second), isTrue);
    await _dispatch();
    final writes = api.calls
        .where((r) => r.path.endsWith('/read-all'))
        .toList();
    expect(writes, hasLength(1));
    expect(writes.single.headers['X-Server-Id'], 's1');
    expect(writes.single.data, isNull);
    expect(writes.single.queryParameters, isEmpty);
    expect(writes.single.extra[sourceDoneOwnsReadRefresh], true);
    held.complete({'persisted': true});
    expect(await first, {'persisted': true});
    expect(await second, {'persisted': true});
    api.routes['POST /channels/t/read-all'] = (_) => {'next': true};
    final next = transport.threadDone('t', identity: identity);
    expect(identical(next, first), isFalse);
    expect(await next, {'next': true});
    expect(api.calls.where((r) => r.path.endsWith('/read-all')), hasLength(2));
  });

  test(
    'Source read-all shared failure retires the slot without another RPC',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      final held = Completer<dynamic>();
      api.routes['POST /channels/t/read-all'] = (_) => held.future;
      final transport = SourceReadAllTransport.of(w.client);
      final identity = SourceReadAllIdentity.capture(w.client);
      final first = transport.threadDone('t', identity: identity);
      expect(
        identical(first, transport.threadDone('t', identity: identity)),
        isTrue,
      );
      final rejection = expectLater(first, throwsA(isA<RaftApiException>()));
      await _dispatch();
      held.completeError(Exception('Fixture read failure'));
      await rejection;
      api.routes['POST /channels/t/read-all'] = (_) => {};
      await transport.threadDone('t', identity: identity);
      expect(
        api.calls.where((r) => r.path.endsWith('/read-all')),
        hasLength(2),
      );
    },
  );

  for (final dimension in ['channel', 'principal', 'server', 'generation']) {
    test(
      'Source read-all in-flight $dimension boundary cannot share the previous write future',
      () async {
        final (w, api) = await fixture('owner');
        addTearDown(w.dispose);
        final held = Completer<dynamic>();
        api.routes['POST /channels/t/read-all'] = (_) => held.future;
        api.routes['POST /channels/other/read-all'] = (_) => held.future;
        final transport = SourceReadAllTransport.of(w.client);
        final previous = transport.threadDone(
          't',
          identity: SourceReadAllIdentity.capture(w.client),
        );
        final oldOutcome = previous.then<Object?>(
          (value) => value,
          onError: (Object e) => e,
        );
        await _dispatch();
        switch (dimension) {
          case 'principal':
            w.client.user = RaftRecord({'id': 'bob'});
          case 'server':
            w.client.selectServer('s2');
          case 'generation':
            w.client.selectServer('s2');
            w.client.selectServer('s1');
        }
        final current = transport.threadDone(
          dimension == 'channel' ? 'other' : 't',
          identity: SourceReadAllIdentity.capture(w.client),
        );
        expect(identical(current, previous), isFalse);
        await _dispatch();
        final writes = api.calls
            .where((r) => r.path.endsWith('/read-all'))
            .toList();
        expect(writes, hasLength(2));
        expect(writes[0].headers['X-Server-Id'], 's1');
        expect(
          writes[1].headers['X-Server-Id'],
          dimension == 'server' ? 's2' : 's1',
        );
        expect(
          writes.every((r) => r.extra[sourceDoneOwnsReadRefresh] == true),
          isTrue,
        );
        held.complete({});
        await current;
        final old = await oldOutcome;
        if (dimension == 'server' || dimension == 'generation') {
          expect(old, isA<RaftApiException>());
        } else {
          expect(old, isA<Map>());
        }
      },
    );
  }

  test('Source read-all retired capture and empty channel fail closed before dispatch', () async {
    final (w, api) = await fixture('owner');
    addTearDown(w.dispose);
    final transport = SourceReadAllTransport.of(w.client);
    final stale = SourceReadAllIdentity.capture(w.client);
    w.client.selectServer('s2');
    await expectLater(
      transport.threadDone('t', identity: stale),
      throwsA(isA<RaftApiException>()),
    );
    await expectLater(
      transport.threadDone(
        '',
        identity: SourceReadAllIdentity.capture(w.client),
      ),
      throwsA(isA<RaftApiException>()),
    );
    expect(api.calls.where((r) => r.path.endsWith('/read-all')), isEmpty);
  });

  test('Source Done suppression is local to the owned write; an ordinary same-path persisted read still reconciles Activity', () async {
    final (w, api) = await fixture('owner');
    final attention = SourceActivityUnreadStore(w);
    addTearDown(() {
      attention.dispose();
      w.dispose();
    });
    attention.acceptWindow({
      'items': [],
      'totalUnreadCount': 4,
    }, scope: attention.scope);
    api.routes['GET /channels/inbox'] = (_) => {
      'items': [],
      'totalUnreadCount': 2,
    };
    final held = Completer<dynamic>();
    api.routes['POST /channels/t/read-all'] = (_) => held.future;
    final transport = SourceReadAllTransport.of(w.client);
    final done = transport.threadDone(
      't',
      identity: SourceReadAllIdentity.capture(w.client),
    );
    // This otherwise identical request is outside the owned Zone and must not
    // inherit local suppression from a path-wide flag.
    final ordinary = w.client.request('POST', '/channels/t/read-all');
    await _dispatch();
    final writes = api.calls
        .where((r) => r.path.endsWith('/read-all'))
        .toList();
    expect(writes, hasLength(2));
    expect(writes[0].extra[sourceDoneOwnsReadRefresh], true);
    expect(writes[1].extra.containsKey(sourceDoneOwnsReadRefresh), false);
    held.complete({});
    await Future.wait([done, ordinary]);
    await _dispatch();
    expect(api.calls.where((r) => r.path == '/channels/inbox'), hasLength(1));
    expect(attention.totalUnreadCount, 2);
    expect(writes.every((r) => r.data == null), true);
  });
}
