import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> message(int seq, String channel) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': '$channel message $seq',
  'senderType': 'user',
  'senderId': 'alice',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://context-tail-race.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final eventsController = StreamController<RaftEvent>.broadcast(sync: true);
  final tailStarted = Completer<void>();
  Completer<Map<String, dynamic>>? holdTail;
  int alphaEnd = 76;
  @override
  Stream<RaftEvent> get events => eventsController.stream;
  @override
  void joinChannel(String id) {}

  Map<String, dynamic> page(String id, {BigInt? before}) {
    final end = before?.toInt() ?? (id == 'alpha' ? alphaEnd : 5);
    final start = (end - 50).clamp(1, end);
    return {
      'messages': [for (var seq = start; seq < end; seq++) message(seq, id)],
      'historyLimited': false,
    };
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    final held = holdTail;
    if (id == 'alpha' && before == null && held != null) {
      if (!tailStarted.isCompleted) tailStarted.complete();
      return held.future;
    }
    return page(id, before: before);
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      path == '/messages/context/alpha-6'
      ? {
          'messages': [message(6, 'alpha')],
          'targetMessageId': 'alpha-6',
          'hasOlder': true,
          'hasNewer': true,
        }
      : {};
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
}

void main() {
  for (final live in [false, true]) {
    test(
      'cancelled return to latest cannot turn a context island into a tail; live=$live',
      () async {
        final client = _Client();
        final cache = DriftWorkspaceCache(NativeDatabase.memory());
        final alpha = RaftChannel({'id': 'alpha', 'joined': true});
        final beta = RaftChannel({'id': 'beta', 'joined': true});
        final w = WorkspaceController(client, cache: cache)
          ..server = RaftRecord({'id': 'server', 'role': 'owner'})
          ..channels = [alpha, beta];
        w.messageDomain.ledger.switchServer('server');
        addTearDown(() async {
          w.dispose();
          await client.eventsController.close();
          await cache.close();
        });
        await w.selectChannel(alpha, navigate: false, autoRead: false);
        await w.flushCache();
        await w.jumpToMessage('alpha', 'alpha-6', navigate: false);
        expect(w.messageDomain.messages.map((m) => m.id), ['alpha-6']);
        expect(w.messageDomain.state.hasNewer, isTrue);

        final late = Completer<Map<String, dynamic>>();
        client.holdTail = late;
        final returning = w.messageDomain.returnToLatest(navigate: false);
        await client.tailStarted.future;
        if (live) {
          client.alphaEnd = 77;
          client.eventsController.add(
            RaftEvent('message:new', message(76, 'alpha')),
          );
          await w.flushCache();
        }
        await w.selectChannel(beta, navigate: false, autoRead: false);
        client.holdTail = null;
        late.complete(client.page('alpha'));
        await returning;
        expect(w.channel?.id, 'beta');
        expect(w.messageDomain.messages.map((m) => m.id), [
          for (var n = 1; n <= 4; n++) 'beta-$n',
        ]);

        await w.selectChannel(alpha, navigate: false, autoRead: false);
        final reopened = w.messageDomain.messages.map((m) => m.id).toList();
        await w.messageDomain.older();
        await w.flushCache();
        expect(
          w.messageDomain.messages.map((m) => m.id),
          [for (var n = 1; n < client.alphaEnd; n++) 'alpha-$n'],
          reason:
              'A cancelled latest request left this reopened window: $reopened',
        );
        expect(w.messageDomain.state.hasMore, isFalse);
      },
    );
  }
}
