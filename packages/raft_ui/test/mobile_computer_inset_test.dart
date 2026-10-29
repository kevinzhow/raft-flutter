import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final bottom in [24.0, 48.0, 116.0]) {
      testWidgets(
        'Computer directory ${dark ? 'dark' : 'light'} clears $bottom padding',
        (t) async {
          t.view.physicalSize = const Size(390, 600);
          t.view.devicePixelRatio = 1;
          t.view.padding = FakeViewPadding(bottom: bottom);
          addTearDown(t.view.reset);
          var selected = false;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: RaftMobileComputerList(
                  emptyTitle: 'No computers yet',
                  emptyDetail: 'Add a computer',
                  addLabel: 'Add Computer',
                  retryLabel: 'Retry',
                  rows: [
                    for (var i = 0; i < 15; i++)
                      RaftComputerRow(
                        key: ValueKey('computer-$i'),
                        mobile: true,
                        name: 'Computer $i',
                        description: 'Shared machine',
                        runLabel: 'Online',
                        offline: false,
                        dot: RaftComputerDot.online,
                        onTap: () => selected = true,
                      ),
                  ],
                ),
              ),
            ),
          );
          final position = t
              .state<ScrollableState>(find.byType(Scrollable))
              .position;
          // Variable-height slivers refine their extent as later cards mount.
          for (var i = 0; i < 3; i++) {
            position.jumpTo(position.maxScrollExtent);
            await t.pump();
          }
          expect(position.pixels, position.maxScrollExtent);
          final last = find.byKey(const ValueKey('computer-14'));
          expect(t.getRect(last).bottom, lessThanOrEqualTo(600 - bottom));
          await t.tap(last);
          await t.pump();
          expect(selected, isTrue);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
