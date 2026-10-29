import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// `RaftCollapsibleSectionHeader` is the profile's collapsed-by-default
/// disclosure: one header row that opens and closes the content below it.
void main() {
  Finder eyebrow(String label) => find.byWidgetPredicate(
    (w) => w is RaftSectionEyebrow && w.label == label,
  );

  Widget host({
    required bool expanded,
    required ValueChanged<bool> onExpandedChanged,
    bool dark = false,
    Widget? action,
    Key disclosureKey = const ValueKey('disclosure'),
  }) => MaterialApp(
    theme: raftTheme(dark: dark),
    home: Scaffold(
      body: RaftDensityScope(
        density: RaftDensity.desktop,
        child: SingleChildScrollView(
          child: RaftPanelSection(
            topBorder: false,
            gap: 16,
            children: [
              RaftCollapsibleSectionHeader(
                disclosureKey: disclosureKey,
                label: 'Skills',
                count: 3,
                expanded: expanded,
                onExpandedChanged: onExpandedChanged,
                action: action,
                children: const [
                  RaftCard.item(child: Text('deploy')),
                  RaftCard.item(child: Text('feature-map')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'collapsed shows only the header row (${dark ? 'dark' : 'light'})',
      (tester) async {
        var changes = <bool>[];
        await tester.pumpWidget(
          host(expanded: false, onExpandedChanged: changes.add, dark: dark),
        );
        expect(eyebrow('Skills'), findsOneWidget);
        expect(
          tester
              .widget<RaftSectionHeader>(find.byType(RaftSectionHeader))
              .count,
          3,
        );
        expect(find.text('deploy'), findsNothing);
        expect(find.text('feature-map'), findsNothing);
        // One row tall: the header only.
        expect(
          tester.getSize(find.byType(RaftCollapsibleSectionHeader)).height,
          tester.getSize(find.byType(RaftSectionHeader)).height,
        );

        await tester.tap(find.byKey(const ValueKey('disclosure')));
        expect(changes, [true]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'expanded shows the content under the same header (${dark ? 'dark' : 'light'})',
      (tester) async {
        var changes = <bool>[];
        await tester.pumpWidget(
          host(expanded: true, onExpandedChanged: changes.add, dark: dark),
        );
        expect(eyebrow('Skills'), findsOneWidget);
        expect(find.text('deploy'), findsOneWidget);
        expect(find.text('feature-map'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(RaftSectionHeader)).dy,
          lessThan(tester.getTopLeft(find.text('deploy')).dy),
        );

        await tester.tap(find.byKey(const ValueKey('disclosure')));
        expect(changes, [false]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('opening and closing animate instead of jumping', (tester) async {
    Widget animatedHost(bool expanded) =>
        host(expanded: expanded, onExpandedChanged: (_) {});
    await tester.pumpWidget(animatedHost(false));
    final closed = tester.getSize(find.byType(RaftCollapsibleSectionHeader));

    await tester.pumpWidget(animatedHost(true));
    // One frame in: the body is present but still shorter than its final
    // height, i.e. it unfolds rather than appearing at full size.
    await tester.pump(const Duration(milliseconds: 60));
    final opening = tester.getSize(find.byType(RaftCollapsibleSectionHeader));
    await tester.pumpAndSettle();
    final open = tester.getSize(find.byType(RaftCollapsibleSectionHeader));
    expect(opening.height, greaterThan(closed.height));
    expect(opening.height, lessThan(open.height));

    await tester.pumpWidget(animatedHost(false));
    await tester.pump(const Duration(milliseconds: 60));
    final closing = tester.getSize(find.byType(RaftCollapsibleSectionHeader));
    expect(closing.height, lessThan(open.height));
    expect(closing.height, greaterThan(closed.height));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(RaftCollapsibleSectionHeader)).height,
      closed.height,
    );
  });

  testWidgets('reduced motion opens and closes without a transition', (
    tester,
  ) async {
    Widget reduced(bool expanded) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: host(expanded: expanded, onExpandedChanged: (_) {}),
    );
    await tester.pumpWidget(reduced(false));
    final closed = tester.getSize(find.byType(RaftCollapsibleSectionHeader));
    await tester.pumpWidget(reduced(true));
    // A single frame is enough: no animation is left running.
    await tester.pump();
    expect(
      tester.getSize(find.byType(RaftCollapsibleSectionHeader)).height,
      greaterThan(closed.height),
    );
    await tester.pumpWidget(reduced(false));
    await tester.pump();
    expect(
      tester.getSize(find.byType(RaftCollapsibleSectionHeader)).height,
      closed.height,
    );
  });

  testWidgets('the header is one button that announces its state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(expanded: false, onExpandedChanged: (_) {}));
    final node = tester.getSemantics(find.byKey(const ValueKey('disclosure')));
    expect(node.label.trim(), 'Skills, 3');
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
      node.getSemanticsData().flagsCollection.isExpanded.toBoolOrNull(),
      isFalse,
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    await tester.pumpWidget(host(expanded: true, onExpandedChanged: (_) {}));
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('disclosure')))
          .getSemanticsData()
          .flagsCollection
          .isExpanded
          .toBoolOrNull(),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('keyboard activation toggles the section', (tester) async {
    var changes = <bool>[];
    await tester.pumpWidget(
      host(expanded: false, onExpandedChanged: changes.add),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<FocusableActionDetector>(find.byType(FocusableActionDetector))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changes, [true]);
  });

  testWidgets('an action keeps its own target beside the disclosure', (
    tester,
  ) async {
    var changes = 0, actions = 0;
    await tester.pumpWidget(
      host(
        expanded: false,
        onExpandedChanged: (_) => changes++,
        action: RaftIconButton(
          glyph: RaftGlyph.plus,
          tooltip: 'Add skill',
          onPressed: () => actions++,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add skill'));
    expect(actions, 1);
    expect(changes, 0);
  });
}
