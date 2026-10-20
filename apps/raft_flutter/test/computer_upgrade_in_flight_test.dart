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
  group('computerUpgradeInFlight', () {
    test('the server pending row is the answer', () {
      final row = request();
      expect(computerUpgradeInFlight(machine(upgrade: row), null, ms(t0)), row);
    });

    test('nothing in flight without a pending row or an accepted click', () {
      expect(computerUpgradeInFlight(machine(), null, ms(t0)), isNull);
      expect(
        computerUpgradeInFlight(
          machine(upgrade: request(state: 'done')),
          null,
          ms(t0),
        ),
        isNull,
      );
    });

    test('an accepted click stays in flight when a refresh drops the row', () {
      final a = accepted();
      expect(
        computerUpgradeInFlight(
          machine(status: 'offline'),
          a,
          ms(t0.add(const Duration(minutes: 1))),
        ),
        a.request,
        reason: 'a coalesced read without the pending row is not evidence',
      );
    });

    test('ends when the row shows that request settled, or a later one', () {
      final a = accepted();
      for (final row in [
        request(state: 'done'),
        request(state: 'failed'),
        request(
          id: 'other',
          state: 'done',
          at: t0.add(const Duration(seconds: 5)),
        ),
      ]) {
        expect(
          computerUpgradeInFlight(machine(upgrade: row), a, ms(t0)),
          isNull,
        );
      }
      // An older settled request says nothing about this one.
      expect(
        computerUpgradeInFlight(
          machine(
            upgrade: request(
              id: 'old',
              state: 'done',
              at: t0.subtract(const Duration(days: 1)),
            ),
          ),
          a,
          ms(t0),
        ),
        a.request,
      );
    });

    test('ends when the machine is online at the target version', () {
      expect(
        computerUpgradeInFlight(machine(version: '1.4.0'), accepted(), ms(t0)),
        isNull,
      );
      expect(
        computerUpgradeInFlight(machine(version: '1.3.0'), accepted(), ms(t0)),
        isNotNull,
      );
      // Offline at the target version is not evidence yet.
      expect(
        computerUpgradeInFlight(
          machine(status: 'offline', version: '1.4.0'),
          accepted(),
          ms(t0),
        ),
        isNotNull,
      );
    });

    test('the 30 minute server deadline ends the client copy', () {
      final a = accepted();
      expect(
        computerUpgradeInFlight(
          machine(),
          a,
          ms(t0.add(const Duration(minutes: 29, seconds: 59))),
        ),
        isNotNull,
      );
      expect(
        computerUpgradeInFlight(
          machine(),
          a,
          ms(t0.add(const Duration(minutes: 30))),
        ),
        isNull,
      );
    });
  });

  group('computerUpgradeReconnect', () {
    ComputerUpgradeReconnect at(
      Duration since, {
      Map<String, dynamic>? m,
      int? observed,
      AcceptedComputerUpgrade? accept,
    }) => computerUpgradeReconnect(
      m ??
          machine(
            status: 'offline',
            upgrade: request(),
            heartbeat: t0.add(const Duration(seconds: 20)),
          ),
      accepted: accept,
      offlineObservedAtMs: observed,
      nowMs: ms(t0.add(since)),
    );

    test('offline inside the 3 minute grace is the upgrade restart', () {
      final r = at(const Duration(minutes: 1));
      expect(r.reconnecting, isTrue);
      expect(r.overdue, isFalse);
      expect(r.targetVersion, '1.4.0');
      expect(
        r.graceEndsAtMs,
        ms(t0.add(const Duration(seconds: 20, minutes: 3))),
        reason: 'counted from the last heartbeat before the request settled in',
      );
    });

    test('offline past the grace is overdue, no longer reconnecting', () {
      final r = at(const Duration(minutes: 4));
      expect(r.reconnecting, isFalse);
      expect(r.overdue, isTrue);
      expect(r.inFlight, isNotNull);
      expect(r.graceEndsAtMs, isNull);
    });

    test('online is neither, even with a request in flight', () {
      final r = at(const Duration(seconds: 1), m: machine(upgrade: request()));
      expect(r.inFlight, isNotNull);
      expect(r.reconnecting, isFalse);
      expect(r.overdue, isFalse);
    });

    test('offline without an upgrade in flight is a plain outage', () {
      final r = at(
        const Duration(seconds: 1),
        m: machine(
          status: 'offline',
          upgrade: request(state: 'done'),
        ),
      );
      expect(r.inFlight, isNull);
      expect(r.reconnecting, isFalse);
      expect(r.overdue, isFalse);
    });

    test('a legacy machine never reads as restarting for an upgrade', () {
      final m = machine(status: 'offline', upgrade: request())
        ..['isComputer'] = false;
      expect(at(const Duration(seconds: 1), m: m).reconnecting, isFalse);
    });

    test('the live online to offline moment anchors the grace', () {
      final observed = ms(t0.add(const Duration(minutes: 2)));
      final r = at(
        const Duration(minutes: 4),
        observed: observed,
        m: machine(status: 'offline', upgrade: request()),
      );
      // 4 min after the request, but only 2 min after the disconnect.
      expect(r.reconnecting, isTrue);
      expect(
        r.graceEndsAtMs,
        observed + const Duration(minutes: 3).inMilliseconds,
      );
    });

    test('the anchor is never earlier than the request itself', () {
      final r = at(
        const Duration(seconds: 30),
        m: machine(
          status: 'offline',
          upgrade: request(),
          heartbeat: t0.subtract(const Duration(hours: 1)),
        ),
      );
      expect(r.graceEndsAtMs, ms(t0.add(const Duration(minutes: 3))));
    });

    test('an accepted click with no row keeps the restart visible', () {
      final r = at(
        const Duration(seconds: 30),
        m: machine(status: 'offline'),
        accept: accepted(),
        observed: ms(t0.add(const Duration(seconds: 10))),
      );
      expect(r.reconnecting, isTrue);
      expect(r.targetVersion, '1.4.0');
    });
  });
}
