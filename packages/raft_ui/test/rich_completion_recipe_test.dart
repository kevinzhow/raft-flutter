import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_list_marker.dart';
import 'package:raft_ui/src/rich_card_tokens.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'forwarded outer inherits card surface while body retains panel $family/$dark',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: RaftForwardedBundle(
                metadata: {
                  'kind': 'forwarded-bundle',
                  'version': 1,
                  'forwardedItems': [
                    {
                      'contentSnapshot': 'Recipient snapshot',
                      'provenanceState': 'available',
                      'attachmentPolicy': 'excluded',
                    },
                  ],
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bundle = find.byType(RaftForwardedBundle);
        final tokens = RaftTokens.of(tester.element(bundle));
        final boxes = tester.widgetList<Container>(
          find.descendant(of: bundle, matching: find.byType(Container)),
        );
        final outer = boxes.firstWhere(
          (box) =>
              box.decoration is BoxDecoration &&
              (box.decoration! as BoxDecoration).borderRadius != null,
        );
        expect(
          (outer.decoration! as BoxDecoration).color,
          family == RaftFamily.brutal ? Colors.white : tokens.card,
        );
        final recipe = ForwardedSnapshotRecipe(tokens);
        expect(
          recipe.semantic.content,
          family == RaftFamily.brutal ? Colors.white : tokens.panel,
        );
        final surfaces = tester.widgetList<DecoratedBox>(
          find.descendant(of: bundle, matching: find.byType(DecoratedBox)),
        );
        expect(
          surfaces
              .where((box) => box.decoration is BoxDecoration)
              .map((box) => (box.decoration as BoxDecoration).color),
          contains(recipe.semantic.content),
        );
        if (dark) {
          expect(recipe.semantic.embedCanvas, isNot(tokens.sidebar));
          expect(recipe.semantic.content, isNot(recipe.semantic.embedCanvas));
        }
        expect(
          find.text('Recipient snapshot', findRichText: true),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'disc marker follows content baseline and ordinal counter stays one line $family/$dark',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: const Scaffold(
              body: Column(
                children: [
                  RaftMessageBody(content: '- First\n  - Nested\n- Second'),
                  RaftMessageBody(
                    content: '99. First ordinal\n100. Second ordinal',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final markers = tester
            .widgetList<RaftMarkdownListMarker>(
              find.byType(RaftMarkdownListMarker),
            )
            .toList();
        expect(
          markers.where((marker) => marker.orderedIndex == null),
          hasLength(3),
        );
        expect(
          find.text('•'),
          findsNWidgets(3),
        ); // Invisible baseline carriers.
        final ordinal = tester.widget<Text>(find.text('100. '));
        expect(ordinal.textAlign, TextAlign.right);
        expect(ordinal.softWrap, false);
        expect(ordinal.maxLines, 1);
        expect(ordinal.overflow, TextOverflow.visible);
        expect(find.text('Nested', findRichText: true), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Nested', findRichText: true)).dx,
          greaterThan(
            tester.getTopLeft(find.text('First', findRichText: true)).dx,
          ),
        );
        final firstDisc = find.byType(RaftMarkdownListMarker).first;
        final markerBox = tester.renderObject<RenderBox>(firstDisc);
        final firstText = tester.renderObject<RenderBox>(
          find.text('First', findRichText: true),
        );
        // getDistanceToBaseline is parent-only during layout/paint. Query the
        // public dry baseline with the actual laid-out constraints, retaining
        // the mounted boxes' global positions and the same geometry tolerance.
        final markerBaseline =
            tester.getTopLeft(firstDisc).dy +
            markerBox.getDryBaseline(
              markerBox.constraints,
              TextBaseline.alphabetic,
            )!;
        final bodyBaseline =
            tester.getTopLeft(find.text('First', findRichText: true)).dy +
            firstText.getDryBaseline(
              firstText.constraints,
              TextBaseline.alphabetic,
            )!;
        expect(markerBaseline, closeTo(bodyBaseline, .1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('outside disc scales with font metrics and gutter, rather than a captured rectangle', () {
    final normal = MessageListMarkerPrimitive.disc(
      indent: 20,
      ascent: 14,
      baseline: 15,
    );
    final nested = MessageListMarkerPrimitive.disc(
      indent: 24,
      ascent: 14,
      baseline: 15,
    );
    final large = MessageListMarkerPrimitive.disc(
      indent: 40,
      ascent: 28,
      baseline: 30,
    );
    expect(normal.width, 5);
    expect(normal.left, closeTo(20 - 14 * 2 / 3 - 7, .001));
    expect(nested.left - normal.left, 4);
    expect(nested.size, normal.size);
    expect(large.width, greaterThan(normal.width));
    expect(large.bottom, lessThan(30));
  });
}
