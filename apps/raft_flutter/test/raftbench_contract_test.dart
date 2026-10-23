// RaftBench data contract (Web v1.21.23 shapes): the dashboard parser, the
// task and cost aggregates with their validation, the access rules and the
// legacy phrase rules.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raftbench_access.dart';
import 'package:raft_flutter/data/raftbench_metrics.dart';
import 'package:raft_flutter/data/raftbench_models.dart';
import 'package:raft_flutter/data/raftbench_rules.dart';

import 'support/raftbench_fixture.dart';

void main() {
  group('access', () {
    test('only an owner or an admin may use RaftBench', () {
      expect(canUseRaftBench('owner'), isTrue);
      expect(canUseRaftBench('admin'), isTrue);
      for (final role in ['member', 'guest', null, '']) {
        expect(canUseRaftBench(role), isFalse, reason: '$role');
      }
    });

    test('candidate channels follow isRaftBenchChannel', () {
      RaftChannel c(Map<String, Object?> json) =>
          RaftChannel({'id': 'x', 'name': 'x', ...json});
      expect(
        isRaftBenchChannel(c({'type': 'channel', 'joined': false})),
        isTrue,
      );
      expect(isRaftBenchChannel(c({'type': 'channel'})), isTrue);
      expect(isRaftBenchChannel(c({'type': 'joint', 'joined': false})), isTrue);
      expect(
        isRaftBenchChannel(c({'type': 'private', 'joined': true})),
        isTrue,
      );
      expect(
        isRaftBenchChannel(c({'type': 'private', 'joined': false})),
        isFalse,
      );
      // A membership row alone is not Web's `joined === true`.
      expect(
        isRaftBenchChannel(
          c({
            'type': 'private',
            'membership': {'role': 'member'},
          }),
        ),
        isFalse,
      );
      expect(isRaftBenchChannel(c({'type': 'dm', 'joined': true})), isFalse);
      expect(
        isRaftBenchChannel(
          c({'type': 'channel', 'archivedAt': '2026-10-01T00:00:00Z'}),
        ),
        isFalse,
      );
    });
  });

  group('dashboard', () {
    RaftbenchDashboard load(String name) =>
        RaftbenchDashboard.parse(raftbenchFixture(name));

    test('disabled: nothing configured', () {
      final d = load('dashboard-disabled');
      expect(d.enabled, isFalse);
      expect(d.revision, 0);
      expect(d.agentId, isNull);
      expect(d.provisioning, isNull);
      expect(d.run, isNull);
      expect(d.coverage, isNull);
      expect(d.historyFrom, isNull);
    });

    test('ready: findings carry evidence and counterevidence', () {
      final d = load('dashboard-ready');
      expect(d.enabled, isTrue);
      expect(d.provisioning!.state, 'active');
      expect(d.run!.status, 'ready');
      expect(d.run!.exhausted, isTrue);
      expect(d.progress!.completedBatches, 4);
      expect(d.coverage!.windowMessages, 189);
      expect(d.pagination.pageCount, 2);
      final first = d.run!.report!.patterns.first;
      expect(first.kind, 'unsupported_completion');
      expect(first.evidence.map((e) => e.messageId.length), [8, 36]);
      expect(first.counterevidence.single.target, '#random');
      expect(first.suggestion, startsWith('Ask the agent'));
      expect(d.run!.report!.patterns.last.evidenceLevel, 'insufficient');
      expect(d.run!.report!.patterns.last.intent, 'unknown');
    });

    test('skipped windows keep an unknown message count as null', () {
      final ranges = load('dashboard-skipped-window').run!.skippedRanges;
      expect(ranges.map((r) => r.messages), [44, null]);
    });

    test('stale run has no report; failed run carries the reason', () {
      expect(load('dashboard-stale').run!.status, 'stale');
      expect(load('dashboard-stale').run!.report, isNull);
      expect(
        load('dashboard-failed').run!.failureReason,
        contains('30 minutes'),
      );
      expect(load('dashboard-provision-failed').provisioning!.state, 'failed');
    });

    test('unknown fields and statuses are tolerated, not fatal', () {
      final json = raftbenchMap('dashboard-ready');
      json['somethingNew'] = {'a': 1};
      (json['run']! as Map)['status'] = 'cancelled';
      final d = RaftbenchDashboard.parse(json);
      expect(d.run!.status, 'cancelled');
    });

    test('a body that is not an object is rejected', () {
      expect(() => RaftbenchDashboard.parse([]), throwsFormatException);
      expect(() => RaftbenchDashboard.parse(null), throwsFormatException);
    });

    test('service agents list', () {
      final agents = RaftbenchServiceAgent.parseList(
        raftbenchFixture('service-agents'),
      );
      expect(agents.map((a) => (a.name, a.ready)), [
        ('raftbench-service', true),
        ('raftbench-service-a1b2c3', false),
      ]);
      expect(RaftbenchServiceAgent.parseList(null), isEmpty);
    });
  });

  group('metrics', () {
    final window = RaftbenchWindow.at(raftbenchNow);

    test('comparison window is the latest complete UTC days', () {
      expect(RaftbenchWindow.iso(window.end), '2026-10-24T00:00:00.000Z');
      expect(RaftbenchWindow.iso(window.start), '2026-10-17T00:00:00.000Z');
      expect(
        RaftbenchWindow.iso(window.previousStart),
        '2026-10-10T00:00:00.000Z',
      );
      // The window follows the UTC day, not the local one.
      final late = DateTime.parse('2026-10-24T23:59:59-08:00');
      expect(
        RaftbenchWindow.iso(RaftbenchWindow.at(late).end),
        '2026-10-25T00:00:00.000Z',
      );
      expect(
        () => RaftbenchWindow.at(raftbenchNow, days: 0),
        throwsFormatException,
      );
      expect(
        () => RaftbenchWindow.at(raftbenchNow, days: 91),
        throwsFormatException,
      );
    });

    test('task snapshot parses and checks its totals', () {
      final s = RaftbenchTaskSnapshot.parse(
        raftbenchFixture('snapshot-metrics'),
      );
      expect(
        (s.total, s.inReview, s.p90Hours, s.medianHours),
        (10, 1, 26.25, 5.5),
      );
      final bad = raftbenchMap('snapshot-metrics')..['total'] = 11;
      expect(() => RaftbenchTaskSnapshot.parse(bad), throwsFormatException);
      final mixed = raftbenchMap('snapshot-metrics')..['agentCreated'] = 3;
      expect(() => RaftbenchTaskSnapshot.parse(mixed), throwsFormatException);
      final negative = raftbenchMap('snapshot-metrics')..['todo'] = -1;
      expect(
        () => RaftbenchTaskSnapshot.parse(negative),
        throwsFormatException,
      );
      final date = raftbenchMap('snapshot-metrics')
        ..['firstCreatedAt'] = 'soon';
      expect(() => RaftbenchTaskSnapshot.parse(date), throwsFormatException);
      final empty = raftbenchMap('snapshot-metrics')
        ..addAll({
          'total': 0,
          'todo': 0,
          'inProgress': 0,
          'inReview': 0,
          'done': 0,
          'closed': 0,
          'humanCreated': 0,
          'agentCreated': 0,
          'durationSamples': 0,
          'medianHours': null,
          'p90Hours': null,
          'firstCreatedAt': null,
          'latestCreatedAt': null,
          'latestUpdatedAt': null,
        });
      expect(RaftbenchTaskSnapshot.parse(empty).firstCreatedAt, isNull);
    });

    test('period metrics must answer the requested window', () {
      final p = RaftbenchTaskPeriods.parse(
        raftbenchFixture('period-metrics'),
        window,
      );
      expect(
        (p.current.completed, p.previous.completed, p.surfaces),
        (4, 1, 3),
      );
      expect(p.current.meanHours, 8.25);
      final shifted = raftbenchMap('period-metrics')
        ..['midpoint'] = '2026-10-18T00:00:00.000Z';
      expect(
        () => RaftbenchTaskPeriods.parse(shifted, window),
        throwsFormatException,
      );
      final samples = raftbenchMap('period-metrics');
      (samples['current']! as Map)['durationSamples'] = 9;
      expect(
        () => RaftbenchTaskPeriods.parse(samples, window),
        throwsFormatException,
      );
      final noSamples = raftbenchMap('period-metrics');
      (noSamples['previous']! as Map)
        ..['durationSamples'] = 0
        ..['completed'] = 0;
      expect(
        () => RaftbenchTaskPeriods.parse(noSamples, window),
        throwsFormatException,
      );
    });

    test('a period without duration samples has no mean or median', () {
      final json = raftbenchMap('period-metrics');
      (json['previous']! as Map)
        ..['completed'] = 2
        ..['durationSamples'] = 0
        ..['meanHours'] = null
        ..['medianHours'] = null;
      final p = RaftbenchTaskPeriods.parse(json, window);
      expect(p.previous.meanHours, isNull);
      expect(p.previous.completed, 2);
    });

    test('cost folds the day buckets into the two windows', () {
      final c = RaftbenchCostComparison.parse(
        raftbenchFixture('hosted-runtime-usage'),
        window,
      );
      expect(c.currentUsd, closeTo(0.125 + 1.5 + 0.0049, 1e-9));
      expect(c.previousUsd, closeTo(0.75, 1e-9));
      expect(c.estimated, isTrue);
      expect(c.unpriced, isFalse);
    });

    test('unpriced usage inside the windows is flagged; outside is not', () {
      final json = raftbenchMap('hosted-runtime-usage');
      (json['periods']! as List).add({
        'start': '2026-10-24T00:00:00.000Z',
        'totalUsd': 3,
        'unpriced': ['model-x'],
      });
      expect(RaftbenchCostComparison.parse(json, window).unpriced, isFalse);
      (json['periods']! as List).add({
        'start': '2026-10-21T00:00:00.000Z',
        'totalUsd': 0,
        'unpriced': ['model-x'],
      });
      expect(RaftbenchCostComparison.parse(json, window).unpriced, isTrue);
    });

    test('spend responses that do not cover the window are refused', () {
      RaftbenchCostComparison parse(void Function(Map<String, Object?>) edit) {
        final json = raftbenchMap('hosted-runtime-usage');
        edit(json);
        return RaftbenchCostComparison.parse(json, window);
      }

      expect(() => parse((j) => j['currency'] = 'EUR'), throwsFormatException);
      expect(() => parse((j) => j['bucket'] = 'hour'), throwsFormatException);
      expect(() => parse((j) => j['estimated'] = 'yes'), throwsFormatException);
      expect(
        () => parse((j) => j['from'] = '2026-10-11T00:00:00.000Z'),
        throwsFormatException,
      );
      expect(
        () => parse((j) => j['to'] = '2026-10-23T00:00:00.000Z'),
        throwsFormatException,
      );
      expect(
        () => parse(
          (j) => (j['periods']! as List).add({
            'start': '2026-10-12T00:00:00.000Z',
            'totalUsd': 1,
            'unpriced': [],
          }),
        ),
        throwsFormatException,
        reason: 'a duplicate day',
      );
      expect(
        () => parse(
          (j) => (j['periods']! as List).add({
            'start': '2026-10-13T06:00:00.000Z',
            'totalUsd': 1,
            'unpriced': [],
          }),
        ),
        throwsFormatException,
        reason: 'not a UTC day start',
      );
      expect(
        () => parse(
          (j) => (j['periods']! as List).add({
            'start': '2026-10-13T00:00:00.000Z',
            'totalUsd': 'free',
            'unpriced': [],
          }),
        ),
        throwsFormatException,
      );
    });
  });

  group('legacy phrase rules', () {
    var n = 0;
    RaftbenchEvidenceMessage m(
      String content, {
      String type = 'user',
      String sender = 'u1',
      String channel = 'c1',
      int minute = 0,
      String? kind,
    }) {
      n++;
      return RaftbenchEvidenceMessage(
        id: 'm${n.toString().padLeft(3, '0')}',
        channelId: channel,
        senderType: type,
        senderId: sender,
        content: content,
        createdAt: DateTime.utc(2026, 10, 23, 9, minute).toIso8601String(),
        messageType: kind,
      );
    }

    test('English and Chinese frustration, negative wording and sentiment', () {
      final e = evaluateRaftbenchMessages([
        m("I'm so frustrated with this", minute: 1),
        m('这个还是不行', minute: 2),
        m('terrible output', minute: 3),
        m('thanks, that works perfectly', minute: 4),
        m('thanks but this is not working', minute: 5),
        m('ok', minute: 6),
        m('wasted my time', minute: 7, kind: 'system'),
      ]);
      expect(e.findings.map((f) => f.kind.name).toSet(), {
        'frustration',
        'negative',
      });
      expect(
        e.findings.where((f) => f.kind == RaftbenchSignal.frustration),
        hasLength(2),
      );
      // A mixed message still raises its negative cue.
      expect(
        e.findings.where((f) => f.kind == RaftbenchSignal.negative),
        hasLength(2),
      );
      final s = e.sentiment;
      expect((s.positive, s.negative, s.mixed, s.unscored), (1, 3, 1, 1));
      expect(e.messages, hasLength(7));
      // Newest evidence first.
      expect(
        e.findings.first.evidence.last.createdAt.compareTo(
              e.findings.last.evidence.last.createdAt,
            ) >=
            0,
        isTrue,
      );
    });

    test('a system message never counts', () {
      final e = evaluateRaftbenchMessages([
        m('wasted my time', kind: 'system'),
      ]);
      expect(e.findings, isEmpty);
      expect(e.sentiment.unscored, 0);
    });

    test(
      'identical agent messages within 15 minutes repeat at the threshold',
      () {
        const text = 'Deploy finished, all checks green  and healthy';
        final e = evaluateRaftbenchMessages([
          m(text, type: 'agent', sender: 'a1', minute: 0),
          m(text.toUpperCase(), type: 'agent', sender: 'a1', minute: 5),
          m(text, type: 'agent', sender: 'a1', minute: 10),
          m(text, type: 'agent', sender: 'a2', minute: 11),
          m('short', type: 'agent', sender: 'a1', minute: 12),
        ]);
        final repeats = e.findings.where(
          (f) => f.kind == RaftbenchSignal.repetition,
        );
        expect(repeats, hasLength(1));
        expect(repeats.single.evidence, hasLength(3));
        expect(
          evaluateRaftbenchMessages([
            m(text, type: 'agent', sender: 'a1', minute: 0),
            m(text, type: 'agent', sender: 'a1', minute: 10),
          ]).findings,
          isEmpty,
        );
        expect(
          evaluateRaftbenchMessages([
            m(text, type: 'agent', sender: 'a1', minute: 0),
            m(text, type: 'agent', sender: 'a1', minute: 10),
          ], minimum: 2).findings,
          hasLength(1),
        );
      },
    );

    test('a repeat past 15 minutes starts a new group', () {
      const text = 'Still waiting on the build to finish here';
      final e = evaluateRaftbenchMessages([
        m(text, type: 'agent', sender: 'a1', minute: 0),
        m(text, type: 'agent', sender: 'a1', minute: 1),
        m(text, type: 'agent', sender: 'a1', minute: 2),
        m(text, type: 'agent', sender: 'a1', minute: 30),
      ]);
      expect(e.findings, hasLength(1));
      expect(e.findings.single.evidence, hasLength(3));
    });

    test('the same input always yields the same ids', () {
      final input = [
        m('stop asking', minute: 1),
        m('already told you', minute: 2),
      ];
      final a = evaluateRaftbenchMessages(input).findings
          .map((f) => f.id)
          .toList();
      final b = evaluateRaftbenchMessages(input.reversed).findings
          .map((f) => f.id)
          .toList();
      expect(a, b);
      expect(a.first, startsWith('raftbench-rules-0.1.0:frustration:'));
    });

    test('the repeat threshold is bounded to 2..20', () {
      expect(
        () => evaluateRaftbenchMessages([], minimum: 1),
        throwsArgumentError,
      );
      expect(
        () => evaluateRaftbenchMessages([], minimum: 21),
        throwsArgumentError,
      );
    });
  });
}
