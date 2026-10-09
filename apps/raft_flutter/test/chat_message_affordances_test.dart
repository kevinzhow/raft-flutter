import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark departed senders retain history but cannot be mentioned',
      (t) async {
        final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.ledger.ingest([
          for (final (id, type, status, seq) in [
            ('active', 'user', 'active', 1),
            ('removed', 'user', 'removed', 2),
            ('left', 'user', 'left', 3),
            ('deleted', 'agent', 'active', 4),
            ('external', 'external_projection', 'removed', 5),
          ])
            {
              'id': id,
              'channelId': 'c1',
              'seq': seq,
              'senderId': id,
              'senderType': type,
              'senderName': 'Author $id',
              'senderMembershipStatus': status,
              'sourceServerId': 's1',
              'content': 'History $id',
              'createdAt': '2026-06-22T02:30:00Z',
            },
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {
          'active',
          'removed',
          'left',
          'deleted',
          'external',
        };
        transport.routes['GET /servers/s1/members'] = (_) => [
          // Deliberately stale directory names must not restore a departed
          // message sender's mention affordance.
          for (final id in ['active', 'removed', 'left'])
            {'userId': id, 'name': id, 'role': 'member'},
        ];
        transport.routes['GET /agents'] = (_) => [
          {
            'id': 'deleted',
            'name': 'deleted',
            'status': 'active',
            'runtime': 'codex',
            'deletedAt': '2026-06-22T03:00:00Z',
          },
        ];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await t.pumpAndSettle();
        expect(find.text('REMOVED'), findsOneWidget);
        expect(find.text('LEFT'), findsOneWidget);
        expect(find.text('DELETED'), findsOneWidget);
        for (final id in ['removed', 'left', 'deleted', 'external']) {
          final row = find.ancestor(
            of: find.text('Author $id'),
            matching: find.byType(RaftMessageRow),
          );
          expect(t.widget<RaftMessageRow>(row).onAuthor, isNull);
          expect(find.text('History $id'), findsOneWidget);
        }
        final activeRow = find.ancestor(
          of: find.text('Author active'),
          matching: find.byType(RaftMessageRow),
        );
        expect(t.widget<RaftMessageRow>(activeRow).onAuthor, isNotNull);
        final editor = find.descendant(
          of: find.byType(RaftComposer),
          matching: find.byType(TextField),
        );
        await t.tap(find.text('Author active'));
        await t.pump();
        expect(t.widget<TextField>(editor).controller!.text, '@active ');
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$family/$dark protocol user gets scoped Owner and typed mention; foreign same-id stays private',
      (t) async {
        final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.ledger.ingest([
          for (final (id, name, server, seq) in [
            ('local', 'artin', 's1', 1),
            ('foreign', 'Foreign artin', 'other-server', 2),
          ])
            {
              'id': id,
              'channelId': 'c1',
              'seq': seq,
              'senderId': 'owner-id',
              'senderType': 'user',
              'senderName': name,
              'sourceServerId': server,
              'content': 'Public $id body',
              'createdAt': '2026-06-22T02:30:00Z',
            },
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'local', 'foreign'};
        transport.routes['GET /agents'] = (_) => [];
        transport.routes['GET /servers/s1/members'] = (_) => [
          {'userId': 'owner-id', 'name': 'artin', 'role': 'owner'},
        ];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await t.pumpAndSettle();
        expect(find.text('Owner'), findsOneWidget);
        final foreignRow = find.ancestor(
          of: find.text('Foreign artin'),
          matching: find.byType(RaftMessageRow),
        );
        expect(t.widget<RaftMessageRow>(foreignRow).onAuthor, isNull);
        final editor = find.descendant(
          of: find.byType(RaftComposer),
          matching: find.byType(TextField),
        );
        await t.enterText(editor, '已有中文');
        await t.tap(find.text('artin'));
        await t.pump();
        final field = t.widget<TextField>(editor);
        expect(field.controller!.text, '已有中文 @artin ');
        expect(field.focusNode!.hasFocus, true);
        expect(w.threadParent, isNull);
        expect(
          w.messages.every((message) => message.string('senderType') == 'user'),
          true,
        );
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$family/$dark actual sender insertion, scoped metadata, pointer picker and save',
      (t) async {
        final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.ledger.ingest([
          {
            'id': 'm1',
            'channelId': 'c1',
            'seq': 1,
            'senderId': 'agent',
            'senderType': 'agent',
            'senderName': 'Cindy',
            'content': 'Public body',
            'createdAt': '2026-06-22T02:30:00Z',
          },
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'m1'};
        transport.routes['GET /agents'] = (_) => [
          {
            'id': 'agent',
            'name': 'Cindy',
            'status': 'active',
            'runtime': 'claude-code',
            'model': 'claude-sonnet-4-6',
            'description': 'Public designer',
          },
        ];
        transport.routes['GET /servers/s1/members'] = (_) => [];
        transport.routes['POST /channels/saved'] = (_) => {};
        transport.routes['GET /tasks/channel/c1'] = (_) => {
          'tasks': [
            {
              'id': 'm1',
              'messageId': 'm1',
              'channelId': 'c1',
              'taskNumber': 10,
              'title': 'Public linked task',
              'status': 'in_progress',
              'claimedByName': 'Cindy',
            },
          ],
        };
        transport.routes['GET /channels/c1/threads/m1'] = (_) => {
          'threadChannelId': 'thread-m1',
          'parentMessage': w.messages.first.json,
        };
        transport.routes['GET /messages/channel/thread-m1'] = (_) => {
          'messages': [],
        };
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.desktop,
                child: RaftChatView(controller: w),
              ),
            ),
          ),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await t.pumpAndSettle();
        expect(find.text('Public designer'), findsOneWidget);
        expect(find.byType(RaftMountedMessageTaskChip), findsOneWidget);
        expect(find.text('#10'), findsOneWidget);
        expect(find.text('Public linked task'), findsNothing);
        expect(
          find.byKey(const ValueKey('mounted-avatar-presence')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('message-react-m1')).hitTestable(),
          findsNothing,
        );
        expect(find.byType(RaftInlineThreadSurface), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        final editor = find.descendant(
          of: find.byType(RaftComposer),
          matching: find.byType(TextField),
        );
        await t.enterText(editor, '草案');
        await t.tap(find.text('Cindy'));
        await t.pump();
        final field = t.widget<TextField>(editor);
        expect(field.controller!.text, '草案 @Cindy ');
        expect(field.focusNode!.hasFocus, true);
        expect(w.threadParent, null);
        final row = find.byType(RaftMessageRow);
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(t.getCenter(row));
        await t.pump(const Duration(milliseconds: 200));
        expect(find.byType(RaftMessageToolbar), findsOneWidget);
        final react = find.byKey(const ValueKey('message-react-m1'));
        expect(react.hitTestable(), findsOneWidget);
        await t.tap(react);
        await t.pump();
        expect(find.byType(RaftQuickReactionPicker), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byType(RaftQuickReactionPicker), findsNothing);
        await mouse.moveTo(t.getCenter(row));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('message-save-m1')));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 20));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        expect(
          transport.calls.where(
            (r) => r.path == '/channels/saved' && r.method == 'POST',
          ),
          hasLength(1),
        );
        await t.tap(find.byType(RaftMountedMessageTaskChip));
        await t.pump();
        expect(w.threadParent?.id, 'm1');
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await mouse.removePointer();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
  }
}
