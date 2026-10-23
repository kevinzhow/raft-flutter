// The conversation-insights controller (Web HostedAnalysis.tsx): load,
// settings writes with revisions, fencing and the generic failure state.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raftbench_hosted_controller.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/raftbench_fixture.dart';

const _c1 = '5d0b8c1e-2a63-4b27-9c1f-0a1b2c3d4e01';
const _c2 = '5d0b8c1e-2a63-4b27-9c1f-0a1b2c3d4e02';
const _agent = '7a1e3c40-9d2b-4f56-8e0a-1b2c3d4e5f60';

class _Harness {
  _Harness({String dashboard = 'dashboard-disabled', this.allowed = true}) {
    api.routes['GET /raftbench'] = (_) => raftbenchFixture(dashboard);
    api.routes['GET /raftbench/agents'] = (_) =>
        raftbenchFixture('service-agents');
    api.routes['GET /agents/$_agent/hosted-runtime/model'] = (_) => {
      'label': 'DeepSeek Flash',
    };
    controller =
        RaftbenchHostedController(
          request: api.request,
          identity: () => identity,
          roleAllowed: () => role == 'owner' || role == 'admin',
          analysisAllowed: () => allowed,
          onEnabled: enabled.add,
          now: () => raftbenchNow,
          poll: false,
        )..setOptions(const [
          RaftbenchOption(_c1, 'general'),
          RaftbenchOption(_c2, 'random'),
        ]);
  }
  final api = RaftbenchApi();
  late final RaftbenchHostedController controller;
  final enabled = <bool>[];
  String identity = 'g1|u1|s1|owner';
  String role = 'owner';
  bool allowed;

