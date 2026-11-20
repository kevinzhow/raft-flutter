import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.android),
    (const Size(1280, 900), TargetPlatform.linux),
  ]) {
    testWidgets('app details pin identity and actions at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final opener = FocusNode();
      addTearDown(opener.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                focusNode: opener,
                onPressed: () => showRaftDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (modal) => RaftConnectedAppDetailCard(
                    eyebrow: 'App detail',
                    name: 'Garden',
                    initials: 'G',
                    byline: 'By Garden Team',
                    onClose: () => Navigator.of(modal).pop(),
                    closeLabel: 'Close app detail',
                    sections: [
                      for (var index = 0; index < 30; index++)
                        RaftConnectedAppDetailSection(
                          title: 'Section $index',
                          child: const Text('Garden details and permissions'),
                        ),
                    ],
                    footer: [
                      RaftConnectedAppButton(
                        label: 'Close',
                        onPressed: () => Navigator.of(modal).pop(),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open Garden'),
              ),
            ),
          ),
        ),
      );
      opener.requestFocus();
      await tester.tap(find.text('Open Garden'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = find.text('Garden');
      final footer = find.text('Close');
      expect(title.hitTestable(), findsOneWidget);
      expect(footer.hitTestable(), findsOneWidget);
      final titlePosition = tester.getTopLeft(title);
      final footerPosition = tester.getTopLeft(footer);
      final body = find.ancestor(
        of: find.text('Section 0'),
        matching: find.byType(Scrollable),
      );
      await tester.drag(body, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(title), titlePosition);
      expect(tester.getTopLeft(footer), footerPosition);
      expect(find.text('Section 0').hitTestable(), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(opener.hasFocus, isTrue);
    });
  }
}
