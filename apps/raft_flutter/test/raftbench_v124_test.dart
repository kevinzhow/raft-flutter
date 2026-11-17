// RaftBench as of Web v1.24.0: finding votes, the kind index and the grouped
// view, per-stream progress, triage, agent access, the `backlog` status, and
// the scope the analysis is keyed by.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raftbench_hosted_controller.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/raftbench_fixture.dart';
import 'support/raftbench_host.dart';

const _c1 = '5d0b8c1e-2a63-4b27-9c1f-0a1b2c3d4e01';
const _c2 = '5d0b8c1e-2a63-4b27-9c1f-0a1b2c3d4e02';

Map<String, Object?> _pattern(String kind, String text) => {
  'kind': kind,
  'explanation': text,
  'evidence': [
    {'target': '#general', 'messageId': '3f9c1a77'},
    {'target': '#general:ab12cd34', 'messageId': '9a8b7c6d'},
  ],
  'counterevidence': <Object?>[],
  'evidenceLevel': 'conversation_only',
  'intent': 'active',
  'suggestion': '',
};

/// A v1.24 dashboard: a finding index over two kinds, votes parallel to the
/// patterns, and the streams / retries / triage fields.
Map<String, Object?> _dashboard({
  String? kind,
  int page = 1,
  String? vote,
  bool index = true,
}) {
  final json = raftbenchMap('dashboard-ready');
  final all = {
    'unsupported_completion': [
      for (var i = 1; i <= 7; i++)
        _pattern('unsupported_completion', 'Claim $i'),
    ],
    'repeated_attempt': [_pattern('repeated_attempt', 'Attempt 1')],
  };
  final kinds = kind == null ? all.keys.toList() : [kind];
  final rows = [for (final k in kinds) ...?all[k]];
  final from = (page - 1) * 5;
  final slice = rows.skip(from).take(5).toList();
  (json['run']! as Map)['report'] = {
    'status': 'complete',
    'reason': null,
    'gaps': <Object?>[],
    'patterns': slice,
  };
  (json['run']! as Map)['unreadRetries'] = {
    'thread': {'failures': 2, 'reason': 'x'},
  };
  json['pagination'] = {
    'page': page,
    'pageCount': (rows.length / 5).ceil(),
    'total': rows.length,
    'pageSize': 5,
  };
  json['findingFeedback'] = [
    for (final (i, _) in slice.indexed)
      {
        'id': 'f-$kind-${from + i}',
        'version': 'v1',
        'value': i == 0 ? vote : null,
        'evidenceAt': '2026-10-22T10:00:00.000Z',
      },
  ];
  if (index) {
    json['findingIndex'] = {
      'kindCounts': {
        'repeated_clarification': 0,
        'repeated_attempt': 1,
        'unsupported_completion': 7,
        'successful_practice': 0,
      },
    };
  }
  (json['progress']! as Map)['streams'] = {
    'channel': {'readMessages': 120, 'scannedThroughAt': null},
    'thread': {'readMessages': 9, 'scannedThroughAt': null},
  };
  json['triage'] = {
    'state': 'running',
    'triagedMessages': 40,
    'labeledMessages': 6,
    'runningBatches': 1,
    'todayTokens': 25,
    'dailyTokenLimit': 200,
  };
  return json;
}

