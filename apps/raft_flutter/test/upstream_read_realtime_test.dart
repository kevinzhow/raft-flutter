import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_sync/raft_sync.dart';

import 'message_presentation_test.dart' show MessageAdapter;

/// Web v1.21.2 -> v1.21.12 read and realtime re-audit (task #120).
class _EventClient extends RaftClient {
  _EventClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void emit(String name, dynamic payload) =>
      stream.add(RaftEvent(name, payload));
}

final _c1 = RaftChannel({'id': 'c1', 'name': 'design', 'joined': true});
final _c2 = RaftChannel({'id': 'c2', 'name': 'release', 'joined': true});

Map<String, dynamic> _row(String id, String channel, Object seq) => {
  'id': id,
  'channelId': channel,
  'seq': seq,
  'senderId': 'bob',
  'senderType': 'user',
  'senderName': 'bob',
  'content': 'Body $id',
  'createdAt': '2026-10-10T02:30:00Z',
};

Future<(WorkspaceController, MessageAdapter, _EventClient)> _login() async {
  final a = MessageAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes['GET /agents'] = (_) => [];
  a.routes['GET /servers/s1/members'] = (_) => [];
  a.routes['GET /channels'] = (_) => [_c1.json, _c2.json];
  a.routes['GET /channels/dm'] = (_) => [];
  a.routes['GET /channels/unread'] = (_) => {'channels': {}};
  a.routes['GET /messages/channel/c1'] = (_) => {
    'messages': [_row('p-c1', 'c1', 20)],
    'threadSummariesByParentMessageId': {
      'p-c1': {
        'threadChannelId': 't-c1',
        'replyCount': 3,
        'unreadCount': 3,
        'firstUnreadMessageId': 't-c1-r1',
        'latestReplies': [
          {
            'messageId': 't-c1-r3',
            'senderType': 'user',
            'senderId': 'bob',
            'senderName': 'bob',
            'preview': 'Reply',
            'createdAt': '2026-10-10T02:31:00Z',
          },
        ],
      },
    },
  };
  a.routes['POST /channels/c1/read'] = (_) => {};
  final client = _EventClient(a);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'member'});
  w.channels = [_c1, _c2];
  w.channel = _c1;
  w.messageDomain.ledger.switchServer('s1');
  return (w, a, client);
}

void main() {
  group('wire seq (Web coerceWireMessageSeq)', () {
    test('[BP-READ-078] canonicalWireSeq reads a JSON number and a decimal string alike', () {
      expect(canonicalWireSeq(600), BigInt.from(600));
      expect(canonicalWireSeq('600'), BigInt.from(600));
      expect(canonicalWireSeq('0600'), isNull);
      expect(canonicalWireSeq(-1), isNull);
      expect(canonicalWireSeq(1.5), isNull);
      expect(canonicalWireSeq(null), isNull);
      expect(canonicalWireSeq('abc'), isNull);
    });

    for (final seq in <Object>[600, '600']) {
      test(
        '[BP-READ-078] a live message behind the read frontier is not counted (seq as ${seq.runtimeType})',
        () async {
          final (w, _, client) = await _login();
          addTearDown(w.dispose);
          await w.selectChannel(_c1, autoRead: false);
          w.unread = {'c2': 0};
          client.emit('read_state:updated', {
            'serverId': 's1',
            'scopeId': 'c2',
            'maxReadSeq': 610,
            'readStateVersion': 1,
          });
          client.emit('message:new', _row('late', 'c2', seq));
          expect(
            w.unread['c2'],
            0,
            reason: 'the frontier already covers seq 600',
          );
          client.emit(
            'message:new',
            _row('fresh', 'c2', seq is int ? 620 : '620'),
          );
          expect(w.unread['c2'], 1);
        },
      );
    }
  });

  group(
    'read_state:updated unreadCount hint (Web applyServerThreadUnread)',
    () {
      Future<(WorkspaceController, _EventClient)> opened() async {
        final (w, _, client) = await _login();
        await w.selectChannel(_c1, autoRead: false);
        expect(w.messageDomain.threadSummaries['p-c1']['unreadCount'], 3);
        return (w, client);
      }

      test('[BP-READ-079] a read elsewhere lowers the thread badge to the server count', () async {
        final (w, client) = await opened();
        addTearDown(w.dispose);
        client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': 't-c1',
          'maxReadSeq': 5,
          'readStateVersion': 1,
          'unreadCount': 1,
        });
        expect(w.messageDomain.threadSummaries['p-c1']['unreadCount'], 1);
        expect(
          w.messageDomain.threadSummaries['p-c1']['firstUnreadMessageId'],
          't-c1-r1',
          reason: 'the server sends a count, not a position',
        );
        expect(w.messageDomain.threadSummaries['p-c1']['replyCount'], 3);
      });

      test('[BP-READ-079] zero drops the jump target; a count never raises the badge', () async {
        final (w, client) = await opened();
        addTearDown(w.dispose);
        client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': 't-c1',
          'maxReadSeq': 5,
          'readStateVersion': 1,
          'unreadCount': 2,
        });
        client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': 't-c1',
          'maxReadSeq': 6,
          'readStateVersion': 2,
          'unreadCount': 9,
        });
        expect(w.messageDomain.threadSummaries['p-c1']['unreadCount'], 2);
        client.emit('read_state:updated_bulk', {
          'serverId': 's1',
          'scopes': [
            {
              'scopeId': 't-c1',
              'maxReadSeq': 9,
              'readStateVersion': 3,
              'unreadCount': 0,
            },
          ],
        });
        expect(w.messageDomain.threadSummaries['p-c1']['unreadCount'], 0);
        expect(
          w.messageDomain.threadSummaries['p-c1']['firstUnreadMessageId'],
          isNull,
        );
      });

      test('[BP-READ-079] a frame without a usable count, or a stale one, leaves the badge alone', () async {
        final (w, client) = await opened();
        addTearDown(w.dispose);
        client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': 't-c1',
          'maxReadSeq': 5,
          'readStateVersion': 5,
        });
        client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': 't-c1',
          'maxReadSeq': 5,
          'readStateVersion': 6,
          'unreadCount': -1,
        });
        // A frame the read-state ledger already has (same version) is stale.
        client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': 't-c1',
          'maxReadSeq': 5,
          'readStateVersion': 6,
          'unreadCount': 0,
        });
        expect(w.messageDomain.threadSummaries['p-c1']['unreadCount'], 3);
      });
    },
  );
}
