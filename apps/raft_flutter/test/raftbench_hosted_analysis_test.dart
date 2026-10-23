// Conversation insights as the owner sees it (Web HostedAnalysis.tsx): every
// run state, the settings, the service agent and the evidence references.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raftbench_hosted_controller.dart';
import 'package:raft_flutter/features/raftbench_hosted_analysis.dart';

import 'support/raftbench_fixture.dart';
import 'support/raftbench_host.dart';

const _c1 = '5d0b8c1e-2a63-4b27-9c1f-0a1b2c3d4e01';
const _c2 = '5d0b8c1e-2a63-4b27-9c1f-0a1b2c3d4e02';
const _agent = '7a1e3c40-9d2b-4f56-8e0a-1b2c3d4e5f60';

class _Case {
  _Case(String dashboard) {
    api.routes['GET /raftbench'] = (_) => raftbenchFixture(dashboard);
    api.routes['GET /raftbench/agents'] = (_) =>
        raftbenchFixture('service-agents');
    api.routes['GET /agents/$_agent/hosted-runtime/model'] = (_) => {
      'label': 'DeepSeek Flash',
    };
    api.routes['PUT /raftbench'] = (_) => {'saved': true};
    api.routes['PUT /raftbench/assignment'] = (_) => {'saved': true};
    api.routes['POST /raftbench/agents'] = (_) => {'agentId': 'new'};
    controller =
        RaftbenchHostedController(
          request: api.request,
          identity: () => 'g|u|s|owner',
          roleAllowed: () => true,
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
  final openedMessages = <(String, String)>[];
  final openedAgents = <String>[];
  bool allowed = true;
}

Future<_Case> _mount(
  WidgetTester t,
  String dashboard, {
  Size size = raftbenchDesktop,
  Locale locale = const Locale('en'),
}) async {
  final c = _Case(dashboard);
  addTearDown(c.controller.dispose);
  await mountRaftbench(
    t,
    SingleChildScrollView(
      child: RaftbenchHostedAnalysis(
        controller: c.controller,
        allowed: true,
        onOpenAgent: c.openedAgents.add,
        onOpenMessage: (channel, message) =>
            c.openedMessages.add((channel, message)),
      ),
    ),
    size: size,
    locale: locale,
  );
  c.controller.start();
  await settle(t);
  return c;
}

Finder _text(String s) => find.text(s);

void main() {
  for (final (name, size) in [
    ('desktop', raftbenchDesktop),
    ('phone', raftbenchPhone),
  ]) {
    testWidgets(
      'disabled: settings are open and Enable starts the analysis ($name)',
      (t) async {
        final semantics = t.ensureSemantics();
        final c = await _mount(t, 'dashboard-disabled', size: size);
        expect(_text('Conversation insights'), findsOneWidget);
        expect(
          _text('Reads selected channels · no DM replies'),
          findsOneWidget,
        );
        expect(_text('Enable and start analysis'), findsOneWidget);
        // `<details open>` while disabled: sources and the start date are visible.
        expect(_text('Channels to analyze (up to 50)'), findsOneWidget);
        expect(_text('general'), findsOneWidget);
        expect(_text('random'), findsOneWidget);
        expect(_text('Analyze messages since (UTC)'), findsOneWidget);
        expect(_text('10/17/2026'), findsOneWidget);
        expect(_text('Past 7 days'), findsOneWidget);
        expect(_text('Past 30 days'), findsOneWidget);
        expect(_text('Past 90 days'), findsOneWidget);
        // No agent yet: the service-agent card is open, with its agents.
        expect(_text('RaftBench service agent'), findsOneWidget);
        expect(_text('raftbench-service'), findsOneWidget);
        expect(_text('Ready to assign'), findsOneWidget);
        expect(
          _text('Setting up; assignment available when ready'),
          findsOneWidget,
        );
        expect(_text('Apply changes and restart'), findsNothing);

        c.api.routes['GET /raftbench'] = (_) =>
            raftbenchFixture('dashboard-queued');
        await t.tap(_text('Enable and start analysis'));
        await settle(t);
        final put = c.api.where('PUT /raftbench').single.data! as Map;
        expect(put['enabled'], true);
        expect(put['channelIds'], [_c1, _c2]);
        // The untouched default start is shown, not sent (Web sends a date only
        // once the user picked one).
        expect(put.containsKey('historyFrom'), isFalse);
        expect(_text('Disable and clear results'), findsOneWidget);
        expect(_text('Waiting for the analysis agent…'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Analysis progress')),
          findsOneWidget,
        );
        expect(
          _text(
            '0 messages read. The total is not known yet; this bar does not show a percentage.',
          ),
          findsNothing,
          reason: 'a progress record exists: it is the batch wording',
        );
        expect(
          _text(
            'This batch has read 0 messages. The background scan continues in further batches.',
          ),
          findsOneWidget,
        );
        semantics.dispose();
        await unmount(t);
      },
    );
  }

  testWidgets('enabling is off with no source or a start date after now', (
    t,
  ) async {
    final c = await _mount(t, 'dashboard-disabled');
    await t.tap(
      find.byType(Checkbox).evaluate().isEmpty
          ? _text('general')
          : _text('general'),
    );
    await t.pump();
    await t.tap(_text('random'));
    await t.pump();
    // Nothing selected: Enable is disabled.
    expect(c.controller.selected, isEmpty);
    await t.tap(_text('Enable and start analysis'), warnIfMissed: false);
    await settle(t);
    expect(c.api.where('PUT /raftbench'), isEmpty);
    await unmount(t);
  });

  testWidgets(
    'queued and running show the progress bar and the batch counters',
    (t) async {
      final c = await _mount(t, 'dashboard-running');
      expect(_text('Reading channel messages…'), findsOneWidget);
      expect(
        _text('Read 96 of 189 messages · 2 batches accepted'),
        findsOneWidget,
      );
      expect(
        _text(
          'This batch has read 41 messages. The background scan continues in further batches.',
        ),
        findsOneWidget,
      );
      expect(
        _text('Current cloud agent model: DeepSeek Flash'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '2 channels · history continues in background; checks for new messages every 15 minutes',
        ),
        findsOneWidget,
      );
      // Selected sources match the saved ones.
      expect(c.controller.selected, [_c1, _c2]);
      // A running analysis shows no verdict line yet.
      expect(_text('Analysis complete'), findsNothing);
      await unmount(t);
    },
  );

  testWidgets('ready: findings, evidence references and the proposal', (
    t,
  ) async {
    final c = await _mount(t, 'dashboard-ready');
    expect(_text('Analysis complete'), findsOneWidget);
    expect(_text('Completion claim needs verification'), findsOneWidget);
    expect(_text('Repeated attempts'), findsOneWidget);
    expect(
      _text(
        'The agent said the deploy finished but no later message confirms it.',
      ),
      findsOneWidget,
    );
    expect(
      _text(
        'Evidence: conversation only; actual task or tool outcome is unverified',
      ),
      findsOneWidget,
    );
    expect(
      _text('Evidence: insufficient to determine the outcome'),
      findsOneWidget,
    );
    expect(_text('Task intent: Actively pursued'), findsOneWidget);
    expect(_text('Task intent: Unknown'), findsOneWidget);
    expect(_text('1 counterexamples were considered'), findsOneWidget);
    expect(_text('Draft improvement or shared-skill proposal'), findsOneWidget);
    expect(
      _text('Ask the agent to post the deploy link before closing the task.'),
      findsOneWidget,
    );
    expect(
      _text(
        'Conversation evidence only. Tool outcomes and thread replies are not included. Suggestions need human review and never create or publish skills automatically.',
      ),
      findsOneWidget,
    );
    expect(_text('Page 1 of 2 · 7 findings'), findsOneWidget);
    expect(_text('Disable and clear results'), findsOneWidget);
    // The settings are collapsed once enabled.
    expect(_text('Channels to analyze (up to 50)'), findsNothing);

    // Evidence opens the source message in its channel.
    await t.tap(_text('Evidence #general · 3f9c1a77'));
    expect(c.openedMessages, [(_c1, '3f9c1a77')]);
    await t.tap(_text('Evidence #general · 3f9c1a78'));
    await t.tap(_text('Counterevidence #random · 8e2d4b10'));
    expect(c.openedMessages.map((e) => e.$1), [_c1, _c1, _c2]);
    expect(c.openedMessages.last.$2, '8e2d4b10-6c3f-4a9b-b2d4-1f0e9d8c7b63');
    await unmount(t);
  });

  testWidgets('an evidence target the page cannot map is unavailable', (
    t,
  ) async {
    final c = _Case('dashboard-ready');
    c.api.routes['GET /raftbench'] = (_) {
      final json = raftbenchMap('dashboard-ready');
      final pattern =
          (((json['run']! as Map)['report']! as Map)['patterns']! as List).first
              as Map;
      pattern['evidence'] = [
        {'target': '#general:3f9c1a77', 'messageId': '3f9c1a77'},
        {'target': '#elsewhere', 'messageId': '3f9c1a78'},
      ];
      return json;
    };
    addTearDown(c.controller.dispose);
    await mountRaftbench(
      t,
      SingleChildScrollView(
        child: RaftbenchHostedAnalysis(
          controller: c.controller,
          allowed: true,
          onOpenAgent: (_) {},
          onOpenMessage: (_, _) {},
        ),
      ),
    );
    c.controller.start();
    await settle(t);
    expect(_text('Source unavailable in this view'), findsNWidgets(2));
    expect(find.textContaining('Evidence #general'), findsNothing);
    await unmount(t);
  });

  testWidgets('paging asks for the next and the previous page', (t) async {
    final c = await _mount(t, 'dashboard-ready');
    expect(find.widgetWithText(InkWell, 'Previous page'), findsNothing);
    await t.ensureVisible(_text('Next page'));
    await t.tap(_text('Next page'));
    await settle(t);
    expect(c.api.where('GET /raftbench').last.query, {'page': 2});
    c.api.routes['GET /raftbench'] = (call) {
      final json = raftbenchMap('dashboard-ready');
      (json['pagination']! as Map)['page'] = 2;
      return json;
    };
    await c.controller.load();
    await settle(t);
    expect(_text('Page 2 of 2 · 7 findings'), findsOneWidget);
    await t.ensureVisible(_text('Previous page'));
    await t.tap(_text('Previous page'));
    await settle(t);
    expect(c.api.where('GET /raftbench').last.query, {'page': 1});
    await unmount(t);
  });

  testWidgets('partial and stale analyses say so', (t) async {
    await _mount(t, 'dashboard-partial');
    expect(_text('Partial analysis — coverage is incomplete'), findsOneWidget);
    expect(_text('Reading stopped at the character limit.'), findsOneWidget);
    await unmount(t);
    await _mount(t, 'dashboard-stale');
    expect(
      _text(
        'A source message changed or was deleted. The old result is hidden; the service will analyze refreshed material.',
      ),
      findsOneWidget,
    );
    expect(_text('Completion claim needs verification'), findsNothing);
    await unmount(t);
  });

  testWidgets('skipped windows are listed with their unknown outcome', (
    t,
  ) async {
    await _mount(t, 'dashboard-skipped-window');
    expect(
      find.textContaining(
        'was not analyzed after 3 failed attempts. Its outcome is unknown.',
      ),
      findsNWidgets(2),
    );
    expect(find.textContaining('(44 messages)'), findsOneWidget);
    expect(find.textContaining('(Unknown messages)'), findsOneWidget);
    expect(_text('A chunk was skipped.'), findsOneWidget);
    await unmount(t);
  });

  testWidgets(
    'a failed run shows the server reason; a failed agent shows the admin hint',
    (t) async {
      await _mount(t, 'dashboard-failed');
      expect(_text('Analysis did not finish'), findsOneWidget);
      expect(
        _text(
          'The cloud analysis did not finish within 30 minutes. No completed result was accepted.',
        ),
        findsOneWidget,
      );
      await unmount(t);
      await _mount(t, 'dashboard-provision-failed');
      expect(
        _text(
          'The analysis agent could not start. An administrator needs to check the cloud agent service.',
        ),
        findsWidgets,
      );
      expect(_text('Disable and clear results'), findsOneWidget);
      await unmount(t);
    },
  );

  testWidgets('messages outside the range offer the newest source day', (
    t,
  ) async {
    final c = await _mount(t, 'dashboard-outside-window');
    expect(
      _text('Selected channels: 412 messages total; 0 in the analysis range.'),
      findsOneWidget,
    );
    expect(
      _text(
        'Messages exist, but they are outside this range. Choose an earlier start date to analyze them.',
      ),
      findsOneWidget,
    );
    // No empty scan banner for a window with nothing in it.
    expect(
      _text('No messages were read in this window; nothing was analyzed.'),
      findsNothing,
    );
    await t.tap(_text('Analyze the newest source day from 2026-10-23'));
    await settle(t);
    final put = c.api.where('PUT /raftbench').single.data! as Map;
    expect(put['historyFrom'], '2026-10-23T00:00:00.000Z');
    await unmount(t);
  });

  testWidgets('no material: the window had nothing', (t) async {
    await _mount(t, 'dashboard-no-material');
    expect(_text('No material in this window'), findsOneWidget);
    expect(
      _text(
        'No messages were read in this window; nothing was analyzed. Try a channel with recent messages.',
      ),
      findsOneWidget,
    );
    expect(
      _text('No messages exist in the selected channels.'),
      findsOneWidget,
    );
    await unmount(t);
  });

  testWidgets(
    'editing the range on an enabled analysis offers Apply and restarts it',
    (t) async {
      final c = await _mount(t, 'dashboard-ready');
      await t.tap(_text('Sources and historical range'));
      await t.pump();
      expect(_text('Apply changes and restart'), findsNothing);
      await t.tap(_text('Past 30 days'));
      await t.pump();
      expect(_text('Apply changes and restart'), findsOneWidget);
      // Assign is blocked while edits are pending.
      await t.tap(_text('Apply changes and restart'));
      await settle(t);
      final put = c.api.where('PUT /raftbench').single.data! as Map;
      expect(put['expectedRevision'], 3);
      expect(put['historyFrom'], '2026-09-24T00:00:00.000Z');
      expect(_text('Apply changes and restart'), findsNothing);
      await unmount(t);
    },
  );

  testWidgets('service agents: create, open and assign', (t) async {
    final c = await _mount(t, 'dashboard-disabled');
    await t.tap(_text('Create service agent'));
    await settle(t);
    expect(c.api.where('POST /raftbench/agents'), hasLength(1));
    await t.tap(_text('raftbench-service'));
    expect(c.openedAgents, [_agent]);
    await t.tap(find.text('Assign agent').first);
    await settle(t);
    final put = c.api.where('PUT /raftbench/assignment').single.data! as Map;
    expect(put['agentId'], _agent);
    expect(put['expectedRevision'], 0);
    expect(put['channelIds'], [_c1, _c2]);
    await unmount(t);
  });

  testWidgets(
    'an unassigned agent card shows the assigned one without Assign',
    (t) async {
      await _mount(t, 'dashboard-configured-disabled');
      // A configured analysis keeps the agent card collapsed.
      expect(_text('Assigned to this analysis'), findsNothing);
      await t.tap(_text('RaftBench service agent'));
      await t.pump();
      expect(_text('Assigned to this analysis'), findsOneWidget);
      expect(
        find.text('Assign agent'),
        findsOneWidget,
        reason: 'only the other agent',
      );
      await unmount(t);
    },
  );

  testWidgets('a failed load is one generic message', (t) async {
    final c = _Case('dashboard-disabled');
    c.api.routes['GET /raftbench'] = (_) => throw RaftApiException(
      'RaftBench is unavailable on this server.',
      status: 403,
    );
    addTearDown(c.controller.dispose);
    await mountRaftbench(
      t,
      SingleChildScrollView(
        child: RaftbenchHostedAnalysis(
          controller: c.controller,
          allowed: true,
          onOpenAgent: (_) {},
          onOpenMessage: (_, _) {},
        ),
      ),
    );
    c.controller.start();
    await settle(t);
    expect(
      _text(
        'Analysis settings could not be loaded or saved. Check access and try again.',
      ),
      findsOneWidget,
    );
    expect(c.enabled, [false]);
    // The toggle cannot act without a dashboard.
    expect(_text('Enable and start analysis'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('loading shows its status before the first answer', (t) async {
    final c = _Case('dashboard-disabled');
    addTearDown(c.controller.dispose);
    await mountRaftbench(
      t,
      SingleChildScrollView(
        child: RaftbenchHostedAnalysis(
          controller: c.controller,
          allowed: true,
          onOpenAgent: (_) {},
          onOpenMessage: (_, _) {},
        ),
      ),
    );
    expect(_text('Loading analysis settings…'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('Chinese wording (Web zh-cn)', (t) async {
    await _mount(t, 'dashboard-ready', locale: const Locale('zh'));
    expect(_text('对话洞察'), findsOneWidget);
    expect(_text('本轮分析已完成'), findsOneWidget);
    expect(_text('完成声明需要核实'), findsOneWidget);
    await unmount(t);
  });
}
