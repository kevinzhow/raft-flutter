import 'package:flutter_test/flutter_test.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _memory = 'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice';

/// The thread under Alpha's `ma`: its parent lookup, channel and replies.
RootFixture _threadFixture() {
  final f = RootFixture();
  f.overrides['GET /messages/context/ma'] = (_) => {
    'messages': [
      {
        'id': 'ma',
        'channelId': 'ca',
        'seq': '1',
        'senderId': 'alice',
        'senderName': 'Alice',
        'content': 'Accepted a',
        'createdAt': '2026-10-10T00:00:00Z',
      },
    ],
  };
  f.overrides['GET /channels/ca/threads/ma'] = (_) => {'threadChannelId': 'ta'};
  f.overrides['GET /messages/channel/ta'] = (_) => {
    'messages': [
      {
        'id': 'ra',
        'channelId': 'ta',
        'seq': '2',
        'senderId': 'bob',
        'senderName': 'Bob',
        'content': 'Reply while the app was gone',
        'createdAt': '2026-10-10T00:01:00Z',
      },
    ],
    'hasMore': false,
    'hasNewer': false,
  };
  f.overrides['POST /channels/ta/read'] = (_) => {};
  return f;
}

void main() {
  // iOS reclaims a backgrounded app; opening it again is a cold start onto the
  // remembered surface. A remembered thread was shown as its page (phone) or
  // panel (wide) without its replies ever being read: "No replies yet" until
  // the thread was closed and opened again.
  for (final width in [390.0, 1280.0]) {
    testWidgets('cold start onto a remembered thread loads its replies at '
        '$width', (t) async {
      final f = _threadFixture();
      try {
        await f.mount(
          t,
          'light',
          width,
          cachedSession: true,
          preferences: {
            '$_memory.last': 'alpha',
            '$_memory.a': '/s/alpha/channel/ca?thread=ca%3Ama',
          },
        );
        final w = f.workspace(t);
        expect(w.location.thread?.itemId, 'ma');
        expect(w.threadChannelId, 'ta');
        expect(w.replies.map((m) => m.id), ['ra']);
        expect(find.text('Reply while the app was gone'), findsOneWidget);
        expect(
          f.adapter.calls.where((c) => c.path == '/messages/channel/ta'),
          isNotEmpty,
        );
      } finally {
        await f.close(t);
      }
    });
  }
}
