import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_card.dart'
    show ChannelSideMode;
import 'package:raft_flutter/features/channel_side_column.dart';
import 'package:raft_flutter/features/channel_side_layout.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/app_services_fixture.dart';
import 'workspace_channel_settings_identity_test.dart' show settingsFixture;
import 'workspace_source_location_contract_test.dart' show frames;

VisibleChannelSideColumn sideColumn(
  int index,
  ChannelSideSection section,
  int width,
) => VisibleChannelSideColumn(
  column: index,
  sections: [section],
  width: width,
  minWidth: channelSideColumnMinWidth([section]),
);

void main() {
  final tasks = sideColumn(1, ChannelSideSection.tasks, 360);
  final details = sideColumn(3, ChannelSideSection.details, 400);

  test('desktop side columns clip in proportion before becoming tabs', () {
    final placement = placeChannelSide(
      [tasks, details],
      width: 600,
      compact: false,
    );
    expect(placement.mode, ChannelSideMode.beside);
    expect(placement.columns.map((c) => c.width), [175.0, 200.0]);
  });

  test('a folded thread gives way before a side column clips', () {
    final placement = placeChannelSide(
      [details],
      width: 700,
      compact: false,
      threadFolded: true,
    );
    expect(placement.columns.single.width, 320);
  });

  test(
    'desktop overflow gathers the rightmost columns into their neighbour',
    () {
      final files = sideColumn(2, ChannelSideSection.files, 360);
      final artifact = sideColumn(3, ChannelSideSection.artifact, 480);
      final placement = placeChannelSide(
        [
          tasks,
          files,
          artifact,
          sideColumn(4, ChannelSideSection.details, 400),
        ],
        width: 620,
        compact: false,
      );
      expect(placement.mode, ChannelSideMode.beside);
      expect(placement.columns.map((c) => c.sections), [
        const [ChannelSideSection.tasks],
        const [
          ChannelSideSection.files,
          ChannelSideSection.artifact,
          ChannelSideSection.details,
        ],
      ]);
    },
  );

  test('a compact viewport covers the panel even if it is 600 wide', () {
    final placement = placeChannelSide([details], width: 600, compact: true);
    expect(placement.mode, ChannelSideMode.overlay);
  });

  testWidgets('picking a grouped column restores its whole stack', (t) async {
    final (w, api) = await settingsFixture(t);
    final store = ChannelSideStore.of(w)..focus('details');
    try {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Material(
            child: Center(
              child: SizedBox(
                width: 220,
                height: 640,
                child: ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => ChannelSideColumnView(
                    store: store,
                    mode: ChannelSideMode.beside,
                    sections: const [
                      ChannelSideSection.tasks,
                      ChannelSideSection.files,
                      ChannelSideSection.details,
                    ],
                    tabGroups: const [
                      [ChannelSideSection.tasks, ChannelSideSection.files],
                      [ChannelSideSection.details],
                    ],
                    titles: const {
                      ChannelSideSection.tasks: 'Tasks',
                      ChannelSideSection.files: 'Files',
                      ChannelSideSection.details: 'Details',
                    },
                    cardOf: (_, section, _) => SizedBox.expand(
                      key: Key('grouped-body-${section.name}'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Finder card(ChannelSideSection section) =>
          find.byKey(Key('grouped-body-${section.name}'));
      expect(card(ChannelSideSection.details), findsOneWidget);
      expect(card(ChannelSideSection.tasks), findsNothing);
      final tasksTab = find.byKey(const Key('channel-side-column-tab-tasks'));
      expect(tasksTab.hitTestable(), findsOneWidget);
      await t.tap(tasksTab);
      await t.pumpAndSettle();
      expect(card(ChannelSideSection.tasks), findsOneWidget);
      expect(card(ChannelSideSection.files), findsOneWidget);
      expect(card(ChannelSideSection.details), findsNothing);
      expect(api.calls.where((call) => call.method == 'PATCH'), isEmpty);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  });

  testWidgets(
    'a narrow desktop row docks Details and Tasks below the workspace bar',
    (t) async {
      final (w, api) = await settingsFixture(t);
      api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
      api.routes['GET /channels/c1/announcement'] = (_) => {
        'announcement': null,
      };
      api.routes['GET /announcements/active'] = (_) => {'announcements': []};
      TaskV2ConversationsFlag.of(w).markEnabled();
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(928, 800);
      addTearDown(t.view.reset);
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        await frames(t, () {});
        await t.pumpAndSettle();

        final area = find.byType(ChannelSideArea);
        final room = t.getRect(area);
        expect(room.width, inInclusiveRange(520, 679));
        final tasksTrigger = find.byKey(const Key('channel-tasks-toggle'));
        expect(tasksTrigger.hitTestable(), findsOneWidget);
        await t.tap(tasksTrigger);
        await frames(t, () {});
        await t.pumpAndSettle();
        final detailsTrigger = find.byKey(
          const Key('channel-overflow-trigger'),
        );
        expect(detailsTrigger.hitTestable(), findsOneWidget);
        await t.tap(detailsTrigger);
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(find.byKey(const Key('channel-details')), findsOneWidget);
        expect(find.byKey(const Key('channel-side-float')), findsNothing);
        expect(find.byKey(const Key('channel-side-overlay')), findsNothing);

        final details = t.getRect(
          find.byKey(const Key('channel-side-column-3')),
        );
        final tasks = t.getRect(find.byKey(const Key('channel-side-column-1')));
        final topBar = t.getRect(find.byKey(const Key('workspace-top-bar')));
        expect(tasks.top, topBar.bottom);
        expect(details.top, topBar.bottom);
        expect(tasks.right, details.left);
        expect(details.right, room.right);
        expect(details.bottom, room.bottom);
        expect(tasks.width, greaterThanOrEqualTo(160));
        expect(details.width, greaterThanOrEqualTo(160));
        expect(tasks.left - room.left, greaterThanOrEqualTo(160));
        final close = find.byKey(const Key('channel-details-close'));
        expect(close.hitTestable(), findsOneWidget);
        await t.tap(close);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('channel-details')), findsNothing);
        expect(find.byKey(const Key('channel-side-column-1')), findsOneWidget);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
