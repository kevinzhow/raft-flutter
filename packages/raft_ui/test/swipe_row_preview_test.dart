import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/swipe_row_previews.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets('${dark ? 'dark' : 'light'} swipe row preview builds', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(body: swipeRowPreview()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
