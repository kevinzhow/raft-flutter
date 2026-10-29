import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show activityFixture, activityScroll;

void main() {
  for (final updatesPressedRow in [false, true]) {
    testWidgets('mouse press keeps its Activity identity when '
        '${updatesPressedRow ? 'the pressed row' : 'another row'} advances', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (client, workspace) = activityFixture();
      addTearDown(client.dispose);
      addTearDown(workspace.dispose);
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ResourceView(
              controller: workspace,
              section: 'activity',
              activitySidebarEnabled: true,
              onMessage: (_, _) async {},
              onActivityItem: (row) async =>
                  opened.add(row['channelId'] as String),
              onActivityCanonical: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = activityScroll(tester);
      scroll.position.jumpTo(1500);
      await tester.pump();
      expect(scroll.position.pixels, greaterThan(1000));
      final viewport = tester.getRect(find.byType(Scrollable).last);
      String? pressedId;
      Rect? pressedRect;
      for (var i = 0; i < 30; i++) {
        final card = find.byKey(ValueKey('activity-channel-ch$i'));
        if (card.evaluate().isEmpty) continue;
        final rect = tester.getRect(card);
        if (rect.top >= viewport.top + 10 &&
            rect.bottom < viewport.bottom - 10) {
          pressedId = 'ch$i';
          pressedRect = rect;
          break;
        }
      }
      expect(pressedId, isNotNull);
      expect(pressedRect, isNotNull);
      final point = pressedRect!.topLeft + const Offset(60, 22);
      final mouse = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(opened, isEmpty);
      client.emit('message:new', {
        'id': 'incoming-while-pressed',
        'channelId': updatesPressedRow ? pressedId : 'ch29',
        'seq': 2000,
        'content': 'Incoming while the mouse is held',
        'senderId': 'carol',
        'senderType': 'user',
        'senderName': 'Carol',
        'createdAt': '2026-10-10T01:00:00Z',
      });
      await tester.pump();
      final dynamic page = tester.state(find.byType(ResourceView));
      expect(
        page.rows.first['channelId'],
        updatesPressedRow ? pressedId : 'ch29',
      );
      await mouse.up();
      await tester.pumpAndSettle();
      final actual = List<String>.of(opened);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(
        actual,
        [pressedId],
        reason: 'The successful mouse press owns the original row, even if its live preview moves before release.',
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
