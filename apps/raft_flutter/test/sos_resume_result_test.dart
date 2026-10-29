import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/sos_resume_result.dart';

void main() {
  test('a response without failed rows completes like Web', () {
    for (final response in <Object?>[
      null,
      {},
      {'ok': true},
      {'ok': false},
      {'ok': true, 'results': null},
      {'ok': true, 'results': 'invalid'},
      {'ok': true, 'total': 2, 'results': []},
      {
        'ok': false,
        'total': 3,
        'results': [
          {'agentId': 'a', 'ok': true},
        ],
      },
    ]) {
      expect(
        SosResumeResult.parse(response).missed,
        isEmpty,
        reason: '$response',
      );
    }
  });

  test(
    'each unsuccessful agent retains the server reason and retry identity',
    () {
      final result = SosResumeResult.parse({
        'ok': false,
        'results': [
          {'agentId': 'ready', 'ok': true},
          {'agentId': 'starting', 'ok': false, 'reason': 'start_in_flight'},
          {'agentId': 'offline', 'ok': false, 'error': 'Computer offline'},
          {'agentId': 'silent'},
        ],
      });
      expect(result.retryAgentIds, ['starting', 'offline', 'silent']);
      expect(result.missed.map((m) => m.reason), [
        'start_in_flight',
        null,
        null,
      ]);
      expect((result.starting, result.failed), (1, 2));
    },
  );

  test('ok is read by JavaScript truthiness', () {
    final result = SosResumeResult.parse({
      'results': [
        {'agentId': 'a', 'ok': 'yes'},
        {'agentId': 'b', 'ok': 1},
        {'agentId': 'c', 'ok': 0},
        {'agentId': 'd', 'ok': ''},
        {'agentId': 'e', 'ok': null},
      ],
    });
    expect(result.retryAgentIds, ['c', 'd', 'e']);
  });
}
