// Web v1.24 task/taskHandoffNotice.ts: a hand-off with a reason is read from
// an assignment line's actionMetadata; it is open until the task goes back to
// whoever handed it off.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/task_handoff_notice.dart';

Map<String, dynamic> _party(String type, String id, String name) => {
  'type': type,
  'id': id,
  'name': name,
  'displayName': name,
};

RaftMessage _line(
  String id,
  String at, {
  required Map<String, dynamic> actor,
  Map<String, dynamic>? assignee,
  String? reason,
  String type = 'system',
}) => RaftMessage({
  'id': id,
  'messageType': type,
  'createdAt': at,
  'actionMetadata': {
    'kind': 'task-assignment',
    'taskNumber': 7,
    'actor': actor,
    'assignee': assignee,
    'reason': ?reason,
  },
});

void main() {
  final otter = _party('agent', 'a1', 'Otter');
  final dana = _party('user', 'u1', 'dana');
  final handoff = _line(
    'm1',
    '2026-11-15T10:42:00Z',
    actor: otter,
    assignee: dana,
    reason: 'Review the copy',
  );

  test('only a hand-off to someone else with a reason is a card', () {
    expect(readTaskHandoffNotice(handoff)?.reason, 'Review the copy');
    expect(
      readTaskHandoffNotice(
        _line('m2', '2026-11-15T10:43:00Z', actor: otter, assignee: dana),
      ),
      isNull,
      reason: 'no reason',
    );
    expect(
      readTaskHandoffNotice(
        _line(
          'm3',
          '2026-11-15T10:44:00Z',
          actor: otter,
          assignee: otter,
          reason: 'mine',
        ),
      ),
      isNull,
      reason: 'taking it yourself',
    );
    expect(
      readTaskHandoffNotice(
        _line(
          'm4',
          '2026-11-15T10:45:00Z',
          actor: otter,
          assignee: dana,
          reason: 'x',
          type: 'text',
        ),
      ),
      isNull,
      reason: 'not a system line',
    );
  });

  test('it is open until it goes back to whoever handed it off', () {
    final handedOn = _line(
      'm5',
      '2026-11-15T10:47:00Z',
      actor: dana,
      assignee: _party('user', 'u2', 'erin'),
    );
    expect(taskHandoffReturn(handoff, [handoff, handedOn]), isNull);

    final tookBack = _line(
      'm6',
      '2026-11-15T10:51:00Z',
      actor: otter,
      assignee: otter,
    );
    final back = taskHandoffReturn(handoff, [handoff, handedOn, tookBack]);
    expect(back?.by.id, 'a1', reason: 'the actor took it back');
    expect(back?.at, DateTime.parse('2026-11-15T10:51:00Z'));

    final handedBack = _line(
      'm7',
      '2026-11-15T10:52:00Z',
      actor: dana,
      assignee: otter,
    );
    expect(
      taskHandoffReturn(handoff, [handoff, handedBack])?.by.id,
      'u1',
      reason: 'someone else gave it back',
    );
    expect(
      taskHandoffReturn(handoff, [tookBack, handoff]),
      isNull,
      reason: 'only a later line counts',
    );
  });
}
