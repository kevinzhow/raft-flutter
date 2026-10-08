import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'an early void focus receipt retries until the actual lazy target mounts',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, a) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      List<Map<String, dynamic>> page(String prefix) => [
        for (var i = 0; i < 80; i++)
          {
            'id': '$prefix-$i',
            'channelId': 'c1',
            'seq': '${i + 1}',
            'senderId': 'alice',
            'content': 'Lazy context row $i',
          },
      ];
      final initial = page('old'), replacement = page('new');
      w.ledger.ingest(initial, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = initial.map((r) => r['id'] as String).toSet();
      a.routes['GET /messages/context/new-79'] = (_) => {
        'messages': replacement,
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(RaftChatView));
      var attempts = 0;
      bool? firstMounted;
      await tester.runAsync(() => w.jumpToMessage('c1', 'new-79'));
      await tester.pump();
      state.adapter.attachScrollMethods(
        scrollToMessageId:
            (
              String id, {
              Duration duration = Duration.zero,
              Curve curve = Curves.linear,
              double alignment = 0,
              double offset = 0,
            }) async {
              attempts++;
              if (attempts == 1) {
                firstMounted = find
                    .byKey(const ValueKey('message-new-79'))
                    .evaluate()
                    .isNotEmpty;
                // A normal void return is permitted while the package has no target
                // in its internal list. It is not a rendered focus acknowledgment.
                return;
              }
              state.viewport.jumpTo(state.viewport.position.maxScrollExtent);
            },
        scrollToIndex: (
          int index, {
          Duration duration = Duration.zero,
          Curve curve = Curves.linear,
          double alignment = 0,
          double offset = 0,
        }) async {},
      );

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(firstMounted, isFalse);
      expect(attempts, greaterThanOrEqualTo(2));
      expect(
        find.byKey(const ValueKey('message-new-79')).hitTestable(),
        findsOneWidget,
      );
      expect(state.scrolledHighlight, 'new-79');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'partial row under page header is rejected and actual render geometry repairs stale observer focus',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (w, a) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      final page = [
        for (var i = 0; i < 80; i++)
          {
            'id': 'focus-$i',
            'channelId': 'c1',
            'seq': '${i + 1}',
            'senderId': 'alice',
            'content': 'Public focus fixture $i',
          },
      ];
      w.ledger.ingest(page, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = page.map((row) => row['id'] as String).toSet();
      a.routes['GET /messages/context/focus-0'] = (_) => {'messages': page};
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            appBar: AppBar(title: const Text('Source channel header')),
            body: RaftChatView(controller: w),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(RaftChatView));
      await tester.runAsync(() => w.jumpToMessage('c1', 'focus-0'));
      await tester.pump();
      bool? partialReceipt;
      state.adapter.attachScrollMethods(
        scrollToMessageId:
            (
              String id, {
              Duration duration = Duration.zero,
              Curve curve = Curves.linear,
              double alignment = 0,
              double offset = 0,
            }) async {
              final row = find.byKey(const ValueKey('message-focus-0'));
              if (row.evaluate().isEmpty) {
                return;
              }
              final render = tester.renderObject<RenderBox>(row);
              final view = RenderAbstractViewport.of(render);
              final position = state.viewport.position as ScrollPosition;
              final staleOffset =
                  view.getOffsetToReveal(render, 0).offset +
                  render.size.height / 2;
              state.viewport.jumpTo(
                staleOffset.clamp(
                  position.minScrollExtent,
                  position.maxScrollExtent,
                ),
              );
              await WidgetsBinding.instance.endOfFrame;
              partialReceipt = state.focusReceiptVisible(id) as bool;
            },
        scrollToIndex: (
          int index, {
          Duration duration = Duration.zero,
          Curve curve = Curves.linear,
          double alignment = 0,
          double offset = 0,
        }) async {},
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (state.scrolledHighlight == 'focus-0') {
          break;
        }
      }
      expect(partialReceipt, false);
      expect(state.scrolledHighlight, 'focus-0');
      expect(state.focusReceiptVisible('focus-0'), true);
      final actions = find.descendant(
        of: find.byKey(const ValueKey('message-focus-0')),
        matching: find.byTooltip('Message actions'),
      );
      expect(actions.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(actions).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
