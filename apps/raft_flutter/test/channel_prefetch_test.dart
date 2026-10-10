import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';

import 'chat_focus_receipt_test.dart' show contextRows;
import 'message_presentation_test.dart' show fixture;

void main() {
  test('[P04] unread channels are prefetched; a first open has rows before the network', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    final two = RaftChannel({'id': 'c2', 'name': 'two', 'joined': true});
    w.channels = [...w.channels, two];
    w.unread = {'c2': 3};
    final rows = [
      for (final row in contextRows('two', count: 20)) {...row, 'channelId': 'c2'},
    ];
    var pageRequests = 0;
    final slow = Completer<Map<String, dynamic>>();
    api.routes['GET /messages/channel/c2'] = (_) {
      pageRequests++;
      return pageRequests == 1 ? {'messages': rows, 'hasMore': false} : slow.future;
    };
    api.routes['POST /channels/c2/read'] = (_) => {};
    await w.prefetchLikelyChannels();
    expect(pageRequests, 1);
    expect(w.unread['c2'], 3, reason: 'Prefetch never marks read');
    expect(w.channel?.id, 'c1', reason: 'Prefetch never selects');

    unawaited(w.selectChannel(two));
    // Before the open's own network page returns, the prefetched rows show.
    for (var i = 0; i < 20 && w.messages.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(w.messages.map((m) => m.id), rows.map((r) => r['id']));
    expect(w.channelLoading, true);
    slow.complete({'messages': rows, 'hasMore': false});
  });

  test('[P04] prefetch skips channels without unread, the open channel and repeats', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    final quiet = RaftChannel({'id': 'c3', 'name': 'quiet', 'joined': true});
    w.channels = [...w.channels, quiet];
    w.unread = {'c1': 5, 'c3': 0};
    var requests = 0;
    api.routes['GET /messages/channel/c1'] = (_) {
      requests++;
      return {'messages': [], 'hasMore': false};
    };
    api.routes['GET /messages/channel/c3'] = (_) {
      requests++;
      return {'messages': [], 'hasMore': false};
    };
    await w.prefetchLikelyChannels();
    await w.prefetchLikelyChannels();
    expect(requests, 0);
  });
}
