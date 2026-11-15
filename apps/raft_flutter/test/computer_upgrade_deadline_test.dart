import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/computer_upgrade_in_flight.dart';

final t0 = DateTime.utc(2026, 10, 21, 8);
int ms(DateTime t) => t.millisecondsSinceEpoch;

Map<String, dynamic> request({
  String id = 'r1',
  String state = 'pending',
  DateTime? at,
  String target = '1.4.0',
}) => {
  'id': id,
  'state': state,
  'targetVersion': target,
  'requestedAt': (at ?? t0).toIso8601String(),
};

Map<String, dynamic> machine({
  String status = 'online',
  String version = '1.3.0',
  Map<String, dynamic>? upgrade,
  DateTime? heartbeat,
}) => {
  'id': 'm',
  'isComputer': true,
  'status': status,
  'computerVersion': version,
  'upgradeRequest': ?upgrade,
  if (heartbeat != null) 'lastHeartbeat': heartbeat.toIso8601String(),
};

AcceptedComputerUpgrade accepted({DateTime? at, Map<String, dynamic>? r}) =>
    AcceptedComputerUpgrade(r ?? request(), ms(at ?? t0));

void main() {
  test(
    'the server\'s own deadline outlives the 30 minute default (a drain)',
    () {
      final r = {
        ...request(),
        'deadlineAt': t0.add(const Duration(minutes: 70)).toIso8601String(),
        'phase': 'draining',
        'drainingAgentIds': ['a'],
        'drainDeadlineAt': t0
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      };
      final a = accepted(r: r);
      expect(
        computerUpgradeRequestDeadlineMs(r),
        const Duration(minutes: 70).inMilliseconds,
      );
      expect(
        computerUpgradeInFlight(
          machine(status: 'offline'),
          a,
          ms(t0.add(const Duration(minutes: 45))),
        ),
        r,
        reason: 'past the old 30 minutes, inside the server deadline',
      );
      expect(
        computerUpgradeInFlight(
          machine(status: 'offline'),
          a,
          ms(t0.add(const Duration(minutes: 71))),
        ),
        isNull,
      );
    },
  );

  test('a request without a deadline keeps the 30 minute default', () {
    expect(
      computerUpgradeRequestDeadlineMs(request()),
      const Duration(minutes: 30).inMilliseconds,
    );
  });
}
