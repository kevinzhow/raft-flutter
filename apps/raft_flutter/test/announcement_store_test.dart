import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/announcement_store.dart';

Map<String, dynamic> row(String id, {int pages = 1}) => {
  'id': id,
  'title': 'Title $id',
  'pages': [
    for (var i = 0; i < pages; i++) {'body': 'Body $i'},
  ],
  'publishedAt': '2026-10-01T00:00:00.000Z',
  'startsAt': '2026-10-01T00:00:00.000Z',
  'endsAt': null,
  'locale': 'en',
};

class Wire {
  final gets = <(String, Map<String, dynamic>?)>[];
  final posts = <String>[];
  Completer<dynamic>? hold;
  Object? Function(Map<String, dynamic>? query) answer = (_) => {
    'announcements': [row('a1')],
  };
  bool failPost = false;
  String? user = 'u1';

  AnnouncementStore store() => AnnouncementStore(
    get: (path, {query}) async {
      gets.add((path, query));
      if (hold != null) return hold!.future;
      return answer(query);
    },
    post: (path, {query}) async {
      posts.add(path);
      if (failPost) throw StateError('500');
      return {'ok': true};
    },
    principal: () => user,
  );
}

void main() {
  test(
    'load presents the oldest unread row from /announcements/active',
    () async {
      final wire = Wire();
      final store = wire.store();
      await store.load();
      expect(wire.gets.single.$1, '/announcements/active');
      expect(wire.gets.single.$2, isNull);
      expect(store.loaded, isTrue);
      expect(store.current?.id, 'a1');
      expect(store.current?.pages.single.body, 'Body 0');
    },
  );

  test('a presented row is owned: later loads never replace it', () async {
    final wire = Wire();
    final store = wire.store();
    await store.load();
    wire.answer = (_) => {'announcements': <Object>[]};
    await store.load();
    expect(wire.gets, hasLength(1));
    expect(store.current?.id, 'a1');
  });

  test('focus + visibility share one in-flight read', () async {
    final wire = Wire()..hold = Completer();
    final store = wire.store();
    final first = store.load(), second = store.load();
    expect(wire.gets, hasLength(1));
    wire.hold!.complete({
      'announcements': [row('a1')],
    });
    await Future.wait([first, second]);
    expect(store.current?.id, 'a1');
  });

  test('close is local: no write, the row returns on the next load', () async {
    final wire = Wire();
    final store = wire.store();
    await store.load();
    store.close('a1');
    expect(store.current, isNull);
    expect(wire.posts, isEmpty);
    await store.load();
    expect(store.current?.id, 'a1');
  });

  test('dismiss writes read-complete once and hides the row', () async {
    final wire = Wire();
    final store = wire.store();
    await store.load();
    await store.dismiss('a1');
    await store.markRead('a1');
    expect(wire.posts, ['/announcements/a1/dismiss']);
    expect(store.current, isNull);
    // The server still answering it (stale) does not resurface it.
    await store.load();
    expect(store.current, isNull);
  });

  test('a failed write is skipped this session via ?after=', () async {
    final wire = Wire()..failPost = true;
    final store = wire.store();
    await store.load();
    await store.dismiss('a1');
    expect(store.writeFailedIds, ['a1']);
    expect(store.markedReadIds, isEmpty);
    wire.answer = (query) => {
      'announcements': [query?['after'] == 'a1' ? row('a2') : row('a1')],
    };
    await store.load();
    expect(wire.gets.last.$2, {'after': 'a1'});
    expect(store.current?.id, 'a2');
  });

  test('reset fences a response of the previous account', () async {
    final wire = Wire()..hold = Completer();
    final store = wire.store();
    final pending = store.load();
    store.reset();
    wire.hold!.complete({
      'announcements': [row('a1')],
    });
    await pending;
    expect(store.current, isNull);
    expect(store.loaded, isFalse);
  });

  test('an account change resets the queue', () async {
    final wire = Wire();
    final store = wire.store();
    await store.load();
    wire.user = 'u2';
    wire.answer = (_) => {
      'announcements': [row('b1')],
    };
    await store.load();
    expect(store.current?.id, 'b1');
  });

  test('a load failure leaves nothing presented', () async {
    final wire = Wire()..answer = (_) => throw StateError('offline');
    final store = wire.store();
    await store.load();
    expect(store.loaded, isTrue);
    expect(store.current, isNull);
  });

  test('pages: [] is kept (the clear signal) but carries no page', () async {
    final wire = Wire()
      ..answer = (_) => {
        'announcements': [row('c1', pages: 0)],
      };
    final store = wire.store();
    await store.load();
    expect(store.current?.id, 'c1');
    expect(store.current?.pages, isEmpty);
  });

  group('onboarding gate', () {
    test('projection → gate state', () {
      expect(
        AnnouncementOnboardingGate.fromProjection(null),
        AnnouncementGateState.blocked,
      );
      expect(
        AnnouncementOnboardingGate.fromProjection({'phase': null}),
        AnnouncementGateState.ready,
      );
      expect(
        AnnouncementOnboardingGate.fromProjection({'phase': 'deferred'}),
        AnnouncementGateState.blocked,
      );
      expect(
        AnnouncementOnboardingGate.fromProjection({
          'phase': 'complete',
          'postSetup': {'surveyPending': true},
        }),
        AnnouncementGateState.blocked,
      );
      expect(
        AnnouncementOnboardingGate.fromProjection({
          'phase': 'complete',
          'postSetup': {'surveyPending': false, 'handoffPending': false},
        }),
        AnnouncementGateState.ready,
      );
    });

    test('suppressed until ready; onboarding seen keeps it suppressed', () {
      final gate = AnnouncementOnboardingGate();
      expect(gate.suppressed(null), isTrue);
      expect(gate.suppressed('s1'), isTrue);
      gate.setForServer('s1', AnnouncementGateState.pending);
      expect(gate.sawOnboardingServerIds, isEmpty);
      gate.setForServer('s1', AnnouncementGateState.ready);
      expect(gate.suppressed('s1'), isFalse);
      gate.setForServer('s2', AnnouncementGateState.blocked);
      gate.setForServer('s2', AnnouncementGateState.ready);
      expect(gate.suppressed('s2'), isTrue);
      // Leaving the server clears the reading, not the session memory.
      gate.clearForServer('s2');
      gate.setForServer('s2', AnnouncementGateState.ready);
      expect(gate.suppressed('s2'), isTrue);
    });

    test('a setup gate unmounting after sign-out is ignored', () {
      final gate = AnnouncementOnboardingGate()..attach('s1');
      gate.dispose();
      gate
        ..detach('s1')
        ..report('s1', {'phase': null})
        ..clearForServer('s1');
    });
  });
}
