import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<void> pump(WidgetTester t, {required bool hasMore, Widget? slot}) =>
      t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                RaftThreadTimelineTopSliver(
                  hasMore: hasMore,
                  historyLimited: true,
                  loadingOlder: false,
                  loadingOlderLabel: 'Loading',
                  historyLimitedLabel: 'Older replies are limited',
                  beginningLabel: 'Beginning',
                  replyCountLabel: '2 replies',
                  historyLimitedChild: slot,
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('the paywall replaces the one-line notice at the limit', (
    t,
  ) async {
    await pump(t, hasMore: false, slot: const Text('paywall'));
    expect(find.text('paywall'), findsOneWidget);
    expect(find.text('Older replies are limited'), findsNothing);
    expect(find.text('2 replies'), findsOneWidget);
  });

  testWidgets('older pages first: the slot waits, the line is not shown', (
    t,
  ) async {
    await pump(t, hasMore: true, slot: const Text('paywall'));
    expect(find.text('paywall'), findsNothing);
    expect(find.text('Older replies are limited'), findsNothing);
  });

  testWidgets('without a slot the line stays', (t) async {
    await pump(t, hasMore: false);
    expect(find.text('Older replies are limited'), findsOneWidget);
  });
}
