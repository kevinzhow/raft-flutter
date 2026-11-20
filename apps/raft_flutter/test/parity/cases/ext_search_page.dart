import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'home_tasks/fixture_workspace.dart';
import 'screens/screen_fixture.dart';

class _SearchPageWorkspace extends ParityFixtureWorkspace {
  _SearchPageWorkspace(super.client, super.ctx, this.routes);

  final Map<String, dynamic> routes;

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    final response = routes['GET $path'];
    if (response case {r'$when': final List rules}) {
      for (final rule in rules.cast<Map<String, dynamic>>()) {
        if ((rule['query'] as Map).entries.every(
          (entry) => query?[entry.key] == entry.value,
        )) {
          return rule['answer'];
        }
      }
      return response[r'$default'];
    }
    return response ?? super.query(path, query: query);
  }
}

Widget _build(ParityContext ctx) {
  final fixture = ctx.fixtures['ext:search-page'] as Map<String, dynamic>;
  final state = ctx.props['extCase'];
  final phone = ctx.props['platform'] == 'mobile';
  final scope = state == 'scoped';
  final fx = ctx.fixtureData;
  final wire = ScreenWire(fx);
  final server = RaftRecord(wire.server());
  final routes = <String, dynamic>{
    ...fixture['routes'] as Map<String, dynamic>,
    ...?(fixture['routeSets'] as Map)[state] as Map<String, dynamic>?,
  };
  final client = ScreenFixtureClient(
    (method, path, query) =>
        routes['$method $path'] ?? wire.common(method, path, query),
    user: wire.me(),
    server: server.id,
    origin: parityOrigin,
  );
  final channels = fx['channels'] as Map;
  final workspace = _SearchPageWorkspace(client, ctx, routes)
    ..server = server
    ..channels = [
      for (final name in ['design', 'androidArtifacts'])
        RaftChannel({
          'id': channels[name]['id'],
          'serverId': server.id,
          'name': channels[name]['name'],
          'description': channels[name]['description'],
          'type': 'channel',
          'joined': true,
          'createdAt': channels[name]['createdAtIso'],
        }),
      RaftChannel({
        ...fixture['privateChannel'] as Map<String, dynamic>,
        'serverId': server.id,
      }),
    ]
    ..section = 'search';
  ctx.onDispose(workspace.dispose);

  final now = parityNow(ctx);
  final searchMemory = SearchMemoryStore(
    storage: ParityMemorySearchStorage(),
    clock: () => now,
  );
  return Scaffold(
    body: ResourceView(
      controller: workspace,
      section: 'search',
      mobileRoot: phone && !scope,
      clock: () => now,
      searchMemory: searchMemory,
      restoreSearchState: false,
      initialSearchChannelId: scope ? channels['design']['id'] as String : null,
      initialSearchDeferUntilQuery: scope,
      onSearchQueryCommitted: scope
          ? (_, {destination = SearchQueryDestination.currentPage}) {}
          : null,
      onBack: () {},
      onMessage: (_, _) async {},
    ),
  );
}

final _channel = find.byWidgetPredicate(
  (widget) => widget is TaskSelectionFilter && widget.field == 'Channel',
);

Future<void> _interact(WidgetTester tester, ParityContext ctx) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(EditableText).first, 'android');
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 550));
  switch (ctx.props['extCase']) {
    case 'channel-dropdown':
      await Scrollable.ensureVisible(tester.element(_channel), alignment: .5);
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(_channel.hitTestable()),
        kind: ctx.props['platform'] == 'mobile'
            ? PointerDeviceKind.touch
            : PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(RaftComboboxPanel), findsOneWidget);
    case 'filters':
      for (final (before, after) in const [
        ('Any time', 'Last 7 days'),
        ('Relevant', 'Recent'),
      ]) {
        final trigger = find.widgetWithText(RaftPickerTriggerButton, before);
        await tester.tapAt(
          tester.getCenter(trigger.hitTestable()),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getCenter(find.text(after).hitTestable()),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final button = find.descendant(
        of: _channel,
        matching: find.byType(FocusableActionDetector),
      );
      final channel = tester.widget<FocusableActionDetector>(button.first);
      channel.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(channel.focusNode?.hasPrimaryFocus, isTrue);
    case 'scoped':
      expect(find.byKey(const Key('scoped-search-back')), findsOneWidget);
      expect(find.text('Search everywhere for “android”'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('search-message:msg-scoped-android')),
        findsOneWidget,
      );
    case 'artifacts':
      expect(
        find.byKey(
          const ValueKey(
            'app:artifacts:pt_00000000-0000-4000-8000-000000000001',
          ),
        ),
        findsOneWidget,
      );
  }
}

final _case = ParityCase(
  widgets: const [
    'raft_flutter:ResourceView(search)',
    'raft_flutter:ResourceSearchResults',
    'raft_flutter:SearchFilterBar',
    'raft_ui:RaftPickerTriggerButton',
    'raft_ui:RaftComboboxPanel',
  ],
  notes: 'Mounted Search page with query entry and live fixture routes.',
  build: _build,
  interact: _interact,
);

final Map<String, ParityCase> extSearchPageCases = {
  for (final (platform, state) in const [
    ('phone', 'results'),
    ('phone', 'channel-dropdown'),
    ('phone', 'scoped'),
    ('desktop', 'results'),
    ('desktop', 'filters'),
    ('desktop', 'channel-dropdown'),
    ('desktop', 'artifacts'),
  ])
    for (final theme in [
      if (platform == 'desktop' || state == 'scoped') 'raft-light',
      'raft-dark',
    ])
      'components.search-ext.$platform.$state.$theme': _case,
};
