// The `raftbench_overview_v0` rollout (Web useServerFeatureFlag + the page's
// confirmed flag): enabled, disabled, and the fail-closed undetermined state.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raftbench_flag_controller.dart';

import 'support/raftbench_fixture.dart';

Future<void> pump() => Future<void>.delayed(Duration.zero);

class _Flag {
  _Flag({this.cachedValue});
  final api = RaftbenchApi();
  bool? cachedValue;
  final remembered = <(bool, String)>[];
  String identity = 'g1|u1|s1|owner';
  String? server = 's1';
  late final controller = RaftbenchFlagController(
    request: api.request,
    identity: () => identity,
    serverId: () => server,
    cached: () => cachedValue,
    remember: (enabled, id) => remembered.add((enabled, id)),
    retryDelay: Duration.zero,
  );

  void answer(bool? enabled) =>
      api.routes['POST /feature-flags/evaluate'] = (_) {
        if (enabled == null) throw RaftApiException('down', status: 503);
        return {
          'evaluations': [
            {'key': 'raftbench_overview_v0', 'enabled': enabled},
            {'key': 'other_flag', 'enabled': true},
          ],
        };
      };
}

void main() {
  _retryTimerLifecycle();
  test(
    'evaluates the one key for this server and remembers the answer',
    () async {
      final f = _Flag()..answer(true);
      expect(f.controller.state, RaftbenchFlagState.loading);
      expect(f.controller.pageEnabled, isFalse);
      await f.controller.refresh();
      expect(f.controller.state, RaftbenchFlagState.enabled);
      expect(f.controller.navEnabled && f.controller.analysisAllowed, isTrue);
      expect(f.remembered, [(true, 'g1|u1|s1|owner')]);
      final body = f.api.calls.single.data! as Map;
      expect(body['keys'], ['raftbench_overview_v0']);
      expect(body['serverId'], 's1');
      f.controller.dispose();
    },
  );

  test('a remembered value makes the first frame final', () {
    expect(_Flag(cachedValue: true).controller.pageEnabled, isTrue);
    expect(_Flag(cachedValue: true).controller.navEnabled, isTrue);
    expect(
      _Flag(cachedValue: false).controller.state,
      RaftbenchFlagState.disabled,
    );
    expect(_Flag(cachedValue: false).controller.pageEnabled, isFalse);
  });

  test('disabled hides the page and the entry', () async {
    final f = _Flag(cachedValue: true)..answer(false);
    await f.controller.refresh();
    expect(f.controller.state, RaftbenchFlagState.disabled);
    expect(f.controller.pageEnabled, isFalse);
    expect(f.controller.navEnabled, isFalse);
    expect(f.remembered.single.$1, isFalse);
    f.controller.dispose();
  });

  test('a failed evaluation retries once, then fails closed', () async {
    final f = _Flag()..answer(null);
    await f.controller.refresh();
    expect(f.api.calls, hasLength(2));
    expect(f.controller.state, RaftbenchFlagState.undetermined);
    expect(f.controller.analysisAllowed, isFalse);
    expect(f.controller.navEnabled, isFalse);
    expect(f.controller.pageEnabled, isFalse, reason: 'never confirmed on');
    expect(
      f.remembered,
      isEmpty,
      reason: 'an unknown answer is not remembered',
    );
    f.controller.dispose();
  });

  test('a retry that succeeds is an ordinary answer', () async {
    final f = _Flag();
    var calls = 0;
    f.api.routes['POST /feature-flags/evaluate'] = (_) {
      if (calls++ == 0) throw RaftApiException('blip', status: 502);
      return {
        'evaluations': [
          {'key': 'raftbench_overview_v0', 'enabled': true},
        ],
      };
    };
    await f.controller.refresh();
    expect(f.controller.state, RaftbenchFlagState.enabled);
    f.controller.dispose();
  });

  test('an open, confirmed page survives an undetermined refresh with analysis paused', () async {
    final f = _Flag()..answer(true);
    await f.controller.refresh();
    f.answer(null);
    await f.controller.refresh();
    expect(f.controller.state, RaftbenchFlagState.undetermined);
    expect(f.controller.pageEnabled, isTrue);
    expect(f.controller.analysisAllowed, isFalse);
    expect(f.controller.navEnabled, isFalse);
    f.answer(false);
    await f.controller.refresh();
    expect(
      f.controller.pageEnabled,
      isFalse,
      reason: 'a confirmed off closes the page',
    );
    f.controller.dispose();
  });

  test(
    'focus refreshes are spaced one second apart; forced ones are not',
    () async {
      final f = _Flag()..answer(true);
      await f.controller.refresh(force: false);
      await f.controller.refresh(force: false);
      expect(f.api.calls, hasLength(1));
      await f.controller.refresh();
      expect(f.api.calls, hasLength(2));
      f.controller.dispose();
    },
  );

  test('a late answer for another identity changes nothing', () async {
    final f = _Flag();
    final gate = Completer<Object?>();
    f.api.routes['POST /feature-flags/evaluate'] = (_) => gate.future;
    final refresh = f.controller.refresh();
    await pump();
    f.identity = 'g2|u1|s2|owner';
    gate.complete({
      'evaluations': [
        {'key': 'raftbench_overview_v0', 'enabled': true},
      ],
    });
    await refresh;
    expect(f.controller.state, RaftbenchFlagState.loading);
    expect(f.remembered, isEmpty);
    await f.controller.refresh();
    expect(
      f.api.calls,
      hasLength(1),
      reason: 'one controller serves one identity',
    );
    f.controller.dispose();
  });

  test('no server, no evaluation', () async {
    final f = _Flag()..server = null;
    await f.controller.refresh();
    expect(f.api.calls, isEmpty);
    f.controller.dispose();
  });
}

// The retry wait is a timer owned by the controller: a page that goes away
// while it waits must not leave it pending (flutter_test fails the test).
void _retryTimerLifecycle() {
  testWidgets('no timer outlives a disposed controller', (t) async {
    final api = RaftbenchApi()
      ..routes['POST /feature-flags/evaluate'] = ((_) =>
          throw RaftApiException('down', status: 503));
    final flag = RaftbenchFlagController(
      request: api.request,
      identity: () => 'g|u|s|owner',
      serverId: () => 's1',
      cached: () => null,
      remember: (_, _) {},
    );
    unawaited(flag.refresh());
    await t.pump(const Duration(milliseconds: 10));
    expect(api.calls, hasLength(1), reason: 'waiting for the retry');
    flag.dispose();
  });
}
