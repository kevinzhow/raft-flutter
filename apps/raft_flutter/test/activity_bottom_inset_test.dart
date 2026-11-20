import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
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

Future<void> _mount(
  WidgetTester t,
  ActivityWorkspace w,
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
  expect(find.byType(RaftInboxItem), findsWidgets);
}

Finder _list(String view) =>
    find.byKey(PageStorageKey(('resource-list', 'activity', view)));

void main() {
  for (final (size, platform, bottom, left) in _windows) {
    for (final pack in [raftThemePackId]) {
      testWidgets(
        '$pack ${size.width}x${size.height} Activity footer clears one system inset',
        (t) async {
          final (client, w) = activityFixture();
          final nextPage = Completer<void>();
          try {
            await _mount(t, w, size, bottom, left, pack);
            expect(
              RaftInteraction.of(t.element(find.byType(ResourceView))).touch,
              platform == TargetPlatform.android,
            );
            final list = _list('all');
            expect(list, findsOneWidget);
            final viewport = t.getRect(list);
            final bar = find.byKey(const Key('workspace-mobile-navigation'));
            final docked = platform == TargetPlatform.linux;
            expect(bar, docked ? findsOneWidget : findsNothing);
            final remainingInset = docked ? 0.0 : bottom;
            expect(viewport.bottom, docked ? t.getRect(bar).top : size.height);
            expect(raftBottomInset(t.element(list)), remainingInset);
            expect(viewport.left, greaterThanOrEqualTo(left));

            // Hold the appended page so the actual footer remains available to
            // inspect and tap even when near-end loading starts automatically.
            w.hold = nextPage;
            await t.drag(list, const Offset(0, -6000));
            await t.pumpAndSettle();
            final footer = find.widgetWithText(RaftButton, 'Load more');
            expect(footer, findsOneWidget);
            final button = t.getRect(footer);
            // Web ThreadsInbox places the tail inside the list's 4px
            // bottom padding and the scroller's 16px safe-bottom padding.
            expect(
              button.bottom,
              closeTo(viewport.bottom - remainingInset - 20, .01),
            );
            expect(
              button.top - t.getRect(find.byType(RaftInboxItem).last).bottom,
              closeTo(2, .01),
            );
            expect(button.left, greaterThanOrEqualTo(left));
            expect(footer.hitTestable(), findsOneWidget);
            await t.tap(footer);
            await t.pump();
            expect(
              w.inboxQueries.where((query) => query['offset'] == 50),
              hasLength(1),
            );
            nextPage.complete();
            await t.pumpAndSettle();
            expect(find.text('Load more'), findsNothing);
            final dynamic state = t.state(find.byType(ResourceView));
            expect(state.rows, hasLength(60));
            await t.drag(list, const Offset(0, -6000));
            await t.pumpAndSettle();
            final lastRow = find.widgetWithText(RaftInboxItem, 'Channel 59');
            expect(lastRow.hitTestable(), findsOneWidget);
            expect(
              t.getRect(lastRow).bottom,
              closeTo(viewport.bottom - remainingInset - 20, .01),
            );
            expect(t.takeException(), isNull);
          } on TestFailure catch (error, stack) {
            // Let testWidgets release its restoration manager and final render
            // tree before reporting an assertion that interrupted the body.
            addTearDown(() => Error.throwWithStackTrace(error, stack));
          } finally {
            await t.pumpWidget(const SizedBox.shrink());
            if (!nextPage.isCompleted) nextPage.complete();
            await t.pump();
            w.dispose();
            await client.dispose();
          }
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
