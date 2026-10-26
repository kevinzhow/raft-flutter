import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web Modal.tsx owns the scrollport. DialogCard.tsx places the header, form
// and actions in one natural-height surface; desktop actions are not pinned.
void main() {
  for (final size in const [Size(390, 844), Size(856, 944), Size(944, 856)]) {
    for (final dark in [false, true]) {
      testWidgets('product card scrolls as a whole: $size dark=$dark', (
        t,
      ) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        addTearDown(() => t.pumpWidget(const SizedBox()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              dark: dark,
              platform: size.width == 390
                  ? TargetPlatform.linux
                  : TargetPlatform.android,
            ),
            home: Scaffold(
              body: RaftModalBackdrop(
                child: RaftDialog.card(
                  title: 'Review changes',
                  onClose: () {},
                  footer: RaftButton(label: 'Finish', onPressed: () {}),
                  child: const SizedBox(height: 1300),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Review changes').hitTestable(), findsOneWidget);
        expect(find.text('Finish').hitTestable(), findsNothing);
        final viewport = find.byType(Scrollable).first;
        await t.scrollUntilVisible(
          find.text('Finish'),
          350,
          scrollable: viewport,
        );
        expect(find.text('Finish').hitTestable(), findsOneWidget);
        expect(find.text('Review changes').hitTestable(), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }
}
