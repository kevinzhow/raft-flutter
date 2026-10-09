import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_selection.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final thread in [false, true]) {
    testWidgets(
      'actual ${thread ? 'thread' : 'main'} menu selects clicked row; keyboard and revocation fence retained actions',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = const Size(390, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final (w, a) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        final rows = [
          {
            'id': 'parent',
            'channelId': 'c1',
            'threadId': 't1',
            'seq': 1,
            'senderId': 'alice',
            'senderType': 'user',
            'senderName': 'Alice',
            'content': 'Public selected parent',
            'messageType': 'chat',
          },
          {
            'id': 'later',
            'channelId': 'c1',
            'seq': 2,
            'senderId': 'alice',
            'senderType': 'user',
            'senderName': 'Alice',
            'content': 'Public second row',
            'messageType': 'chat',
          },
          {
            'id': 'reply',
            'channelId': 't1',
            'seq': 3,
            'senderId': 'alice',
            'senderType': 'user',
            'senderName': 'Alice',
            'content': 'Public selected reply',
            'messageType': 'chat',
          },
        ];
        w.ledger.switchServer('s1');
        w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'parent', 'later'};
        w.visibleIds['t1'] = {'reply'};
        if (thread) {
          w.threadParent = w.messages.first;
          w.threadChannelId = 't1';
        }
        a.routes['GET /servers/s1/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        a.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
        a.routes['GET /agents'] = (_) => [];
        a.routes['GET /servers/s1/members'] = (_) => [];
        a.routes['GET /channels/c1/available-mentions'] = (_) => {
          'humans': [],
          'agents': [],
        };
        final handle = ChatSelectionHandle();
        addTearDown(handle.dispose);
        final writes = <String>[];
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              writes.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: RaftChatView(
                controller: w,
                thread: thread,
                selectionHandle: handle,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final target = find.byKey(
          ValueKey('message-${thread ? 'reply' : 'parent'}'),
        );
        expect(target, findsOneWidget);
        final rect = t.getRect(target);
        await t.longPressAt(Offset(rect.left + 2, rect.center.dy));
        await t.pumpAndSettle();
        await t.tap(find.text('Select Message'));
        await t.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
        expect(handle.active, isTrue);
        expect(
          find.byTooltip('Select All'),
          thread ? findsOneWidget : findsNothing,
        );
        if (thread) {
          await t.tap(find.byTooltip('Select All'));
        } else {
          final checkbox = find.byWidgetPredicate(
            (w) =>
                w is Checkbox && w.semanticLabel == 'Select message by Alice',
          );
          expect(checkbox, findsNWidgets(2));
          await t.tap(checkbox.last);
        }
        await t.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);
        await t.tap(find.byTooltip('More'));
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byType(RaftMenuItem), findsNothing);
        expect(
          handle.active,
          isTrue,
          reason: 'Escape from More must not escape selection.',
        );
        // Once the popup is closed, Escape belongs to select mode, not the
        // still-focused More trigger. Re-enter through the real row menu.
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(handle.active, isFalse);
        expect(find.byType(RaftSelectionToolbar), findsNothing);
        expect(find.byType(RaftComposer), findsOneWidget);
        final again = t.getRect(target);
        await t.longPressAt(Offset(again.left + 2, again.center.dy));
        await t.pumpAndSettle();
        await t.tap(find.text('Select Message'));
        await t.pumpAndSettle();
        if (thread) {
          await t.tap(find.byTooltip('Select All'));
        } else {
          await t.tap(find.byType(Checkbox).last);
        }
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('More'));
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pumpAndSettle();
        expect(find.text('Copy MD'), findsOneWidget);
        await t.tap(find.text('Copy MD'));
        await t.pumpAndSettle();
        expect(writes, hasLength(1));
        expect(writes.single, contains('Public selected parent'));
        expect(
          writes.single,
          contains(thread ? '> Public selected reply' : 'Public second row'),
        );
        if (!thread) {
          expect(writes.single, isNot(contains('Public selected reply')));
        }
        final retained = t.widget<RaftSelectionToolbar>(
          find.byType(RaftSelectionToolbar),
        );
        final before = a.calls.length;
        w.server = RaftRecord({'id': 's1', 'role': 'guest'});
        w.setError(null);
        await t.pumpAndSettle();
        expect(handle.active, isFalse);
        expect(find.byType(RaftSelectionToolbar), findsNothing);
        retained.onCopyMarkdown!();
        retained.onCopyLinks!();
        retained.onPreview!();
        retained.onForward!();
        await t.pump();
        expect(writes, hasLength(1));
        expect(a.calls.length, before);
        expect(t.takeException(), isNull);
      },
    );
  }
}
