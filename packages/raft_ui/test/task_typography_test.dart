import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark task inherits document face and retains separate status action',
      (tester) async {
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
  }
}
