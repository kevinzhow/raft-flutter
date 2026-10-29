import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'composer_composing_underline_test.dart' show loadImeFonts;

void main() {
  testWidgets('IME ranges repaint without changing text, caret or selection', (
    t,
  ) async {
    final f = await _Fixture.mount(t);
    const text = 'prefix 中  A  文  B suffix';
    final value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.indexOf('A') + 1),
      composing: TextRange(
        start: text.indexOf('中'),
        end: text.indexOf('B') + 1,
      ),
    );
    await f.edit(value);
    final first = await f.indicatorPixels();
    expect(first, isNotEmpty);
    expect(f.controller.value, value);

    // Move only the composing range, not text or selection. Previously painted
    // parts must disappear immediately rather than waiting for a text layout.
    final changed = value.copyWith(
      composing: TextRange(
        start: text.indexOf('A'),
        end: text.indexOf('A') + 1,
      ),
    );
    await f.edit(changed);
    final narrowed = await f.indicatorPixels();
    expect(narrowed, isNotEmpty);
    expect(narrowed.length, lessThan(first.length));
    final box = f.editable
        .getBoxesForSelection(
          TextSelection(
            baseOffset: text.indexOf('A'),
            extentOffset: text.indexOf('A') + 1,
          ),
        )
        .single;
    final left = f.editorRegion.left + box.left * 2;
    final right = f.editorRegion.left + box.right * 2;
    expect(
      narrowed.every((pixel) => pixel.dx >= left - 1 && pixel.dx <= right + 1),
      true,
      reason:
          'Committed prefix, CJK text and suffix must not remain underlined',
    );
    expect(f.controller.value, changed);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(f.sent, isEmpty);
    expect(f.controller.value, changed);

    // A composing value received while unfocused must not leave an indicator.
    f.field.focusNode!.unfocus();
    await t.pump();
    f.controller.value = changed;
    await t.pump();
    expect(await f.indicatorPixels(), isEmpty);
    f.field.focusNode!.requestFocus();
    await t.pump();
    await f.edit(changed);
    expect(await f.indicatorPixels(), isNotEmpty);
    f.update(() => f.enabled = false);
    await t.pump();
    expect(await f.indicatorPixels(), isEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'wrapped UTF-16 composing ranges stay in their viewport after resize and scroll',
    (t) async {
      final f = await _Fixture.mount(t);
      final text =
          'prefix ${List.filled(9, '中文 A 👩‍💻 e\u0301 日本語 ffi\r\n').join()} suffix';
      final range = TextRange(start: 0, end: text.lastIndexOf(' suffix'));
      final value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: range.end),
        composing: range,
      );
      await f.edit(value);
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(f.editable.offset.pixels, greaterThan(0));
      final firstPixels = await f.indicatorPixels();
      expect(firstPixels, isNotEmpty);
      expect(_rowGroups(firstPixels).length, greaterThan(2));
      expect(_rowGroups(firstPixels).every((group) => group.length <= 3), true);
      expect(f.controller.value, value);

      t.view.physicalSize = const Size(560, 1688);
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(await f.indicatorPixels(), isNotEmpty);
      expect(f.controller.value, value);
      final top = value.copyWith(
        selection: const TextSelection.collapsed(offset: 0),
      );
      await f.edit(top);
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(f.editable.offset.pixels, 0);
      final topPixels = await f.indicatorPixels();
      expect(topPixels, isNotEmpty);
      expect(_rowGroups(topPixels).every((group) => group.length <= 3), true);
      expect(f.controller.value, top);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'non-Android keeps native composing drawing and editor behavior',
    (t) async {
      final f = await _Fixture.mount(t, platform: TargetPlatform.iOS);
      const text = '中文 mixed';
      const value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange(start: 0, end: text.length),
      );
      await f.edit(value);
      expect(await f.indicatorPixels(), isNotEmpty);
      expect(f.controller.value, value);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}

List<List<int>> _rowGroups(List<Offset> pixels) {
  final rows = pixels.map((pixel) => pixel.dy.toInt()).toSet().toList()..sort();
  final groups = <List<int>>[];
  for (final row in rows) {
    if (groups.isEmpty || row > groups.last.last + 1) groups.add([]);
    groups.last.add(row);
  }
  return groups;
}

class _Fixture {
  final WidgetTester tester;
  _Fixture(this.tester);
  final capture = GlobalKey();
  final sent = <String>[];
  late StateSetter update;
  bool enabled = true;
  TextField get field => tester.widget<TextField>(find.byType(TextField));
  TextEditingController get controller => field.controller!;
  RenderEditable get editable =>
      tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;

  static Future<_Fixture> mount(
    WidgetTester t, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await loadImeFonts(t);
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final f = _Fixture(t);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: StatefulBuilder(
              builder: (_, setState) {
                f.update = setState;
                return RepaintBoundary(
                  key: f.capture,
                  child: RaftComposer(
                    enabled: f.enabled,
                    onSend: (text) async {
                      f.sent.add(text);
                      return false;
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(TextField));
    await t.pump();
    return f;
  }

  Future<void> edit(TextEditingValue value) async {
    tester.testTextInput.updateEditingValue(value);
    await tester.pump();
    expect(controller.value, value);
  }

  Rect get editorRegion {
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final top = boundary.globalToLocal(editable.localToGlobal(Offset.zero));
    return Rect.fromLTWH(
      top.dx * 2,
      top.dy * 2,
      editable.size.width * 2,
      editable.size.height * 2,
    );
  }

  Future<_Snapshot> snapshot() async {
    late _Snapshot result;
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final top = boundary.globalToLocal(editable.localToGlobal(Offset.zero));
      result = _Snapshot(
        picture.width,
        picture.height,
        Uint8List.fromList(bytes!.buffer.asUint8List()),
        Rect.fromLTWH(
          top.dx * 2,
          top.dy * 2,
          editable.size.width * 2,
          editable.size.height * 2,
        ),
      );
      picture.dispose();
    });
    return result;
  }

  Future<List<Offset>> indicatorPixels() async {
    final value = controller.value;
    final original = await snapshot();
    controller.value = value.copyWith(composing: TextRange.empty);
    await tester.pump();
    final committed = await snapshot();
    controller.value = value;
    await tester.pump();
    expect(controller.value, value);
    expect(original.region, committed.region);
    expect(original.width, committed.width);
    expect(original.height, committed.height);
    final pixels = <Offset>[];
    for (
      var y = original.region.top.ceil().clamp(0, original.height);
      y < original.region.bottom.floor().clamp(0, original.height);
      y++
    ) {
      for (
        var x = original.region.left.ceil().clamp(0, original.width);
        x < original.region.right.floor().clamp(0, original.width);
        x++
      ) {
        final index = (y * original.width + x) * 4;
        final delta =
            (original.rgba[index] - committed.rgba[index]).abs() +
            (original.rgba[index + 1] - committed.rgba[index + 1]).abs() +
            (original.rgba[index + 2] - committed.rgba[index + 2]).abs();
        if (delta > 90) pixels.add(Offset(x.toDouble(), y.toDouble()));
      }
    }
    return pixels;
  }
}

class _Snapshot {
  const _Snapshot(this.width, this.height, this.rgba, this.region);
  final int width, height;
  final Uint8List rgba;
  final Rect region;
}
