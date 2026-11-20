import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_object_row_test.dart' show objectRow;
import 'parity/parity_harness.dart' show loadParityFonts;
import 'support/activity_list_harness.dart';

void main() {
  testWidgets('Activity shows ten flat placeholders for a slow first read', (
    tester,
  ) async {
    await tester.runAsync(loadParityFonts);
    final (client, workspace) = activityFixture();
    addTearDown(client.dispose);
    addTearDown(workspace.dispose);
    final pending = Completer<void>();
    workspace.hold = pending;
    addTearDown(() {
      if (!pending.isCompleted) pending.complete();
    });

    await mountActivity(tester, workspace, phoneTouch, settle: false);
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byType(RaftInboxItemSkeleton), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    final placeholders = find.byType(RaftInboxItemSkeleton);
    expect(placeholders, findsNWidgets(10));
    expect(find.byType(RaftActivityLoadingList), findsNothing);
    final group = tester.getRect(find.byType(RaftInboxItemListGroup));
    final first = tester.getRect(placeholders.first);
    final second = tester.getRect(placeholders.at(1));
    expect(group.height, 608);
    expect(first.top - group.top, 30);
    expect(first.height, 56);
    expect(second.top - first.bottom, 2);
    final bars = find.descendant(
      of: placeholders.first,
      matching: find.byType(RaftSkeleton),
    );
    // Actual Web DOM bounds relative to the first row.
    expect(tester.getTopLeft(bars.at(1)).dy - first.top, closeTo(13.73, .05));
    expect(tester.getTopLeft(bars.at(2)).dy - first.top, closeTo(15.53, .05));
    expect(tester.getTopLeft(bars.at(3)).dy - first.top, closeTo(34.34, .05));

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RaftInboxItemSkeleton), findsNothing);
    expect(find.byType(RaftInboxItem), findsWidgets);
  });

  testWidgets('Activity desktop title and counts share a 44px header', (
    tester,
  ) async {
    final (client, workspace) = activityFixture();
    addTearDown(client.dispose);
    addTearDown(workspace.dispose);

    await mountActivity(tester, workspace, desktop);
    final header = find.byType(RaftPanelHeaderBar);
    expect(tester.getSize(header).height, 44);
    final title = find.text('Activity');
    final counts = find.textContaining('in progress');
    expect(tester.getTopLeft(title).dx, 16);
    expect(
      tester.getCenter(counts).dx,
      greaterThan(tester.getCenter(title).dx),
    );
    expect(tester.getCenter(counts).dy, closeTo(tester.getCenter(title).dy, 3));
  });

  testWidgets('Activity fallback DM uses its conversation glyph', (
    tester,
  ) async {
    final (client, workspace) = activityFixture();
    addTearDown(client.dispose);
    addTearDown(workspace.dispose);
    workspace.inbox = [
      {...dayRow(0, day: 12), 'kind': 'dm', 'channelType': 'dm'},
    ];

    await mountActivity(tester, workspace, phoneMouse);
    final tile = find.descendant(
      of: find.byType(RaftInboxItem),
      matching: find.byType(RaftIconTile),
    );
    expect(tester.widget<RaftIconTile>(tile).glyph, RaftGlyph.directMessage);
  });

  testWidgets('Activity opens the previous Artifact version and returns', (
    tester,
  ) async {
    final (client, workspace) = activityFixture();
    addTearDown(client.dispose);
    addTearDown(workspace.dispose);
    workspace.inbox = [
      objectRow(target: {'version': 2}, preview: {'text': 'Check the notes.'}),
    ];

    await mountActivity(tester, workspace, phoneMouse);
    final artifact = find.byKey(const ValueKey('activity-object-art1'));
    expect(artifact, findsOneWidget);
    await tester.tap(artifact);
    await tester.pumpAndSettle();
    final viewer = find.byType(ArtifactWorkspaceViewer);
    expect(viewer, findsOneWidget);
    final target = tester.widget<ArtifactWorkspaceViewer>(viewer).target;
    expect(target.id, 'art1');
    expect(target.version, 2);

    final close = find.byKey(const ValueKey('artifact-viewer-close'));
    expect(close, findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
    expect(artifact, findsOneWidget);
    expect(client.posts.where((p) => p.contains('/read')), isEmpty);
  });

  testWidgets('Activity uses the workspace channel marks and DM presence', (
    tester,
  ) async {
    final (client, workspace) = activityFixture();
    addTearDown(client.dispose);
    addTearDown(workspace.dispose);
    workspace
      ..server = RaftRecord({...workspace.server!.json, 'publicPageLive': true})
      ..channels = [
        RaftChannel({
          'id': 'ch0',
          'name': 'Published',
          'type': 'channel',
          'guestVisible': true,
        }),
        RaftChannel({
          'id': 'ch1',
          'name': 'External',
          'type': 'private',
          'hasExternalRelation': true,
        }),
      ]
      ..dms = [
        RaftChannel({
          'id': 'ch2',
          'name': 'Helper',
          'type': 'dm',
          'peerId': 'a1',
          'peerType': 'agent',
        }),
      ]
      ..inbox = [
        dayRow(0, day: 12),
        dayRow(1, day: 12),
        {...dayRow(2, day: 12), 'kind': 'dm', 'channelType': 'dm'},
      ];

    await mountActivity(tester, workspace, phoneMouse);
    expect(find.byType(RaftPublicChannelMark), findsOneWidget);
    expect(find.byType(RaftExternalChannelMark), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mounted-avatar-presence')),
      findsOneWidget,
    );
  });

  for (final env in [phoneMouse, foldA, foldB]) {
    testWidgets(
      '${env.name}: the Activity menu opens without selecting the row',
      (tester) async {
        final (client, workspace) = activityFixture();
        addTearDown(client.dispose);
        addTearDown(workspace.dispose);
        workspace.inbox = [dayRow(0, day: 12, unread: 1)];

        await mountActivity(tester, workspace, env);
        final row = find.byType(RaftInboxItem);
        final fill = find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('inbox-item-fill')),
        );
        Color? fillColor() =>
            (tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: fill,
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration)
                .color;
        final resting = fillColor();
        if (env.touch) {
          await tester.longPress(row);
        } else {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await mouse.addPointer(location: const Offset(5, 5));
          addTearDown(mouse.removePointer);
          await mouse.down(tester.getCenter(row));
          await mouse.up();
          // Hover can paint the same fill as a popup. Move off the row
          // while the menu is open to prove the popup owns the highlight.
          await mouse.moveTo(const Offset(5, 5));
        }
        await tester.pumpAndSettle();
        final menu = find.byKey(const ValueKey('activity-menu-done'));
        expect(menu, findsOneWidget);
        expect(fillColor(), resting);
        expect(tester.widget<RaftInboxItem>(row).selected, isFalse);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(menu, findsNothing);
        expect(fillColor(), resting);
        expect(client.posts.where((p) => p.contains('/read')), isEmpty);
      },
    );
  }

  testWidgets('Activity menu places the 240px surface using the Web estimate', (
    tester,
  ) async {
    final (client, workspace) = activityFixture();
    addTearDown(client.dispose);
    addTearDown(workspace.dispose);
    workspace.inbox = [threadRow(0, unread: 1)];

    await mountActivity(tester, workspace, phoneMouse);
    final row = find.byType(RaftInboxItem);
    final action = find.byKey(const ValueKey('activity-menu-done'));
    final y = tester.getCenter(row).dy;
    for (final (anchorX, expectedLeft) in [(171.0, 171.0), (374.0, 190.0)]) {
      await tester.tapAt(
        Offset(anchorX, y),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(action);
      expect(rect.left, expectedLeft + 4);
      expect(rect.width, 232);
      expect(rect.height, 36);
      expect(action.hitTestable(), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(action, findsNothing);
    }
    expect(client.posts.where((p) => p.contains('/read')), isEmpty);
  });
}
