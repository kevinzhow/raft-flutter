import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

// raft-ui 0.7.0 textMd uses px-3. Only data-icon=inline-start/end
// activates pl/pr-2.5; a plain Lucide SVG child has no such attribute.
void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'explicit Button source icon markers select padding dark=$dark',
      (t) async {
        for (final (start, end, expected) in [
          (false, false, const EdgeInsets.symmetric(horizontal: 12)),
          (true, false, const EdgeInsets.only(left: 10, right: 12)),
          (false, true, const EdgeInsets.only(left: 12, right: 10)),
        ]) {
          RaftSlotStyle? actual;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: Center(
                  child: RaftButton(
                    label: 'Inspect',
                    glyph: RaftGlyph.plus,
                    uiSize: RaftButtonSize.sm,
                    iconInlineStart: start,
                    iconInlineEnd: end,
                    onPressed: () {},
                    styleBuilder: (_, _, root) {
                      actual = root;
                      return root;
                    },
                  ),
                ),
              ),
            ),
          );
          expect(actual!.padding, expected);
        }
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'actual task Add Another matches its plain Web SVG dark=$dark',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1280, 800);
        addTearDown(t.view.reset);
        await (FontLoader('packages/raft_ui/SpaceGrotesk')..addFont(
              rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
            ))
            .load();
        final title = TextEditingController();
        addTearDown(title.dispose);
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        var added = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RaftCreateTaskDialogView(
                titles: [title],
                filledCount: 0,
                onClose: () {},
                onSubmit: () {},
                onAddRow: () => added++,
                onRemoveRow: (_) {},
              ),
            ),
          ),
        );
        final button = find.byKey(const ValueKey('create-task-add-row'));
        final box = find
            .descendant(of: button, matching: find.byType(RaftRecipeBox))
            .first;
        // Same font, icon=16, gap=8, px-3, used 1px border. Saved real Web
        // content=102.5625 and button=128.5625, not a score-derived tolerance.
        expect(
          {
            'inlineStart': t.widget<RaftButton>(button).iconInlineStart,
            'width': t.getSize(box).width,
          },
          {'inlineStart': false, 'width': closeTo(128.5625, .01)},
          reason: 'Web passes plain Plus with no data-icon marker at DPR 1',
        );
        await t.tap(button);
        await t.pump();
        expect(added, 1);
      },
    );
  }
}
