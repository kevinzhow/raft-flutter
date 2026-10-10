import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'sending from older history permits only its own window refresh and clears the unchanged draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      final old = {
        'id': 'old',
        'channelId': 'c1',
        'seq': '1',
        'senderId': 'alice',
        'content': 'Older message',
      };
      final fresh = {
        'id': 'fresh',
        'channelId': 'c1',
        'seq': '20',
        'senderId': 'alice',
        'content': 'Latest message',
      };
      w.ledger.ingest([old], expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = {'old'};
      w.hasNewer = true;
      a.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [fresh],
      };
      a.routes['POST /channels/c1/read'] = (_) => {};
      a.routes['POST /v2/messages'] = (o) => {
        'message': {
          'id': 'sent',
          'channelId': 'c1',
          'seq': '21',
          'senderId': 'alice',
          'content': o.data['content'],
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Send after refreshing history',
      );
      await tester.pump();
      final editor = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller;
      final before = w.channelGeneration;
      final button = tester.widget<RaftComposerAction>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RaftComposerAction &&
              widget.tooltip == 'Send message (Ctrl+Enter)',
        ),
      );
      await tester.runAsync(() async {
        button.onPressed!();
        // The editor clears on submit (Web MessageInput); wait for the ACK.
        for (
          var i = 0;
          i < 100 && !w.messages.any((m) => m.id == 'sent');
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(w.channelGeneration, before + 1);
      expect(w.messages.any((m) => m.id == 'sent'), isTrue);
      expect(editor.text, isEmpty);
      expect(w.drafts[w.draftScope()], '');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'accepted old-channel ACK before unmount cannot clear the next channel draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final requested = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      a.routes['POST /v2/messages'] = (_) {
        requested.complete();
        return response.future;
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Old pending draft');
      final oldController = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller;
      await tester.pump();
      expect(
        tester.widget<RaftComposer>(find.byType(RaftComposer)).canSend,
        isTrue,
      );
      expect(oldController.text, 'Old pending draft');
      final button = tester.widget<RaftComposerAction>(
        find.byWidgetPredicate(
          (w) =>
              w is RaftComposerAction &&
              w.tooltip == 'Send message (Ctrl+Enter)',
        ),
      );
      await tester.runAsync(() async {
        // The real state callback runs in the I/O zone so the mocked Dio
        // response can be delivered before the next test layout frame.
        button.onPressed!();
        for (var i = 0; i < 30 && !requested.isCompleted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(
        requested.isCompleted,
        isTrue,
        reason:
            'error=${w.error}; enabled=${tester.widget<RaftComposer>(find.byType(RaftComposer)).enabled}; composing=${oldController.value.composing}; calls=${a.calls.map((c) => c.path)}',
      );
      // Change authority and deliver ACK in one frame, before the old composer
      // has rebuilt or disposed. This is the lifecycle race, not a disposed-state test.
      await tester.runAsync(() async {
        w.channel = RaftChannel({'id': 'c2', 'name': 'new', 'joined': true});
        w.channelGeneration++;
        w.saveDraft('New scope draft');
        w.setError(null);
        response.complete({
          'message': {
            'id': 'ack',
            'channelId': 'c1',
            'seq': '1',
            'senderId': 'alice',
            'content': 'Old pending draft',
          },
        });
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      // Web MessageInput clears the editor on submit; the late ACK neither
      // restores it nor touches the next channel's draft.
      expect(oldController.text, isEmpty);
      expect(w.drafts[w.draftScope()], 'New scope draft');
      expect(w.messages.any((m) => m.id == 'ack'), isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'repeated context replacement after own send renders a small variable-height window',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      Map<String, dynamic> row(int i, {String? id, String? content}) => {
        'id': id ?? 'variable-$i',
        'channelId': 'c1',
        'seq': '$i',
        'senderId': 'alice',
        'senderName': 'Alice',
        'content':
            content ??
            List.filled(i % 7 + 1, 'Variable-height message $i').join('\n'),
      };
      final initial = [for (var i = 1; i <= 100; i++) row(i)];
      w.ledger.ingest(initial, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = initial.map((r) => r['id'] as String).toSet();
      a.routes['POST /channels/c1/read'] = (_) => {};
      a.routes['GET /messages/context/variable-98'] = (_) => {
        'messages': initial.skip(60).toList(),
        'hasOlder': true,
      };
      const source = 'flowchart LR\n A[中文输入] --> B[日本語確認]';
      final sent = row(
        101,
        id: 'rich-next',
        content: 'Native rich\n\n```mermaid\n$source\n```',
      );
      a.routes['POST /v2/messages'] = (_) => {'message': sent};
      final response = Completer<Map<String, dynamic>>();
      a.routes['GET /messages/context/rich-next'] = (_) => response.future;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() => w.jumpToMessage('c1', 'variable-98'));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('message-variable-98')), findsOneWidget);
      await tester.drag(find.byType(ChatAnimatedList), const Offset(0, 450));
      await tester.pump(const Duration(milliseconds: 50));
      Future<void>? jumping;
      await tester.runAsync(() async {
        expect(await w.send(sent['content'] as String), isTrue);
        jumping = w.jumpToMessage('c1', 'rich-next');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 16));
      response.complete({
        'messages': [row(100), sent],
        'hasOlder': true,
      });
      await tester.runAsync(() => jumping!);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // A row sent from this session keeps its optimistic presentation key.
      final target = find.byKey(
        ValueKey(
          'message-${w.messageKey(w.messages.singleWhere((m) => m.id == 'rich-next'))}',
        ),
      );
      expect(target, findsOneWidget);
      expect(
        find.descendant(of: target, matching: find.byType(RaftMermaidBlock)),
        findsOneWidget,
      );
      expect(target.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'committed context cannot retain 5364px history offset beyond its smaller viewport',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      Map<String, dynamic> row(int i) => {
        'id': 'offset-$i',
        'channelId': 'c1',
        'seq': '$i',
        'senderId': 'alice',
        'senderName': 'Alice',
        'content': 'Context row $i',
      };
      final initial = [for (var i = 1; i <= 100; i++) row(i)];
      w.ledger.ingest(initial, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = initial.map((r) => r['id'] as String).toSet();
      a.routes['POST /channels/c1/read'] = (_) => {};
      a.routes['GET /messages/context/offset-94'] = (_) => {
        'messages': initial.skip(84).toList(),
        'hasOlder': true,
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SizedBox(height: 602, child: RaftChatView(controller: w)),
          ),
        ),
      );
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final list = tester.state(find.byType(ChatAnimatedList));
      var viewport = tester
          .widget<CustomScrollView>(
            find.descendant(
              of: find.byType(ChatAnimatedList),
              matching: find.byType(CustomScrollView),
            ),
          )
          .controller!;
      expect(viewport.position.maxScrollExtent, greaterThan(5364));
      viewport.jumpTo(5364);
      await tester.pump();
      expect(viewport.offset, 5364);
      await tester.runAsync(() => w.jumpToMessage('c1', 'offset-94'));
      // The accepted 16-row context stages behind the real retained timeline.
      // Source keeps the old reading position until the new target is centered.
      expect(w.messages, hasLength(16));
      expect(viewport.offset, 5364);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final dynamic chatState = tester.state(find.byType(RaftChatView));
      viewport = chatState.viewport as ScrollController;
      expect(
        viewport.offset,
        inInclusiveRange(
          viewport.position.minScrollExtent,
          viewport.position.maxScrollExtent,
        ),
      );
      expect(
        find.byKey(const ValueKey('message-offset-94')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.state(find.byType(ChatAnimatedList)), isNot(same(list)));
      final anchor = viewport.offset;
      w.setError(null);
      await tester.pump();
      expect(viewport.offset, anchor);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'same-chat context jump replaces its observer and reveals target; history append retains the new list',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      final first = [
        for (var i = 0; i < 60; i++)
          {
            'id': 'old-$i',
            'channelId': 'c1',
            'seq': '${i + 1}',
            'senderId': 'alice',
            'senderName': 'Alice',
            'content': 'Old message $i',
          },
      ];
      w.ledger.ingest(first, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = first.map((r) => r['id'] as String).toSet();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final list = tester.state(find.byType(ChatAnimatedList));
      final next = [
        for (var i = 0; i < 20; i++)
          {
            'id': 'context-$i',
            'channelId': 'c1',
            'seq': '${i + 100}',
            'senderId': 'alice',
            'senderName': 'Alice',
            'content': 'Context message $i',
          },
      ];
      a.routes['GET /messages/context/context-16'] = (_) => {'messages': next};
      await tester.runAsync(() => w.jumpToMessage('c1', 'context-16'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final replacementList = tester.state(find.byType(ChatAnimatedList));
      expect(replacementList, isNot(same(list)));
      final target = find.byKey(const ValueKey('message-context-16'));
      expect(target, findsOneWidget);
      expect(target.hitTestable(), findsOneWidget);
      w.ledger.ingest([
        {
          'id': 'older',
          'channelId': 'c1',
          'seq': '90',
          'content': 'Older history',
        },
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['c1']!.add('older');
      w.setError(null);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.state(find.byType(ChatAnimatedList)),
        same(replacementList),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
