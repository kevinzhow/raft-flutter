import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityWorkspace, activityFixture;
import 'support/app_services_fixture.dart';

const _windows = [
  (Size(856, 944), TargetPlatform.android, 32.0, 0.0),
  (Size(944, 856), TargetPlatform.android, 32.0, 24.0),
  (Size(390, 844), TargetPlatform.linux, 0.0, 0.0),
];

Future<ActivityWorkspace> _mount(
  WidgetTester t,
  Size size,
  double bottom,
  double left,
  String pack,
) async {
  DevicePreferences.reset();
  SharedPreferences.setMockInitialValues({});
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..viewPadding = FakeViewPadding(top: 24, left: left, bottom: bottom)
    ..padding = FakeViewPadding(top: 24, left: left, bottom: bottom);
  addTearDown(t.view.reset);
  addTearDown(DevicePreferences.reset);
  final (client, w) = activityFixture();
  addTearDown(w.dispose);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(Duration.zero);
  });
  client.responses['POST /feature-flags/evaluate'] = {
    'evaluations': [
      {
        'key': ActivityRolloutFlags.activityConversationListKey,
        'enabled': true,
      },
    ],
  };
  w
    ..loading = false
    ..section = 'activity';
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(pack: packForThemeId(pack)),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  expect(find.byType(WorkspaceView), findsOneWidget);
  expect(find.byType(ResourceView), findsOneWidget);
  expect(find.byType(RaftConversationListRow), findsWidgets);
  return w;
}

Finder _list(String view) =>
    find.byKey(PageStorageKey(('resource-list', 'activity', view)));

void main() {
  for (final (size, platform, bottom, left) in _windows) {
    for (final pack in [
      raftThemePackId,
      elegantThemePackId,
      brutalThemePackId,
    ]) {
      testWidgets(
        '$pack ${size.width}x${size.height} Activity footer clears one system inset',
        (t) async {
          final w = await _mount(t, size, bottom, left, pack);
          expect(
            RaftInteraction.of(t.element(find.byType(ResourceView))).touch,
            platform == TargetPlatform.android,
          );
          final list = _list('all');
          expect(list, findsOneWidget);
          final viewport = t.getRect(list);
          expect(viewport.bottom, closeTo(size.height, .01));
          expect(viewport.left, greaterThanOrEqualTo(left));

          // Hold the appended page so the actual footer remains available to
          // inspect and tap even when near-end loading starts automatically.
          final nextPage = Completer<void>();
          w.hold = nextPage;
          addTearDown(() {
            if (!nextPage.isCompleted) nextPage.complete();
          });
          await t.drag(list, const Offset(0, -6000));
          await t.pumpAndSettle();
          final footer = find.widgetWithText(RaftButton, 'Load more');
          expect(footer, findsOneWidget);
          final button = t.getRect(footer);
          expect(
            button.bottom,
            closeTo(viewport.bottom - bottom, .01),
            reason: 'The final control must clear the system bar exactly once.',
          );
          expect(button.left, greaterThanOrEqualTo(left));
          expect(footer.hitTestable(), findsOneWidget);
          await t.tap(footer);
          await t.pump();
          expect(
            w.inboxQueries.where((query) => query['offset'] == 30),
            hasLength(1),
          );
          nextPage.complete();
          await t.pumpAndSettle();
          expect(find.text('Load more'), findsNothing);
          final dynamic state = t.state(find.byType(ResourceView));
          expect(state.rows, hasLength(60));
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }

  testWidgets(
    'retained Activity pager page keeps its final row above the system bar',
    (t) async {
      await _mount(t, const Size(700, 900), 32, 0, raftThemePackId);
      final all = _list('all');
      await t.drag(all, const Offset(0, -6000));
      await t.pumpAndSettle();
      await t.drag(all, const Offset(-600, 0));
      await t.pumpAndSettle();
      final dynamic state = t.state(find.byType(ResourceView));
      expect(state.filter, 'unread');
      // Bring the visited All page partly back into the viewport. A fully
      // offscreen keep-alive child has no valid global paint transform.
      final swipe = await t.startGesture(t.getCenter(_list('unread')));
      await swipe.moveBy(const Offset(20, 0));
      await t.pump();
      await swipe.moveBy(const Offset(200, 0));
      await t.pump();
      final page = t.widget<PageView>(
        find
            .ancestor(of: _list('unread'), matching: find.byType(PageView))
            .first,
      );
      expect(page.controller!.page, allOf(greaterThan(0), lessThan(1)));
      final retained = find.byKey(
        const PageStorageKey(('resource-list', 'activity', 'all')),
        skipOffstage: false,
      );
      expect(retained, findsOneWidget);
      final screen = Offset.zero & const Size(700, 900);
      final retainedBounds = t.getRect(retained);
      final visible = retainedBounds.intersect(screen);
      expect(visible.width, greaterThan(0));
      expect(visible.width, lessThan(retainedBounds.width));
      expect(visible.height, greaterThan(0));
      expect(
        t.widget<ListView>(retained).padding!.resolve(TextDirection.ltr).bottom,
        32,
      );
      // The inactive projection has no paging footer. Measure its reachable
      // end rather than the offset retained from the taller active list.
      final scroll = t.widget<ListView>(retained).controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pump();
      final lastRow = find
          .descendant(
            of: retained,
            matching: find.byType(RaftConversationListRow, skipOffstage: false),
            skipOffstage: false,
          )
          .last;
      try {
        expect(t.getRect(retained).bottom, closeTo(900, .01));
        final rowBounds = t.getRect(lastRow);
        expect(rowBounds.overlaps(screen), isTrue);
        // Auto-pagination can grow the lazy window after its prior maximum
        // was measured. The visible final row must remain above the bar;
        // only the list's system padding is required to be exactly once.
        expect(rowBounds.bottom, lessThanOrEqualTo(900 - 32 + .01));
        expect(t.takeException(), isNull);
      } finally {
        await swipe.up();
        await t.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
