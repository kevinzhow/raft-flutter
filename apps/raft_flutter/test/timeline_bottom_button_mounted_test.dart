import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

/// ChatPanel.tsx:1514-1525 / ThreadPanel.tsx:2610-2620: the "Back to bottom"
/// button floats centered, 12px above the composer, in the channel timeline and
/// in the thread timeline; in a centered history window it reloads the latest
/// page.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K04] $family/$dark history-window button is centered above the composer and reloads latest',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(900, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        api.routes['GET /messages/context/target-40'] = (_) => {
          'messages': contextRows('target'),
          'hasOlder': true,
          'hasNewer': true,
        };
        api.routes['POST /channels/c1/read'] = (_) => {};
        await tester.runAsync(() => w.jumpToMessage('c1', 'target-40'));
        expect(w.hasNewer, true);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await tester.pumpAndSettle();

        final button = find.byType(RaftTimelineBottomButton);
        expect(button, findsOneWidget);
        expect(find.text('Back to bottom'), findsOneWidget);
        final timeline = tester.getRect(
          find.byKey(const ValueKey('current-timeline')),
        );
        final composer = tester.getRect(find.byType(RaftComposer));
        final control = tester.getRect(
          find.ancestor(
            of: find.text('Back to bottom'),
            matching: find.byType(RaftRecipeButton),
          ),
        );
        // Centered on the timeline, floating 12px above the composer edge.
        expect(control.center.dx, closeTo(timeline.center.dx, .5));
        expect(control.bottom, closeTo(timeline.bottom - 12, .5));
        expect(timeline.bottom, lessThanOrEqualTo(composer.top + .5));
        expect(control.bottom, lessThan(composer.top));

        // A real tap in a history window reloads the latest page.
        final latestRequests = <int>[];
        api.routes['GET /messages/channel/c1'] = (_) {
          latestRequests.add(1);
          return {'messages': contextRows('latest', count: 8)};
        };
        await tester.tap(find.text('Back to bottom'));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(latestRequests, hasLength(1));
        expect(w.hasNewer, false);
        expect(paintedMessage(tester, 'latest-7'), isNotNull);
        expect(find.text('Back to bottom'), findsNothing);
        expect(find.byType(RaftTimelineBottomButton), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      '[K04] $family/$dark thread panel shows the centered button when scrolled away, counts replies and returns to its end',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(900, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final replies = [
          for (var i = 0; i < 80; i++)
            {
              ...row('reply-$i', 'thread-1', i + 1),
              'content': List.filled(i % 4 + 1, 'Reply $i').join('\n'),
            },
        ];
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [row('parent', 'c1', 1)],
        };
        api.routes['GET /messages/channel/thread-1'] = (_) => {
          'messages': replies,
        };
        api.routes['POST /channels/thread-1/read'] = (_) => {};
        await tester.runAsync(() async {
          await w.openThreadIdentity(
            parentChannelId: 'c1',
            parentMessageId: 'parent',
            initialThreadChannelId: 'thread-1',
            navigate: false,
          );
          for (var i = 0; i < 40 && w.threadLoading; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w, thread: true)),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byType(RaftChatView));
        final ScrollController viewport = state.viewport;
        // At the end of the thread there is no button.
        expect(state.distanceFromLatest(viewport.position), 0);
        expect(find.byType(RaftTimelineBottomButton), findsNothing);

        viewport.jumpTo(viewport.offset - 600);
        await tester.pumpAndSettle();
        expect(find.text('Back to bottom'), findsOneWidget);
        final timeline = tester.getRect(
          find.byKey(const ValueKey('current-timeline')),
        );
        final composer = tester.getRect(find.byType(RaftComposer));
        final control = tester.getRect(
          find.ancestor(
            of: find.text('Back to bottom'),
            matching: find.byType(RaftRecipeButton),
          ),
        );
        expect(control.center.dx, closeTo(timeline.center.dx, .5));
        expect(control.bottom, closeTo(timeline.bottom - 12, .5));
        expect(control.bottom, lessThan(composer.top));

        // A reply arriving while scrolled away is counted, not followed.
        await tester.runAsync(() async {
          w.ledger.ingest([
            {...row('reply-new', 'thread-1', 999), 'senderId': 'bob'},
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['thread-1']!.add('reply-new');
          w.notifyListeners();
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpAndSettle();
        expect(find.text('1 new'), findsOneWidget);
        expect(state.distanceFromLatest(viewport.position), greaterThan(100));

        // The outer channel stays untouched by the thread's button.
        final channelCalls = api.calls.length;
        await tester.tap(find.text('1 new'));
        await tester.pumpAndSettle();
        expect(state.distanceFromLatest(viewport.position), 0);
        expect(find.byType(RaftTimelineBottomButton), findsNothing);
        expect(
          api.calls.skip(channelCalls).where((c) => c.path.contains('/c1')),
          isEmpty,
        );
        expect(paintedMessage(tester, 'reply-new'), isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
