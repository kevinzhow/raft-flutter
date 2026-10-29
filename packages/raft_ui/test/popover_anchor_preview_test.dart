import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/menu_popup_backend_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  testWidgets(
    'controlled language preview keeps keyboard and typed selection',
    (tester) async {
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: TargetPlatform.linux),
            home: Scaffold(body: menuPopupBackendPreview()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RaftMenuPopupBackend), findsNothing);
        await tester.tap(find.text('Choose a language'));
        await tester.pumpAndSettle();
        expect(find.byType(RaftMenuPopupBackend), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(RaftMenuPopupBackend), findsNothing);
        await tester.tap(find.text('Choose a language'));
        await tester.pumpAndSettle();
        final popup = tester.widget<RaftMenuPopupBackend>(
          find.byType(RaftMenuPopupBackend),
        );
        expect(
          popup.entries
              .where((entry) => entry.selected)
              .map((entry) => entry.label),
          ['中文'],
        );
        expect(
          popup.entries
              .singleWhere((entry) => entry.label == 'Unavailable')
              .enabled,
          isFalse,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(RaftMenuPopupBackend), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    skip: raftLookSkip(raftLookRaft),
  );
}
