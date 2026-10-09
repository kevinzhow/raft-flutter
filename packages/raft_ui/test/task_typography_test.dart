import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> loadTaskFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final family in ['HankenGrotesk', 'Inter', 'Geist', 'GeistMono']) {
    ByteData data;
    try {
      data = await rootBundle.load('packages/raft_ui/assets/fonts/$family.ttf');
    } on FlutterError {
      data = await rootBundle.load('assets/fonts/$family.ttf');
    }
    await (FontLoader(
      'packages/raft_ui/$family',
    )..addFont(Future.value(data))).load();
  }
});

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark task inherits document face and retains separate status action',
      (tester) async {
        await loadTaskFonts(tester);
        var opened = 0;
        String? selected;
        final theme = raftTheme(family, dark: dark);
        final tokens = theme.extension<RaftTokens>()!;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: DefaultTextStyle(
                style: RaftTaskSectionRecipe(tokens).documentStyle,
                child: SizedBox(
                  width: 600,
                  child: RaftTaskCard(
                    title: 'Review the thread header strip baselines',
                    number: '210',
                    channel: 'design',
                    description: 'Source task description',
                    status: 'todo',
                    onTap: () => opened++,
                    statusOptions: const ['todo', 'in_progress'],
                    onStatus: (value) => selected = value,
                  ),
                ),
              ),
            ),
          ),
        );
        // MainLayout font-display is inherited; the number keeps its explicit
        // Source family: font-mono in Brutal, font-sans in Elegant.
        expect(
          tester
              .widget<Text>(
                find.text('Review the thread header strip baselines'),
              )
              .style!
              .fontFamily,
          tokens.headingFont,
        );
        expect(
          tester
              .widget<Text>(find.text('Source task description'))
              .style!
              .fontFamily,
          tokens.headingFont,
        );
        expect(
          tester.widget<Text>(find.text('#210')).style!.fontFamily,
          family == RaftFamily.brutal ? tokens.monoFont : tokens.bodyFont,
        );
        await tester.tap(find.text('Review the thread header strip baselines'));
        expect(opened, 1);
        await tester.tap(find.text('Todo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('In Progress'));
        await tester.pumpAndSettle();
        expect(selected, 'in_progress');
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$family/$dark inline status inherits its document face', (
      tester,
    ) async {
      await loadTaskFonts(tester);
      final theme = raftTheme(family, dark: dark);
      final tokens = theme.extension<RaftTokens>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RaftInlineLineBox(
                style: RaftTaskSectionRecipe(tokens).documentStyle,
                child: RaftTaskStatusEditor(
                  status: 'in_progress',
                  options: raftTaskStatuses,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('In Progress')).style!.fontFamily,
        tokens.headingFont,
      );
      // Source DOM: h20 Brutal badge keeps the h24 strut; the h22 Elegant
      // badge plus its baseline descent grows the inline line to h25.
      expect(
        tester.getSize(find.byType(RaftInlineLineBox)).height,
        family == RaftFamily.brutal ? 24 : 25,
      );
      if (family == RaftFamily.brutal) {
        final badge = find
            .ancestor(
              of: find.text('In Progress'),
              matching: find.byType(DecoratedBox),
            )
            .first;
        // Actual Chromium DOM: badge top 3, h20 in the document's h24 line.
        expect(tester.getTopLeft(badge).dy, 3);
        expect(tester.getSize(badge).height, 20);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('task keeps the Source fractional meta line and card height', (
    tester,
  ) async {
    await loadTaskFonts(tester);
    final theme = raftTheme(RaftFamily.brutal);
    final tokens = theme.extension<RaftTokens>()!;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: DefaultTextStyle(
              style: RaftTaskSectionRecipe(tokens).documentStyle,
              child: SizedBox(
                width: 358,
                child: RaftTaskCard(
                  title: 'Review the thread header strip baselines',
                  number: '210',
                  channel: 'design',
                  status: 'in_review',
                  statusOptions: raftTaskStatuses,
                  onStatus: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final number = find.ancestor(
      of: find.text('#210'),
      matching: find.byType(RaftCssText),
    );
    expect(tester.getSize(number).height, 16.5);
    // Source DOM measurement, 358px card, one title line, editable status.
    expect(tester.getSize(find.byType(RaftTaskCard)).height, 103.25);
    expect(tester.takeException(), isNull);
  });
}
