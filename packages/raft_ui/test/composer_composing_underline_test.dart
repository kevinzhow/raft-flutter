import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'task_typography_test.dart' show loadTaskFonts;

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'mixed-font composing underline has one vertical position ${dark ? 'dark' : 'light'}/$scale',
        (t) async {
          await loadImeFonts(t);
          t.view.physicalSize = const Size(1170, 2532);
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          final boundaryKey = GlobalKey();
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark)
                  .copyWith(platform: TargetPlatform.android),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: RaftComposer(onSend: (_) async => false),
                  ),
                ),
              ),
            ),
          );
          final field = find.byType(TextField);
          await t.tap(field);
          await t.pump();
          const text = '中  A  文  B';
          t.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
              composing: TextRange(start: 0, end: text.length),
            ),
          );
          await t.pump();
          final editable = t
              .state<EditableTextState>(find.byType(EditableText))
              .renderEditable;
          final expectedValue = t.widget<TextField>(field).controller!.value;
          final tokens = RaftTokens.of(t.element(field));
          final rows = <int>[];
          await t.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final picture = await boundary.toImage(pixelRatio: 3);
            final data = await picture.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final rgba = data!.buffer.asUint8List();
            final origin = boundary.globalToLocal(
              editable.localToGlobal(Offset.zero),
            );
            final background = tokens.panel.toARGB32();
            for (final character in [0, 3, 6, 9]) {
              final box = editable
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: character,
                      extentOffset: character + 1,
                    ),
                  )
                  .single;
              final column = ((origin.dx + (box.left + box.right) / 2) * 3)
                  .floor();
              var bottomInk = -1;
              for (
                var y = (origin.dy * 3).ceil();
                y < ((origin.dy + editable.size.height) * 3).floor();
                y++
              ) {
                final offset = (y * picture.width + column) * 4;
                final delta =
                    (rgba[offset] - ((background >> 16) & 255)).abs() +
                    (rgba[offset + 1] - ((background >> 8) & 255)).abs() +
                    (rgba[offset + 2] - (background & 255)).abs();
                if (delta > 90) bottomInk = y;
              }
              expect(bottomInk, greaterThan(0));
              rows.add(bottomInk);
            }
            final evidence = Platform.environment['RAFT_IME_EVIDENCE_DIR'];
            if (evidence != null) {
              final png = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '$evidence/${dark ? 'dark' : 'light'}-$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
            }
            picture.dispose();
          });
          expect(
            rows.toSet(),
            hasLength(1),
            reason:
                'CJK and Latin glyphs must share the same painted composing line: $rows',
          );
          expect(t.widget<TextField>(field).controller!.value, expectedValue);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}

Future<void> loadImeFonts(WidgetTester t) async {
  await loadTaskFonts(t);
  await t.runAsync(() async {
    // Optional local-only device font control. Proprietary system fonts are
    // never bundled in production or redistributed with the regression test.
    final path =
        Platform.environment['RAFT_IME_FONT_PATH'] ?? _imeFixturePath();
    final bytes = await File(path).readAsBytes();
    // Match the first product fallback. Unknown families in Flutter tests can
    // resolve to the test font before a later fallback is considered.
    await (FontLoader(
      'Noto Sans CJK JP',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });
}

/// The committed CJK fixture, found from the test's working directory
/// (packages/raft_ui, or the repository root under tool/check-project).
String _imeFixturePath() {
  const rel = 'test/fixtures/ime/RaftImeCjkFixture.ttf';
  for (var d = Directory.current.absolute; ; d = d.parent) {
    for (final candidate in [
      '${d.path}/$rel',
      '${d.path}/packages/raft_ui/$rel',
    ]) {
      if (File(candidate).existsSync()) return candidate;
    }
    if (d.parent.path == d.path) return rel;
  }
}
