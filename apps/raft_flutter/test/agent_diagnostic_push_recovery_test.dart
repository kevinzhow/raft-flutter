import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_diagnostic_info.dart';

/// Web utils/agentDiagnosticInfo.ts (v1.24): an external agent's push webhook
/// adds `pushRecovery: {push.recovery}` right after `pushLastError`, only when
/// the server sent one.
Map<String, dynamic> _diagnostics(Map<String, dynamic> push) => {
  'agentId': 'ext-1',
  'generatedAt': '2026-10-24T01:02:00.000Z',
  'presence': {'lastSeenAt': null, 'onlineWindowMs': 120000},
  'status': {
    'activity': 'online',
    'detailKind': 'none',
    'detail': '',
    'observedAt': '2026-10-24T01:01:00.000Z',
    'statusProtocolAdoptedAt': null,
  },
  'provider': null,
  'push': push,
  'events': {'lastCursorPullAt': null, 'pendingCursorAckCount': 0},
  'connections': const [],
};

List<String> _lines(Map<String, dynamic> push) => buildAgentDiagnosticInfo(
  agent: const {
    'id': 'ext-1',
    'name': 'hermes',
    'runtime': 'external',
    'external': true,
  },
  title: 'T',
  serverId: 's',
  activity: 'online',
  externalDiagnostics: _diagnostics(push),
  reportedAt: DateTime.utc(2026, 10, 24, 1, 2, 3),
).split('\n');

void main() {
  const registered = {
    'registered': true,
    'enabled': false,
    'disabledReason': 'too_many_failures',
    'endpointHost': 'hooks.example.com',
    'consecutiveFailures': 3,
    'lastDeliveryAt': null,
    'lastAttemptAt': null,
    'lastError': 'HTTP 500',
  };

  test(
    'a registered webhook with a recovery state lists it after the error',
    () {
      final lines = _lines({
        ...registered,
        'recovery': 'Raft stopped probing; PUT /push-webhook to re-enable.',
      });
      final at = lines.indexOf('pushLastError: HTTP 500');
      expect(at, isNonNegative);
      expect(
        lines[at + 1],
        'pushRecovery: Raft stopped probing; PUT /push-webhook to re-enable.',
      );
    },
  );

  test('no recovery state means no pushRecovery line', () {
    expect(
      _lines(registered).any((l) => l.startsWith('pushRecovery')),
      isFalse,
    );
    expect(
      _lines({...registered, 'recovery': ''})
          .any((l) => l.startsWith('pushRecovery')),
      isFalse,
    );
    expect(
      _lines({'registered': false, 'recovery': 'x'})
          .any((l) => l.startsWith('pushRecovery')),
      isFalse,
    );
  });
}
