import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Fixed Web db5e399f SelectionPopoverOptionRow contract. These are public
// compatibility API observations; no app source is needed to compile them.
const _capture = ValueKey('selection-compat-capture');
const _plainRow = ValueKey('compat-plain');
const _selectedRow = ValueKey('compat-selected');
const _disabledRow = ValueKey('compat-disabled');
const _hintRow = ValueKey('compat-hint');

Widget _host(Widget child, {required bool dark}) {
  final theme = raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux);
  return MaterialApp(
    theme: theme,
    builder: (context, child) => RepaintBoundary(key: _capture, child: child!),
    home: Scaffold(
      body: DefaultTextStyle(
        style: TextStyle(
          fontFamily: theme.extension<RaftTokens>()!.bodyFont,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
        ),
        child: child,
      ),
    ),
  );
}

TextStyle _style(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

Future<void> _retire(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<Color> _pixel(WidgetTester tester, Offset position) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final i = (position.dy.floor() * image.width + position.dx.floor()) * 4;
      return Color.fromARGB(
        bytes.getUint8(i + 3),
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

Widget _compatRows(List<String> calls) => Align(
  alignment: Alignment.topLeft,
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: RaftMenuPanel(
      width: 220,
      kind: RaftMenuKind.selectionPopover,
      children: [
        RaftMenuItem(
          key: _plainRow,
          label: 'Ordinary',
          kind: RaftMenuKind.selectionPopover,
          onPressed: () => calls.add('ordinary'),
        ),
        RaftMenuItem(
          key: _selectedRow,
          label: 'Selected',
          kind: RaftMenuKind.selectionPopover,
          selected: true,
          onPressed: () => calls.add('selected'),
        ),
        const RaftMenuItem(
          key: _disabledRow,
          label: 'Disabled selected',
          kind: RaftMenuKind.selectionPopover,
          selected: true,
        ),
        RaftMenuItem(
          key: _hintRow,
          label: 'Unassigned',
          kind: RaftMenuKind.selectionPopover,
          italic: true,
          divider: true,
          onPressed: () => calls.add('unassigned'),
        ),
      ],
    ),
  ),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'compatibility choice rows keep source checked disabled and hint states; dark=$dark',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final calls = <String>[];
        try {
          await tester.pumpWidget(_host(_compatRows(calls), dark: dark));
          final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
          expect(tester.getRect(find.byKey(_plainRow)).height, 36);
          expect(_style(tester, 'Ordinary').fontSize, 14);
          expect(_style(tester, 'Ordinary').height, 20 / 14);
          expect(_style(tester, 'Ordinary').fontWeight, FontWeight.w500);
          expect(_style(tester, 'Selected').fontWeight, FontWeight.w700);
          expect(
            _style(tester, 'Disabled selected').fontWeight,
            FontWeight.w400,
          );
          expect(
            _style(tester, 'Disabled selected').color,
            tokens.ui.foregroundDisabled,
          );
          expect(_style(tester, 'Unassigned').color, tokens.ui.foregroundMuted);
          expect(_style(tester, 'Unassigned').fontStyle, FontStyle.normal);
          final selected = tester.getSemantics(find.byKey(_selectedRow));
          final disabled = tester.getSemantics(find.byKey(_disabledRow));
          expect(selected.flagsCollection.isChecked, ui.CheckedState.isTrue);
          expect(disabled.flagsCollection.isEnabled, ui.Tristate.isFalse);
          await tester.tap(find.byKey(_disabledRow));
          expect(calls, isEmpty);
          await tester.tap(find.byKey(_plainRow));
          await tester.pump();
          expect(calls, ['ordinary']);
          expect(tester.takeException(), isNull);
        } finally {
          await _retire(tester);
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'compatibility choice hover paints source brand-soft; dark=$dark',
      (tester) async {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        try {
          await tester.pumpWidget(_host(_compatRows(<String>[]), dark: dark));
          await mouse.addPointer(location: const Offset(700, 500));
          await mouse.moveTo(tester.getCenter(find.byKey(_plainRow)));
          await tester.pumpAndSettle();
          final row = tester.getRect(find.byKey(_plainRow));
          // Independent pinned Web samples of brand-soft on this popover:
          // Help hover raft.png SHA d5178aacf77f5dcb, dark SHA 55e9dc86dc56b547.
          // See selection-compat-regression/hover-reference-sample.json. Do not
          // derive the expected paint through Dart Color.alphaBlend: its
          // floating-point result differs from Chrome's dark blue byte37.
          expect(
            await _pixel(tester, row.topLeft + Offset(5, row.height / 2)),
            dark ? const Color(0xff383425) : const Color(0xfffff0bd),
          );
          expect(tester.takeException(), isNull);
        } finally {
          await mouse.removePointer();
          await _retire(tester);
        }
      },
    );
  }
}
