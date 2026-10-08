import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final density in RaftDensity.values) {
      testWidgets(
        '$family dark=$dark $density controlled section geometry and actions',
        (tester) async {
          var expanded = true, sorted = 0, added = 0;
          const disclosureKey = ValueKey('section-disclosure');
          const sortKey = ValueKey('section-sort');
          const addKey = ValueKey('section-add');
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: RaftDensityScope(
                  density: density,
                  child: StatefulBuilder(
                    builder: (context, update) => Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 320,
                        child: RaftSidebarSectionHeader(
                          label: 'Channels',
                          count: 3,
                          expanded: expanded,
                          disclosureKey: disclosureKey,
                          onExpandedChanged: (next) =>
                              update(() => expanded = next),
                          actions: [
                            RaftSidebarSectionAction(
                              key: sortKey,
                              label: 'Sort channels',
                              glyph: RaftGlyph.arrowDownUp,
                              onPressed: () => sorted++,
                            ),
                            RaftSidebarSectionAction(
                              key: addKey,
                              label: 'Create channel',
                              glyph: RaftGlyph.plus,
                              onPressed: () => added++,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final header = tester.getRect(find.byType(RaftSidebarSectionHeader));
          final target = density == RaftDensity.touch ? 48.0 : 24.0;
          expect(header.size, Size(320, target + 16));
          final disclosure = tester.getRect(find.byKey(disclosureKey));
          final sort = tester.getRect(find.byKey(sortKey));
          final add = tester.getRect(find.byKey(addKey));
          expect(disclosure.top - header.top, 12);
          expect(disclosure.left - header.left, 8);
          expect(sort.size, Size(target, target));
          expect(add.size, Size(target, target));
          expect(add.right, header.right - 8);
          expect(sort.overlaps(add), false);
          expect(disclosure.overlaps(sort), false);
          expect(add.left - sort.right, 4);
          expect(sort.left - disclosure.right, 4);
          for (final key in [sortKey, addKey]) {
            final control = find.byKey(key);
            final face = find.descendant(
              of: control,
              matching: find.byType(AnimatedContainer),
            );
            expect(tester.getSize(face), const Size(24, 24));
            final glyph = find.descendant(
              of: control,
              matching: find.byType(RaftIcon),
            );
            expect(tester.getSize(glyph), const Size(14, 14));
            expect(tester.getCenter(glyph), tester.getCenter(face));
          }
          expect(
            tester.widget<Text>(find.text('3')).style!.fontWeight,
            FontWeight.w700,
          );
          final title = tester.widget<Text>(find.text('CHANNELS'));
          expect(title.style!.fontSize, 12);
          expect(title.style!.fontWeight, FontWeight.w700);
          expect(title.style!.letterSpacing, 1.2);
          expect(
            tester.widget<Text>(find.text('3')).style!.fontFamily,
            RaftSidebarSectionRecipe(
              raftTheme(family, dark: dark).extension<RaftTokens>()!,
              density,
            ).count.fontFamily,
          );
          expect(
            tester
                .widget<AnimatedRotation>(find.byType(AnimatedRotation))
                .turns,
            .25,
          );
          await tester.tap(find.byKey(sortKey));
          expect(sorted, 1);
          expect(expanded, true);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(added, 1);
          expect(expanded, true);
          await tester.tap(find.byKey(disclosureKey));
          await tester.pumpAndSettle();
          expect(expanded, false);
          expect(
            tester
                .widget<AnimatedRotation>(find.byType(AnimatedRotation))
                .turns,
            0,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'noninteractive heading has no invented disclosure and custom emoji is separate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: RaftSidebarSectionHeader(
                label: 'Workspace',
                expanded: true,
                onExpandedChanged: null,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(RaftControl), findsNothing);
      expect(find.byType(AnimatedRotation), findsNothing);
      expect(find.text('WORKSPACE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
