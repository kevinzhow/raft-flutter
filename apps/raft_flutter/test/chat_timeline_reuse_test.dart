import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

Widget host(WorkspaceController w, {double scale = 1, bool dark = false}) =>
    MaterialApp(
      theme: raftTheme(dark: dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: RaftChatView(controller: w)),
    );

Future<WorkspaceController> open(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  w.messageDomain.ledger.switchServer('s1');
  final rows = contextRows('reuse', count: 80);
  w.messageDomain.ledger.ingest(
    rows,
    expectedGeneration: w.messageDomain.ledger.generation,
  );
  w.messageDomain.visibleIds['c1'] = rows
      .map((row) => row['id'] as String)
      .toSet();
  await tester.pumpWidget(host(w));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  return w;
}

void main() {
  testWidgets('bottom controls do not invalidate displayed message rows', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Back to Bottom'), findsNothing);
    final rows = find.byType(RaftMessageTile);
    Map<Key?, RaftMessageTile> snapshot() => {
      for (final row in tester.widgetList<RaftMessageTile>(rows)) row.key: row,
    };
    final before = snapshot();
    expect(before, isNotEmpty);
    final scroll = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(RaftMessageTimeline),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final latest = scroll.pixels;
    scroll.jumpTo(latest - 120);
    await tester.pumpAndSettle();
    expect(find.text('Back to Bottom'), findsOneWidget);
    final after = snapshot();
    final common = before.keys.toSet().intersection(after.keys.toSet());
    expect(common, isNotEmpty);
    for (final key in common) {
      expect(
        after[key],
        same(before[key]),
        reason: 'Crossing the bottom threshold must preserve row $key.',
      );
    }
    await tester.tap(find.text('Back to Bottom'));
    await tester.pumpAndSettle();
    expect(scroll.pixels, closeTo(latest, 1));
    expect(find.text('Back to Bottom'), findsNothing);
  });
  testWidgets(
    'unrelated workspace changes preserve message row builds and paint',
    (tester) async {
      final w = await open(tester);
      final rect = paintedMessage(tester, 'reuse-79');
      expect(rect, isNotNull);
      final builds = RaftMessageTimeline.debugRowBuilds;
      for (var i = 0; i < 5; i++) {
        w.notifyListeners();
        await tester.pump();
        await tester.pump();
        expect(paintedMessage(tester, 'reuse-79'), rect);
      }
      expect(RaftMessageTimeline.debugRowBuilds, builds);
    },
  );

  testWidgets(
    'retained rows refresh message edits, theme and system text size',
    (tester) async {
      final w = await open(tester);
      final old = paintedMessage(tester, 'reuse-79')!;
      final changed = contextRows('reuse')[79]
        ..['content'] = 'Edited live message';
      w.messageDomain.ledger.ingest([
        changed,
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('Edited live message'), findsWidgets);
      expect(find.textContaining('reuse message 79'), findsNothing);
      final edited = paintedMessage(tester, 'reuse-79')!;
      expect(edited.height, lessThan(old.height));
      var builds = RaftMessageTimeline.debugRowBuilds;
      await tester.pumpWidget(host(w, dark: true));
      await tester.pumpAndSettle();
      expect(RaftMessageTimeline.debugRowBuilds, greaterThan(builds));
      expect(paintedMessage(tester, 'reuse-79')!.height, edited.height);
      builds = RaftMessageTimeline.debugRowBuilds;
      await tester.pumpWidget(host(w, dark: true, scale: 2));
      await tester.pumpAndSettle();
      expect(RaftMessageTimeline.debugRowBuilds, greaterThan(builds));
      expect(
        paintedMessage(tester, 'reuse-79')!.height,
        greaterThan(edited.height),
      );
    },
  );
}
