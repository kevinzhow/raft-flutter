import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

Map<String, Object?> _msg(String id) => {
  'id': id,
  'senderType': 'user',
  'senderId': 'u1',
  'senderName': 'Mina',
  'senderAvatarUrl': null,
  'createdAt': '2026-09-20T10:00:00.000Z',
  'preview': 'hello',
};

void main() {
  group('HiddenHistory.read (Web readHiddenHistory)', () {
    test('reads counts and the newest hidden messages', () {
      final hidden = HiddenHistory.read({
        'hiddenCount': 7,
        'hiddenCountCapped': true,
        'parentHidden': true,
        'latest': [_msg('a'), _msg('b')],
      })!;
      expect(hidden.hiddenCount, 7);
      expect(hidden.hiddenCountCapped, isTrue);
      expect(hidden.parentHidden, isTrue);
      expect(hidden.latest.map((m) => m.id), ['a', 'b']);
      expect(hidden.latest.first.preview, 'hello');
    });

    test('malformed shapes are ignored', () {
      expect(HiddenHistory.read(null), isNull);
      expect(HiddenHistory.read('x'), isNull);
      expect(HiddenHistory.read({'hiddenCount': '3'}), isNull);
      expect(HiddenHistory.read({'hiddenCount': -1}), isNull);
      expect(HiddenHistory.read({}), isNull);
    });

    test('bad latest rows are dropped, the rest kept', () {
      final hidden = HiddenHistory.read({
        'hiddenCount': 2,
        'latest': [
          _msg('ok'),
          {..._msg('x'), 'senderType': 'robot'},
          {..._msg('y'), 'createdAt': 5},
          'nope',
        ],
      })!;
      expect(hidden.latest.map((m) => m.id), ['ok']);
      expect(hidden.hiddenCountCapped, isFalse);
      expect(hidden.parentHidden, isFalse);
    });
  });

  group('HiddenHistoryStore.recordPage (Web recordHiddenHistory)', () {
    final limited = {
      'historyLimited': true,
      'hiddenHistory': {'hiddenCount': 3, 'latest': <Object>[]},
    };

    test('a limited page records, a page that is not limited clears', () {
      final store = HiddenHistoryStore()..recordPage('c', limited);
      expect(store.of('c')?.hiddenCount, 3);
      store.recordPage('c', {'historyLimited': false});
      expect(store.of('c'), isNull);
    });

    test('a limited page without hiddenHistory keeps the last answer', () {
      final store = HiddenHistoryStore()..recordPage('c', limited);
      store.recordPage('c', {'historyLimited': true});
      expect(store.of('c')?.hiddenCount, 3);
      store.recordPage('c', {'historyLimited': true, 'hiddenHistory': 'junk'});
      expect(store.of('c')?.hiddenCount, 3);
    });

    test('channels are independent', () {
      final store = HiddenHistoryStore()..recordPage('a', limited);
      expect(store.of('b'), isNull);
    });
  });

  group('HiddenTarget (Web readHiddenTarget / readHistoryLimitedError)', () {
    Map<String, Object?> body() => {
      'target': {..._msg('t'), 'seq': 9},
      'before': [_msg('b')],
      'after': [_msg('a1'), _msg('a2')],
      'thread': {
        'hiddenReplyCount': 4,
        'hiddenReplyCountCapped': true,
        'parentHidden': true,
      },
      'replies': {'count': 3, 'latest': _msg('r')},
    };

    test('reads the target, neighbours, thread counts and reply box', () {
      final target = HiddenTarget.read(body())!;
      expect(target.target.id, 't');
      expect(target.before.single.id, 'b');
      expect(target.after.map((m) => m.id), ['a1', 'a2']);
      expect(target.threadCounts?.count, 4);
      expect(target.threadCounts?.capped, isTrue);
      expect(target.threadCounts?.parentHidden, isTrue);
      expect(target.replies?.count, 3);
      expect(target.replies?.latest.id, 'r');
    });

    test('a target without a numeric seq is ignored', () {
      final noSeq = body()..['target'] = _msg('t');
      expect(HiddenTarget.read(noSeq), isNull);
      expect(HiddenTarget.read(null), isNull);
    });

    test('an empty reply box (count 0) is dropped', () {
      final noReplies = body()..['replies'] = {'count': 0, 'latest': _msg('r')};
      expect(HiddenTarget.read(noReplies)!.replies, isNull);
    });

    RaftApiException failure(int status, Map<String, Object?> body) =>
        RaftApiException.response('x', status: status, body: body);

    test('only a 404 with code history_limited carries a target', () {
      expect(
        HiddenTarget.fromError(
          failure(404, {
            'error': 'History limited',
            'code': 'history_limited',
            'hiddenTarget': body(),
          }),
        )?.target.id,
        't',
      );
      expect(
        HiddenTarget.fromError(failure(404, {'error': 'Message not found'})),
        isNull,
      );
      expect(
        HiddenTarget.fromError(
          failure(500, {
            'error': 'x',
            'code': 'history_limited',
            'hiddenTarget': body(),
          }),
        ),
        isNull,
      );
      expect(HiddenTarget.fromError(StateError('x')), isNull);
    });
  });
}