  Future<void> loaded() async {
    controller.start();
    await pump();
  }
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'first load: dashboard, service agents, enabled state reported',
    () async {
      final h = _Harness(dashboard: 'dashboard-ready');
      await h.loaded();
      expect(h.controller.loading, isFalse);
      expect(h.controller.failed, isFalse);
      expect(h.controller.data!.run!.status, 'ready');
      expect(
        h.controller.serviceAgents.map((a) => a.name),
        contains('raftbench-service'),
      );
      expect(h.enabled, [true]);
      expect(h.api.where('GET /raftbench').single.query, {'page': 1});
      // The analysis agent is active: its model is read for the footer line.
      expect(h.controller.modelAgentId, _agent);
      expect(h.controller.modelLabel, 'DeepSeek Flash');
      h.controller.dispose();
    },
  );

  test(
    'a disabled analysis selects the first visible channels and a 7 day start',
    () async {
      final h = _Harness();
      await h.loaded();
      expect(h.controller.selected, [_c1, _c2]);
      expect(h.controller.dateValue, '2026-10-17');
      expect(h.controller.changed, isFalse);
      expect(h.controller.invalidHistory, isFalse);
      expect(h.enabled, [false]);
      expect(h.api.where('GET /agents/$_agent/hosted-runtime/model'), isEmpty);
      h.controller.dispose();
    },
  );

  test(
    'enable sends the chosen sources, the UTC start and the revision',
    () async {
      final h = _Harness();
      h.api.routes['PUT /raftbench'] = (_) => {'saved': true};
      await h.loaded();
      h.controller.toggleChannel(_c2);
      h.controller.chooseHistoryDays(30);
      expect(h.controller.dateValue, '2026-09-24');
      h.api.routes['GET /raftbench'] = (_) =>
          raftbenchFixture('dashboard-queued');
      await h.controller.toggleAnalysis();
      final put = h.api.where('PUT /raftbench').single;
      expect(put.data, {
        'enabled': true,
        'channelIds': [_c1],
        'expectedRevision': 0,
        'historyFrom': '2026-09-24T00:00:00.000Z',
      });
      // Saved settings clear the draft and the dashboard is read again.
      expect(h.controller.changed, isFalse);
      expect(h.controller.saving, isFalse);
      expect(h.controller.data!.run!.status, 'queued');
      expect(h.enabled, containsAllInOrder([false, true]));
      h.controller.dispose();
    },
  );

  test(
    'disable sends enabled false without a start date and clears the run',
    () async {
      final h = _Harness(dashboard: 'dashboard-ready');
      h.api.routes['PUT /raftbench'] = (_) => {'saved': true};
      await h.loaded();
      h.api.routes['GET /raftbench'] = (_) =>
          raftbenchFixture('dashboard-configured-disabled');
      h.controller.chooseHistoryDays(7);
      await h.controller.toggleAnalysis();
      expect(h.api.where('PUT /raftbench').single.data, {
        'enabled': false,
        'channelIds': [_c1, _c2],
        'expectedRevision': 3,
      });
      expect(h.controller.data!.enabled, isFalse);
      expect(h.controller.data!.run, isNull);
      expect(h.enabled.last, isFalse);
      h.controller.dispose();
    },
  );

  test('applying edited settings restarts with the new range', () async {
    final h = _Harness(dashboard: 'dashboard-ready');
    h.api.routes['PUT /raftbench'] = (_) => {'saved': true};
    await h.loaded();
    h.controller.setHistoryDate('2026-10-01');
    expect(h.controller.changed, isTrue);
    await h.controller.applySettings();
    expect(h.api.where('PUT /raftbench').single.data, {
      'enabled': true,
      'channelIds': [_c1, _c2],
      'expectedRevision': 3,
      'historyFrom': '2026-10-01T00:00:00.000Z',
    });
    h.controller.dispose();
  });

  test('outside-window shortcut restarts from the newest source day', () async {
    final h = _Harness(dashboard: 'dashboard-outside-window');
    h.api.routes['PUT /raftbench'] = (_) => {'saved': true};
    await h.loaded();
    expect(h.controller.emptyRange, isTrue);
    expect(h.controller.emptyScan, isTrue);
    expect(h.controller.availableHistory, '2026-10-23');
    await h.controller.analyzeAvailableHistory();
    expect(
      (h.api.where('PUT /raftbench').single.data! as Map)['historyFrom'],
      '2026-10-23T00:00:00.000Z',
    );
    h.controller.dispose();
  });

  test('a start date in the future or empty blocks saving state', () async {
    final h = _Harness();
    await h.loaded();
    h.controller.setHistoryDate('2026-10-25');
    expect(h.controller.invalidHistory, isTrue);
    h.controller.setHistoryDate('');
    expect(h.controller.invalidHistory, isTrue);
    h.controller.setHistoryDate('2026-10-24');
    expect(
      h.controller.invalidHistory,
      isFalse,
      reason: 'today 00:00 UTC is before now',
    );
    h.controller.setHistoryDate('2026-10-23');
    expect(h.controller.invalidHistory, isFalse);
    h.controller.dispose();
  });

  test('at most 50 sources can be selected', () async {
    final h = _Harness();
    h.controller.setOptions([
      for (var i = 0; i < 60; i++) RaftbenchOption('c$i', 'ch$i'),
    ]);
    await h.loaded();
    expect(h.controller.selected, hasLength(50));
    h.controller.toggleChannel('c55');
    expect(h.controller.selected, hasLength(50));
    expect(h.controller.selected, isNot(contains('c55')));
    h.controller.toggleChannel('c0');
    h.controller.toggleChannel('c55');
    expect(h.controller.selected, contains('c55'));
    expect(h.controller.selected, isNot(contains('c0')));
    h.controller.dispose();
  });

  test('a failed save is one generic failure and keeps the draft', () async {
    final h = _Harness();
    h.api.routes['PUT /raftbench'] = (_) =>
        throw RaftApiException('raftbench_revision_conflict', status: 409);
    await h.loaded();
    h.controller.chooseHistoryDays(7);
    await h.controller.toggleAnalysis();
    expect(h.controller.failed, isTrue);
    expect(h.controller.saving, isFalse);
    expect(h.controller.changed, isTrue);
    expect(h.controller.data!.enabled, isFalse);
    h.controller.dispose();
  });

  test(
    'a server that is not allowed fails the load and reports disabled',
    () async {
      final h = _Harness();
      h.api.routes['GET /raftbench'] = (_) =>
          throw RaftApiException('RaftBench is unavailable', status: 403);
      await h.loaded();
      expect(h.controller.failed, isTrue);
      expect(h.controller.loading, isFalse);
      expect(h.controller.data, isNull);
      expect(h.enabled, [false]);
      expect(h.api.where('GET /raftbench/agents'), isEmpty);
      h.controller.dispose();
    },
  );

  test('service agents failing leaves the dashboard readable', () async {
    final h = _Harness(dashboard: 'dashboard-ready');
    h.api.routes['GET /raftbench/agents'] = (_) =>
        throw RaftApiException('x', status: 500);
    await h.loaded();
    expect(h.controller.failed, isFalse);
    expect(h.controller.serviceAgents, isEmpty);
    expect(h.controller.data, isNotNull);
    h.controller.dispose();
  });

  test('create service agent posts, then reads the dashboard again', () async {
    final h = _Harness();
    h.api.routes['POST /raftbench/agents'] = (_) => {'agentId': 'new'};
    await h.loaded();
    await h.controller.createServiceAgent();
    await pump();
    expect(
      h.api.where('POST /raftbench/agents').single.data,
      <String, Object?>{},
    );
    expect(h.api.where('GET /raftbench'), hasLength(2));
    expect(h.controller.saving, isFalse);
    h.controller.dispose();
  });

  test(
    'first assignment carries sources and start; later ones only the agent',
    () async {
      final h = _Harness();
      h.api.routes['PUT /raftbench/assignment'] = (_) => {'saved': true};
      await h.loaded();
      h.controller.chooseHistoryDays(7);
      await h.controller.assignAgent(_agent);
      expect(h.api.where('PUT /raftbench/assignment').single.data, {
        'agentId': _agent,
        'expectedRevision': 0,
        'channelIds': [_c1, _c2],
        'historyFrom': '2026-10-17T00:00:00.000Z',
      });
      expect(h.enabled.last, isTrue);
      h.controller.dispose();

      final later = _Harness(dashboard: 'dashboard-ready');
      later.api.routes['PUT /raftbench/assignment'] = (_) => {'saved': true};
      await later.loaded();
      await later.controller.assignAgent(_agent);
      expect(later.api.where('PUT /raftbench/assignment').single.data, {
        'agentId': _agent,
        'expectedRevision': 3,
      });
      later.controller.dispose();
    },
  );

  test('assignment waits while edited settings are not applied', () async {
    final h = _Harness(dashboard: 'dashboard-ready');
    h.api.routes['PUT /raftbench/assignment'] = (_) => {'saved': true};
    await h.loaded();
    h.controller.toggleChannel(_c2);
    expect(h.controller.assignmentBlocked, isTrue);
    await h.controller.assignAgent(_agent);
    expect(h.api.where('PUT /raftbench/assignment'), isEmpty);
    h.controller.dispose();
  });

  test('a response after the identity changed is dropped', () async {
    final h = _Harness();
    final gate = Completer<Object?>();
    h.api.routes['GET /raftbench'] = (_) => gate.future;
    h.controller.start();
    await pump();
    h.identity = 'g2|u1|s2|owner';
    gate.complete(raftbenchFixture('dashboard-ready'));
    await pump();
    expect(h.controller.data, isNull);
    expect(h.controller.loading, isTrue);
    expect(h.enabled, isEmpty);
    h.controller.dispose();
  });

  test('a response after the role lost admin is dropped', () async {
    final h = _Harness();
    final gate = Completer<Object?>();
    h.api.routes['GET /raftbench'] = (_) => gate.future;
    h.controller.start();
    await pump();
    h.role = 'member';
    gate.complete(raftbenchFixture('dashboard-ready'));
    await pump();
    expect(h.controller.data, isNull);
    h.controller.dispose();
  });

  test('analysis not allowed hides data and blocks reads', () async {
    final h = _Harness(dashboard: 'dashboard-ready', allowed: false);
    await h.loaded();
    expect(h.controller.data, isNull);
    expect(h.api.where('GET /raftbench'), isEmpty);
    h.controller.dispose();
  });

  test(
    'a load never overlaps a running write, and a late read is discarded',
    () async {
      final h = _Harness(dashboard: 'dashboard-ready');
      final gate = Completer<Object?>();
      h.api.routes['PUT /raftbench'] = (_) => gate.future;
      await h.loaded();
      final reads = h.api.where('GET /raftbench').length;
      final save = h.controller.save(true);
      await pump();
      expect(h.controller.saving, isTrue);
      await h.controller.load();
      expect(h.api.where('GET /raftbench').length, reads);
      gate.complete({'saved': true});
      await save;
      expect(h.controller.saving, isFalse);
      h.controller.dispose();
    },
  );

  test('paging re-reads the requested page', () async {
    final h = _Harness(dashboard: 'dashboard-ready');
    await h.loaded();
    h.controller.setPage(2);
    await pump();
    await pump();
    expect(h.api.where('GET /raftbench').last.query, {'page': 2});
    h.controller.setPage(0);
    await pump();
    expect(h.controller.page, 1);
    h.controller.dispose();
  });

  test('derived states: busy, no material, skipped windows', () async {
    for (final (name, busy, noMaterial) in [
      ('dashboard-queued', true, false),
      ('dashboard-running', true, false),
      ('dashboard-ready', false, false),
      ('dashboard-no-material', false, true),
      ('dashboard-provision-failed', false, false),
      ('dashboard-failed', false, false),
    ]) {
      final h = _Harness(dashboard: name);
      await h.loaded();
      expect(h.controller.busy, busy, reason: name);
      expect(h.controller.noMaterial, noMaterial, reason: name);
      h.controller.dispose();
    }
  });

  test('disposed controller ignores late answers', () async {
    final h = _Harness();
    final gate = Completer<Object?>();
    h.api.routes['GET /raftbench'] = (_) => gate.future;
    h.controller.start();
    await pump();
    h.controller.dispose();
    gate.complete(raftbenchFixture('dashboard-ready'));
    await pump();
    expect(h.enabled, isEmpty);
  });
}
