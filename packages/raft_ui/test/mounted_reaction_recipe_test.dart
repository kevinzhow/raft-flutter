import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/mounted_reaction_recipe.dart';

void main() {
  testWidgets('count animates only on changed values and finishes in180ms', (
    tester,
  ) async {
    Widget host(int count) => MaterialApp(
      home: Center(
        child: RaftReactionCount(
          count: count,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
    await tester.pumpWidget(host(2));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpWidget(host(2));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpWidget(host(3));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, .7);
    await tester.pump(const Duration(milliseconds: 81));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pump(const Duration(milliseconds: 99));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion suppresses changed-count animation', (
    tester,
  ) async {
    Widget host(int count) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Center(
          child: RaftReactionCount(
            count: count,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(2));
    await tester.pumpWidget(host(3));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
