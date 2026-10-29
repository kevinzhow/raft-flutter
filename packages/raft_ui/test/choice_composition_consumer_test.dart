import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/web_agent_reset_options.g.dart';
import 'package:raft_ui/src/recipes/web_xlsx_tabs_layout.g.dart';
import 'package:raft_ui/test_themes.dart';

// These assertions bind the actual Reset/XLSX consumers to generated product
// composition slots extracted from Web db5e399f, not a standalone specimen.
// The real paired-screen visual gate remains separate.
Map<String, dynamic> _xlsx() {
  var root = Directory.current.absolute;
  while (true) {
    final file = File(
      '${root.path}/tool/parity-ext/fixtures/threadattachments.json',
    );
    if (file.existsSync()) {
      final fixture = jsonDecode(file.readAsStringSync()) as Map;
      return Map<String, dynamic>.from(
        fixture['documents']['xlsx']['preview'] as Map,
      );
    }
    if (root.parent.path == root.path)
      throw StateError('Missing shared XLSX fixture');
    root = root.parent;
  }
}

Future<void> _host(WidgetTester tester, bool dark, Widget child) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Center(child: SizedBox(width: 640, child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Reset options consume generated row and text slots dark=$dark',
      (tester) async {
        await _host(
          tester,
          dark,
          RaftResetAgentDialog(
            agentName: 'Test Agent',
            canFullReset: true,
            onConfirm: (_) async {},
          ),
        );
        final group = tester.widget<RaftRadioGroup<String>>(
          find.byType(RaftRadioGroup<String>),
        );
        final rowFinder = find.byKey(
          const ValueKey('agent-reset-option-restart'),
        );
        final row = tester.widget<RaftRadioGroupItem<String>>(rowFinder);
        final t = RaftTokens.of(tester.element(rowFinder));
        final recipe = RaftWebAgentResetOptionsRecipe.resolve(
          tokens: t.recipeTokens,
        );
        expect(group.spacing, recipe.root.rowGap);
        expect(row.padding, recipe.row.padding);
        expect(row.minHeight, recipe.row.minHeight);
        expect(row.gap, recipe.row.columnGap);
        expect(row.markInset, recipe.indicator.margin);
        final title = tester.widget<RaftCssText>(
          find.descendant(
            of: rowFinder,
            matching: find.byWidgetPredicate(
              (w) => w is RaftCssText && w.data == 'Restart',
            ),
          ),
        );
        final description = tester.widget<RaftCssText>(
          find.descendant(
            of: rowFinder,
            matching: find.byWidgetPredicate(
              (w) => w is RaftCssText && w.data == 'Stop and restart the agent process. Keeps the runtime session and workspace files.',
            ),
          ),
        );
        for (final pair in [
          (title, recipe.title),
          (description, recipe.description),
        ]) {
          final expected = pair.$2.text(t.recipeTokens);
          expect(pair.$1.style!.fontSize, expected.fontSize);
          expect(pair.$1.style!.height, expected.height);
          expect(pair.$1.style!.fontWeight, expected.fontWeight);
          expect(pair.$1.style!.color, expected.color);
        }
        final content = row.child! as Column;
        expect(content.spacing, recipe.content.rowGap);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('XLSX Tabs keep their generated root box model dark=$dark', (
      tester,
    ) async {
      await _host(tester, dark, RaftDocumentPreview(data: _xlsx()));
      final tabs = find.byType(RaftTabsList<int>);
      final t = RaftTokens.of(tester.element(tabs));
      final recipe = RaftWebXlsxTabsLayoutRecipe.resolve(tokens: t.recipeTokens)
          .root;
      final rootBox = find.ancestor(
        of: tabs,
        matching: find.byWidgetPredicate(
          (w) =>
              w is RaftRecipeBox &&
              w.style.classes.join(' ') == recipe.classes.join(' '),
        ),
      );
      expect(rootBox, findsOneWidget);
      final box = tester.widget<RaftRecipeBox>(rootBox);
      expect(box.style.padding, recipe.padding);
      final margin = tester.widget<Padding>(
        find.ancestor(of: rootBox, matching: find.byType(Padding)).first,
      );
      expect(margin.padding, recipe.margin);
      expect(
        tester.getSize(rootBox).height - tester.getSize(tabs).height,
        recipe.padding.vertical,
      );
      await tester.tap(find.text('Failing'));
      await tester.pump();
      expect(find.text('html.loading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
