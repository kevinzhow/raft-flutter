import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      Future<void> host(WidgetTester t, Widget child) async {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id), dark: dark),
            home: Scaffold(body: SizedBox(width: 390, child: child)),
          ),
        );
      }

      testWidgets(
        'agent banner keeps component copy and inline action $id/$dark',
        (t) async {
          var taps = 0;
          await host(
            t,
            RaftAgentBanner(
              status: RaftAgentBannerStatus.warning,
              description: 'Agent limit reached.',
              action: 'Upgrade',
              onAction: () => taps++,
            ),
          );
          final paragraph = t.renderObject<RenderParagraph>(
            find.byWidgetPredicate(
              (w) =>
                  w is RichText &&
                  w.text.toPlainText() == 'Agent limit reached. Upgrade',
            ),
          );
          final tokens = RaftTokens.of(t.element(find.byType(RaftAgentBanner)));
          expect(
            paragraph.text.style!.fontSize,
            tokens.size('type.bannerBody.size', fallback: -1),
          );
          expect(
            paragraph.text.style!.color,
            tokens.colors['foreground-banner-body'],
          );
          // Tap the action's actual glyph box, rather than the description midpoint.
          final boxes = paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 21, extentOffset: 27),
          );
          await t.tapAt(paragraph.localToGlobal(boxes.last.toRect().center));
          await t.pump();
          expect(taps, 1);
        },
      );

      testWidgets(
        'agent select retains shared height and selection $id/$dark',
        (t) async {
          String? value = 'one';
          await host(
            t,
            StatefulBuilder(
              builder: (context, setState) => RaftAgentSelect<String>(
                value: value,
                options: const [
                  RaftAgentSelectOption('one', 'One'),
                  RaftAgentSelectOption('two', 'Two'),
                ],
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          );
          final select = find.byType(RaftAgentSelect<String>);
          final tokens = RaftTokens.of(t.element(select));
          expect(
            t.getSize(select).height,
            tokens.size('size.fieldSelect', fallback: -1),
          );
          await t.tap(select);
          await t.pumpAndSettle();
          await t.tap(find.text('Two').last);
          await t.pumpAndSettle();
          expect(value, 'two');
          expect(find.text('Two'), findsOneWidget);
        },
      );

      testWidgets('agent input keeps the field box height $id/$dark', (
        t,
      ) async {
        final controller = TextEditingController(text: 'Product-QA-Bot');
        addTearDown(controller.dispose);
        await host(t, RaftAgentTextInput(controller: controller));
        final input = find.byType(RaftAgentTextInput);
        final tokens = RaftTokens.of(t.element(input));
        expect(
          t.getSize(input).height,
          tokens.size('size.fieldInput', fallback: -1),
        );
        await t.enterText(find.byType(TextField), 'Updated-Agent');
        expect(controller.text, 'Updated-Agent');
      });

      if (id == raftThemePackId) {
        testWidgets(
          'field label accessory leaves the source label line intact $dark',
          (t) async {
            await host(
              t,
              Column(
                children: [
                  RaftStableField(
                    label: 'Name',
                    labelAccessory: RaftIconButton(
                      glyph: RaftGlyph.dices,
                      visualSize: 32,
                      onPressed: () {},
                    ),
                    child: const SizedBox(
                      key: Key('field-control'),
                      height: 44,
                    ),
                  ),
                ],
              ),
            );
            final field = find.byType(RaftStableField);
            expect(
              t.getTopLeft(find.byKey(const Key('field-control'))).dy -
                  t.getTopLeft(field).dy,
              24,
            );
            final paragraph = t.renderObject<RenderParagraph>(
              find.byWidgetPredicate(
                (w) => w is RichText && w.text.toPlainText() == 'Name',
              ),
            );
            expect(paragraph.text.style!.fontSize, 13);
            expect(paragraph.text.style!.fontWeight, FontWeight.w600);
          },
        );
      }
    }
  }
}
