import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  test(
    'dark inset recipe clips to CSS padding box and keeps source offsets',
    () {
      final tokens = raftTheme(
        RaftFamily.elegant,
        dark: true,
      ).extension<RaftTokens>()!;
      final recipe = RaftFieldInsetRecipe(tokens);
      final box = recipe.paddingBox(
        const Rect.fromLTWH(0, 0, 300, 38),
        BorderRadius.circular(6),
        1,
      );
      expect(box.outerRect, const Rect.fromLTWH(1, 1, 298, 36));
      expect(box.tlRadiusX, 5);
      expect(recipe.line.a, closeTo(.35, 1 / 255));
      expect(recipe.line.r, 0);
      expect(recipe.top.a, closeTo(.30, 1 / 255));
      expect(recipe.top.r, 0);
      expect(recipe.topOffset, 1);
      expect(recipe.topBlurRadius, 2);
      expect(recipe.topBlurSigma, 1);
      expect(recipe.bottomOffset, 1); // outer, not inset
    },
  );

  testWidgets('disabled picker blocks pointer, keys and controller opening', (
    tester,
  ) async {
    var enabled = false;
    var activated = 0;
    late StateSetter rebuild;
    final controller = RaftMenuController();
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return RaftDensityScope(
                  density: RaftDensity.desktop,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RaftDropdownMenu(
                        label: 'Sort',
                        enabled: enabled,
                        glyph: RaftGlyph.arrowDownUp,
                        trailingGlyph: RaftGlyph.chevronDown,
                        controller: controller,
                        entries: [
                          RaftMenuEntry(
                            label: 'Relevance',
                            onPressed: () => activated++,
                          ),
                        ],
                      ),
                      RaftTextButton(label: 'Next', onPressed: () {}),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      final glyphs = tester
          .widgetList<RaftIcon>(find.byType(RaftIcon))
          .toList();
      expect(glyphs.map((icon) => icon.glyph), [
        RaftGlyph.arrowDownUp,
        RaftGlyph.chevronDown,
      ]);
      expect(glyphs.map((icon) => icon.size), [14, 12]);
      final trigger = find.widgetWithText(RaftControl, 'Sort');
      expect(
        tester.getSemantics(trigger).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      await tester.tapAt(tester.getCenter(trigger));
      controller.open();
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(find.byType(RaftMenuItem), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(activated, 0);

      rebuild(() => enabled = true);
      await tester.pump();
      await tester.tapAt(tester.getCenter(trigger));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('Relevance'), findsOneWidget);
      rebuild(() => enabled = false);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(find.byType(RaftMenuItem), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(activated, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
      controller.dispose();
    }
  });

  testWidgets('picker and text trigger retain leading and trailing glyphs', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftDensityScope(
            density: RaftDensity.desktop,
            child: RaftTextButton(
              label: 'Channel',
              glyph: RaftGlyph.hash,
              trailingGlyph: RaftGlyph.chevronDown,
              onPressed: () => selected++,
            ),
          ),
        ),
      ),
    );
    final icons = tester.widgetList<RaftIcon>(find.byType(RaftIcon)).toList();
    expect(icons.map((i) => i.glyph), [RaftGlyph.hash, RaftGlyph.chevronDown]);
    expect(icons.last.size, 12);
    await tester.tap(find.text('Channel'));
    expect(selected, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('source Search history glyphs paint inside their12px slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RaftIcon(RaftGlyph.clock3, size: 12),
              RaftIcon(RaftGlyph.star, size: 12),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final glyph in [RaftGlyph.clock3, RaftGlyph.star]) {
      final finder = find.byWidgetPredicate(
        (w) => w is RaftIcon && w.glyph == glyph,
      );
      expect(tester.getSize(finder), const Size(12, 12));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
