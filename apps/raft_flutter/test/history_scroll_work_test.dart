import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets('paging extends the measured index during a held drag', (
    tester,
  ) async {
    final scroll = RaftTimelineScrollController(bottomAnchored: true);
    addTearDown(scroll.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    var messages = [
      for (var i = 0; i < 1000; i++)
        chat.Message.text(id: '$i', authorId: 'a', text: '$i'),
    ];
    var shift = 0;
    Widget view() => MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.macOS),
      home: RaftMessageTimeline(
        controller: scroll,
        messages: messages,
        centerIndex: 999 + shift,
        epoch: 0,
        extentRevision: 0,
        estimateRow: (_) => 50,
        rowRevision: (_) => 0,
        rowBuilder: (_, i) =>
            SizedBox(height: 50, child: Text('row-${messages[i].id}')),
        indexOfId: (id) => messages.indexWhere((m) => m.id == id),
        slivers: (a, b) => [a, b],
      ),
    );
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(RaftMessageTimeline));
    final original = state.extentIndex;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(RaftMessageTimeline)),
    );
    try {
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      final before = scroll.position.pixels;
      messages = [
        for (var i = -50; i < 0; i++)
          chat.Message.text(id: '$i', authorId: 'a', text: '$i'),
        ...messages,
      ];
      shift = 50;
      await tester.pumpWidget(view());
      expect(
        identical(state.extentIndex, original),
        isTrue,
        reason: 'Retain measured history instead of rebuilding it during input',
      );
      expect(scroll.position.pixels, closeTo(before, .01));
    } finally {
      await gesture.up();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a burst of workspace notifications shares one pending synchronization',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, _) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(RaftChatView));
      state.sync();
      final first = state.updates;
      for (var i = 0; i < 30; i++) {
        state.sync();
      }
      expect(
        identical(first, state.updates),
        isTrue,
        reason: 'No redundant queued full-window work for the same notification burst',
      );
      await tester.pumpAndSettle();
      expect(find.byType(RaftComposer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
