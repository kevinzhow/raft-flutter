import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/dm_read_status.dart';

import 'message_presentation_test.dart' show fixture;

RaftMessage sent({
  String sender = 'alice',
  String type = 'user',
  int? seq = 2,
}) => RaftMessage({
  'id': 'm',
  'channelId': 'd',
  'senderId': sender,
  'senderType': type,
  'seq': seq,
  'content': 'Public DM fixture',
});

void main() {
  test('unknown, non-human, peer, pending and foreign-server messages do not claim read', () async {
    final (w, api) = await fixture('owner');
    addTearDown(w.dispose);
    w.channel = RaftChannel({'id': 'd', 'name': 'Ada', 'type': 'dm'});
    w.channels = [];
    w.dms = [w.channel!];
    api.routes['GET /channels/d'] = (_) => {
      'peerReadStates': [
        {'peerKind': 'agent', 'peerId': 'ada', 'maxReadSeq': 10},
      ],
    };
    await w.readReceipts.hydrate('d');
    expect(dmReadStatusMessageId(w, [sent()], thread: false), 'm');
    for (final row in [
      sent(sender: 'bob'),
      sent(type: 'agent'),
      sent(type: 'external_projection'),
      sent(seq: null),
      sent(seq: 0),
      RaftMessage({...sent().json, 'pendingSend': true}),
      RaftMessage({...sent().json, 'sourceServerId': 'foreign'}),
      RaftMessage({...sent().json, 'channelId': 'foreign'}),
    ]) {
      expect(dmReadStatusMessageId(w, [row], thread: false), isNull);
    }
    expect(dmReadStatusMessageId(w, [], thread: false), isNull);
    w.dms = [];
    expect(dmReadStatusMessageId(w, [sent()], thread: false), isNull);
  });

  test(
    'identity changes discard old frontiers and re-read the same scope ID',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      w.channel = RaftChannel({'id': 'd', 'name': 'Ada', 'type': 'dm'});
      w.channels = [];
      w.dms = [w.channel!];
      var peerSeq = 10;
      api.routes['GET /channels/d'] = (_) => {
        'peerReadStates': [
          {'peerKind': 'agent', 'peerId': 'ada', 'maxReadSeq': peerSeq},
        ],
      };
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      expect(dmReadStatusMessageId(w, [sent()], thread: false), isNull);
      await settle();
      expect(dmReadStatusMessageId(w, [sent()], thread: false), 'm');
      final first = api.calls.where((o) => o.path == '/channels/d').length;
      w.client.user = RaftRecord({'id': 'bob'});
      peerSeq = 0;
      expect(
        dmReadStatusMessageId(w, [sent(sender: 'bob')], thread: false),
        isNull,
      );
      await settle();
      expect(api.calls.where((o) => o.path == '/channels/d').length, first + 1);
      expect(
        dmReadStatusMessageId(w, [sent(sender: 'bob')], thread: false),
        isNull,
      );
      w.client.selectServer('s2');
      w.server = RaftRecord({'id': 's2', 'role': 'owner'});
      peerSeq = 10;
      expect(
        dmReadStatusMessageId(w, [sent(sender: 'bob')], thread: false),
        isNull,
      );
      await settle();
      expect(api.calls.where((o) => o.path == '/channels/d').length, first + 2);
      expect(
        dmReadStatusMessageId(w, [sent(sender: 'bob')], thread: false),
        'm',
      );
      w.sessionScope.revokedServers.add('s2');
      expect(
        dmReadStatusMessageId(w, [sent(sender: 'bob')], thread: false),
        isNull,
      );
    },
  );
}
