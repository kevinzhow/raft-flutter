// The legacy phrase scan: bounded message reads (Web liveMessages.ts) and the
// review controller around them (RaftBenchPage rule section).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raftbench_hosted_controller.dart'
    show RaftbenchOption;
import 'package:raft_flutter/data/raftbench_live_messages.dart';
import 'package:raft_flutter/data/raftbench_rules.dart';
import 'package:raft_flutter/data/raftbench_rules_controller.dart';

import 'support/raftbench_fixture.dart';

Map<String, Object?> _row(
  String id,
  String channel,
  String content, {
  String type = 'user',
  String sender = 'u1',
  int minute = 0,
  String? name,
}) => {
  'id': id,
  'channelId': channel,
  'senderType': type,
  'senderId': sender,
  'senderName': ?name,
  'messageType': 'chat',
  'content': content,
  'createdAt': DateTime.utc(2026, 10, 23, 9, minute).toIso8601String(),
  // Receiver-private fields the scan must not keep.
  'attachments': [
    {'id': 'file'},
  ],
};

RaftbenchApi _api(Map<String, List<Map<String, Object?>>> channels) {
  final api = RaftbenchApi();
  for (final entry in channels.entries) {
    api.routes['GET /messages/channel/${entry.key}'] = (_) => {
      'messages': entry.value,
    };
  }
  return api;
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('message reads', () {
    test('reads the latest 200 and keeps only the evidence fields', () async {
      final api = _api({
        'c1': [_row('m1', 'c1', 'hello', name: 'Ann')],
      });
      final snap = await loadRaftbenchMessageSnapshot(
        api.request,
        'c1',
        now: () => raftbenchNow,
      );
      expect(api.calls.single.query, {'limit': 200});
      expect(snap.messages.single.senderName, 'Ann');
      expect(snap.messages.single.content, 'hello');
      expect(snap.mayHaveOlder, isFalse);
      expect(snap.historyLimited, isFalse);
    });

    test(
      'a full page may have older history; the plan limit is reported',
      () async {
        final api = RaftbenchApi()
          ..routes['GET /messages/channel/c1'] = ((_) => {
            'historyLimited': true,
            'messages': [for (var i = 0; i < 200; i++) _row('m$i', 'c1', 'x')],
          });
        final snap = await loadRaftbenchMessageSnapshot(api.request, 'c1');
        expect(snap.mayHaveOlder, isTrue);
        expect(snap.historyLimited, isTrue);
      },
    );

    test('a malformed row, a foreign channel row or a duplicate id fails the channel', () async {
      for (final rows in [
        [_row('m1', 'c1', 'a'), _row('m1', 'c1', 'b')],
        [_row('m1', 'other', 'a')],
        [
          {..._row('m1', 'c1', 'a'), 'createdAt': 'yesterday'},
        ],
        [
          {..._row('m1', 'c1', 'a'), 'senderType': 'robot'},
        ],
      ]) {
        final api = _api({'c1': rows});
        expect(
          loadRaftbenchMessageSnapshot(api.request, 'c1'),
          throwsA(isA<FormatException>()),
          reason: '$rows',
        );
      }
    });

    test(
      'denied channels contribute nothing and are listed; all denied fails',
      () async {
        final api =
            _api({
                'c2': [_row('m2', 'c2', 'two')],
                'c1': [_row('m1', 'c1', 'one')],
              })
              ..routes['GET /messages/channel/c3'] = ((_) =>
                  throw RaftApiException('Forbidden', status: 403));
        final result = await loadRaftbenchChannelSnapshots(api.request, [
          'c2',
          'c3',
          'c1',
          'c2',
        ], now: () => raftbenchNow);
        expect(result.requestedChannels, 3);
        expect(result.unavailableChannelIds, ['c3']);
        expect(result.channels.map((c) => c.channelId), ['c1', 'c2']);
        expect(result.messages.map((m) => m.id), ['m1', 'm2']);
        final denied = RaftbenchApi();
        expect(
          loadRaftbenchChannelSnapshots(denied.request, ['c1']),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('one to twenty channels', () async {
      final api = RaftbenchApi();
      expect(
        loadRaftbenchChannelSnapshots(api.request, []),
        throwsFormatException,
      );
      expect(
        loadRaftbenchChannelSnapshots(api.request, [
          for (var i = 0; i < 21; i++) 'c$i',
        ]),
        throwsFormatException,
      );
    });

    test('at most four reads are in flight', () async {
      var inFlight = 0, peak = 0;
      final gates = <Completer<void>>[];
      Future<dynamic> request(
        String m,
        String p, {
        Object? data,
        Map<String, dynamic>? query,
      }) async {
        inFlight++;
        peak = inFlight > peak ? inFlight : peak;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        inFlight--;
        final id = p.split('/').last;
        return {
          'messages': [_row('m-$id', id, 'x')],
        };
      }

      final done = loadRaftbenchChannelSnapshots(request, [
        for (var i = 0; i < 9; i++) 'c$i',
      ]);
      await pump();
      expect(inFlight, 4);
      while (gates.length < 9 || inFlight > 0) {
        for (final g in gates.where((g) => !g.isCompleted)) {
          g.complete();
        }
        await pump();
      }
      await done;
      expect(peak, 4);
    });

    test('a stale scope abandons the read', () async {
      final api = _api({
        'c1': [_row('m1', 'c1', 'x')],
      });
      var current = true;
      final read = loadRaftbenchChannelSnapshots(api.request, [
        'c1',
      ], isCurrent: () => current);
      current = false;
      expect(read, throwsA(isA<StateError>()));
    });
  });

  group('review controller', () {
    final options = [
      const RaftbenchOption(
        'c1',
        'general',
        activityAt: '2026-10-23T10:00:00Z',
      ),
      const RaftbenchOption('c2', 'random', activityAt: '2026-10-23T12:00:00Z'),
      const RaftbenchOption('c3', 'old', activityAt: '2026-10-01T10:00:00Z'),
    ];
    RaftbenchRulesController make(
      RaftbenchApi api, {
      String Function()? identity,
    }) => RaftbenchRulesController(
      request: api.request,
      identity: identity ?? () => 'g1|u1|s1|owner',
      roleAllowed: () => true,
      now: () => raftbenchNow,
    );

    RaftbenchApi api() => _api({
      'c1': [
        _row('a1', 'c1', 'I am so frustrated', minute: 1, name: 'Ann'),
        _row('a2', 'c1', 'and nearby context', minute: 2),
        _row('a3', 'c1', 'far away message', minute: 20),
      ],
      'c2': [_row('b1', 'c2', 'this is terrible', minute: 3)],
      'c3': [_row('c1', 'c3', 'stop asking', minute: 4)],
    });

    void configure(
      RaftbenchRulesController c, {
      String scope = raftbenchWorkspaceScope,
      bool consented = true,
      bool allowed = true,
    }) => c.configure(
      channelId: scope,
      options: options,
      consented: consented,
      analysisAllowed: allowed,
    );

    test(
      'scanning needs the AI analysis enabled and the flag confirmed',
      () async {
        final a = api();
        final c = make(a);
        configure(c, consented: false);
        expect(c.canScan, isFalse);
        await c.analyze();
        expect(a.calls, isEmpty);
        configure(c, allowed: false);
        await c.analyze();
        expect(a.calls, isEmpty);
        configure(c);
        expect(c.canScan, isTrue);
        c.dispose();
      },
    );

    test(
      'workspace scope reads the most active channels, newest first',
      () async {
        final a = api();
        final c = make(a);
        configure(c);
        await c.analyze();
        expect(c.snapshot, isNotNull);
        expect(a.calls.map((x) => x.path).toSet(), {
          '/messages/channel/c1',
          '/messages/channel/c2',
          '/messages/channel/c3',
        });
        expect(c.snapshot!.requestedChannels, 3);
        expect(c.evaluation.findings, hasLength(3));
        expect(c.pendingCount, 3);
        c.dispose();
      },
    );

    test('a channel scope reads only that channel', () async {
      final a = api();
      final c = make(a);
      configure(c, scope: 'c2');
      await c.analyze();
      expect(a.calls.single.path, '/messages/channel/c2');
      expect(c.evaluation.findings.single.kind, RaftbenchSignal.negative);
      c.dispose();
    });

    test('filters, drill-down, selection and the nearby context', () async {
      final c = make(api());
      configure(c);
      await c.analyze();
      c.setFilter(RaftbenchSignal.frustration);
      expect(c.findings.map((f) => f.kind).toSet(), {
        RaftbenchSignal.frustration,
      });
      expect(c.findings, hasLength(2));
      c.drillTo('c1');
      expect(c.findings.single.evidence.first.id, 'a1');
      expect(c.finding!.evidence.single.id, 'a1');
      // Within two minutes of the match: a2 is context, a3 (19 minutes later) is not.
      expect(c.evidence.map((m) => m.id), ['a1', 'a2']);
      expect(c.evidenceIds, {'a1'});
      c.setFilter(null);
      c.clearDrill();
      expect(c.findings, hasLength(3));
      c.chooseFinding(c.findings.last.id);
      expect(c.finding!.id, c.findings.last.id);
      c.dispose();
    });

    test(
      'reviews: confirm, dismiss, reopen, note; reset by the threshold',
      () async {
        final c = make(api());
        configure(c);
        await c.analyze();
        final id = c.finding!.id;
        expect(c.review!.status, RaftbenchReview.needsReview);
        c.setNote('checked with the customer');
        c.confirm();
        expect(c.reviews[id]!.status, RaftbenchReview.confirmed);
        expect(c.reviews[id]!.note, 'checked with the customer');
        expect(c.pendingCount, 2);
        c.dismiss();
        expect(c.reviews[id]!.status, RaftbenchReview.dismissed);
        c.reopen();
        expect(c.pendingCount, 3);
        c.confirm();
        c.changeMinimum('1');
        c.changeMinimum('21');
        c.changeMinimum('abc');
        expect(c.minimum, 3);
        expect(c.reviews, isNotEmpty);
        c.changeMinimum('4');
        expect(c.minimum, 4);
        expect(c.reviews, isEmpty, reason: 'new threshold, new cues');
        c.dispose();
      },
    );

    test(
      'a different scope, membership or consent drops everything derived',
      () async {
        final c = make(api());
        configure(c);
        await c.analyze();
        c.confirm();
        expect(c.snapshot, isNotNull);
        configure(c);
        expect(c.snapshot, isNotNull, reason: 'same inputs keep the result');
        configure(c, scope: 'c1');
        expect(c.snapshot, isNull);
        expect(c.reviews, isEmpty);
        await c.analyze();
        expect(c.snapshot, isNotNull);
        configure(c, scope: 'c1', consented: false);
        expect(c.snapshot, isNull);
        c.dispose();
      },
    );

    test('an identity change mid-scan discards the result', () async {
      var identity = 'g1|u1|s1|owner';
      final gate = Completer<Object?>();
      final a = RaftbenchApi()
        ..routes['GET /messages/channel/c1'] = ((_) => gate.future);
      final c = make(a, identity: () => identity);
      configure(c, scope: 'c1');
      final scan = c.analyze();
      await pump();
      expect(c.loading, isTrue);
      identity = 'g2|u1|s2|owner';
      gate.complete({
        'messages': [_row('m1', 'c1', 'stop asking')],
      });
      await scan;
      expect(c.snapshot, isNull);
      expect(c.failed, isFalse);
      c.dispose();
    });

    test('an unreadable scope is a failure, not an empty result', () async {
      final c = make(RaftbenchApi());
      configure(c, scope: 'c1');
      await c.analyze();
      expect(c.failed, isTrue);
      expect(c.snapshot, isNull);
      expect(c.loading, isFalse);
      c.dispose();
    });
  });
}
