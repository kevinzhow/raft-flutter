import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Actual published raft-ui 0.7.0 DropdownMenu.item (Web db5e399f):
// data-[selected]:font-bold; font-medium otherwise; hover/data-highlighted
// use brand-soft; data-disabled changes text to foreground-disabled.
// Selection is visual emphasis on a menu action, not a checkbox/radio role.
const _selected = ValueKey('dropdown-selected-action');
const _plain = ValueKey('dropdown-plain-action');
const _disabled = ValueKey('dropdown-disabled-selected-action');

Widget _host(Widget child, {required bool dark}) => MaterialApp(
  theme: raftTheme(dark: dark, platform: TargetPlatform.linux),
  home: Scaffold(
    body: RaftDensityScope(
      density: RaftDensity.desktop,
      child: Align(
        alignment: Alignment.topLeft,
        // No surface declaration: observe the source row's translucent fill,
        // independently of the popup's separately tested opaque composition.
        child: Focus(
          child: Semantics(
            role: SemanticsRole.menu,
            explicitChildNodes: true,
            child: SizedBox(width: 320, child: child),
          ),
        ),
      ),
    ),
  ),
);

TextStyle _labelStyle(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

Color? _paintedFill(WidgetTester tester, Key key) {
  final box = tester.renderObject<RenderDecoratedBox>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox && widget.decoration is BoxDecoration,
      ),
    ),
  );
  return (box.decoration as BoxDecoration).color;
}

Color _paintedGlyphInk(WidgetTester tester, Key key) =>
    (tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(key),
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is CustomPaint &&
                          widget.painter is RaftGlyphPainter,
                    ),
                  ),
                )
                .painter
            as RaftGlyphPainter)
        .color;

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'dropdown selected action keeps source emphasis and menu semantics; dark=$dark',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final focus = FocusNode();
        var activated = 0;
        try {
          await tester.pumpWidget(
            _host(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftMenuItem(
                    key: _selected,
                    kind: RaftMenuKind.dropdownMenu,
                    label: 'Pinned action',
                    selected: true,
                    focusNode: focus,
                    onPressed: () => activated++,
                  ),
                  RaftMenuItem(
                    key: _plain,
                    kind: RaftMenuKind.dropdownMenu,
                    label: 'Regular action',
                    onPressed: () {},
                  ),
                ],
              ),
              dark: dark,
            ),
          );
          expect(
            _labelStyle(tester, 'Pinned action').fontWeight,
            FontWeight.w700,
          );
          expect(
            _labelStyle(tester, 'Regular action').fontWeight,
            FontWeight.w500,
          );
          final node = tester.getSemantics(find.byKey(_selected));
          expect(node.getSemanticsData().role, SemanticsRole.menuItem);
          expect(node.flagsCollection.isChecked, CheckedState.none);
          await tester.tap(find.byKey(_selected));
          await tester.pump();
          expect(activated, 1);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          focus.requestFocus();
          await tester.pump();
          expect(focus.hasFocus, isTrue);
          expect(
            _paintedFill(tester, _selected),
            raftTheme(dark: dark).extension<RaftTokens>()!.ui['brand-soft'],
          );
          expect(
            tester
                .getSemantics(find.byKey(_selected))
                .flagsCollection
                .isFocused,
            Tristate.isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(activated, 2);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          focus.dispose();
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'dropdown hover and disabled selected action retain source states; dark=$dark',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        var activated = 0;
        try {
          await tester.pumpWidget(
            _host(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftMenuItem(
                    key: _plain,
                    kind: RaftMenuKind.dropdownMenu,
                    label: 'Hover action',
                    glyph: RaftGlyph.download,
                    onPressed: () => activated++,
                  ),
                  const RaftMenuItem(
                    key: _disabled,
                    kind: RaftMenuKind.dropdownMenu,
                    label: 'Unavailable pinned action',
                    glyph: RaftGlyph.download,
                    selected: true,
                  ),
                ],
              ),
              dark: dark,
            ),
          );
          final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
          await mouse.addPointer(location: const Offset(420, 420));
          await mouse.moveTo(tester.getCenter(find.byKey(_plain)));
          await tester.pump();
          expect(_paintedFill(tester, _plain), tokens.ui['brand-soft']);
          expect(_paintedGlyphInk(tester, _plain), tokens.ui.foregroundMuted);
          await mouse.moveTo(tester.getCenter(find.byKey(_disabled)));
          await tester.pump();
          expect(
            _paintedFill(tester, _disabled),
            anyOf(isNull, Colors.transparent),
          );
          expect(
            _labelStyle(tester, 'Unavailable pinned action').color,
            tokens.ui.foregroundDisabled,
          );
          expect(
            _paintedGlyphInk(tester, _disabled),
            tokens.ui.foregroundDisabled,
          );
          expect(
            _labelStyle(tester, 'Unavailable pinned action').fontWeight,
            FontWeight.w700,
          );
          final node = tester.getSemantics(find.byKey(_disabled));
          expect(node.getSemanticsData().role, SemanticsRole.menuItem);
          expect(node.flagsCollection.isEnabled, Tristate.isFalse);
          expect(node.flagsCollection.isChecked, CheckedState.none);
          await tester.tap(find.byKey(_disabled));
          await tester.pump();
          expect(activated, 0);
          await tester.tap(find.byKey(_plain));
          await tester.pump();
          expect(activated, 1);
          expect(tester.takeException(), isNull);
        } finally {
          await mouse.removePointer();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          semantics.dispose();
        }
      },
    );
  }
}
