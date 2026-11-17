import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// The sign-up legal checkbox is the canonical RaftCheckbox graphic, while the
// ordinary RaftCheckbox delegates to RaftCheckboxControl: two distinct call shapes.
void main() {
  for (final id in raftThemeMatrix([raftThemePackId])) {
    for (final dark in raftThemeMatrix([false, true])) {
      testWidgets(
        'legal checkbox preserves its legacy call shape $id dark=$dark',
        (tester) async {
          addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
          final pack = packForThemeId(id);
          final legalChanges = <bool>[];
          final ordinaryChanges = <bool>[];
          Widget host(bool enabled) => MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: raftTheme(pack: pack, dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  RaftAuthLegalCheckbox(
                    checked: false,
                    onChanged: enabled ? legalChanges.add : null,
                    onTerms: () {},
                    onPrivacy: () {},
                  ),
                  RaftCheckbox(
                    key: const ValueKey('ordinary-checkbox'),
                    value: false,
                    onChanged: enabled ? ordinaryChanges.add : null,
                  ),
                ],
              ),
            ),
          );

          final legalGraphic = find.descendant(
            of: find.byType(RaftAuthLegalCheckbox),
            matching: find.byType(RaftCheckbox),
          );
          for (final enabled in [true, false]) {
            await tester.pumpWidget(host(enabled));
            expect(find.byType(Checkbox), findsNothing);
            expect(tester.getSize(legalGraphic), const Size(20, 20));
            final ordinary = find.byKey(const ValueKey('ordinary-checkbox'));
            expect(tester.getSize(ordinary), const Size(20, 20));
            expect(
              find.descendant(of: ordinary, matching: find.byType(Checkbox)),
              findsNothing,
            );
            await tester.tap(legalGraphic, warnIfMissed: enabled);
            await tester.tap(ordinary, warnIfMissed: enabled);
            expect(legalChanges, [true]);
            expect(ordinaryChanges, [true]);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
