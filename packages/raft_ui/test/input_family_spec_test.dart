import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 Input family (Label, Field, InputGroup, Textarea, Kbd) as the Web draws it: the numbers below
// are the Web's (`h-11`, `gap-1.5`, `text-footnote`, `min-h-24`), not whatever the widgets happened to paint.
Widget _app(bool dark, Widget child, {double width = 358}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

TextStyle _labelStyle(WidgetTester t, String text) {
  final paragraph = t.renderObject<RenderParagraph>(
    find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().startsWith(text),
    ),
  );
  return paragraph.text.style!;
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode Field: 13/18 600 muted label, 6px to the control', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          dark,
          const RaftField(
            label: 'Name',
            hint: 'Shown to everyone',
            child: SizedBox(key: Key('control'), height: 44),
          ),
        ),
      );
      final label = _labelStyle(t, 'Name');
      expect(label.fontSize, 13);
      expect(label.height! * label.fontSize!, closeTo(18, .001));
      expect(label.fontWeight, FontWeight.w600);
      expect(label.color, ui.foregroundMuted);
      expect(t.getTopLeft(find.byKey(const Key('control'))).dy, 18 + 6);
      final hint = _labelStyle(t, 'Shown to everyone');
      expect(hint.fontSize, 12);
      expect(hint.color, ui.foregroundHint);
      expect(t.getTopLeft(find.text('Shown to everyone')).dy, 18 + 6 + 44 + 6);
    });

    testWidgets(
      '$mode Field error is semibold danger-strong, markers are hint ink',
      (t) async {
        await t.pumpWidget(
          _app(
            dark,
            const RaftField(
              label: 'Email',
              required: true,
              error: 'Enter a valid email',
              child: SizedBox(height: 44),
            ),
          ),
        );
        final error = _labelStyle(t, 'Enter a valid email');
        expect(error.fontWeight, FontWeight.w600);
        expect(error.color, ui['danger-strong']);
        final label = t.renderObject<RenderParagraph>(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().startsWith('Email'),
          ),
        );
        final spans = <TextSpan>[];
        label.text.visitChildren((s) {
          if (s is TextSpan && s.text == '*') spans.add(s);
          return true;
        });
        expect(spans.single.style!.color, ui.foregroundHint);
      },
    );

    testWidgets('$mode compact Field is the sm label step (12/16)', (t) async {
      await t.pumpWidget(
        _app(
          dark,
          const RaftField(
            label: 'Nickname',
            compact: true,
            child: SizedBox(key: Key('control'), height: 44),
          ),
        ),
      );
      final label = _labelStyle(t, 'Nickname');
      expect(label.fontSize, 12);
      expect(label.height! * label.fontSize!, closeTo(16, .001));
      expect(t.getTopLeft(find.byKey(const Key('control'))).dy, 16 + 6);
    });

    testWidgets('$mode Label is the field-label step with an optional marker', (
      t,
    ) async {
      await t.pumpWidget(_app(dark, const RaftLabel('Topic', optional: true)));
      final style = _labelStyle(t, 'Topic');
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, ui.foregroundMuted);
      expect(find.textContaining('(optional)', findRichText: true), findsOne);
    });

    testWidgets('$mode InputGroup is 44px with a muted container addon', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          dark,
          const RaftPrefixedInput(prefix: '/', initialValue: 'general'),
        ),
      );
      expect(t.getSize(find.byType(RaftInputGroup)), const Size(358, 44));
      final root = t.widget<Container>(
        find
            .descendant(
              of: find.byType(RaftInputGroup),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = root.decoration! as BoxDecoration;
      expect(decoration.color, ui.layerCard);
      expect(decoration.borderRadius, BorderRadius.circular(8));
      // The `/` block: muted fill, `px-3`, centred.
      final addon = t.getRect(find.text('/'));
      expect(addon.center.dy, closeTo(22, 1));
    });

    testWidgets(
      '$mode search group: icon addon, clear button while typing, Esc hint',
      (t) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        await t.pumpWidget(
          _app(
            dark,
            RaftSearchInput(
              controller: controller,
              focusNode: focus,
              hint: 'Search',
              clearLabel: 'Clear Search',
              onClear: controller.clear,
              showEscape: true,
            ),
          ),
        );
        expect(find.byTooltip('Clear Search'), findsNothing);
        expect(find.text('Esc'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'hello');
        await t.pump();
        expect(find.byTooltip('Clear Search'), findsOneWidget);
        expect(t.getSize(find.byType(RaftInputGroup)).height, 44);
      },
    );

    testWidgets(
      '$mode Textarea is at least min-h-24 (96px) and 1.5px line-strong',
      (t) async {
        await t.pumpWidget(_app(dark, const RaftTextarea(hintText: 'Notes')));
        expect(t.getSize(find.byType(RaftTextarea)).height, 96);
        final box = t.widget<Container>(
          find
              .descendant(
                of: find.byType(RaftTextarea),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.color, ui.layerCard);
        expect((decoration.border! as Border).top.color, ui.lineStrong);
        expect(decoration.borderRadius, BorderRadius.circular(8));
      },
    );

    testWidgets('$mode Kbd is a mono hint-ink key cap', (t) async {
      await t.pumpWidget(_app(dark, const RaftKbd('Esc')));
      final style = t.widget<Text>(find.text('Esc')).style!;
      expect(style.color, ui.foregroundHint);
      expect(style.fontFamily, contains('Mono'));
      expect(t.getSize(find.byType(RaftKbd)).width, greaterThanOrEqualTo(16));
    });
  }
}
