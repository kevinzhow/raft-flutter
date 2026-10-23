// "Tasks and cost" (Web ManagerOverview.tsx): three independent reads of
// existing aggregates, each failing on its own, never inferring a total.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raftbench_overview_controller.dart';

import 'support/raftbench_fixture.dart';

Future<void> pump() => Future<void>.delayed(Duration.zero);

RaftbenchApi _api() => RaftbenchApi()
  ..routes['GET /tasks/server/snapshot-metrics'] = ((_) =>
      raftbenchFixture('snapshot-metrics'))
  ..routes['GET /tasks/server/period-metrics'] = ((_) =>
      raftbenchFixture('period-metrics'))
  ..routes['GET /billing/hosted-runtime-usage'] = ((_) =>
      raftbenchFixture('hosted-runtime-usage'));

RaftbenchOverviewController _controller(
  RaftbenchApi api, {
  String? channel,
  String Function()? identity,
  bool Function()? role,
}) => RaftbenchOverviewController(
  request: api.request,
  identity: identity ?? () => 'g1|u1|s1|owner',
  roleAllowed: role ?? () => true,
  channelId: channel,
  now: () => raftbenchNow,
);

void main() {
  test(
    'workspace scope reads all three aggregates with the UTC window',
    () async {
      final api = _api();
      final c = _controller(api);
      expect(c.snapshot.kind, RaftbenchLoadKind.idle);
      final load = c.load();
      expect(c.anyLoading, isTrue);
      await load;
      expect(c.anyLoading, isFalse);
      expect(c.snapshot.value!.total, 10);
      expect(c.tasks.value!.current.completed, 4);
      expect(c.costs.value!.currentUsd, greaterThan(1.6));
      expect(
        api.where('GET /tasks/server/snapshot-metrics').single.query,
        isEmpty,
      );
      expect(api.where('GET /tasks/server/period-metrics').single.query, {
        'from': '2026-10-10T00:00:00.000Z',
        'midpoint': '2026-10-17T00:00:00.000Z',
        'to': '2026-10-24T00:00:00.000Z',
      });
      expect(api.where('GET /billing/hosted-runtime-usage').single.query, {
        'from': '2026-10-10T00:00:00.000Z',
        'to': '2026-10-24T00:00:00.000Z',
        'bucket': 'day',
      });
      c.dispose();
    },
  );

  test(
    'a channel scope narrows the task reads, never the server-wide cost',
    () async {
      final api = _api();
      final c = _controller(api, channel: 'chan-1');
      await c.load();
      expect(api.where('GET /tasks/server/snapshot-metrics').single.query, {
        'channelId': 'chan-1',
      });
      expect(
        api
            .where('GET /tasks/server/period-metrics')
            .single
            .query!['channelId'],
        'chan-1',
      );
      expect(
        api
            .where('GET /billing/hosted-runtime-usage')
            .single
            .query!
            .containsKey('channelId'),
        isFalse,
      );
      c.dispose();
    },
  );

  test(
    'each aggregate fails alone; a malformed answer is an error, not a total',
    () async {
      final api = _api()
        ..routes['GET /tasks/server/snapshot-metrics'] = ((_) => {
          ...raftbenchMap('snapshot-metrics'),
          'total': 99,
        })
        ..routes['GET /tasks/server/period-metrics'] = ((_) =>
            throw RaftApiException('boom', status: 500));
      final c = _controller(api);
      await c.load();
      expect(c.snapshot.kind, RaftbenchLoadKind.error);
      expect(c.tasks.kind, RaftbenchLoadKind.error);
      expect(c.costs.kind, RaftbenchLoadKind.ready);
      c.dispose();
    },
  );

  test(
    'billing 404 means unavailable (not zero cost); other failures are errors',
    () async {
      final api = _api()
        ..routes['GET /billing/hosted-runtime-usage'] = ((_) =>
            throw RaftApiException('Not found', status: 404));
      final c = _controller(api);
      await c.load();
      expect(c.costs.kind, RaftbenchLoadKind.unavailable);
      api.routes['GET /billing/hosted-runtime-usage'] = ((_) =>
          throw RaftApiException('Forbidden', status: 403));
      await c.load();
      expect(c.costs.kind, RaftbenchLoadKind.error);
      c.dispose();
    },
  );

  test('a spend answer for another window is an error', () async {
    final api = _api()
      ..routes['GET /billing/hosted-runtime-usage'] = ((_) => {
        ...raftbenchMap('hosted-runtime-usage'),
        'to': '2026-10-23T00:00:00.000Z',
      });
    final c = _controller(api);
    await c.load();
    expect(c.costs.kind, RaftbenchLoadKind.error);
    c.dispose();
  });

  test('refreshing replaces the data and a stale answer is dropped', () async {
    final api = _api();
    final c = _controller(api);
    final gate = Completer<Object?>();
    api.routes['GET /tasks/server/snapshot-metrics'] = (_) => gate.future;
    final first = c.load();
    await pump();
    api.routes['GET /tasks/server/snapshot-metrics'] = ((_) => {
      ...raftbenchMap('snapshot-metrics'),
      'todo': 3,
      'inProgress': 2,
      'total': 10,
    });
    await c.load();
    expect(c.snapshot.value!.todo, 3);
    gate.complete(raftbenchFixture('snapshot-metrics'));
    await first;
    expect(
      c.snapshot.value!.todo,
      3,
      reason: 'the older read must not overwrite',
    );
    c.dispose();
  });

  test(
    'identity or role changes drop pending answers; no read without the role',
    () async {
      var identity = 'g1|u1|s1|owner';
      var role = true;
      final api = _api();
      final gate = Completer<Object?>();
      for (final route in [
        'GET /tasks/server/snapshot-metrics',
        'GET /tasks/server/period-metrics',
        'GET /billing/hosted-runtime-usage',
      ]) {
        api.routes[route] = (_) => gate.future;
      }
      final c = _controller(api, identity: () => identity, role: () => role);
      final load = c.load();
      await pump();
      identity = 'g1|u1|s2|owner';
      gate.complete(raftbenchFixture('snapshot-metrics'));
      await load;
      expect(c.snapshot.kind, RaftbenchLoadKind.loading);
      expect(c.tasks.kind, RaftbenchLoadKind.loading);
      expect(c.costs.kind, RaftbenchLoadKind.loading);
      final reads = api.calls.length;
      await c.load();
      expect(
        api.calls.length,
        reads,
        reason: 'a controller serves one identity',
      );
      c.dispose();

      final denied = _controller(_api(), role: () => false);
      await denied.load();
      expect(denied.snapshot.kind, RaftbenchLoadKind.idle);
      denied.dispose();
    },
  );
}
