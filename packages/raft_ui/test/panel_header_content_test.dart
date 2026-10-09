import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> fonts(WidgetTester t) => t.runAsync(() async {
  for (final family in ['HankenGrotesk', 'Inter', 'Geist', 'GeistMono']) {
    final bytes = await rootBundle.load('assets/fonts/$family.ttf');
    await (FontLoader(
      'packages/raft_ui/$family',
    )..addFont(Future.value(bytes))).load();
  }
});

Finder css(String value) => find.byWidgetPredicate(
  (widget) => widget is RaftCssText && widget.data == value,
);

double baseline(WidgetTester t, Finder finder) {
  final box = t.renderObject<RenderBox>(finder);
  return t.getRect(finder).top +
      box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '$family/$dark width$width actual shared headers consume Source title/meta flow',
        (t) async {
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await fonts(t);
          var searches = 0, closes = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: Column(
                  children: [
                    RaftChannelHeader(
                      name: 'design',
                      description: 'Product and UI decisions',
                      onSearch: () => searches++,
                      onSettings: () {},
                    ),
                    RaftPanelHeaderBar(
                      title: 'Designer',
                      subtitle: '@designer',
                      actions: [
                        RaftPanelIconButton(
                          glyph: RaftGlyph.x,
                          tooltip: 'Close profile',
                          onPressed: () => closes++,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          for (final (title, meta) in [
            ('design', 'Product and UI decisions'),
            ('Designer', '@designer'),
          ]) {
            final heading = css(title), subtitle = css(meta);
            expect(heading, findsOneWidget);
            expect(subtitle, findsOneWidget);
            final head = t.getRect(heading), sub = t.getRect(subtitle);
            final inline = family == RaftFamily.elegant && width >= 768;
            if (inline) {
              expect(sub.left - head.right, closeTo(8, .02));
              expect(
                baseline(t, heading),
                closeTo(baseline(t, subtitle), .001),
              );
              expect(head.height, 21.25);
              expect(sub.height, 12);
            } else {
              expect(sub.left, head.left);
              expect(
                sub.top - head.bottom,
                family == RaftFamily.elegant ? 4 : 0,
              );
              expect(sub.height, family == RaftFamily.elegant ? 15 : 16);
            }
          }
          final heading = t.widget<RaftCssText>(css('design'));
          final meta = t.widget<RaftCssText>(css('Product and UI decisions'));
          expect(
            heading.style!.fontFamily,
            'packages/raft_ui/${family == RaftFamily.brutal ? 'HankenGrotesk' : 'Inter'}',
          );
          expect(
            meta.style!.fontFamily,
            'packages/raft_ui/${family == RaftFamily.brutal ? 'GeistMono' : 'Geist'}',
          );
          await t.tap(find.bySemanticsLabel('Search this channel'));
          await t.tap(find.bySemanticsLabel('Close profile'));
          expect([searches, closes], [1, 1]);
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark constrained desktop title keeps real caller actions reachable',
      (t) async {
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var searches = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 260,
                child: RaftChannelHeader(
                  name: 'A very long channel title within a constrained desktop panel',
                  description: 'Accepted channel description',
                  onSearch: () => searches++,
                  onSettings: () {},
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.bySemanticsLabel('Search this channel'));
        expect(searches, 1);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'content direction changes retain actual caller focus and child state',
    (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final input = TextEditingController(text: 'draft');
      addTearDown(input.dispose);
      Future<void> mount(RaftFamily family) => t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family),
          home: Scaffold(
            body: RaftPanelHeaderBar(
              title: 'Designer',
              subtitle: '@designer',
              actions: [
                SizedBox(
                  width: 120,
                  child: TextField(focusNode: focus, controller: input),
                ),
              ],
            ),
          ),
        ),
      );
      await mount(RaftFamily.brutal);
      await t.pumpAndSettle();
      focus.requestFocus();
      await t.pump();
      input.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
      final editable = t.state(find.byType(EditableText));
      final titleBox = t.renderObject(css('Designer'));
      await mount(RaftFamily.elegant);
      await t.pumpAndSettle();
      expect(t.state(find.byType(EditableText)), same(editable));
      expect(t.renderObject(css('Designer')), same(titleBox));
      expect(focus.hasFocus, true);
      expect(
        input.selection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      await mount(RaftFamily.brutal);
      await t.pumpAndSettle();
      expect(t.state(find.byType(EditableText)), same(editable));
      expect(t.renderObject(css('Designer')), same(titleBox));
      expect(focus.hasFocus, true);
      expect(t.takeException(), isNull);
    },
  );
}
