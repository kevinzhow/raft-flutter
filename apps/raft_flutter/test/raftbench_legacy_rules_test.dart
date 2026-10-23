// The collapsed legacy phrase rules (Web RaftBenchPage `raftbench-legacy-rules`):
// scan on request, cues, evidence with nearby context, review labels.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raftbench_hosted_controller.dart'
    show RaftbenchOption;
import 'package:raft_flutter/data/raftbench_rules_controller.dart';
import 'package:raft_flutter/features/raftbench_legacy_rules.dart';

import 'support/raftbench_fixture.dart';
import 'support/raftbench_host.dart';

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
};

class _Case {
  final api = RaftbenchApi();
  final opened = <(String, String)>[];
  late final RaftbenchRulesController controller;
  _Case({this.consented = true, this.allowed = true}) {
    api.routes['GET /messages/channel/c1'] = (_) => {
      'messages': [
        _row(
          'a1',
          'c1',
          'I am so frustrated with this',
          minute: 1,
          name: 'Ann',
        ),
        _row('a2', 'c1', 'nearby context line', minute: 2, name: 'Bob'),
        _row('a3', 'c1', 'thanks, works perfectly', minute: 30, name: 'Ann'),
      ],
    };
    api.routes['GET /messages/channel/c2'] = (_) => {
      'messages': [
        _row(
          'b1',
          'c2',
          'Deploy finished, all checks green and healthy',
          type: 'agent',
          sender: 'ag',
          minute: 1,
        ),
        _row(
          'b2',
          'c2',
          'Deploy finished, all checks green and healthy',
          type: 'agent',
          sender: 'ag',
          minute: 2,
        ),
        _row(
          'b3',
          'c2',
          'Deploy finished, all checks green and healthy',
          type: 'agent',
          sender: 'ag',
          minute: 3,
        ),
      ],
    };
    controller = RaftbenchRulesController(
      request: api.request,
      identity: () => 'g|u|s|owner',
      roleAllowed: () => true,
      now: () => raftbenchNow,
    );
  }
  final scope = raftbenchWorkspaceScope;
  bool consented, allowed;
  static const options = [
    RaftbenchOption('c1', 'general', activityAt: '2026-10-23T10:00:00Z'),
    RaftbenchOption('c2', 'ops', activityAt: '2026-10-23T11:00:00Z'),
    RaftbenchOption('c3', 'lounge', unjoinedPublic: true),
  ];
  void configure() => controller.configure(
    channelId: scope,
    options: options,
    consented: consented,
    analysisAllowed: allowed,
  );
}

Future<_Case> _mount(
  WidgetTester t, {
  bool consented = true,
  bool allowed = true,
  Size size = raftbenchDesktop,
  Locale locale = const Locale('en'),
}) async {
  final c = _Case(consented: consented, allowed: allowed);
  addTearDown(c.controller.dispose);
  c.configure();
  await mountRaftbench(
    t,
    SingleChildScrollView(
      child: RaftbenchLegacyRules(
        controller: c.controller,
        channelName: 'Workspace overview',
        onOpenMessage: (channel, message) => c.opened.add((channel, message)),
      ),
    ),
    size: size,
    locale: locale,
  );
  return c;
}

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('Legacy phrase and repetition rules'));
  await t.pump();
}

