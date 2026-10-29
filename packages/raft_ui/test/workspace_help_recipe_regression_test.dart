import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Product contract: Web LeftRail Help uses a 320px Popover with zero content
// inset and MenuItem rows. The row metrics come from the pinned Web MenuItem,
// not from the old Flutter RaftMenuRecipe (31.5px / 13px regular labels).
const _captureKey = ValueKey('help-contract-capture');
const _documentation = 'Documentation';
const _unavailable = 'Unavailable action';
const _feedback = 'Feedback';
const _community = 'Community';

class _HelpFixture {
  final controller = RaftMenuController();
  final editorFocus = FocusNode(skipTraversal: true);
  final calls = <String>[];
}

Finder _row(String label) => find.bySemanticsLabel(RegExp('^$label\$'));
Finder get _trigger => find.byType(RaftWorkspaceRailAction);
Finder get _popup => find.byType(RaftMenuPanel);

Future<_HelpFixture> _mount(
  WidgetTester tester, {
  required bool dark,
  double height = 844,
}) async {
  final fixture = _HelpFixture();
  tester.view.physicalSize = Size(900, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    fixture.controller.dispose();
    fixture.editorFocus.dispose();
  });
  final theme = raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) =>
          RepaintBoundary(key: _captureKey, child: child!),
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Focus(focusNode: fixture.editorFocus, child: const Text('Editor')),
            Positioned(
              left: 12,
              bottom: 44,
              child: RaftWorkspaceHelpMenu(
                label: 'Help',
                heading: 'Help & resources',
                controller: fixture.controller,
                entries: [
                  RaftMenuEntry(
                    label: _documentation,
                    glyph: RaftGlyph.bookOpenText,
                    onPressed: () => fixture.calls.add(_documentation),
                  ),
                  const RaftMenuEntry(label: _unavailable),
                  RaftMenuEntry(
                    label: _feedback,
                    glyph: RaftGlyph.messageSquare,
                    onPressed: () => fixture.calls.add(_feedback),
                  ),
                  RaftMenuEntry(
                    label: _community,
                    glyph: RaftGlyph.users,
                    onPressed: () => fixture.calls.add(_community),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_trigger);
  await tester.pumpAndSettle();
  expect(_row(_documentation), findsOneWidget);
}

TextStyle _paintedLabelStyle(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

Future<List<Color>> _pixels(WidgetTester tester, List<Offset> points) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return [
        for (final point in points)
          Color.fromARGB(
            data.getUint8(
              (point.dy.floor() * image.width + point.dx.floor()) * 4 + 3,
            ),
            data.getUint8(
              (point.dy.floor() * image.width + point.dx.floor()) * 4,
            ),
            data.getUint8(
              (point.dy.floor() * image.width + point.dx.floor()) * 4 + 1,
            ),
            data.getUint8(
              (point.dy.floor() * image.width + point.dx.floor()) * 4 + 2,
            ),
          ),
      ];
    } finally {
      image.dispose();
    }
  }))!;
}

void _expectColor(Color actual, Color expected, {required String reason}) {
  expect(actual.r, closeTo(expected.r, 1 / 255), reason: reason);
  expect(actual.g, closeTo(expected.g, 1 / 255), reason: reason);
  expect(actual.b, closeTo(expected.b, 1 / 255), reason: reason);
  expect(actual.a, closeTo(expected.a, 1 / 255), reason: reason);
}

