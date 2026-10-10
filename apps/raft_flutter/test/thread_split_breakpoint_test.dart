import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart'
    show pageFixture, mountPage, pageFrames;

// Web index.css900–979: a thread sits beside its channel only when the
// viewport is landscape or at least 1280 wide (portrait), and the actual
// thread-layout container is at least 680 wide (max-width 679.98 folds).
// Driven through the mounted WorkspaceView with a real canonical thread whose
// URL owns a focused reply; resizing must keep that location and focus.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[N23] $family/$dark thread splits only at portrait>=1280 or landscape with container>=680; resize keeps location and msg focus',
      (tester) async {
        final (w, api) = await pageFixture(tester);
        w.ledger.ingest([
          row('main', 'c1', 1),
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'main'};
        w.navigation.navigate(
          w.location.withQuery({
            'thread': 'c1:parent',
            'msg': 'reply-40',
            'keep': 'value:with space',
          }),
        );
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [row('parent', 'c1', 2)],
        };
        api.routes['GET /messages/context/reply-40'] = (_) => {
          'messages': [
            for (final m in contextRows('reply')) {...m, 'channelId': 't1'},
          ],
          'hasOlder': true,
          'hasNewer': true,
        };
        await tester.runAsync(
          () => w.openThreadIdentity(
            parentChannelId: 'c1',
            parentMessageId: 'parent',
            initialThreadChannelId: 't1',
            focusedMessageId: 'reply-40',
            navigate: false,
          ),
        );
        await mountPage(tester, w, family, dark);
        final uri = w.location,
            index = w.navigation.index,
            entries = w.navigation.entries.length;
        final threadView = find.byWidgetPredicate(
          (widget) => widget is RaftChatView && widget.thread,
        );
        final focus = find.byKey(const ValueKey('message-reply-40'));
        expect(threadView, findsOneWidget);
        final threadState = tester.state(threadView);

        // Measure rail + sidebar + trailing dock from the real layout.
        tester.view.physicalSize = const Size(1440, 700);
        await pageFrames(tester, () {});
        final panel = find.byKey(const Key('workspace-thread-panel'));
        expect(panel, findsOneWidget);
        final container =
            tester.getRect(panel).right -
            tester
                .getRect(find.byKey(const Key('workspace-sidebar-panel')))
                .right;
        final chrome = 1440 - container;
        // Sanity: in portrait the container itself would be wide enough, so
        // the 1279/1280 cases isolate the portrait viewport rule.
        expect(1279 - chrome, greaterThanOrEqualTo(680));

        for (final (size, split) in [
          (const Size(1440, 900), true), // landscape
          (const Size(1279, 1400), false), // portrait below xl
          (const Size(1280, 1400), true), // portrait xl
          (const Size(1279, 900), true), // landscape below xl
          (Size(chrome + 679.98, 700), false), // container 679.98
          (Size(chrome + 680, 700), true), // container 680
          (const Size(1279, 1400), false),
          (const Size(1440, 900), true),
        ]) {
          tester.view.physicalSize = size;
          await pageFrames(tester, () {
            expect(
              panel,
              split ? findsOneWidget : findsNothing,
              reason: '$size split=$split',
            );
            // Folded: the thread covers the channel, which is not painted.
            expect(
              find.byKey(const ValueKey('message-main')),
              split ? findsOneWidget : findsNothing,
              reason: '$size main visibility',
            );
            expect(find.byType(RaftThreadHeader), findsOneWidget);
            expect(w.location, uri, reason: '$size must keep the location');
            expect(w.location.messageId, 'reply-40');
            expect(w.location.query('keep'), 'value:with space');
            expect(w.navigation.index, index);
            expect(w.navigation.entries.length, entries);
            expect(w.threadIdentity?.parentMessageId, 'parent');
          }, count: 3);
          if (split) {
            expect(
              tester.getRect(panel).left,
              greaterThan(
                tester
                    .getRect(find.byKey(const Key('workspace-sidebar-panel')))
                    .right,
              ),
            );
          }
          // The focused reply stays painted and highlighted in the same
          // thread timeline state.
          expect(
            paintedMessage(tester, 'reply-40'),
            isNotNull,
            reason: '$size',
          );
          expect(tester.widget<RaftMessageTile>(focus).highlighted, true);
          expect(w.highlightedMessageId, 'reply-40');
          expect(tester.state(threadView), same(threadState));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
