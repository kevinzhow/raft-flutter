// The RaftBench page and its gates (Web RaftBenchPage.tsx): owner / admin
// only, then the server flag, then the three sections and the scope picker.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raftbench_flag_controller.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/management_support.dart'
    show cachedServerFlag, pageIdentity, rememberServerFlag;
import 'package:raft_flutter/features/raftbench_page.dart';

import 'support/integ_fixture.dart';
import 'support/raftbench_fixture.dart';
import 'support/raftbench_host.dart';

const _general = '5d0b8c1e-2a63-4b27-9c1f-0a1b2c3d4e01';
const _random = '5d0b8c1e-2a63-4b27-9c1f-0a1b2c3d4e02';

class _Page {
  _Page(this.w, this.api, this.flag);
  final WorkspaceController w;
  final IntegAdapter api;
  final RaftbenchFlagController flag;
}

/// [flagAnswer] null: the evaluation fails (undetermined).
Future<_Page> _mount(
  WidgetTester t, {
  String role = 'owner',
  bool? flagAnswer = true,
  bool resolveFlag = true,
  bool hangFlag = false,
  String dashboard = 'dashboard-ready',
  Size size = raftbenchDesktop,
  Locale locale = const Locale('en'),
}) async {
  final made = (await t.runAsync(() => integFixture(role)))!;
  final w = made.$1, api = made.$2;
  addTearDown(w.dispose);
  w.channels = [
    RaftChannel({
      'id': _general,
      'name': 'general',
      'type': 'channel',
      'joined': true,
      'lastMessageAt': '2026-10-23T10:00:00Z',
    }),
    RaftChannel({
      'id': _random,
      'name': 'random',
      'type': 'channel',
      'joined': false,
      'lastMessageAt': '2026-10-23T12:00:00Z',
    }),
    RaftChannel({
      'id': 'p1',
      'name': 'secret',
      'type': 'private',
      'joined': false,
    }),
    RaftChannel({
      'id': 'p2',
      'name': 'mine',
      'type': 'private',
      'joined': true,
    }),
    RaftChannel({
      'id': 'a1',
      'name': 'old',
      'type': 'channel',
      'joined': true,
      'archivedAt': '2026-10-01T00:00:00Z',
    }),
  ];
  api.routes['POST /feature-flags/evaluate'] = (_) {
    if (hangFlag) return Completer<Object?>().future;
    if (flagAnswer == null) throw RaftApiException('down', status: 503);
    return {
      'evaluations': [
        {'key': 'raftbench_overview_v0', 'enabled': flagAnswer},
      ],
    };
  };
  api.routes['GET /raftbench'] = (_) => raftbenchFixture(dashboard);
  api.routes['GET /raftbench/agents'] = (_) =>
      raftbenchFixture('service-agents');
  api.routes['GET /tasks/server/snapshot-metrics'] = (_) =>
      raftbenchFixture('snapshot-metrics');
  api.routes['GET /billing/hosted-runtime-usage'] = (_) =>
      raftbenchFixture('hosted-runtime-usage');
  api.routes['GET /agents/7a1e3c40-9d2b-4f56-8e0a-1b2c3d4e5f60/hosted-runtime/model'] =
      (_) => {'label': 'DeepSeek Flash'};
  // The period windows follow the clock; answer for the window asked.
  api.routes['GET /tasks/server/period-metrics'] = (o) {
    final q = o.queryParameters;
    return {
      ...raftbenchMap('period-metrics'),
      'from': q['from'],
      'midpoint': q['midpoint'],
      'to': q['to'],
    };
  };
  final flag = RaftbenchFlagController(
    request: w.client.request,
    identity: () => pageIdentity(w),
    serverId: () => w.server?.id,
    cached: () => cachedServerFlag(w, 'raftbench_overview_v0'),
    remember: (enabled, identity) =>
        rememberServerFlag(w, 'raftbench_overview_v0', enabled, identity),
    retryDelay: Duration.zero,
  );
  addTearDown(flag.dispose);
  if (resolveFlag) await t.runAsync(flag.refresh);
  await mountRaftbench(
    t,
    RaftbenchPage(controller: w, flag: flag),
    size: size,
    locale: locale,
  );
  await settle(t);
  await settle(t);
  return _Page(w, api, flag);
}

