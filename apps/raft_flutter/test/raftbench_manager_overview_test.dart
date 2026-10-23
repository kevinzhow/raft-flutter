// "Tasks and cost" as the owner sees it (Web ManagerOverview.tsx): values,
// partial failures, an unavailable bill and the refresh.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raftbench_overview_controller.dart';
import 'package:raft_flutter/features/raftbench_manager_overview.dart';

import 'support/raftbench_fixture.dart';
import 'support/raftbench_host.dart';

RaftbenchApi _api() => RaftbenchApi()
  ..routes['GET /tasks/server/snapshot-metrics'] = ((_) =>
      raftbenchFixture('snapshot-metrics'))
  ..routes['GET /tasks/server/period-metrics'] = ((_) =>
      raftbenchFixture('period-metrics'))
  ..routes['GET /billing/hosted-runtime-usage'] = ((_) =>
      raftbenchFixture('hosted-runtime-usage'));

RaftbenchOverviewController _controller(RaftbenchApi api) =>
    RaftbenchOverviewController(
      request: api.request,
      identity: () => 'g|u|s|owner',
      roleAllowed: () => true,
      channelId: null,
      now: () => raftbenchNow,
    );

Future<RaftbenchOverviewController> _mount(
  WidgetTester t,
  RaftbenchApi api, {
  Size size = raftbenchDesktop,
  Locale locale = const Locale('en'),
}) async {
  final controller = _controller(api);
  addTearDown(controller.dispose);
  await mountRaftbench(
    t,
    SingleChildScrollView(
      child: RaftbenchManagerOverview(controller: controller),
    ),
    size: size,
    locale: locale,
  );
  await t.runAsync(controller.load);
  await t.pump();
  return controller;
}

void main() {
  for (final (name, size) in [
    ('desktop', raftbenchDesktop),
    ('phone', raftbenchPhone),
  ]) {
    testWidgets(
      'shows the task snapshot, the comparison and the spend ($name)',
      (t) async {
        await _mount(t, _api(), size: size);
        expect(find.text('Tasks and cost'), findsOneWidget);
        expect(
          find.text('Database metrics · no AI scan needed'),
          findsOneWidget,
        );
        // Snapshot tiles.
        for (final label in [
          'All tasks',
          'Awaiting review',
          'In progress',
          'To do',
          'Done',
          'Closed',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text('10'), findsOneWidget);
        expect(
          find.text(
            'Creation → done: median 5.5 h, 90th percentile 26.3 h (3 valid completed tasks). Calendar time includes waiting.',
          ),
          findsOneWidget,
        );
        // Period comparison, current / previous.
        expect(find.text('4 / 1'), findsOneWidget);
        expect(find.text('5.5 h / 30 h'), findsOneWidget);
        expect(find.text('8.3 h / 30 h'), findsOneWidget);
        // Server-wide spend, estimated.
        expect(
          find.byKey(const ValueKey('raftbench-cost-comparison')),
          findsOneWidget,
        );
        expect(
          (t.widget(
            find.byKey(const ValueKey('raftbench-cost-comparison')),
          ) as Text).data,
          r'$1.63 / $0.75',
        );
        expect(
          find.text(
            'Estimated, in USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Some usage has no price and is not included.'),
          findsNothing,
        );
        await unmount(t);
      },
    );
  }

  testWidgets('a collapsed Sources and limits opens on tap', (t) async {
    await _mount(t, _api());
    expect(
      find.textContaining('Current task states across accessible task sources'),
      findsNothing,
    );
    await t.tap(find.text('Sources and limits').first);
    await t.pump();
    expect(
      find.textContaining('Current task states across accessible task sources'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '3 accessible task sources · created 2026-09-02–2026-10-23 · last task update 2026-10-23 (UTC)',
      ),
      findsOneWidget,
    );
    expect(find.text('Created by people: 6 · by agents: 4.'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('no completed task in either period says so', (t) async {
    final api = _api()
      ..routes['GET /tasks/server/period-metrics'] = ((_) {
        final json = raftbenchMap('period-metrics');
        json['current'] = {
          'completed': 0,
          'durationSamples': 0,
          'meanHours': null,
          'medianHours': null,
        };
        json['previous'] = {
          'completed': 0,
          'durationSamples': 0,
          'meanHours': null,
          'medianHours': null,
        };
        return json;
      });
    await _mount(t, api);
    expect(
      find.text('No tasks were completed in either comparison period.'),
      findsOneWidget,
    );
    expect(find.text('Completed · current / previous'), findsNothing);
    await unmount(t);
  });

  testWidgets('a failing aggregate shows its own error and no inferred total', (
    t,
  ) async {
    final api = _api()
      ..routes['GET /tasks/server/snapshot-metrics'] = ((_) =>
          throw RaftApiException('boom', status: 500));
    await _mount(t, api);
    expect(
      find.text(
        'Task aggregation is unavailable. No task totals have been inferred from a partial sample.',
      ),
      findsOneWidget,
    );
    expect(find.text('All tasks'), findsNothing);
    // The other aggregates are unaffected.
    expect(find.text('4 / 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('raftbench-cost-comparison')),
      findsOneWidget,
    );
    await unmount(t);
  });

  testWidgets('billing 404 says unavailable, not zero cost', (t) async {
    final api = _api()
      ..routes['GET /billing/hosted-runtime-usage'] = ((_) =>
          throw RaftApiException('Not found', status: 404));
    await _mount(t, api);
    expect(
      find.text(
        'Cloud agent billing is not available for this server. This does not mean zero cost.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('raftbench-cost-comparison')),
      findsNothing,
    );
    await unmount(t);
  });

  testWidgets('a billing failure and unpriced usage', (t) async {
    final failing = _api()
      ..routes['GET /billing/hosted-runtime-usage'] = ((_) =>
          throw RaftApiException('Forbidden', status: 403));
    await _mount(t, failing);
    expect(
      find.text(
        'Could not read the requested scope. Check your access and retry. Previous evidence has been cleared.',
      ),
      findsOneWidget,
    );
    await unmount(t);

    final unpriced = _api()
      ..routes['GET /billing/hosted-runtime-usage'] = ((_) {
        final json = raftbenchMap('hosted-runtime-usage');
        json['estimated'] = false;
        (json['periods']! as List)[3] = {
          'start': '2026-10-20T00:00:00.000Z',
          'totalUsd': 0.004,
          'unpriced': ['model-x'],
        };
        return json;
      });
    await _mount(t, unpriced);
    expect(
      find.text('Some usage has no price and is not included.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'In USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.',
      ),
      findsOneWidget,
    );
    // A positive amount under a cent is "under", never $0.00.
    await unmount(t);
  });

  testWidgets('refresh reads the aggregates again and is off while loading', (
    t,
  ) async {
    final api = _api();
    final controller = await _mount(t, api);
    expect(api.where('GET /billing/hosted-runtime-usage'), hasLength(1));
    await t.tap(find.text('Refresh task and cost metrics'));
    await t.pump();
    await settle(t);
    expect(api.where('GET /billing/hosted-runtime-usage'), hasLength(2));
    expect(controller.anyLoading, isFalse);
    await unmount(t);
  });

  testWidgets('Chinese wording (Web zh-cn)', (t) async {
    await _mount(t, _api(), locale: const Locale('zh'));
    expect(find.text('任务与费用'), findsOneWidget);
    expect(find.text('云端 agent 运行费用 · 整个 server'), findsOneWidget);
    expect(find.text('读取总览'), findsOneWidget);
    await unmount(t);
  });
}