void main() {
  testWidgets(
    'collapsed by default; opening shows the scan and the empty hint',
    (t) async {
      await _mount(t);
      expect(find.text('Scan phrases and repeats'), findsNothing);
      await _open(t);
      expect(find.text('Scan phrases and repeats'), findsOneWidget);
      expect(
        find.text('Pilot results stay inside staging. Export is unavailable.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Start a workspace overview, or choose a channel. Messages are read only when you start.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Rule version: raftbench-rules-0.1.0. Exact repetition and phrase rules only; semantic loops and indirect frustration may be missed.',
        ),
        findsOneWidget,
      );
      await unmount(t);
    },
  );

  testWidgets(
    'the scan needs the AI analysis enabled and the rollout confirmed',
    (t) async {
      for (final (consented, allowed) in [(false, true), (true, false)]) {
        final c = await _mount(t, consented: consented, allowed: allowed);
        await _open(t);
        await t.tap(find.text('Scan phrases and repeats'), warnIfMissed: false);
        await settle(t);
        expect(c.api.calls, isEmpty, reason: '$consented/$allowed');
        await unmount(t);
      }
    },
  );

  testWidgets('a scan lists cues, counts and coverage', (t) async {
    final c = await _mount(t);
    await _open(t);
    await t.tap(find.text('Scan phrases and repeats'));
    await settle(t);
    await settle(t);
    expect(find.text('Refresh phrase scan'), findsOneWidget);
    expect(find.byKey(const ValueKey('raftbench-cue-count')), findsOneWidget);
    expect(
      (t.widget(
        find.byKey(const ValueKey('raftbench-cue-count')),
      ) as Text).data,
      '2',
    );
    expect(find.text('2 awaiting review'), findsOneWidget);
    expect(
      find.text('1 positive · 1 negative · 0 mixed · 1 unscored'),
      findsOneWidget,
    );
    expect(find.text('Messages observed'), findsOneWidget);
    // Each scanned channel and its cue count.
    expect(find.text('general · 1 cues'), findsOneWidget);
    expect(find.text('ops · 1 cues'), findsOneWidget);
    expect(find.text('Human frustration · 1'), findsOneWidget);
    expect(find.text('Repeated agent messages · 3'), findsOneWidget);
    expect(c.api.calls.map((x) => x.path).toSet(), {
      '/messages/channel/c1',
      '/messages/channel/c2',
      '/messages/channel/c3',
    });
    // Coverage and limits are collapsed; opening them names the scope and the denied channel.
    await t.ensureVisible(find.text('Coverage & limitations'));
    await t.tap(find.text('Coverage & limitations'));
    await t.pump();
    expect(
      find.textContaining('Workspace overview · Snapshot of 6 messages'),
      findsOneWidget,
    );
    expect(
      find.text(
        '2 of 3 requested channels read · 3 visible channels in this workspace',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1 channels could not be read'), findsOneWidget);
    expect(
      find.textContaining(
        'Public channels not joined: 1 available; 0 read in this snapshot.',
      ),
      findsOneWidget,
    );
    await unmount(t);
  });

  testWidgets(
    'selecting a cue shows its evidence and nearby context; Open original message jumps',
    (t) async {
      final c = await _mount(t);
      await _open(t);
      await t.tap(find.text('Scan phrases and repeats'));
      await settle(t);
      await settle(t);
      await t.ensureVisible(find.text('Evidence and nearby context'));
      // The newest cue is selected: the agent repeat in #ops.
      expect(find.text('Matched'), findsWidgets);
      await t.tap(find.text('Human frustration · 1'));
      await t.pump();
      expect(find.text('I am so frustrated with this'), findsOneWidget);
      expect(find.text('nearby context line'), findsOneWidget);
      expect(find.text('Nearby context'), findsOneWidget);
      expect(
        find.text('thanks, works perfectly'),
        findsNothing,
        reason: '28 minutes away',
      );
      await t.ensureVisible(find.text('Open original message').first);
      await t.tap(find.text('Open original message').first);
      expect(c.opened, [('c1', 'a1')]);
      await unmount(t);
    },
  );

  testWidgets(
    'review labels and the note are per cue and reset by the threshold',
    (t) async {
      final c = await _mount(t);
      await _open(t);
      await t.tap(find.text('Scan phrases and repeats'));
      await settle(t);
      await settle(t);
      await t.tap(find.text('Human frustration · 1'));
      await t.pump();
      await t.ensureVisible(find.text('Confirm signal'));
      await t.tap(find.text('Confirm signal'));
      await t.pump();
      expect(c.controller.reviews.values.single.status.name, 'confirmed');
      expect(find.text('1 awaiting review'), findsOneWidget);
      expect(find.textContaining('Confirmed'), findsWidgets);
      await t.ensureVisible(find.text('Mark as false positive'));
      await t.tap(find.text('Mark as false positive'));
      await t.pump();
      expect(c.controller.reviews.values.single.status.name, 'dismissed');
      await t.tap(find.text('Reopen'));
      await t.pump();
      expect(c.controller.pendingCount, 2);
      await unmount(t);
    },
  );

  testWidgets('filters narrow the queue and the empty queue says so', (
    t,
  ) async {
    final c = await _mount(t);
    await _open(t);
    await t.tap(find.text('Scan phrases and repeats'));
    await settle(t);
    await settle(t);
    await t.ensureVisible(find.text('Negative sentiment').first);
    await t.tap(find.text('Negative sentiment').first);
    await t.pump();
    expect(c.controller.findings, isEmpty);
    expect(
      find.text(
        'No matching cues in this window. This does not establish that the agent succeeded.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Select a cue to inspect its original messages.'),
      findsOneWidget,
    );
    await unmount(t);
  });

  testWidgets(
    'an unreadable scope shows the retry text and clears the evidence',
    (t) async {
      final c = _Case();
      c.api.routes.clear();
      addTearDown(c.controller.dispose);
      c.configure();
      await mountRaftbench(
        t,
        SingleChildScrollView(
          child: RaftbenchLegacyRules(
            controller: c.controller,
            channelName: 'x',
            onOpenMessage: (_, _) {},
          ),
        ),
      );
      await _open(t);
      await t.tap(find.text('Scan phrases and repeats'));
      await settle(t);
      await settle(t);
      expect(
        find.text(
          'Could not read the requested scope. Check your access and retry. Previous evidence has been cleared.',
        ),
        findsOneWidget,
      );
      expect(find.text('Review cues'), findsNothing);
      await unmount(t);
    },
  );

  testWidgets('phone layout stacks the queue above the evidence', (t) async {
    await _mount(t, size: raftbenchPhone);
    await _open(t);
    await t.tap(find.text('Scan phrases and repeats'));
    await settle(t);
    await settle(t);
    final queue = t.getTopLeft(find.text('Review queue'));
    final evidence = t.getTopLeft(find.text('Evidence and nearby context'));
    expect(evidence.dy, greaterThan(queue.dy));
    expect(evidence.dx, queue.dx);
    await unmount(t);
  });

  testWidgets('Chinese wording (Web zh-cn)', (t) async {
    await _mount(t, locale: const Locale('zh'));
    expect(find.text('旧版短语与重复规则'), findsOneWidget);
    await unmount(t);
  });
}
