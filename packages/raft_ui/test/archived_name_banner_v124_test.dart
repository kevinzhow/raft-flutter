import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'rename collision offers open and restore without changing name dark=$dark',
      (t) async {
        var opens = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RaftArchivedNameBanner(
                name: 'held',
                canUnarchive: true,
                showHint: false,
                onUnarchive: () {},
                onOpen: () => opens++,
              ),
            ),
          ),
        );
        expect(find.text('Change name'), findsNothing);
        expect(find.text('Unarchive'), findsOneWidget);
        expect(
          t
              .widget<RaftButton>(
                find.widgetWithText(RaftButton, 'Open channel'),
              )
              .uiSize,
          RaftButtonSize.md,
        );
        await t.tap(find.text('Open channel'));
        expect(opens, 1);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
