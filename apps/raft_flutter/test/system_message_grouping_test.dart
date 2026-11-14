import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/plan_history.dart';
import 'package:raft_flutter/features/system_message_grouping.dart';

RaftMessage _m(String id, String content, {String type = 'system'}) =>
    RaftMessage({'id': id, 'content': content, 'messageType': type});

String _format(String text, Map<String, Object?> values) => text
    .replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => '${values[m[1]] ?? m[0]}');

void main() {
  test('adjacent system rows collapse into one summary, the rest hide', () {
    final states = buildSystemGroupStates([
      _m('a', 'hello', type: 'chat'),
      _m('s1', 'Cindy joined the channel.'),
      _m('s2', 'Designer joined the channel.'),
      _m('s3', 'artin renamed the channel.'),
      _m('b', 'bye', type: 'chat'),
    ], _format);
    expect(states[0], isNull);
    expect(states[4], isNull);
    final summary = states[1]! as SystemGroupSummary;
    expect(summary.summary, 'There are 3 system messages');
    expect(summary.messageIndexes, [1, 2, 3]);
    expect(summary.groupId, 'system-group:s1:s3');
    expect(states[2], isA<SystemGroupHide>());
    expect(states[3], isA<SystemGroupHide>());
  });

  test('a lone system row is not grouped; task events count as updates', () {
    expect(
      buildSystemGroupStates([_m('s1', 'Cindy joined.')], _format).single,
      isNull,
    );
    final states = buildSystemGroupStates([
      _m('t1', 'artin claimed #12 "Fix header"'),
      _m('t2', 'artin moved #12 "Fix header" to done'),
      _m('r1', 'Reminder #ab12: stand-up'),
    ], _format);
    expect(
      (states[0]! as SystemGroupSummary).summary,
      'There are 2 task updates, 1 reminder update',
    );
  });

  test('plan history days follow the trial end', () {
    expect(planHistoryLimit('free', now: DateTime.utc(2026, 6, 19)).days, -1);
    final after = planHistoryLimit('free', now: DateTime.utc(2026, 6, 24));
    expect((after.plan, after.days), ('Free', 30));
    expect(planHistoryLimit('pro', now: DateTime.utc(2026, 7, 1)).days, -1);
  });
}
