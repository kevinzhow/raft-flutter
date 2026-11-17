import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_announcement_store.dart';

Map<String, Object?> announcement(String title) => {
  'artifactId': 'pt_123',
  'title': title,
  'version': 1,
  'updatedAt': '2026-11-01T00:00:00Z',
  'updatedBy': {'type': 'user', 'id': 'u1', 'name': 'Ana'},
  'note': null,
  'seen': false,
};

void main() {
  test('keeps the last accepted announcement when a refresh fails', () async {
    var calls = 0;
    final store = ChannelAnnouncementStore((id) async {
      calls++;
      if (calls == 2) throw StateError('offline');
      return {'announcement': announcement('First')};
    });
    await store.load('c1');
    expect(store.forChannel('c1')?.title, 'First');
    await store.load('c1');
    expect(store.forChannel('c1')?.title, 'First');
    store.dispose();
  });

  test('a later write wins over an older pending read', () async {
    final pending = Completer<dynamic>();
    final store = ChannelAnnouncementStore((_) => pending.future);
    final load = store.load('c1');
    store.accept('c1', announcement('New'));
    pending.complete({'announcement': announcement('Old')});
    await load;
    expect(store.forChannel('c1')?.title, 'New');
    store.dispose();
  });

  test(
    'reset prevents an older server response from restoring its data',
    () async {
      final pending = Completer<dynamic>();
      final store = ChannelAnnouncementStore((_) => pending.future);
      final load = store.load('c1');
      store.reset();
      pending.complete({'announcement': announcement('Old')});
      await load;
      expect(store.forChannel('c1'), isNull);
      store.dispose();
    },
  );

  test(
    'concurrent reads share a request and null clears the announcement',
    () async {
      final pending = Completer<dynamic>();
      var calls = 0;
      final store = ChannelAnnouncementStore((_) {
        calls++;
        return pending.future;
      });
      store.accept('c1', announcement('First'));
      final first = store.load('c1');
      final second = store.load('c1');
      expect(calls, 1);
      pending.complete({'announcement': null});
      await Future.wait([first, second]);
      expect(store.forChannel('c1'), isNull);
      store.dispose();
    },
  );
}
