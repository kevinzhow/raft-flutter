import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Future<void> fonts(WidgetTester t) => t.runAsync(() async {
  for (final family in [
    'SpaceGrotesk',
    'SpaceMono',
    'HankenGrotesk',
    'Inter',
    'Geist',
    'GeistMono',
  ]) {
    ByteData bytes;
    try {
      bytes = await rootBundle.load(
        'packages/raft_ui/assets/fonts/$family.ttf',
      );
    } on FlutterError {
      bytes = await rootBundle.load('assets/fonts/$family.ttf');
    }
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
  for (final (bottomRule, profileBody) in [
    (false, false),
    (true, false),
    (false, true),
  ]) {
    testWidgets(
      'page surface reaches header and status bar rule=$bottomRule profile=$profileBody',
      (t) async {
        const surface = Color(0xff123456);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: RaftPanelHeaderBar(
                title: 'Activity',
                background: surface,
                bottomRule: bottomRule,
                profileBody: profileBody,
              ),
            ),
          ),
        );
        final frame = find
            .descendant(
              of: find.byType(RaftPanelHeaderBar),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration is BoxDecoration,
              ),
            )
            .first;
        expect(
          (t.widget<Container>(frame).decoration! as BoxDecoration).color,
          surface,
        );
        final status = find.descendant(
          of: find.byType(RaftPanelHeaderBar),
          matching: find.byType(RaftStatusBarSource),
        );
        expect(t.widget<RaftStatusBarSource>(status).color, surface);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} width$width actual shared headers consume Source title/meta flow',
        (t) async {
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await fonts(t);
          var searches = 0, closes = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
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
                          tooltip: 'Close Profile',
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
            // Below md the headers still render Web's PanelHeader recipe
            // (`max-md:` variants at 390px): RaftCssText title/meta flow.
            Finder textOf(String value) => css(value);
            final heading = textOf(title), subtitle = textOf(meta);
            expect(heading, findsOneWidget);
            expect(subtitle, findsOneWidget);
            final head = t.getRect(heading), sub = t.getRect(subtitle);
            // Profile panels now consume the current Web headline/meta stack;
            // channel headers still use their independently generated recipe.
            if (title == 'Designer') {
              expect(sub.left, head.left);
              expect(sub.top - head.bottom, 0);
              expect(head.height, 22);
              expect(sub.height, 16);
              continue;
            }
            // Current PanelHeadline/PanelMeta are a 22px/16px stack,
            // with no gap, at desktop and phone widths (raft-ui PanelHeader).
            expect(sub.left, head.left);
            expect(sub.top - head.bottom, 0);
            expect(head.height, 22);
            expect(sub.height, 16);
          }
          final heading = t.widget<RaftCssText>(css('design'));
          final meta = t.widget<RaftCssText>(css('Product and UI decisions'));
          expect(heading.style!.fontFamily, 'packages/raft_ui/SpaceGrotesk');
          expect(meta.style!.fontFamily, 'packages/raft_ui/SpaceGrotesk');
          await t.tap(find.bySemanticsLabel('Search This Channel'));
          await t.tap(find.bySemanticsLabel('Close Profile'));
          expect([searches, closes], [1, 1]);
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} constrained desktop title keeps real caller actions reachable',
      (t) async {
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var searches = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
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
        await t.tap(find.bySemanticsLabel('Search This Channel'));
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
      Future<void> mount({required bool dark}) => t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
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
      await mount(dark: false);
      await t.pumpAndSettle();
      focus.requestFocus();
      await t.pump();
      input.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
      final editable = t.state(find.byType(EditableText));
      final titleBox = t.renderObject(css('Designer'));
      await mount(dark: true);
      await t.pumpAndSettle();
      expect(t.state(find.byType(EditableText)), same(editable));
      expect(t.renderObject(css('Designer')), same(titleBox));
      expect(focus.hasFocus, true);
      expect(
        input.selection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      await mount(dark: false);
      await t.pumpAndSettle();
      expect(t.state(find.byType(EditableText)), same(editable));
      expect(t.renderObject(css('Designer')), same(titleBox));
      expect(focus.hasFocus, true);
      expect(t.takeException(), isNull);
    },
  );
}
