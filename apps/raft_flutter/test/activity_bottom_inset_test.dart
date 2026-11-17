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
  return w;
}

Finder _list(String view) =>
    find.byKey(PageStorageKey(('resource-list', 'activity', view)));

void main() {
  for (final (size, platform, bottom, left) in _windows) {
    for (final pack in [raftThemePackId]) {
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
          // A phone tab root (v1.24) has the bar; a docked bar ends the list.
          final bar = find.byKey(const Key('workspace-mobile-navigation'));
          expect(
            viewport.bottom,
            anyOf([
              closeTo(size.height, .01),
              if (bar.evaluate().isNotEmpty) closeTo(t.getRect(bar).top, .01),
            ]),
          );
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
          // Activity is a phone tab root (v1.24): the final control clears the
          // bottom bar, which itself clears the system bar once.
          expect(
            button.bottom,
            closeTo(
              // The list's own `pb-1` (4px) sits under the final control.
              (bar.evaluate().isEmpty
                      ? viewport.bottom - bottom
                      : t.getRect(bar).top) -
                  4,
              .01,
            ),
            reason: 'The final control must clear the system bar exactly once.',
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
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
