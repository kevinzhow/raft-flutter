import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// WP-DS3 content family against raft-ui 0.95.3 / Web v1.24: code block frame,
// the keyboard region of an overflowing block, inline code, markdown
// blockquote / table head / links, and ShowMoreToggle. Input mode is set with
// RaftInteractionScope, never by width.

const _touchSizes = [Size(856, 944), Size(944, 856)];
const _mouseSizes = [Size(390, 844)];
const _wideMouse = Size(1024, 768);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required bool touch,
  bool dark = false,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RaftInteractionScope(
      interaction: touch
          ? RaftInteraction.touchMode
          : RaftInteraction.pointerMode,
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RaftTokens _tokens(WidgetTester tester, Finder at) =>
    RaftTokens.of(tester.element(at));

Widget _body(String content, {double width = 340}) => SizedBox(
  width: width,
  child: RaftMessageBody(content: content, fontSize: 14, lineHeight: 22),
);

BoxDecoration _codeDecoration(WidgetTester tester) =>
    tester
            .widget<Container>(find.byKey(const ValueKey('code-container')))
            .decoration!
        as BoxDecoration;

Iterable<SemanticsNode> _labelled(SemanticsNode root, String label) sync* {
  if (root.label == label) yield root;
  final children = <SemanticsNode>[];
  root.visitChildren((c) {
    children.add(c);
    return true;
  });
  for (final c in children) {
    yield* _labelled(c, label);
  }
}

SemanticsNode _semanticsRoot(WidgetTester tester) =>
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;

dynamic _underlines(WidgetTester tester) =>
    tester.renderObject(find.byType(RaftUnderlines).first) as dynamic;

List<dynamic> _allBackgrounds(WidgetTester tester) => [
  for (final e in find.byType(RaftUnderlines).evaluate())
    ...((e.renderObject as dynamic).debugBackgrounds as List),
];

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    for (final size in _mouseSizes) {
      testWidgets('code block frame, copy button and text colour $mode $size', (
        tester,
      ) async {
        await _pump(
          tester,
          _body('```js\nconst a = 1;\nconst b = 2;\nconst c = 3;\n```'),
          size: size,
          touch: false,
          dark: dark,
        );
        final t = _tokens(tester, find.byKey(const ValueKey('code-container')));
        final box = _codeDecoration(tester);
        expect(box.borderRadius, BorderRadius.circular(10));
        expect(box.color, t.colors['layer-code']);
        final border = box.border! as Border;
        expect(border.top.color, t.colors['line-hairline']);
        expect(border.top.width, 1);
        final container = tester.getRect(
          find.byKey(const ValueKey('code-container')),
        );
        // Web: py-2 (8) around three 22px lines, plus the 1px border.
        expect(container.height, 3 * 22 + 16 + 2);
        final padding = tester
            .widget<Container>(find.byKey(const ValueKey('code-container')))
            .padding!;
        expect(padding.resolve(TextDirection.ltr).top, 8);
        expect(padding.resolve(TextDirection.ltr).bottom, 8);
        // Ghost icon-md, 6px from the outer corner.
        final button = tester.getRect(find.byType(RaftButton));
        expect(button.width, button.height);
        expect(button.width, greaterThanOrEqualTo(32));
        expect(container.right - button.right, 6);
        expect(button.top - container.top, 6);
        // The text column keeps clear of the button (Web: 12 + 34 + 5).
        expect(padding.resolve(TextDirection.ltr).right, greaterThan(46));
      });

      testWidgets('code block plain text uses the product code colour $mode', (
        tester,
      ) async {
        await _pump(
          tester,
          _body('```\nplain text\n```'),
          size: size,
          touch: false,
          dark: dark,
        );
        final text = tester.widget<SelectableText>(
          find.descendant(
            of: find.byKey(const ValueKey('code-container')),
            matching: find.byType(SelectableText),
          ),
        );
        expect(
          text.textSpan!.style?.color ?? text.style?.color,
          dark ? const Color(0xfff0f3f6) : const Color(0xff24292e),
        );
      });
    }

    testWidgets('code block line height follows the message body $mode', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          width: 340,
          child: RaftMessageBody(
            content: '```\na\nb\n```',
            fontSize: 16,
            lineHeight: 26,
          ),
        ),
        size: _mouseSizes.first,
        touch: false,
        dark: dark,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('code-container'))).height,
        2 * 26 + 16 + 2,
      );
    });

    for (final size in [..._touchSizes, ..._mouseSizes]) {
      final touch = _touchSizes.contains(size);
      testWidgets(
        'overflowing code is one labelled keyboard region, short code is none $mode $size touch=$touch',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await _pump(
            tester,
            _body('```\n${'x' * 200}\n```', width: 300),
            size: size,
            touch: touch,
            dark: dark,
          );
          final region = find.byKey(const ValueKey('code-block-region'));
          expect(region, findsOneWidget);
          expect(_labelled(_semanticsRoot(tester), 'Code'), isNotEmpty);
          // Keyboard: Tab lands on the region and shows the 2px ring.
          expect(find.byKey(const ValueKey('code-block-ring')), findsNothing);
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTraditional;
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          for (var i = 0; i < 6; i++) {
            if (find
                .byKey(const ValueKey('code-block-ring'))
                .evaluate()
                .isNotEmpty) {
              break;
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          }
          final ring = find.byKey(const ValueKey('code-block-ring'));
          expect(ring, findsOneWidget);
          final decoration =
              tester.widget<DecoratedBox>(ring).decoration as BoxDecoration;
          final side = (decoration.border! as Border).top;
          expect(side.width, 2);
          expect(side.color, _tokens(tester, ring).colors['foreground']);

          await _pump(
            tester,
            _body('```\nshort\n```', width: 300),
            size: size,
            touch: touch,
            dark: dark,
          );
          expect(
            tester
                .widget<Focus>(find.byKey(const ValueKey('code-block-region')))
                .canRequestFocus,
            isFalse,
          );
          expect(_labelled(_semanticsRoot(tester), 'Code'), isEmpty);
          semantics.dispose();
        },
      );
    }

    testWidgets('region label is localised $mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        _body('```\n${'x' * 200}\n```', width: 300),
        size: _mouseSizes.first,
        touch: false,
        dark: dark,
        locale: const Locale('zh'),
      );
      expect(_labelled(_semanticsRoot(tester), '代码'), isNotEmpty);
      semantics.dispose();
    });

    testWidgets('background span paints a rounded, 1px taller fill $mode', (
      tester,
    ) async {
      // The Markdown vendor flattens a returned RaftBackgroundSpan today (see
      // the report), so the span is exercised directly.
      await _pump(
        tester,
        const RaftUnderlines(
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 14, height: 1.5),
              children: [
                TextSpan(text: 'use '),
                RaftBackgroundSpan(
                  background: Color(0xffeeeeee),
                  radius: 4,
                  verticalInset: 1,
                  text: 'value',
                ),
              ],
            ),
          ),
        ),
        size: _mouseSizes.first,
        touch: false,
        dark: dark,
      );
      final backgrounds = _allBackgrounds(tester);
      expect(backgrounds, hasLength(1));
      expect(backgrounds.first.radius, 4);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).first,
      );
      final tight = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 4, extentOffset: 9),
          )
          .first
          .toRect();
      expect((backgrounds.first.rect as Rect).height, tight.height + 2);
    });

    testWidgets('markdown blockquote, table head and link tokens $mode', (
      tester,
    ) async {
      await _pump(
        tester,
        _body(
          '> quoted\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n[site](https://example.invalid)',
        ),
        size: _mouseSizes.first,
        touch: false,
        dark: dark,
      );
      final t = _tokens(tester, find.byType(RaftMessageBody));
      final quote = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('quoted', findRichText: true),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).border != null,
              ),
            )
            .first,
      );
      final edge = ((quote.decoration as BoxDecoration).border! as Border).left;
      expect(edge.color, t.colors['line-seam']);
      final quoted = tester.widget<RichText>(
        find.text('quoted', findRichText: true),
      );
      expect(quoted.text.style?.fontStyle, isNot(FontStyle.italic));
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.text('quoted', findRichText: true),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Padding &&
                    (w.padding as EdgeInsets).left == 10 &&
                    (w.padding as EdgeInsets).top == 0,
              ),
            )
            .first,
      );
      expect((padding.padding as EdgeInsets).left, 10);
      final table = tester.widget<Table>(find.byType(Table));
      expect(
        (table.children.first.decoration! as BoxDecoration).color,
        t.colors['fill-muted'],
      );
      final link = tester.widget<RichText>(
        find.text('site', findRichText: true),
      );
      final style = (link.text as TextSpan).children!
          .whereType<TextSpan>()
          .first
          .style!;
      expect(style.color, t.colors['foreground-link']);
      final underline = (_underlines(tester).debugUnderlines as List)
          .where((u) => u.rect.width > 0)
          .first;
      expect(
        (underline.color as Color).toARGB32(),
        t.colors['foreground-link']!.withValues(alpha: .4).toARGB32(),
      );
    });
  }

  testWidgets('link underline is full on a mouse hover only', (tester) async {
    await _pump(
      tester,
      _body('[site](https://example.invalid)'),
      size: _mouseSizes.first,
      touch: false,
    );
    final t = _tokens(tester, find.byType(RaftMessageBody));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(380, 600));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('site', findRichText: true)));
    await tester.pump();
    final underline = (_underlines(tester).debugUnderlines as List).first;
    expect(
      (underline.color as Color).toARGB32(),
      t.colors['foreground-link']!.toARGB32(),
    );
  });

  for (final size in [..._touchSizes, ..._mouseSizes, _wideMouse]) {
    final touch = _touchSizes.contains(size);
    testWidgets('ShowMoreToggle footnote step, weight 500, hover underline '
        '$size touch=$touch', (tester) async {
      await _pump(
        tester,
        RaftShowMoreToggle(label: 'Show More', onPressed: () {}),
        size: size,
        touch: touch,
      );
      final t = _tokens(tester, find.byType(RaftShowMoreToggle));
      final label = find.byType(RaftUnderlinedText);
      final text = tester.widget<RaftUnderlinedText>(label);
      // Web desktop step: width >= 48rem and a fine pointer.
      expect(text.style!.fontSize, touch || size.width < 768 ? 13 : 12);
      expect(text.style!.height! * text.style!.fontSize!, closeTo(18, .01));
      expect(text.style!.fontWeight, FontWeight.w500);
      expect(text.style!.color, t.colors['foreground-muted']);
      expect(text.underline, isFalse);
      expect(text.underlineThickness, 1.5);
      expect(text.underlineOffset, 3);
      expect(tester.getSize(find.byType(RaftShowMoreToggle)).height, 18);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 800));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(label));
      await tester.pump();
      final hovered = tester.widget<RaftUnderlinedText>(label);
      expect(hovered.underline, !touch);
      expect(hovered.style!.color, t.colors['foreground']);
    });
  }
}
