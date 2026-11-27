import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/agent_token_usage.dart';

void main() {
  test('matches the Web v1.24 parity fixture for the week and its last day', () {
    final fixture = jsonDecode(
      File('../../tool/parity-ext/fixtures/members-pages.json')
          .readAsStringSync(),
    ) as Map;
    final report = AgentUsageReport.parse(
      fixture['routeSets']['agent-usage-ready']['GET /servers/visual-server/agent-usage'],
    );
    final agent = report.agentIds.single;
    final week = report.figures(AgentUsagePeriod.week, agentId: agent);
    expect(week.counts.total(withCacheReads: false), 22500);
    expect(week.counts.total(), 76500);
    expect(week.models.map((model) => model.tokens), [19000, 3500]);
    expect(week.context, (used: 4800, window: 16000));
    final today = report.figures(
      AgentUsagePeriod.week,
      agentId: agent,
      selectedDay: report.to,
    );
    expect(today.counts.total(withCacheReads: false), 3500);
    expect(today.counts.total(), 11900);
  });

  test('requests the selected period and its comparison in UTC', () {
    expect(
      agentUsageQuery(
        AgentUsagePeriod.month,
        DateTime.parse('2026-11-27T02:00:00+09:00'),
        agentId: 'a1',
      ),
      {'from': '2026-09-28', 'to': '2026-11-26', 'agents': 'a1'},
    );
  });

  test('groups days and models with Web total and prior-day rules', () {
    final report = AgentUsageReport.parse({
      'from': '2026-11-14',
      'to': '2026-11-27',
      'as_of': '2026-11-27T12:00:00Z',
      'since': '2026-11-15',
      'visible_agents': 2,
      'agents': [
        {'agent_id': 'a1', 'since': '2026-11-18', 'usage_reported': true},
        {'agent_id': 'a2', 'usage_reported': false},
      ],
      'context': [
        {'agent_id': 'a1', 'context_used': 2000, 'context_window': 16000},
      ],
      'rows': [
        {
          'agent_id': 'a1',
          'day': '2026-11-19',
          'runtime': 'claude',
          'model': 'sonnet',
          'input_new': 100,
        },
        {
          'agent_id': 'a1',
          'day': '2026-11-26',
          'runtime': 'claude',
          'model': 'sonnet',
          'input_new': 120,
          'cache_read': 40,
          'output': 60,
          'reasoning_output': 35,
          'turns': 2,
        },
        {
          'agent_id': 'a1',
          'day': '2026-11-27',
          'runtime': 'claude',
          'model': 'haiku',
          'input_new': 10,
          'output': 0,
          'turns': 1,
        },
        {'agent_id': 'a2', 'day': '2026-11-27', 'input_new': 900},
      ],
    });

    final figures = report.figures(AgentUsagePeriod.week, agentId: 'a1');
    expect(figures.counts.total(withCacheReads: false), 190);
    expect(figures.counts.total(), 230);
    expect(figures.counts.cacheWrite, isNull);
    expect(figures.counts.reasoning, 35);
    expect(figures.counts.turns, 3);
    expect(figures.models.map((model) => model.tokens), [180, 10]);
    expect(figures.days.last.partial, isTrue);
    expect(figures.context, (used: 2000, window: 16000));
    final past = report.figures(
      AgentUsagePeriod.week,
      agentId: 'a1',
      selectedDay: '2026-11-26',
    );
    expect((past.compared, past.base, past.baseDay), (180, 100, '2026-11-19'));
    final idle = report.figures(
      AgentUsagePeriod.week,
      agentId: 'a1',
      selectedDay: '2026-11-25',
    );
    expect(idle.counts.total(), 0);
    expect(
      report.figures(AgentUsagePeriod.week, agentId: 'a2').supported,
      isFalse,
    );
  });
}
