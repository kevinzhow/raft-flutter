import 'package:flutter_test/flutter_test.dart';
import 'package:raft_agent_ui/raft_agent_ui.dart';
import 'package:raft_flutter/features/agent_mode/agent_conversation.dart';

/// The rows of a channel as the wire gives them, to the conversation view.
/// Fictional data only.
final _now = DateTime.utc(2026, 10, 17, 12);

Map<String, dynamic> _row(
  String id,
  Object seq, {
  String senderType = 'user',
  String senderId = 'u-bo',
  String name = 'Bo',
  String content = '你好',
  String type = 'chat',
  String at = '2026-10-17T09:00:00.000Z',
  Map<String, dynamic> more = const {},
}) => {
  'id': id,
  'channelId': 'c1',
  'seq': seq,
  'senderId': senderId,
  'senderType': senderType,
  'senderName': name,
  'content': content,
  'messageType': type,
  'createdAt': at,
  ...more,
};

Map<String, dynamic> _sys(String id, int seq, String content) => _row(
  id,
  '$seq',
  senderType: 'system',
  senderId: '',
  name: 'System',
  content: content,
  type: 'system',
);

HfMessageData _one(
  Map<String, dynamic> row, {
  String? me = 'u-kevin',
  List<Map<String, dynamic>> others = const [],
}) => hfMessagesFrom(
  [...others, row],
  myUserId: me,
  now: _now,
).firstWhere((m) => m.id == row['id']);

