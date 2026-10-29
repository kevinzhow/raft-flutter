import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/dropdown_menu_role_previews.dart';

bool _realFontsLoaded = false;

Future<void> _loadRealFonts(WidgetTester tester) async {
  if (_realFontsLoaded) return;
  await tester.runAsync(() async {
    Directory? fonts;
    var directory = Directory.current;
    while (fonts == null) {
      for (final relative in [
        'assets/fonts/',
        'packages/raft_ui/assets/fonts/',
      ]) {
        final candidate = Directory.fromUri(directory.uri.resolve(relative));
        if (File.fromUri(candidate.uri.resolve('SpaceGrotesk.ttf'))
            .existsSync()) {
          fonts = candidate;
          break;
        }
      }
      if (fonts != null) break;
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Cannot locate the checked-out raft_ui font assets.');
      }
      directory = parent;
    }
    for (final family in [
      'SpaceGrotesk',
      'SpaceMono',
      'HankenGrotesk',
      'Inter',
      'Geist',
      'GeistMono',
    ]) {
      final bytes = await File.fromUri(fonts.uri.resolve('$family.ttf'))
          .readAsBytes();
      await (FontLoader(
        'packages/raft_ui/$family',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    // A missing file or failed font registration must fail this case and let
    // the next case retry, never silently cache a fallback to Ahem.
    _realFontsLoaded = true;
  });
  if (!_realFontsLoaded) {
    throw StateError('Real-font loading failed; geometry was not exercised.');
  }
}

const _label = 'Open published menu';

Widget _host(Widget child, double scale) => MaterialApp(
  theme: raftTheme(platform: TargetPlatform.linux),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RaftTextScaling(child: child!),
  ),
  home: Scaffold(body: child),
);

void _expectBoundedLabel(WidgetTester tester, double scale) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(_label));
  expect(paragraph.text.toPlainText(), _label);
  expect(paragraph.didExceedMaxLines, isFalse);
  final labelRect = tester.getRect(find.text(_label));
  final controlRect = tester.getRect(
    find
        .ancestor(of: find.text(_label), matching: find.byType(RaftControl))
        .first,
  );
  expect(labelRect.right, lessThanOrEqualTo(390));
  expect(labelRect.left, greaterThanOrEqualTo(controlRect.left));
  expect(labelRect.right, lessThanOrEqualTo(controlRect.right));
  expect(labelRect.top, greaterThanOrEqualTo(controlRect.top));
  expect(labelRect.bottom, lessThanOrEqualTo(controlRect.bottom));
  if (scale > 1) {
    expect(paragraph.maxLines, isNull);
    expect(paragraph.softWrap, isTrue);
  }
}

void main() {
  for (final scale in [1.0, 3.1]) {
    for (final expanded in [false, true]) {
      testWidgets(
        'actual dropdown role preview keeps full trigger bounded at $scale; expanded=$expanded',
        (tester) async {
          await _loadRealFonts(tester);
          final ratio = tester.view.devicePixelRatio;
          tester.view.physicalSize = Size(390 * ratio, 600 * ratio);
          final errors = <FlutterErrorDetails>[];
          final previous = FlutterError.onError;
          FlutterError.onError = errors.add;
          try {
            // The unchanged registered preview is the exact reported surface.
            await tester.pumpWidget(_host(dropdownMenuRolePreview(), scale));
            await tester.pumpAndSettle();
            if (expanded) {
              await tester.tap(find.byType(RaftDropdownMenu));
              await tester.pumpAndSettle();
              expect(find.text('Open details'), findsOneWidget);
            }
            expect(
              errors,
              isEmpty,
              reason: 'trigger must honor available width',
            );
            _expectBoundedLabel(tester, scale);
          } finally {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            tester.view.reset();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            FlutterError.onError = previous;
          }
        },
      );
    }
  }

  for (final style in RaftDropdownTriggerStyle.values) {
    testWidgets(
      'current $style long label shares finite width with both icons at 3.1',
      (tester) async {
        await _loadRealFonts(tester);
        final ratio = tester.view.devicePixelRatio;
        tester.view.physicalSize = Size(390 * ratio, 600 * ratio);
        final controller = RaftMenuController();
        var actions = 0;
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await tester.pumpWidget(
            _host(
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 240,
                  child: RaftDropdownMenu(
                    label: _label,
                    controller: controller,
                    triggerStyle: style,
                    glyph: RaftGlyph.info,
                    trailingGlyph: RaftGlyph.chevronDown,
                    entries: [
                      RaftMenuEntry(
                        label: 'Choose',
                        onPressed: () => actions++,
                      ),
                    ],
                  ),
                ),
              ),
              3.1,
            ),
          );
          await tester.pumpAndSettle();
          expect(errors, isEmpty);
          _expectBoundedLabel(tester, 3.1);
          expect(
            tester.getRect(find.text(_label)).right,
            lessThanOrEqualTo(240),
          );
          await tester.tap(find.byType(RaftDropdownMenu));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Choose'));
          await tester.pumpAndSettle();
          expect(actions, 1);
          expect(controller.isOpen, isFalse);
          expect(errors, isEmpty);
        } finally {
          controller.close();
          await tester.pumpAndSettle();
          tester.view.reset();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          controller.dispose();
          FlutterError.onError = previous;
        }
      },
    );
  }
}
