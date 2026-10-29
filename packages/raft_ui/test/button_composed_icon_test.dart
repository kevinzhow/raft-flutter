import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

// raft-ui 0.7.0 textMd: px-3, with inline-start pl-2.5. A composed
// Widget label must supply the same source state as a String label.
void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Widget icon and Widget label match String Button padding/$dark',
      (t) async {
        RaftSlotStyle? composed, strings;
        var taps = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftButton.text(
                      key: const Key('composed'),
                      icon: const RaftIcon(RaftGlyph.plus, size: 16),
                      label: const Text('Inspect'),
                      onPressed: () => taps++,
                      styleBuilder: (_, _, style) {
                        composed = style;
                        return style;
                      },
                    ),
                    RaftButton(
                      key: const Key('strings'),
                      label: 'Inspect',
                      glyph: RaftGlyph.plus,
                      uiVariant: RaftButtonVariant.ghost,
                      onPressed: () => taps++,
                      styleBuilder: (_, _, style) {
                        strings = style;
                        return style;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(strings!.padding.left, 10);
        expect(strings!.padding.right, 12);
        expect(composed!.padding, strings!.padding);
        Finder painted(String key) => find
            .descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(RaftRecipeBox),
            )
            .first;
        expect(t.getSize(painted('composed')), t.getSize(painted('strings')));
        for (final key in ['composed', 'strings']) {
          await t.tap(find.byKey(Key(key)));
          await t.pump();
        }
        expect(taps, 2);
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'composed trailing icon uses the source inline-end state/$dark',
      (t) async {
        RaftSlotStyle? style;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftButton(
                  child: const Text('Inspect'),
                  trailingGlyph: RaftGlyph.plus,
                  uiVariant: RaftButtonVariant.ghost,
                  onPressed: () {},
                  styleBuilder: (_, _, root) {
                    style = root;
                    return root;
                  },
                ),
              ),
            ),
          ),
        );
        expect(style!.padding.left, 12);
        expect(style!.padding.right, 10);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets('leading-only content keeps the no-label padding/$dark', (
      t,
    ) async {
      RaftSlotStyle? style;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Center(
              child: RaftButton(
                leading: const Text('Standalone content'),
                uiVariant: RaftButtonVariant.ghost,
                onPressed: () {},
                styleBuilder: (_, _, root) {
                  style = root;
                  return root;
                },
              ),
            ),
          ),
        ),
      );
      expect(style!.padding.left, 12);
      expect(style!.padding.right, 12);
      await t.pumpWidget(const SizedBox());
    });
  }
}