double _colorDistance(Color a, Color b) =>
    ((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs()) * 255;

void _helpTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      // Flutter verifies semantics ownership before addTearDown callbacks.
      semantics.dispose();
    }
  });
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    for (final height in [844.0, 600.0]) {
      final compact = height <= 600;
      _helpTest(
        '$mode Help ${compact ? 'compact' : 'regular'} uses Web action metrics',
        (tester) async {
          await _mount(tester, dark: dark, height: height);
          await _open(tester);
          final row = tester.getRect(_row(_documentation));
          final style = _paintedLabelStyle(tester, _documentation);
          final icon = find.byWidgetPredicate(
            (widget) =>
                widget is RaftIcon && widget.glyph == RaftGlyph.bookOpenText,
          );
          final iconWidget = tester.widget<RaftIcon>(icon);
          final iconElement = tester.element(icon);
          final actualInk = iconWidget.color ?? IconTheme.of(iconElement).color;
          final tokens = Theme.of(iconElement).extension<RaftTokens>()!;
          expect(
            {
              'rowHeight': row.height,
              'fontSize': style.fontSize,
              'lineHeight': style.height,
              'fontWeight': style.fontWeight,
              'iconSize': tester.getSize(icon),
              'iconInk': actualInk,
            },
            {
              'rowHeight': compact ? 32.0 : 36.0,
              'fontSize': 14.0,
              'lineHeight': closeTo(20 / 14, .0001),
              'fontWeight': FontWeight.w500,
              'iconSize': const Size.square(14),
              'iconInk': tokens.ui.foregroundMuted,
            },
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    _helpTest('$mode Help preserves the source surface and paint-only edge', (
      tester,
    ) async {
      await _mount(tester, dark: dark);
      await _open(tester);
      final popup = tester.getRect(_popup);
      final trigger = tester.getRect(_trigger);
      expect(popup.width, 320);
      expect(popup.left, trigger.right + 8);
      expect(popup.bottom, trigger.bottom);
      expect(
        tester.getTopLeft(find.text('Help & resources')).dx - popup.left,
        12,
        reason:
            'The source header inset is 12px; the outer ring adds no border.',
      );
      final tokens = Theme.of(tester.element(_popup)).extension<RaftTokens>()!;
      final samples = await _pixels(tester, [
        Offset(popup.left + 12, popup.bottom - 3),
        Offset(popup.left + 2, popup.bottom - 3),
        Offset(popup.left - 1, popup.center.dy),
        Offset(popup.left - 2, popup.center.dy),
      ]);
      _expectColor(
        samples[0],
        tokens.popover,
        reason: 'Inside the 10px corner',
      );
      expect(
        _colorDistance(samples[1], tokens.popover),
        greaterThan(15),
        reason: 'The 10px source corner leaves this pixel on its outer ring.',
      );
      expect(
        _colorDistance(samples[2], samples[3]),
        greaterThan(10),
        reason: 'The source has one crisp outer ring before the soft shadow.',
      );
      expect(tester.takeException(), isNull);
    });

    _helpTest('$mode Help hover uses the source brand wash', (tester) async {
      final hovered = await _mount(tester, dark: dark);
      hovered.editorFocus.requestFocus();
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(880, 20));
      await mouse.moveTo(tester.getCenter(_trigger));
      await tester.pumpAndSettle();
      expect(hovered.controller.isOpen, isTrue);
      expect(hovered.editorFocus.hasFocus, isTrue);
      await mouse.moveTo(tester.getCenter(_row(_documentation)));
      await tester.pumpAndSettle();
      final hoverRect = tester.getRect(_row(_documentation));
      final tokens = Theme.of(tester.element(_popup)).extension<RaftTokens>()!;
      final expected = Color.alphaBlend(
        tokens.colors['brand-soft']!,
        tokens.popover,
      );
      final hoverPixel = (await _pixels(tester, [
        Offset(hoverRect.right - 12, hoverRect.center.dy),
      ])).single;
      _expectColor(hoverPixel, expected, reason: 'Pointer hover is brand-soft');
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    });

    _helpTest('$mode Help keyboard focus uses the source brand wash', (
      tester,
    ) async {
      await _mount(tester, dark: dark);
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.text(_documentation))).hasFocus,
        isTrue,
      );
      final tokens = Theme.of(tester.element(_popup)).extension<RaftTokens>()!;
      final expected = Color.alphaBlend(
        tokens.colors['brand-soft']!,
        tokens.popover,
      );
      final focusRect = tester.getRect(_row(_documentation));
      final focusPixel = (await _pixels(tester, [
        Offset(focusRect.right - 12, focusRect.center.dy),
      ])).single;
      _expectColor(
        focusPixel,
        expected,
        reason: 'Keyboard focus is brand-soft',
      );
      expect(tester.takeException(), isNull);
    });

    _helpTest('$mode Help keeps disabled, keyboard and focus-return behavior', (
      tester,
    ) async {
      final fixture = await _mount(tester, dark: dark);
      await _open(tester);
      await tester.tap(_row(_unavailable));
      await tester.pumpAndSettle();
      expect(fixture.calls, isEmpty);
      expect(fixture.controller.isOpen, isTrue);
      expect(
        tester.getSemantics(_row(_unavailable)).flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      // Start the keyboard journey from its own explicit trigger action,
      // rather than assuming a disabled pointer press owns keyboard focus.
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fixture.calls, [_community]);
      expect(fixture.controller.isOpen, isFalse);

      // Trigger focus is restored after activation. Home then Down must
      // select Feedback, skipping the disabled second entry.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(fixture.controller.isOpen, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fixture.calls, [_community, _feedback]);
      expect(fixture.controller.isOpen, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fixture.calls, [_community, _feedback, _community]);
      expect(fixture.controller.isOpen, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(fixture.controller.isOpen, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(fixture.controller.isOpen, isFalse);
      expect(fixture.calls, [_community, _feedback, _community]);
      expect(tester.takeException(), isNull);
    });
  }
}
