import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_card.dart'
    show ChannelSideMode;
import 'package:raft_flutter/features/channel_side_layout.dart';
import 'package:raft_flutter/features/channel_side_stack.dart';
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

  test('columns that fit at their own minimum share the room in proportion', () {
    // 360 chat + 280 Tasks + 320 Details = 960, inside 1000.
    final placement = placeChannelSide(
      [tasks, details],
      width: 1000,
      compact: false,
      layout: RaftLayoutClass.wide,
    );
    expect(placement.mode, ChannelSideMode.beside);
    expect(placement.stackedBelow, 0);
    expect(placement.columns.map((c) => c.sections), [
      const [ChannelSideSection.tasks],
      const [ChannelSideSection.details],
    ]);
    expect(placement.columns.map((c) => c.width), [300.0, 340.0]);
    expect(
      1000 - placement.columns.fold(0.0, (sum, c) => sum + c.width),
      channelSideChatMinWidth,
    );
  });

  test('one column that fits is placed exactly as it was before', () {
    // The chat's saved share is what is left, so nothing is given back.
    final placement = placeChannelSide(
      [details],
      width: 1143,
      compact: false,
      layout: RaftLayoutClass.wide,
    );
    expect(placement.mode, ChannelSideMode.beside);
    expect(placement.columns.single.width, 400);
    expect(placement.stackedBelow, 0);
  });

  test('a column too wide for the room beside the chat covers instead', () {
    // 360 + 280 is already past 600: squeezing both to 160 is what the Web
    // desktop rule did here.
    final placement = placeChannelSide(
      [tasks, details],
      width: 600,
      compact: false,
      layout: RaftLayoutClass.wide,
    );
    expect(placement.mode, ChannelSideMode.overlay);
    expect(placement.columns.single.sections, const [
      ChannelSideSection.tasks,
    ]);
    expect(placement.columns.single.width, 600);
    expect(placement.stackedBelow, 1);
  });

  test('a folded thread does not reserve a second chat', () {
    final placement = placeChannelSide(
      [details],
      width: 700,
      compact: false,
      layout: RaftLayoutClass.wide,
      threadFolded: true,
    );
    expect(placement.columns.single.width, 340);
    expect(
      placement.columns.single.width,
      greaterThanOrEqualTo(channelSideColumnMinWidth(const [
        ChannelSideSection.details,
      ]).toDouble()),
    );
    expect(700 - placement.columns.single.width, channelSideChatMinWidth);
  });

  test('the panes that do not fit wait behind the one opened last', () {
    final files = sideColumn(2, ChannelSideSection.files, 360);
    final artifact = sideColumn(3, ChannelSideSection.artifact, 480);
    final last = sideColumn(4, ChannelSideSection.details, 400);
    final placement = placeChannelSide(
      [tasks, files, artifact, last],
      width: 1200,
      compact: false,
      layout: RaftLayoutClass.wide,
      stack: const ChannelSideStack({
        ChannelSideSection.tasks: 1,
        ChannelSideSection.files: 2,
        ChannelSideSection.artifact: 3,
        ChannelSideSection.details: 4,
      }),
    );
    expect(placement.mode, ChannelSideMode.beside);
    // Tasks fits first but is the oldest, so it gives its place to Details,
    // the pane opened last. The shown pair keeps the layout's order.
    expect(placement.columns.map((c) => c.sections), [
      const [ChannelSideSection.files],
      const [ChannelSideSection.details],
    ]);
    expect(placement.stackedBelow, 2);
    for (final column in placement.columns) {
      expect(
        column.width,
        greaterThanOrEqualTo(
          channelSideColumnMinWidth(column.sections).toDouble(),
        ),
      );
    }
  });

  test('the medium class covers the conversation with the pane on top', () {
    final placement = placeChannelSide(
      [tasks, details],
      width: 640,
      compact: false,
      layout: RaftLayoutClass.medium,
      stack: const ChannelSideStack({
        ChannelSideSection.details: 1,
        ChannelSideSection.tasks: 2,
      }),
    );
    expect(placement.mode, ChannelSideMode.overlay);
    expect(placement.columns.single.sections, const [
      ChannelSideSection.tasks,
    ]);
    expect(placement.columns.single.width, 640);
    expect(placement.stackedBelow, 1);
  });

  test('the medium class covers even where two columns would fit', () {
    final placement = placeChannelSide(
      [tasks, details],
      width: 1000,
      compact: false,
      layout: RaftLayoutClass.medium,
    );
    expect(placement.mode, ChannelSideMode.overlay);
    expect(placement.columns, hasLength(1));
  });

  test('a saved width survives being covered at a medium width', () {
    final dragged = sideColumn(3, ChannelSideSection.details, 520);
    expect(
      placeChannelSide(
        [dragged],
        width: 544,
        compact: false,
        layout: RaftLayoutClass.medium,
      ).columns.single.width,
      544,
    );
    expect(
      placeChannelSide(
        [dragged],
        width: 1143,
        compact: false,
        layout: RaftLayoutClass.wide,
      ).columns.single.width,
      520,
    );
  });

  test('a compact viewport covers the panel even if it is 600 wide', () {
    final placement = placeChannelSide(
      [details],
      width: 600,
      compact: true,
      layout: RaftLayoutClass.compact,
    );
    expect(placement.mode, ChannelSideMode.overlay);
  });

  testWidgets(
    'a desktop row docks Details and Tasks below the workspace bar',
    (t) async {
      final (w, api) = await settingsFixture(t);
      api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
      api.routes['GET /channels/c1/announcement'] = (_) => {
        'announcement': null,
      };
      api.routes['GET /announcements/active'] = (_) => {'announcements': []};
      TaskV2ConversationsFlag.of(w).markEnabled();
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1440, 800);
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
        // Each column at its own minimum or wider, and the chat keeps 360.
        expect(
          tasks.width,
          greaterThanOrEqualTo(
            channelSideColumnMinWidth(const [
              ChannelSideSection.tasks,
            ]).toDouble(),
          ),
        );
        expect(
          details.width,
          greaterThanOrEqualTo(
            channelSideColumnMinWidth(const [
              ChannelSideSection.details,
            ]).toDouble(),
          ),
        );
        expect(
          tasks.left - room.left,
          greaterThanOrEqualTo(channelSideChatMinWidth),
        );
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
