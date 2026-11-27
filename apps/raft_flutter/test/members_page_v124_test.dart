import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart' show RaftFitToolbar;

import 'support/close_support.dart';

void main() {
  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('directory opens the row menu at $size on $platform', (
      tester,
    ) async {
      final (workspace, api) = await mountWorkspace(
        tester,
        size,
        platform: platform,
      );
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'agent_usage_v0', 'enabled': false},
        ],
      };
      workspace.section = 'members';
      workspace.notifyListeners();
      await frames(tester);
      final row = find.byKey(const ValueKey('desktop-directory-agent-a1'));
      await tester.ensureVisible(row);
      if (platform == TargetPlatform.android) {
        await tester.longPress(row);
      } else {
        await tester.tapAt(
          tester.getCenter(row),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
      }
      await frames(tester);
      expect(find.byKey(const ValueKey('member-menu-message')), findsOneWidget);
      expect(find.byKey(const ValueKey('members-view-usage')), findsNothing);
      expect(
        api.calls.where((call) => call.path == '/servers/s1/agent-usage'),
        isEmpty,
      );
      if (platform == TargetPlatform.android) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await frames(tester);
        await tester.tap(row);
        await frames(tester);
        final list = find.byKey(const PageStorageKey('desktop-directory-list'));
        final profile = find.byKey(const Key('profile-panel'));
        expect(profile, findsOneWidget);
        expect(list, findsOneWidget);
        expect(
          tester.getRect(list).right,
          lessThanOrEqualTo(tester.getRect(profile).left),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Members route filters, searches, and shows agent usage', (
    tester,
  ) async {
    final (workspace, api) = await mountWorkspace(
      tester,
      const Size(1280, 900),
      platform: TargetPlatform.linux,
    );
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'agent_usage_v0', 'enabled': true},
      ],
    };
    var usageReads = 0;
    api.routes['GET /servers/s1/agent-usage'] = (request) {
      if (usageReads++ == 0) return (503, {'error': 'Fixture unavailable'});
      final from = request.queryParameters['from'] as String;
      final to = request.queryParameters['to'] as String;
      return {
        'from': from,
        'to': to,
        'as_of': '${to}T12:00:00Z',
        'since': from,
        'visible_agents': 1,
        'agents': [
          {'agent_id': 'a1', 'since': from, 'usage_reported': true},
        ],
        'rows': [
          {
            'day': to,
            'agent_id': 'a1',
            'runtime': 'claude',
            'model': 'sonnet',
            'input_new': 120,
            'cache_read': 40,
            'output': 60,
            'reasoning_output': 35,
            'turns': 2,
          },
        ],
        'context': [],
      };
    };
    workspace.section = 'members';
    workspace.notifyListeners();
    await frames(tester);
    final bob = find.byKey(const ValueKey('desktop-directory-human-bob'));
    final agent = find.byKey(const ValueKey('desktop-directory-agent-a1'));
    expect(bob, findsOneWidget);
    expect(agent, findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('members-search')), 'bOB');
    await frames(tester);
    expect(bob, findsOneWidget);
    expect(agent, findsNothing);
    await tester.enterText(find.byKey(const ValueKey('members-search')), '');
    await tester.tap(find.byKey(const ValueKey('members-tab-agent')));
    await frames(tester);
    expect(bob, findsNothing);
    expect(agent, findsOneWidget);
    await tester.tapAt(
      tester.getCenter(agent),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await frames(tester);
    expect(find.byKey(const ValueKey('member-menu-message')), findsOneWidget);
    await tester.tapAt(const Offset(700, 750));
    await frames(tester);

    final view = find.byKey(const ValueKey('members-view-usage'));
    await tester.tap(view);
    await frames(tester);
    expect(find.text('Could not load usage'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await frames(tester);
    expect(find.text('Could not load usage'), findsNothing);
    final toolbar = find.byType(RaftFitToolbar);
    for (final key in [
      'members-usage-filter',
      'agent-usage-period',
      'members-view-usage',
      'desktop-directory-add-agent',
      'members-add-agent-options',
    ]) {
      final control = find.byKey(ValueKey(key));
      expect(find.descendant(of: toolbar, matching: control), findsOneWidget);
      expect(
        tester.getCenter(control).dy,
        closeTo(tester.getCenter(view).dy, 3),
      );
    }
    expect(
      find.text('Share of total counts the 1 agent you can see.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('members-group-select')));
    await frames(tester);
    await tester.tap(find.text('By computer'));
    await frames(tester);
    expect(find.text('External & cloud  1'), findsOneWidget);
    final headline = find.byKey(const ValueKey('agent-usage-headline'));
    expect(tester.widget<Text>(headline).data, '180');
    await tester.tap(find.byKey(const ValueKey('agent-usage-cache-reads')));
    await frames(tester);
    expect(tester.widget<Text>(headline).data, '220');
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final bar = find.byKey(ValueKey('agent-usage-day-$today'));
    await tester.ensureVisible(bar);
    await tester.tapAt(tester.getCenter(bar), kind: PointerDeviceKind.mouse);
    await frames(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await frames(tester);
    expect(tester.widget<Text>(headline).data, '0');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester);
    expect(tester.widget<Text>(headline).data, '220');
    expect(
      api.calls.where((call) => call.path == '/servers/s1/agent-usage'),
      hasLength(2),
    );
    await tester.tap(find.byKey(const ValueKey('members-usage-filter')));
    await frames(tester);
    final picker = find.byKey(const ValueKey('members-usage-filter-menu'));
    await tester.enterText(
      find.descendant(of: picker, matching: find.byType(EditableText)),
      'cindy',
    );
    final agentChoice = find.byKey(
      const ValueKey('members-usage-filter-option-agent:a1'),
    );
    await frames(tester);
    expect(agentChoice, findsOneWidget);
    expect(
      find.byKey(const ValueKey('members-usage-filter-option-runtime:claude')),
      findsNothing,
    );
    await tester.tap(agentChoice);
    await frames(tester);
    expect(picker, findsOneWidget);
    expect(tester.widget<Text>(headline).data, '220');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester);
    expect(picker, findsNothing);
    expect(usageReads, 2);
    await tester.tap(find.byKey(const ValueKey('agent-usage-period')));
    await frames(tester);
    await tester.tap(find.text('14 days'));
    await frames(tester);
    final query = api.calls
        .lastWhere((call) => call.path == '/servers/s1/agent-usage')
        .queryParameters;
    expect(
      DateTime.parse(query['to'] as String)
          .difference(DateTime.parse(query['from'] as String))
          .inDays,
      27,
    );
    expect(find.text('Could not load usage'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('removal waits for impact and removes through the profile', (
    tester,
  ) async {
    final (workspace, api) = await mountWorkspace(
      tester,
      const Size(1280, 900),
    );
    api.routes['GET /servers/s1/members/bob/profile'] = (_) => {
      'userId': 'bob',
      'name': 'Bob',
      'role': 'member',
    };
    final impact = Completer<Object?>();
    api.routes['GET /servers/s1/members/bob/removal-impact'] = (_) =>
        impact.future;
    var removed = false;
    api.routes['DELETE /servers/s1/members/bob'] = (_) {
      removed = true;
      api.routes['GET /servers/s1/members'] = (_) => [];
      return {'ok': true};
    };
    workspace.section = 'members';
    workspace.notifyListeners();
    await frames(tester);
    final bob = find.byKey(const ValueKey('desktop-directory-human-bob'));
    await tester.tap(bob);
    await frames(tester);
    final remove = find.byKey(const ValueKey('member-remove'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await frames(tester);
    expect(
      find.text('Checking which Computers this takes offline…'),
      findsOneWidget,
    );
    final confirm = find.byKey(const ValueKey('human-remove-member-confirm'));
    await tester.tap(confirm, warnIfMissed: false);
    await frames(tester, 2);
    expect(removed, isFalse);
    impact.complete({
      'computers': 1,
      'computerNames': ['Studio Mac'],
      'othersAgents': 2,
    });
    await frames(tester);
    expect(find.textContaining('Studio Mac'), findsOneWidget);
    await tester.tap(confirm);
    await frames(tester);
    expect(removed, isTrue);
    expect(confirm, findsNothing);
    expect(bob, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
