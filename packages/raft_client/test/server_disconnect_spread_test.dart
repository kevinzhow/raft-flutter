import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

RaftClient _client({int seed = 1, List<Duration>? backoff}) => RaftClient(
  origin: 'https://example.invalid',
  sessionStore: MemorySessionStore(),
  transport: Dio(),
  governor: RateLimitGovernor(random: math.Random(seed)),
  recoveryBackoff: backoff ?? RaftClient.defaultRecoveryBackoff,
);

void main() {
  group('server-initiated socket disconnect (Web scheduleServerDisconnectReconnect)', () {
    test('[BP-RT-063] the reconnect is spread over 1-5 s so a deploy is not a stampede', () async {
      final delays = <Duration>{};
      for (var seed = 0; seed < 200; seed++) {
        final client = _client(seed: seed);
        final delay = client.serverDisconnectReconnectDelay();
        expect(delay, greaterThanOrEqualTo(const Duration(seconds: 1)));
        expect(delay, lessThan(const Duration(seconds: 5)));
        delays.add(delay);
        await client.dispose();
      }
      expect(
        delays.length,
        greaterThan(100),
        reason: 'clients must not reconnect together',
      );
    });

    test('[BP-RT-063] the spread scales with an injected backoff and stays zero when it is zero', () async {
      final fast = _client(backoff: const [Duration.zero]);
      expect(fast.serverDisconnectReconnectDelay(), Duration.zero);
      await fast.dispose();
      final off = _client(backoff: const []);
      expect(
        off.serverDisconnectReconnectDelay(),
        greaterThanOrEqualTo(const Duration(seconds: 1)),
      );
      await off.dispose();
    });
  });
}
