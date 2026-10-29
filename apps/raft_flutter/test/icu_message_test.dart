import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/icu_message.dart';

void main() {
  const stats =
      '{turns, plural, one {# turn} other {# turns}} below · {steps, plural, one {# step} other {# steps}} · {problems, plural, =0 {nothing went wrong} one {# step went wrong} other {# steps went wrong}}';

  test('English picks one / other and the exact =0 arm', () {
    expect(
      expandIcuMessage(stats, {'turns': 1, 'steps': 12, 'problems': 0}),
      '1 turn below · 12 steps · nothing went wrong',
    );
    expect(
      expandIcuMessage(stats, {'turns': 3, 'steps': 1, 'problems': 1}),
      '3 turns below · 1 step · 1 step went wrong',
    );
    expect(
      expandIcuMessage(stats, {'turns': 3, 'steps': 1, 'problems': 4}),
      '3 turns below · 1 step · 4 steps went wrong',
    );
  });

  test('zh has no one form: other, and =0 still wins', () {
    const zh =
        '下面共 {turns} 轮 · {steps} 步 · {problems, plural, =0 {都很顺利} other {# 步不顺}}';
    expect(
      expandIcuMessage(zh, {
        'turns': 1,
        'steps': 1,
        'problems': 0,
      }, oneForm: false),
      '下面共 1 轮 · 1 步 · 都很顺利',
    );
    expect(
      expandIcuMessage(zh, {
        'turns': 2,
        'steps': 5,
        'problems': 2,
      }, oneForm: false),
      '下面共 2 轮 · 5 步 · 2 步不顺',
    );
    expect(
      expandIcuMessage(
        'ran {count, plural, one {a command} other {# commands}}',
        {'count': 1},
        oneForm: false,
      ),
      'ran 1 commands',
    );
  });

  test('simple placeholders and an unknown one are kept', () {
    expect(
      expandIcuMessage('{time} · {code}', {'time': '10:00'}),
      '10:00 · {code}',
    );
  });
}
