import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Android displays progress and latches until release ($dark)', (
      tester,
    ) async {
      final pending = Completer<void>();
      var refreshes = 0;
      await tester.pumpWidget(
        host(
          platform: TargetPlatform.android,
          dark: dark,
          onRefresh: () {
            refreshes++;
            return pending.future;
          },
        ),
      );
      final start =
          tester.getTopLeft(find.byType(ListView)) + const Offset(120, 100);
      final drag = await tester.startGesture(start);
      await drag.moveBy(const Offset(0, 40));
      await drag.moveBy(const Offset(0, 100));
      await tester.pump();
      final indicator = find.byType(RefreshProgressIndicator);
      expect(indicator, findsOneWidget);
      expect(
        tester.widget<RefreshProgressIndicator>(indicator).value,
        closeTo(.77, .01),
      );
      expect(refreshes, 0);
      await drag.moveBy(const Offset(0, 80));
      await drag.moveBy(const Offset(0, -80));
      await drag.up();
      await tester.pump();
      expect(refreshes, 1);
      expect(tester.widget<RefreshProgressIndicator>(indicator).value, isNull);
      expect(find.text('Held row'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(indicator, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Inline indicator reserves the damped distance and cancels', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      host(
        platform: TargetPlatform.iOS,
        onRefresh: () async {
          refreshes++;
        },
      ),
    );
    final list = find.byType(ListView);
    final top = tester.getTopLeft(list).dy;
    final drag = await tester.startGesture(tester.getCenter(list));
    await drag.moveBy(const Offset(0, 40));
    await drag.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(tester.getTopLeft(find.text('Held row')).dy - top, closeTo(55, .1));
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(list).dy, top);
    expect(refreshes, 0);
    final held = await tester.startGesture(tester.getCenter(list));
    await tester.pump(const Duration(milliseconds: 600));
    await held.moveBy(
      const Offset(0, 230),
      timeStamp: const Duration(milliseconds: 600),
    );
    await held.up();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    final pointer = await tester.startGesture(
      tester.getCenter(list),
      kind: PointerDeviceKind.mouse,
    );
    await pointer.moveBy(const Offset(0, 230));
    await pointer.up();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget host({
  required TargetPlatform platform,
  required Future<void> Function() onRefresh,
  bool dark = false,
}) => MaterialApp(
  theme: raftTheme(dark: dark).copyWith(platform: platform),
  home: Scaffold(
    body: RaftPullToRefresh(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [Text('Held row')],
      ),
    ),
  ),
);
