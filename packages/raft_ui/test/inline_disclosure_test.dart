import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (look, dark) in [
    (raftThemePackId, false),
    (raftThemePackId, true),
    (elegantThemePackId, false),
    (elegantThemePackId, true),
    (brutalThemePackId, false),
  ]) {
    testWidgets('inline summary wraps and exposes one button: $look/$dark', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      try {
        for (final scale in [1.0, 1.3, 2.0, 3.1]) {
          var expanded = false;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: builtInTheme(look), dark: dark),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: SizedBox(
                      width: 230,
                      child: StatefulBuilder(
                        builder: (context, setState) =>
                            RaftCollapsibleSectionHeader(
                              disclosureKey: const ValueKey('inline-summary'),
                              label: 'Identity — Basic profile, no content',
                              labelSpan: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Identity',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' — Basic profile, no content',
                                  ),
                                ],
                              ),
                              leadingDisclosure: true,
                              expanded: expanded,
                              onExpandedChanged: (value) =>
                                  setState(() => expanded = value),
                              children: const [Text('Permission details')],
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final header = find.byKey(const ValueKey('inline-summary'));
          final node = t.getSemantics(header);
          expect(node.label, 'Identity — Basic profile, no content');
          expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
          expect(
            node.getSemanticsData().flagsCollection.isExpanded.toBoolOrNull(),
            isFalse,
          );
          expect(find.text('Permission details'), findsNothing);
          await t.tap(header);
          await t.pumpAndSettle();
          expect(find.text('Permission details'), findsOneWidget);
          expect(
            t
                .getSemantics(header)
                .getSemanticsData()
                .flagsCollection
                .isExpanded
                .toBoolOrNull(),
            isTrue,
          );
          await t.sendKeyEvent(LogicalKeyboardKey.space);
          await t.pumpAndSettle();
          expect(find.text('Permission details'), findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        }
      } finally {
        handle.dispose();
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    });
  }
}
