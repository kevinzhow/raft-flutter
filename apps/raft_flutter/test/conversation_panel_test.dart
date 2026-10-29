import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/test_themes.dart';

import 'message_presentation_test.dart' show fixture;
import 'flutter_test_config.dart' show leakDebt;

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['SourceChannelFilesStore']);
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} actual tab bodies preserve draft/cursor and reject hidden reads',
      (t) async {
        t.view.physicalSize = const Size(390, 720);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        // Large in-memory JSON fixtures must not spawn a real decoding
        // isolate inside the widget test's fake clock. Native profile runs
        // keep the actual HTTP/image decoding path.
        w.client.http.transformer = SyncTransformer();
        w.messageDomain.ledger.switchServer('s1');
        w.messageDomain.ledger.ingest([
          {
            'id': 'm1',
            'channelId': 'c1',
            'seq': 1,
            'senderId': 'alice',
            'senderType': 'user',
            'content': 'Public message',
            'createdAt': '2026-06-22T02:30:00Z',
            'taskId': 't1',
            'taskNumber': 7,
            'taskStatus': 'in_progress',
            'taskTitle': 'Public task',
          },
        ], expectedGeneration: w.messageDomain.ledger.generation);
        w.messageDomain.visibleIds['c1'] = {'m1'};
        transport.routes['GET /agents'] = (_) => [];
        transport.routes['GET /servers/s1/members'] = (_) => [];
        transport.routes['GET /tasks/channel/c1'] = (_) => {
          'tasks': [
            for (var i = 0; i < 600; i++)
              {
                'id': i == 0 ? 't1' : 'task-$i',
                'messageId': i == 0 ? 'm1' : 'other-message-$i',
                'channelId': 'c1',
                'taskNumber': i + 7,
                'status': 'in_progress',
                'title': 'Public task $i',
              },
          ],
          'nextCursor': null,
        };
        transport.routes['GET /channels/c1/files'] = (_) => {
          'files': [],
          'nextCursor': null,
        };
        var taskOpens = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: ConversationPanel(
                controller: w,
                onMessageTask: (_, _) => taskOpens++,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final editor = find.descendant(
          of: find.byType(RaftComposer),
          matching: find.byType(TextField),
        );
        await t.enterText(editor, 'Retained 中文 draft');
        final field = t.widget<TextField>(editor);
        field.controller!.selection = const TextSelection.collapsed(offset: 5);
        final original = t.state(find.byType(RaftComposer));
        final tabs = find.byKey(const Key('conversation-tabs'));
        var chatBuilds = 0, notifications = 0;
        final previousRebuild = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (element, builtBefore) {
          previousRebuild?.call(element, builtBefore);
          if (element.widget is RaftChatView) chatBuilds++;
        };
        addTearDown(() => debugOnRebuildDirtyWidget = previousRebuild);
        void changed() => notifications++;
        w.addListener(changed);
        w.navigation.bind('section-paging-fixture', w.location);
        final navigationLength = w.navigation.entries.length;
        final taskReads = transport.calls
            .where((r) => r.path == '/tasks/channel/c1')
            .length;
        final drag = await t.startGesture(const Offset(360, 300));
        await drag.moveBy(const Offset(-20, 0));
        await t.pump();
        await drag.moveBy(const Offset(-250, 0));
        for (var frame = 0; frame < 8; frame++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(
            t.widget<PageView>(find.byType(PageView)).controller!.page,
            greaterThan(.5),
          );
          expect(w.location.chatTab, isNull);
          expect(find.byType(RaftComposer), findsOneWidget);
          expect(find.text('Public message'), findsOneWidget);
          expect(chatBuilds, 0);
          expect(notifications, 0);
          expect(
            transport.calls.where((r) => r.path == '/tasks/channel/c1'),
            hasLength(taskReads),
          );
        }
        await drag.up();
        // Finish the page animation, then let the real async fixture request
        // complete before settling its loading animation in the fake clock.
        for (
          var frame = 0;
          frame < 100 && w.location.chatTab != 'tasks';
          frame++
        ) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(w.location.chatTab, 'tasks');
        await t.pump();
        for (var step = 0; step < 4; step++) {
          await t.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await t.pump();
        }
        await t.pumpAndSettle();
        expect(
          transport.calls.where((r) => r.path == '/tasks/channel/c1'),
          isNotEmpty,
        );
        expect(
          transport.calls.where((r) => r.path == '/tasks/server'),
          isEmpty,
        );
        expect(w.location.chatTab, 'tasks');
        expect(
          find.byType(RaftTaskCard).evaluate().length,
          inInclusiveRange(1, 15),
        );
        final retainedChip = t.widget<RaftMountedMessageTaskChip>(
          find.byKey(const ValueKey('message-task-m1'), skipOffstage: false),
        );
        expect(
          retainedChip.onOpen,
          isNotNull,
          reason: 'A retained section must keep the enabled paint; the pager gates input.',
        );
        retainedChip.onOpen!();
        expect(
          taskOpens,
          0,
          reason: 'Inactive/stale callbacks must remain inert.',
        );
        expect(w.navigation.entries.length, navigationLength);
        // Cached chat is still laid out for reverse drags, but cannot send
        // or mark read while the accepted section is Tasks.
        expect(editor, findsNothing);
        expect(
          t
              .widget<RaftComposer>(
                find.byType(RaftComposer, skipOffstage: false),
              )
              .enabled,
          false,
        );
        w.removeListener(changed);
        final before = transport.calls.length;
        await t.runAsync(() => w.markRead('c1'));
        expect(transport.calls.length, before);
        await t.tap(find.descendant(of: tabs, matching: find.text('Files')));
        await t.pumpAndSettle();
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await t.pumpAndSettle();
        expect(
          transport.calls.where((r) => r.path == '/channels/c1/files'),
          hasLength(1),
        );
        expect(w.location.chatTab, 'files');
        expect(find.text('No files yet'), findsOneWidget);
        // Return through the visited Tasks section, then drag the cached chat
        // into view. No chat rebuild/layout activation occurs mid-gesture.
        await t.tap(find.descendant(of: tabs, matching: find.text('Tasks')));
        await t.pumpAndSettle();
        chatBuilds = 0;
        final back = await t.startGesture(const Offset(30, 300));
        await back.moveBy(const Offset(20, 0));
        await t.pump();
        await back.moveBy(const Offset(250, 0));
        for (var frame = 0; frame < 8; frame++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(
            t.widget<PageView>(find.byType(PageView)).controller!.page,
            lessThan(.5),
          );
          expect(w.location.chatTab, 'tasks');
          expect(find.text('Public message'), findsOneWidget);
          expect(chatBuilds, 0);
          final chip = t.widget<RaftMountedMessageTaskChip>(
            find.byKey(const ValueKey('message-task-m1')),
          );
          expect(chip.onOpen, isNotNull);
          chip.onOpen!();
          expect(taskOpens, 0);
          expect(
            t.widget<RaftComposer>(find.byType(RaftComposer)).enabled,
            false,
          );
        }
        await back.up();
        await t.pumpAndSettle();
        expect(w.location.chatTab, isNull);
        expect(t.widget<RaftComposer>(find.byType(RaftComposer)).enabled, true);
        await t.tap(find.descendant(of: tabs, matching: find.text('Chat')));
        await t.pumpAndSettle();
        expect(w.location.chatTab, isNull);
        expect(t.state(find.byType(RaftComposer)), same(original));
        expect(t.widget<TextField>(editor).controller, same(field.controller));
        expect(field.controller!.text, 'Retained 中文 draft');
        expect(field.controller!.selection.baseOffset, 5);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
  }
}
