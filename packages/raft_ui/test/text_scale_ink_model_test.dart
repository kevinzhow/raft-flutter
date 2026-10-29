import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/testing/text_scale_audit.dart';

Future<AuditReport> inspect(
  WidgetTester t,
  Widget Function() build, {
  AuditMode mode = AuditMode.x2,
  Future<void> Function(WidgetTester)? after,
}) async {
  await loadAuditFonts(t, AuditFonts.real);
  return auditSurface(
    t,
    surface: 'ink-model',
    build: build,
    theme: ThemeData(fontFamily: 'packages/raft_ui/SpaceGrotesk'),
    mode: mode,
    size: const Size(300, 200),
    truncationBaseline: {},
    after: after,
  );
}

Widget label(String text) => Text(
  text,
  style: const TextStyle(fontSize: 17, height: 22 / 17),
  maxLines: 1,
  softWrap: false,
  overflow: TextOverflow.ellipsis,
);

void main() {
  testWidgets('nowrap ellipsis ink uses the actual paragraph width', (t) async {
    for (final text in ['A long display name', '骨直令：很长的中文名字']) {
      final report = await inspect(
        t,
        () => Align(
          alignment: Alignment.topLeft,
          child: ClipRect(child: SizedBox(width: 80, child: label(text))),
        ),
      );
      expect(report.inkClipped, isEmpty, reason: report.failures.join('\n'));
    }
  });

  testWidgets('a smaller ancestor still cuts ellipsised ink', (t) async {
    for (final text in ['A long display name', '骨直令：很长的中文名字']) {
      final report = await inspect(
        t,
        () => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 40,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: 120,
                child: SizedBox(width: 120, child: label(text)),
              ),
            ),
          ),
        ),
      );
      expect(report.inkClipped, isNotEmpty);
    }
  });

  testWidgets('a multiline editor viewport scrolls to its unchanged text end', (
    t,
  ) async {
    final controller = TextEditingController(
      text: 'Start 中文\nsecond line\nthird line\nfourth line\nEnd descenders Gypsy',
    );
    addTearDown(controller.dispose);
    for (final end in [false, true]) {
      final report = await inspect(
        t,
        () => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            height: 100,
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              decoration: const InputDecoration.collapsed(hintText: ''),
              style: const TextStyle(fontSize: 17, height: 22 / 17),
            ),
          ),
        ),
        mode: AuditMode.x31,
        after: (t) async {
          final RenderEditable editable = t
              .state<EditableTextState>(find.byType(EditableText))
              .renderEditable;
          final position = editable.offset as ScrollPosition;
          expect(position.maxScrollExtent, greaterThan(0));
          expect(
            editable.size.height,
            greaterThanOrEqualTo(editable.preferredLineHeight),
          );
          position.jumpTo(end ? position.maxScrollExtent : 0);
          await t.pump();
          expect(position.pixels, end ? position.maxScrollExtent : 0);
        },
      );
      expect(report.inkClipped, isEmpty, reason: report.failures.join('\n'));
      expect(controller.text, endsWith('End descenders Gypsy'));
    }
  });

  testWidgets('a one-line editor too short for its ink still fails', (t) async {
    final controller = TextEditingController(text: 'Gypsy 骨直令');
    addTearDown(controller.dispose);
    final report = await inspect(
      t,
      () => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 240,
          height: 12,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration.collapsed(hintText: ''),
            style: const TextStyle(fontSize: 17, height: 22 / 17),
          ),
        ),
      ),
    );
    expect(report.inkClipped, isNotEmpty);
  });

  testWidgets('an outer clip cutting a scrollable editor still fails', (
    t,
  ) async {
    final controller = TextEditingController(
      text: 'Long first line 中文\nsecond long line\nthird long line\nEnd',
    );
    addTearDown(controller.dispose);
    final report = await inspect(
      t,
      () => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 80,
          height: 100,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: 240,
              maxHeight: 100,
              child: SizedBox(
                width: 240,
                height: 100,
                child: TextField(
                  controller: controller,
                  expands: true,
                  maxLines: null,
                  decoration: const InputDecoration.collapsed(hintText: ''),
                  style: const TextStyle(fontSize: 17, height: 22 / 17),
                ),
              ),
            ),
          ),
        ),
      ),
      mode: AuditMode.x31,
    );
    expect(report.inkClipped, isNotEmpty);
  });
}