void main() {
  test('rows are sorted old to new by seq, as numbers, not text', () {
    final out = hfMessagesFrom([
      _row('c', '10'),
      _row('a', '2'),
      _row('b', '9'),
    ], myUserId: null);
    expect([for (final m in out) m.id], ['a', 'b', 'c']);
  });

  test('seq may be a number as well as a string', () {
    final out = hfMessagesFrom([_row('b', 2), _row('a', 1)], myUserId: null);
    expect([for (final m in out) m.id], ['a', 'b']);
  });

  test('mine is a person with my id; an Agent never is', () {
    final mine = _one(_row('m', '1', senderId: 'u-kevin', name: 'Kevin'));
    expect(mine.isMine, isTrue);
    expect(mine.isAgent, isFalse);
    expect(_one(_row('m', '1')).isMine, isFalse);
    final agent = _one(
      _row('m', '1', senderType: 'agent', senderId: 'u-kevin', name: 'Cindy'),
    );
    expect(agent.isAgent, isTrue);
    expect(agent.isMine, isFalse);
    expect(_one(_row('m', '1', senderId: 'u-kevin'), me: null).isMine, isFalse);
    // The legacy "human" sender type counts as a person.
    expect(
      _one(_row('m', '1', senderType: 'human', senderId: 'u-kevin')).isMine,
      isTrue,
    );
  });

  test('a bubble has its name, words and local time', () {
    final m = _one(
      _row(
        'm',
        '1',
        name: 'Bo',
        content: '周五评审',
        more: {'senderDisplayName': 'Bo Li'},
      ),
    );
    expect(m.kind, HfMessageKind.chat);
    expect(m.senderName, 'Bo Li');
    expect(m.text, '周五评审');
    expect(m.time, DateTime.utc(2026, 10, 17, 9).toLocal());
    expect(m.time.isUtc, isFalse);
  });

  test('an external projection is another person, named by its author', () {
    final m = _one({
      'id': 'x',
      'seq': '1',
      'senderType': 'external_projection',
      'senderId': 'ext',
      'content': '来自别的服务器',
      'externalAuthor': {'name': 'Zed', 'provider': 'slack'},
      'createdAt': '2026-10-17T09:00:00Z',
    });
    expect(m.senderName, 'Zed');
    expect(m.isMine, isFalse);
    expect(m.isAgent, isFalse);
  });

  test('a row without a time takes the given now', () {
    final m = hfMessagesFrom(
      [
        {'id': 'x', 'seq': '1', 'senderType': 'user', 'content': 'hi'},
      ],
      myUserId: null,
      now: _now,
    ).single;
    expect(m.time, _now);
  });

  test('attachments: a picture, a file with its size', () {
    final m = _one(
      _row(
        'm',
        '1',
        more: {
          'attachments': [
            {
              'id': 'a1',
              'filename': 'shot.png',
              'mimeType': 'image/png',
              'sizeBytes': 2048,
            },
            {
              'id': 'a2',
              'filename': 'spec.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 1572864,
            },
            {'id': 'a3', 'mimeType': 'text/plain'},
          ],
        },
      ),
    );
    expect(m.attachments.map((a) => a.name), ['shot.png', 'spec.pdf', '附件']);
    expect(m.attachments.map((a) => a.isImage), [true, false, false]);
    expect(m.attachments.map((a) => a.sizeLabel), ['2.0 KB', '1.5 MB', null]);
  });

  test('reactions: counts, and mine from the reactor ids', () {
    final m = _one(
      _row(
        'm',
        '1',
        more: {
          'reactions': [
            {
              'emoji': '👍',
              'count': 3,
              'reactorIds': ['u-bo', 'u-mia', 'u-kevin'],
              'reactorNames': ['Bo', 'Mia', 'Kevin'],
            },
            {
              'emoji': '🎉',
              'reactorIds': ['u-bo'],
              'reactorNames': ['Bo'],
            },
            {'emoji': '👀', 'count': 0, 'reactorIds': [], 'reactorNames': []},
          ],
        },
      ),
    );
    expect(m.reactions.map((r) => '${r.emoji}${r.count}${r.mine}'), [
      '👍3true',
      '🎉1false',
    ]);
    expect(
      _one(
        _row(
          'm',
          '1',
          more: {
            'reactions': [
              {
                'emoji': '👍',
                'count': 1,
                'reactorIds': ['u-kevin'],
                'reactorNames': ['Kevin'],
              },
            ],
          },
        ),
        me: null,
      ).reactions.single.mine,
      isFalse,
    );
  });

  test('a thread count', () {
    expect(_one(_row('m', '1', more: {'replyCount': 4})).replyCount, 4);
    expect(_one(_row('m', '1', more: {'replyCount': '2'})).replyCount, 2);
    expect(_one(_row('m', '1')).replyCount, 0);
  });

  test('a message that is a task carries the chip', () {
    final m = _one(
      _row(
        'm',
        '1',
        content: '把登录页改了',
        more: {
          'taskNumber': 12,
          'taskStatus': 'in_review',
          'taskAssigneeName': 'Cindy',
          'taskCurrentProjection': {'title': '登录页改版'},
        },
      ),
    );
    expect(m.kind, HfMessageKind.chat);
    expect(m.task!.number, 12);
    expect(m.task!.title, '登录页改版');
    expect(m.task!.status, 'in_review');
    expect(m.task!.statusLabel, '等验收');
    expect(m.task!.claimant, 'Cindy');
    // Without a known status there is no chip.
    expect(
      _one(_row('m', '1', more: {'taskNumber': 3, 'taskStatus': 'nope'})).task,
      isNull,
    );
  });

  test('edited and deleted; a deleted message keeps no words', () {
    final e = _one(_row('m', '1', more: {'editedAt': '2026-10-17T09:05:00Z'}));
    expect(e.edited, isTrue);
    expect(e.deleted, isFalse);
    final d = _one(
      _row(
        'm',
        '1',
        content: '秘密',
        more: {
          'deletedAt': '2026-10-17T09:05:00Z',
          'editedAt': '2026-10-17T09:04:00Z',
          'attachments': [
            {'id': 'a', 'filename': 'x.png', 'mimeType': 'image/png'},
          ],
          'reactions': [
            {'emoji': '👍', 'count': 1},
          ],
        },
      ),
    );
    expect(d.deleted, isTrue);
    expect(d.text, '');
    expect(d.attachments, isEmpty);
    expect(d.reactions, isEmpty);
    expect(d.edited, isFalse);
  });

  test(
    'a permalink to a message of the list is a quote, and leaves the text',
    () {
      final target = _row('t1', '1', name: 'Bo', content: '周五前把登录页看完\n第二行');
      final reply = _row(
        'r1',
        '2',
        senderId: 'u-kevin',
        name: 'Kevin',
        content: 'https://app.raft.build/s/acme/channel/c1?msg=t1 好的',
      );
      final out = hfMessagesFrom(
        [reply, target],
        myUserId: 'u-kevin',
        now: _now,
      );
      final m = out.last;
      expect(m.quote!.author, 'Bo');
      expect(m.quote!.text, '周五前把登录页看完');
      expect(m.quote!.id, 't1');
      expect(m.text, '好的');
      // A link to a message that is not in the list stays as written.
      final lost = _one(
        _row(
          'r2',
          '3',
          content: 'https://app.raft.build/s/acme/channel/c1?msg=zzz 看这个',
        ),
      );
      expect(lost.quote, isNull);
      expect(lost.text, contains('https://'));
    },
  );

  test('code and "> " lines stay in the text for the view to draw', () {
    final m = _one(_row('m', '1', content: '看:\n```dart\nrun();\n```\n> 注意'));
    expect(m.text, contains('```dart'));
    expect(HfConversation.bodyOf(m.text).map((s) => s.kind), [
      HfBodyKind.text,
      HfBodyKind.code,
      HfBodyKind.quote,
    ]);
  });

  group('system messages', () {
    test('a plain one is a note', () {
      final m = _one(_sys('s', 1, 'Mia joined the channel'));
      expect(m.kind, HfMessageKind.system);
      expect(m.text, 'Mia joined the channel');
      expect(m.isMine, isFalse);
      expect(m.task, isNull);
    });

    test('a reminder is a reminder', () {
      expect(
        _one(_sys('s', 1, 'Reminder #ab12: 周五评审')).kind,
        HfMessageKind.reminder,
      );
      expect(
        _one(_sys('s', 1, 'Bo scheduled a reminder for 10:00')).kind,
        HfMessageKind.reminder,
      );
    });

    test('a task converted from a message', () {
      final m = _one(
        _sys('s', 1, 'Bo converted a message to task #12 "登录页改版"'),
      );
      expect(m.kind, HfMessageKind.taskEvent);
      expect(m.text, 'Bo 把消息转成了任务');
      expect(m.task!.number, 12);
      expect(m.task!.title, '登录页改版');
      expect(m.task!.status, 'todo');
    });

    test('claimed, released, deleted', () {
      final c = _one(_sys('s', 1, 'Cindy claimed #12 "登录页改版"'));
      expect(c.text, 'Cindy 认领了任务');
      expect(c.task!.claimant, 'Cindy');
      expect(
        _one(_sys('s', 1, 'Cindy released #12 "登录页改版"')).text,
        'Cindy 放下了任务',
      );
      expect(_one(_sys('s', 1, 'Bo deleted #12 "登录页改版"')).text, 'Bo 删除了任务');
    });

    test('moved to a status, in Chinese', () {
      final m = _one(_sys('s', 1, 'Cindy moved #12 "登录页改版" to In Review'));
      expect(m.kind, HfMessageKind.taskEvent);
      expect(m.task!.status, 'in_review');
      expect(m.text, 'Cindy 把任务移到了「等验收」');
      final done = _one(_sys('s', 1, 'Cindy moved #12 "x" to done'));
      expect(done.task!.status, 'done');
      expect(done.text, contains('已完成'));
    });

    test('a leading status glyph is ignored', () {
      final m = _one(_sys('s', 1, '✅ Cindy moved #12 "登录页改版" to done'));
      expect(m.kind, HfMessageKind.taskEvent);
      expect(m.task!.number, 12);
    });

    test('a new task', () {
      final m = _one(_sys('s', 1, 'New task created: #13 "写测试"'));
      expect(m.kind, HfMessageKind.taskEvent);
      expect(m.task!.number, 13);
      expect(m.task!.title, '写测试');
      // Without a number or a title it is only a note.
      expect(_one(_sys('s', 1, 'New task created')).kind, HfMessageKind.system);
    });

    test('a system sender without a system message type is a note too', () {
      final m = _one({
        'id': 'q',
        'seq': '1',
        'senderType': 'system',
        'content': 'Cleanup done',
        'createdAt': '2026-10-17T09:00:00Z',
      });
      expect(m.kind, HfMessageKind.system);
    });
  });

  test(
    'a whole channel makes a view that round trips and parts that number',
    () {
      final rows = [
        _row('m3', '3', senderId: 'u-kevin', name: 'Kevin', content: '好'),
        _sys('s1', 2, 'Cindy claimed #12 "登录页改版"'),
        _row('m1', '1', content: '开始吧'),
        _sys('s2', 4, 'Mia joined the channel'),
        _sys('s3', 5, 'Reminder #1: 开会'),
      ];
      final out = hfMessagesFrom(rows, myUserId: 'u-kevin', now: _now);
      expect([for (final m in out) m.id], ['m1', 's1', 'm3', 's2', 's3']);
      final again = [for (final m in out) HfMessageData.fromJson(m.toJson())];
      expect(again, out);
      final parts = HfConversation.partsOf(out, now: _now);
      expect(parts.whereType<HfMessagePart>().map((p) => p.n), [1, 2]);
      expect(parts.whereType<HfTaskEventPart>(), hasLength(1));
      expect(
        parts.whereType<HfNoteGroupPart>().single.summary,
        '2 条系统更新：1 条系统消息、1 条提醒',
      );
    },
  );
}
