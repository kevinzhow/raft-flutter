import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  const textKey = Key('multiline-selection');
  final toolbar = find.byKey(const Key('selection-shortcut-frame'));

  Widget host(TargetPlatform platform, {ValueChanged<String>? onSelected}) =>
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
            child: RaftSelectionArea(
              shortcut: RaftSelectionShortcut(onQuote: (_) {}),
              onSelectionChanged: (content) =>
                  onSelected?.call(content?.plainText ?? ''),
              child: const Text(
                'First line same length\nSecond line same length',
                key: textKey,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      );

  testWidgets('messageSelectionShortcutUtils anchors at the focused line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(TargetPlatform.linux));
    final text = tester.getRect(find.byKey(textKey));
    final first = text.topLeft + Offset(2, text.height / 4);
    final last = text.bottomRight - Offset(2, text.height / 4);
    Future<double> select(Offset from, Offset to) async {
      final gesture = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(to);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      return tester.getBottomLeft(toolbar).dy;
    }

    final forward = await select(first, last);
    final backward = await select(last, first);
    expect(forward - backward, greaterThan(text.height / 3));
  });

  for (final size in [const Size(856, 944), const Size(944, 856)]) {
    testWidgets('foldable $size keeps the touch selection menu', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = '';
      await tester.pumpWidget(
        host(TargetPlatform.android, onSelected: (value) => selected = value),
      );
      final text = tester.getRect(find.byKey(textKey));
      await tester.longPressAt(text.topLeft + const Offset(15, 8));
      await tester.pump(const Duration(milliseconds: 200));
      expect(selected, isNotEmpty);
      expect(toolbar, findsNothing);
    });
  }
}