class _Harness {
  _Harness({this.channelId, bool index = true}) {
    String? vote;
    api.routes['GET /raftbench'] = (call) => _dashboard(
      kind: call.query?['kind'] as String?,
      page: call.query?['page'] as int? ?? 1,
      vote: vote,
      index: index,
    );
    api.routes['GET /raftbench/agents'] = (_) =>
        raftbenchFixture('service-agents');
    api.routes['GET /agents/7a1e3c40-9d2b-4f56-8e0a-1b2c3d4e5f60/hosted-runtime/model'] =
        (_) => {'label': 'M'};
    for (final id in ['f-null-0', 'f-unsupported_completion-0']) {
      api.routes['PUT /raftbench/findings/$id/feedback'] = (call) {
        vote = (call.data! as Map)['value'] as String?;
        return {'saved': true};
      };
    }
    api.routes['GET /raftbench/readers'] = (_) => {'readers': readers};
    api.routes['PUT /raftbench/readers/a1'] = (call) {
      readers[0]['enabled'] = (call.data! as Map)['enabled'];
      return {'saved': true};
    };
    controller =
        RaftbenchHostedController(
          request: api.request,
          identity: () => 'g|u|s|owner',
          roleAllowed: () => true,
          analysisAllowed: () => true,
          onEnabled: (_) {},
          now: () => raftbenchNow,
          poll: false,
          channelId: channelId,
        )..setOptions(const [
          RaftbenchOption(_c1, 'general'),
          RaftbenchOption(_c2, 'random'),
        ]);
  }
  final String? channelId;
  final api = RaftbenchApi();
  late final RaftbenchHostedController controller;
  final readers = <Map<String, Object?>>[
    {'agentId': 'a1', 'name': 'bot', 'displayName': null, 'enabled': false},
    {'agentId': 'a2', 'name': 'other', 'displayName': 'Other', 'enabled': true},
  ];
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

Future<_Harness> _mount(
  WidgetTester t, {
  String? channelId,
  Size size = raftbenchDesktop,
  Locale locale = const Locale('en'),
  Future<bool> Function(String, String, String)? onEvidence,
  bool index = true,
}) async {
  final h = _Harness(channelId: channelId, index: index);
  addTearDown(h.controller.dispose);
  await mountRaftbench(
    t,
    SingleChildScrollView(
      child: RaftbenchHostedAnalysis(
        controller: h.controller,
        allowed: true,
        onOpenAgent: (_) {},
        onOpenEvidence: onEvidence ?? (_, _, _) async => true,
      ),
    ),
    size: size,
    locale: locale,
  );
  h.controller.start();
  await settle(t);
  return h;
}

void main() {
  group('controller', () {
    test(
      'every read names the period, the kind and the channel scope',
      () async {
        final h = _Harness(channelId: _c1);
        h.controller.start();
        await _pump();
        await _pump();
        final reads = h.api
            .where('GET /raftbench')
            .map((c) => c.query)
            .toList();
        // The page, then one read per kind that has findings (Web `load`).
        expect(reads.first, {'page': 1, 'period': 'recent', 'channelId': _c1});
        expect(reads.skip(1).map((q) => q!['kind']), [
          'repeated_attempt',
          'unsupported_completion',
        ]);
        expect(reads.skip(1).every((q) => q!['channelId'] == _c1), isTrue);
        final groups = h.controller.groups!;
        expect(groups['unsupported_completion']!.total, 7);
        expect(groups['unsupported_completion']!.patterns, hasLength(5));
        h.controller.dispose();
      },
    );

    test('Show more reads one more page of that kind only', () async {
      final h = _Harness();
      h.controller.start();
      await _pump();
      await _pump();
      h.controller.expandGroup('unsupported_completion');
      await _pump();
      await _pump();
      final more = h.api
          .where('GET /raftbench')
          .map((c) => c.query!)
          .where((q) => q['kind'] == 'unsupported_completion')
          .toList();
      expect(more.map((q) => q['page']), containsAll([1, 2]));
      expect(
        h.controller.groups!['unsupported_completion']!.patterns,
        hasLength(7),
      );
      h.controller.dispose();
    });

    test(
      'a kind filter reads the flat list; a period resets the view',
      () async {
        final h = _Harness();
        h.controller.start();
        await _pump();
        await _pump();
        h.controller.filterKind('repeated_attempt');
        expect(h.controller.data, isNull);
        expect(h.controller.loading, isTrue);
        await _pump();
        await _pump();
        expect(h.controller.groups, isNull);
        expect(h.api.where('GET /raftbench').last.query, {
          'page': 1,
          'period': 'recent',
          'kind': 'repeated_attempt',
        });
        h.controller.choosePeriod('history');
        await _pump();
        await _pump();
        expect(h.api.where('GET /raftbench').last.query!['period'], 'history');
        expect(h.controller.kind, 'repeated_attempt');
        h.controller.dispose();
      },
    );

    test('a failed group read falls back to the flat list', () async {
      final h = _Harness();
      final base = h.api.routes['GET /raftbench']!;
      h.api.routes['GET /raftbench'] = (call) => call.query!.containsKey('kind')
          ? throw RaftApiException('x', status: 500)
          : base(call);
      h.controller.start();
      await _pump();
      await _pump();
      expect(h.controller.groups, isNull);
      expect(h.controller.groupsUnavailable, isTrue);
      expect(h.controller.data, isNotNull);
      expect(h.controller.loadError, isNull);
      h.controller.dispose();
    });

    test('a vote is one PUT with the revision, then a re-read', () async {
      final h = _Harness();
      h.controller.filterKind(null);
      h.controller.start();
      await _pump();
      await _pump();
      final f = h.controller.data!.findingFeedback.first;
      final before = h.api.where('GET /raftbench').length;
      await h.controller.reviewFinding(f, 'agree');
      final put = h.api
          .where('PUT /raftbench/findings/f-null-0/feedback')
          .single;
      expect(put.data, {'revision': 3, 'version': 'v1', 'value': 'agree'});
      expect(h.api.where('GET /raftbench').length, greaterThan(before));
      expect(h.controller.feedbackSaving, isNull);
      expect(h.controller.feedbackError, isFalse);
      // The same vote again clears it.
      final again = h.controller.data!.findingFeedback.first;
      expect(again.value, 'agree');
      await h.controller.reviewFinding(again, 'agree');
      expect(
        h.api.where('PUT /raftbench/findings/f-null-0/feedback').last.data,
        containsPair('value', null),
      );
      h.controller.dispose();
    });

    test('a failed vote shows one error and keeps the finding', () async {
      final h = _Harness();
      h.api.routes['PUT /raftbench/findings/f-null-0/feedback'] = (_) =>
          throw RaftApiException('x', status: 500);
      h.controller.start();
      await _pump();
      await _pump();
      await h.controller.reviewFinding(
        h.controller.data!.findingFeedback.first,
        'inaccurate',
      );
      expect(h.controller.feedbackError, isTrue);
      expect(h.controller.feedbackSaving, isNull);
      expect(h.controller.data, isNotNull);
      h.controller.dispose();
    });

    test('load and save failures carry their diagnostic code apart', () async {
      final h = _Harness();
      h.api.routes['GET /raftbench'] = (_) =>
          throw RaftApiException('x', status: 401);
      h.controller.start();
      await _pump();
      expect(h.controller.loadError, 'HTTP 401');
      expect(h.controller.saveError, isNull);
      expect(RaftbenchHostedController.errorCode(StateError('x')), 'UNKNOWN');
      expect(
        RaftbenchHostedController.errorCode(RaftApiException('x', status: 403)),
        'HTTP 403',
      );
      h.controller.dispose();
    });

    test(
      'agent access reads once, grants one agent, then reads again',
      () async {
        final h = _Harness();
        h.controller.start();
        await _pump();
        await _pump();
        expect(h.api.where('GET /raftbench/readers'), hasLength(1));
        expect(h.controller.readers.readers.map((r) => r.label), [
          'bot',
          'Other',
        ]);
        final first = h.controller.readers.readers.first;
        await h.controller.readers.toggle(first);
        await _pump();
        expect(h.api.where('PUT /raftbench/readers/a1').single.data, {
          'enabled': true,
        });
        expect(h.api.where('GET /raftbench/readers'), hasLength(2));
        expect(h.controller.readers.readers.first.enabled, isTrue);
        expect(h.controller.readers.failed, isFalse);
        h.controller.dispose();
      },
    );

    test('a failed grant says so and does not read again', () async {
      final h = _Harness();
      h.api.routes['PUT /raftbench/readers/a1'] = (_) =>
          throw RaftApiException('x', status: 500);
      h.controller.start();
      await _pump();
      await _pump();
      await h.controller.readers.toggle(h.controller.readers.readers.first);
      expect(h.controller.readers.failed, isTrue);
      expect(h.controller.readers.busy, isFalse);
      expect(h.api.where('GET /raftbench/readers'), hasLength(1));
      h.controller.dispose();
    });
  });

  group('contract', () {
    test('the snapshot counts backlog and the total includes it', () {
      final json = raftbenchMap('snapshot-metrics')
        ..['backlog'] = 2
        ..['total'] = 12
        ..['humanCreated'] = 8;
      final snapshot = RaftbenchTaskSnapshot.parse(json);
      expect(snapshot.backlog, 2);
      expect(snapshot.total, 12);
      // The old total no longer adds up once backlog is counted.
      expect(
        () => RaftbenchTaskSnapshot.parse({...json, 'total': 10}),
        throwsFormatException,
      );
      expect(
        () => RaftbenchTaskSnapshot.parse(Map.of(json)..remove('backlog')),
        throwsFormatException,
      );
    });

    test('the dashboard reads the index, votes, streams and triage', () {
      final d = RaftbenchDashboard.parse(_dashboard(vote: 'agree'));
      expect(d.kindCounts!['unsupported_completion'], 7);
      expect(d.findingFeedback.first.value, 'agree');
      expect(d.progress!.streamRead, {'channel': 120, 'thread': 9});
      expect(d.run!.unreadFailures, {'thread': 2});
      expect(d.triage!.usage, 13);
      expect(
        RaftbenchDashboard.parse(raftbenchFixture('dashboard-ready'))
            .kindCounts,
        isNull,
      );
    });

    test('an evidence target with a short id still names its channel', () {
      const options = [RaftbenchOption(_c1, 'general')];
      expect(
        raftbenchEvidenceSource(
          options,
          const RaftbenchEvidenceRef('#general:ab12cd34', 'x'),
        )?.value,
        _c1,
      );
      expect(
        raftbenchParseEvidenceTarget('#general:ab12cd34').threadShortId,
        'ab12cd34',
      );
      expect(raftbenchParseEvidenceTarget('#general').threadShortId, isNull);
    });
  });

  for (final (name, size) in [
    ('desktop', raftbenchDesktop),
    ('phone', raftbenchPhone),
  ]) {
    group('view ($name)', () {
      testWidgets('the finding index, stream lines and triage', (t) async {
        await _mount(t, size: size);
        expect(find.text('What deserves attention'), findsWidgets);
        expect(find.text('Last 30 days'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('All patterns'), findsOneWidget);
        expect(find.textContaining('Analyzed through 10/2'), findsOneWidget);
        expect(
          find.text('Channel messages read: 120 · Thread replies read: 9'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Thread replies failed to load 2 times; unread history is kept for retry.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Channel messages failed'), findsNothing);
        expect(
          find.text(
            "Labeling messages: 40 labeled, 6 flagged · 13% of today's budget used",
          ),
          findsOneWidget,
        );
        // The All view is grouped by kind, each with its total.
        expect(
          find.byKey(const ValueKey('raftbench-group-unsupported_completion')),
          findsOneWidget,
        );
        expect(find.text('Show 2 more'), findsOneWidget);
        await unmount(t);
      });

      testWidgets('Agree and Inaccurate vote; the selected one is pressed', (
        t,
      ) async {
        final h = await _mount(t, size: size);
        h.controller.filterKind('unsupported_completion');
        await settle(t);
        expect(find.text('Agree'), findsWidgets);
        expect(find.text('Inaccurate'), findsWidgets);
        await t.ensureVisible(find.text('Agree').first);
        await t.tap(find.text('Agree').first);
        await settle(t);
        final put = h.api
            .where(
              'PUT /raftbench/findings/f-unsupported_completion-0/feedback',
            )
            .single;
        expect(put.data, {'revision': 3, 'version': 'v1', 'value': 'agree'});
        // Voting again on the selected value clears it.
        await t.ensureVisible(find.text('Agree').first);
        await t.tap(find.text('Agree').first);
        await settle(t);
        expect(
          h.api
              .where(
                'PUT /raftbench/findings/f-unsupported_completion-0/feedback',
              )
              .last
              .data,
          containsPair('value', null),
        );
        await unmount(t);
      });

      testWidgets('an evidence chip opens its message, a short id included', (
        t,
      ) async {
        final opened = <(String, String, String)>[];
        await _mount(
          t,
          size: size,
          onEvidence: (c, target, id) async {
            opened.add((c, target, id));
            return target.contains(':') ? false : true;
          },
        );
        await t.ensureVisible(find.text('#general 3f9c1a77').first);
        await t.tap(find.text('#general 3f9c1a77').first);
        await settle(t);
        expect(opened, [(_c1, '#general', '3f9c1a77')]);
        // A reply that no longer resolves turns its chip static.
        await t.ensureVisible(find.text('#general:ab12cd34 9a8b7c6d').first);
        await t.tap(find.text('#general:ab12cd34 9a8b7c6d').first);
        await settle(t);
        expect(opened, hasLength(2));
        await t.tap(find.text('#general:ab12cd34 9a8b7c6d').first);
        await settle(t);
        expect(opened, hasLength(2));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RaftTooltip &&
                w.message == 'Source unavailable in this view',
          ),
          findsWidgets,
        );
        await unmount(t);
      });

      testWidgets('Agent access lists agents and grants one', (t) async {
        final h = await _mount(t, size: size);
        expect(find.text('Allow access'), findsNothing, reason: 'collapsed');
        await t.ensureVisible(find.text('Agent access'));
        await t.tap(find.text('Agent access'));
        await t.pump();
        expect(find.text('bot'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
        expect(find.text('Revoke access'), findsOneWidget);
        await t.ensureVisible(find.text('Allow access'));
        await t.tap(find.text('Allow access'));
        await settle(t);
        expect(h.api.where('PUT /raftbench/readers/a1'), hasLength(1));
        expect(find.text('Allow access'), findsNothing);
        expect(find.text('Revoke access'), findsNWidgets(2));
        await unmount(t);
      });
    });
  }

  testWidgets('Chinese wording (Web zh-cn)', (t) async {
    await _mount(t, locale: const Locale('zh'));
    expect(find.text('最近 30 天'), findsOneWidget);
    expect(find.text('全部模式'), findsOneWidget);
    expect(find.text('值得关注的模式'), findsWidgets);
    expect(find.textContaining('正在分拣消息：已分拣 40 条，标出 6 条'), findsOneWidget);
    expect(find.text('同意'), findsWidgets);
    expect(find.text('不准'), findsWidgets);
    await unmount(t);
  });
}
