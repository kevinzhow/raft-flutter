import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'message_presentation_test.dart' show fixture;

void main() {
  for (final mode in [
    'double',
    'expire',
    'filter',
    'authority',
    'different',
    'different-double',
    'late',
    'keyboard',
    'blank',
  ]) {
    testWidgets(
      'Unread gesture $mode preserves hit target and original focus',
      (tester) async {
        const timing = MethodChannel('app.raft/interaction');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(timing, (_) async => 0.5);
        addTearDown(() => messenger.setMockMethodCallHandler(timing, null));
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.channels = [
          RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
        ];
        final first = {
          ...activityRow('thread'),
          'firstMentionMessageId': 'mention',
          'hasMention': true,
        };
        final second = {
          ...first,
          'threadChannelId': 'thread-2',
          'parentMessagePreview': 'Second thread',
        };
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /channels/inbox'] = (_) => {
          'items': [first, second],
          'hasMore': false,
        };
        for (final id in ['thread-1', 'thread-2']) {
          api.routes['POST /channels/$id/read-all'] = (_) => {
            'maxReadSeq': 5,
            'readStateVersion': 7,
          };
        }
        final preview = <Map<String, dynamic>>[],
            canonical = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: ResourceView(
                controller: w,
                section: 'activity',
                onMessage: (_, _) async {},
                onActivityItem: (row) async => preview.add(row),
                onActivityCanonical: (row) async => canonical.add(row),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unread').first);
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('activity-thread-thread-1'));
        final next = find.byKey(const ValueKey('activity-thread-thread-2'));
        final rect = tester.getRect(card), nextRect = tester.getRect(next);
        final point = rect.bottomLeft + const Offset(35, -10);
        await tester.tapAt(point);
        expect(preview.single['firstUnreadMessageId'], 'first');
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.getRect(card), rect);
        expect(tester.getRect(next), nextRect);
        expect(
          find.descendant(of: card, matching: find.text('2 new')),
          findsNothing,
        );
        if (mode == 'double') {
          await tester.tapAt(point);
          expect(canonical.single['threadChannelId'], 'thread-1');
          expect(canonical.single['firstUnreadMessageId'], 'first');
          expect(canonical.single['firstMentionMessageId'], 'mention');
          expect(preview, hasLength(1));
        } else if (mode == 'expire') {
          await tester.pump(const Duration(milliseconds: 151));
          expect(card, findsNothing);
          expect(canonical, isEmpty);
        } else if (mode == 'filter') {
          await tester.tap(find.text('All').first);
          await tester.pump();
          final dynamic state = tester.state(find.byType(ResourceView));
          expect(state.activityGestureCurrent, false);
        } else if (mode == 'authority') {
          api.routes['GET /channels/inbox'] = (_) => {'items': []};
          w.client.user = RaftRecord({'id': 'another'});
          w.notifyListeners();
          await tester.pump();
          expect(card, findsNothing);
          expect(next, findsNothing);
        } else if (mode == 'different' || mode == 'different-double') {
          await tester.tap(next);
          expect(preview, hasLength(2));
          expect(preview.last['threadChannelId'], 'thread-2');
          expect(canonical, isEmpty);
          await tester.pump();
          expect(tester.getRect(next), nextRect);
          if (mode == 'different-double') {
            await tester.pump(const Duration(milliseconds: 350));
            await tester.tapAt(nextRect.bottomLeft + const Offset(35, -10));
            expect(preview, hasLength(2));
            expect(canonical.single['threadChannelId'], 'thread-2');
            expect(canonical.single['firstUnreadMessageId'], 'first');
            expect(canonical.single['firstMentionMessageId'], 'mention');
          }
        } else if (mode == 'late') {
          await tester.pump(const Duration(milliseconds: 151));
          await tester.tap(next);
          expect(preview, hasLength(2));
          expect(preview.last['threadChannelId'], 'thread-2');
          expect(canonical, isEmpty);
        } else if (mode == 'keyboard') {
          Focus.of(
            tester.element(
              find
                  .descendant(of: next, matching: find.byType(RaftCssText))
                  .first,
            ),
          ).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(preview, hasLength(2));
          expect(preview.last['threadChannelId'], 'thread-2');
          expect(canonical, isEmpty);
        } else {
          await tester.tapAt(nextRect.bottomLeft + const Offset(35, 35));
          expect(preview, hasLength(1));
          expect(canonical, isEmpty);
          final dynamic state = tester.state(find.byType(ResourceView));
          expect(state.activityGestureCurrent, false);
        }
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(
          api.calls.where((r) => r.path == '/channels/thread-1/read-all'),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
}