void main() {
  testWidgets(
    'a member sees the administrators-only notice and nothing is read',
    (t) async {
      final p = await _mount(t, role: 'member');
      expect(
        find.text('RaftBench is for server administrators'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Only this server’s owner or administrators can open this overview. Existing channel permissions still apply.',
        ),
        findsOneWidget,
      );
      expect(find.text('Workspace efficiency and cost'), findsNothing);
      expect(
        p.api.calls.where(
          (c) => c.path.startsWith('/raftbench') || c.path.startsWith('/tasks'),
        ),
        isEmpty,
      );
      await unmount(t);
    },
  );

  testWidgets('a disabled rollout shows the not-enabled notice', (t) async {
    final p = await _mount(t, role: 'admin', flagAnswer: false);
    expect(
      find.text('RaftBench is not enabled for this server'),
      findsOneWidget,
    );
    expect(
      find.text(
        'This pilot is off by default and only available to explicitly enrolled servers.',
      ),
      findsOneWidget,
    );
    expect(p.api.calls.where((c) => c.path.startsWith('/raftbench')), isEmpty);
    await unmount(t);
  });

  testWidgets(
    'an unresolved rollout shows no notice yet (the first frame is final)',
    (t) async {
      await _mount(t, resolveFlag: false, hangFlag: true);
      expect(
        find.text('RaftBench is not enabled for this server'),
        findsNothing,
      );
      expect(find.text('Workspace efficiency and cost'), findsNothing);
      await unmount(t);
    },
  );

  for (final (name, size) in [
    ('desktop', raftbenchDesktop),
    ('phone', raftbenchPhone),
  ]) {
    testWidgets('owner on an enrolled server sees the three sections ($name)', (
      t,
    ) async {
      final p = await _mount(t, size: size);
      expect(find.text('Workspace efficiency and cost'), findsOneWidget);
      expect(
        find.text(
          'Two views: task metrics from the database and AI insights from conversations.',
        ),
        findsOneWidget,
      );
      // Section links, scope, the two panels and the collapsed legacy rules.
      expect(find.text('Tasks and cost'), findsWidgets);
      expect(find.text('Conversation insights'), findsWidgets);
      expect(find.text('Task metrics and phrase-scan scope'), findsWidgets);
      expect(find.text('Workspace overview'), findsWidgets);
      expect(
        find.byKey(const ValueKey('raftbench-task-snapshot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('raftbench-hosted-analysis')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('raftbench-legacy-rules')),
        findsOneWidget,
      );
      expect(find.text('Legacy phrase and repetition rules'), findsOneWidget);
      expect(find.text('Analysis complete'), findsOneWidget);
      // The workspace scope reads task aggregates without a channel.
      expect(
        p.api.calls
            .firstWhere((c) => c.path == '/tasks/server/snapshot-metrics')
            .uri
            .queryParameters,
        isEmpty,
      );
      // A confirmed rollout shows no pause banner.
      expect(
        find.textContaining('Rollout status could not be refreshed'),
        findsNothing,
      );
      await unmount(t);
    });
  }

  testWidgets('only active channels the viewer can read are candidates', (
    t,
  ) async {
    final p = await _mount(t, dashboard: 'dashboard-disabled');
    // Public (joined or not) and joined private channels; not a private channel
    // the viewer has not joined, nor an archived one.
    expect(find.text('general'), findsOneWidget);
    expect(find.text('random'), findsOneWidget);
    expect(find.text('mine'), findsOneWidget);
    expect(find.text('secret'), findsNothing);
    expect(find.text('old'), findsNothing);
    expect(p.api.calls, isNotEmpty);
    await unmount(t);
  });

  testWidgets('choosing a channel narrows the task reads to it', (t) async {
    final p = await _mount(t);
    await t.tap(find.text('Workspace overview').first);
    await settle(t);
    await t.tap(find.text('random').last);
    await settle(t);
    await settle(t);
    final reads = p.api.calls
        .where((c) => c.path == '/tasks/server/snapshot-metrics')
        .toList();
    expect(reads.length, greaterThan(1));
    expect(reads.last.uri.queryParameters, {'channelId': _random});
    // The spend stays server-wide.
    expect(
      p.api.calls
          .where((c) => c.path == '/billing/hosted-runtime-usage')
          .last
          .uri
          .queryParameters
          .containsKey('channelId'),
      isFalse,
    );
    await unmount(t);
  });

  testWidgets(
    'an undetermined rollout keeps the confirmed page and pauses analysis',
    (t) async {
      final p = await _mount(t);
      p.api.routes['POST /feature-flags/evaluate'] = (_) =>
          throw RaftApiException('down', status: 503);
      await t.runAsync(p.flag.refresh);
      await settle(t);
      expect(
        find.text(
          'Rollout status could not be refreshed. Your current evidence and review are preserved; new reads are paused until the status is confirmed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Workspace efficiency and cost'), findsOneWidget);
      // Analysis data is hidden while reads are paused; no new dashboard read.
      final reads = p.api.calls.where((c) => c.path == '/raftbench').length;
      await t.pump(const Duration(seconds: 6));
      expect(p.api.calls.where((c) => c.path == '/raftbench').length, reads);
      await unmount(t);
    },
  );

  testWidgets('the section links scroll to their section', (t) async {
    await _mount(t, size: raftbenchPhone);
    final aiTitle = find.byKey(const ValueKey('raftbench-hosted-analysis'));
    final before = t.getTopLeft(aiTitle).dy;
    await t.tap(find.text('Reads selected channels · no DM replies').first);
    await t.pumpAndSettle();
    expect(t.getTopLeft(aiTitle).dy, lessThan(before));
    await unmount(t);
  });

  testWidgets('Chinese wording (Web zh-cn)', (t) async {
    await _mount(t, locale: const Locale('zh'));
    expect(find.text('工作区效率与成本'), findsOneWidget);
    await unmount(t);
  });

  test('the Web /raftbench URL is the RaftBench Settings page', () {
    final location = RaftLocation.fromUri(Uri.parse('/s/acme/raftbench'));
    expect(location.route, RaftRoute.settings);
    expect(location.settingsPath, ['raftbench']);
    expect(
      RaftLocation.fromUri(Uri.parse('/s/acme/settings/raftbench'))
          .settingsPath,
      ['raftbench'],
    );
    expect(
      RaftLocation.fromUri(Uri.parse('/s/acme/raftbench/extra')).route,
      RaftRoute.unknown,
    );
  });
}
