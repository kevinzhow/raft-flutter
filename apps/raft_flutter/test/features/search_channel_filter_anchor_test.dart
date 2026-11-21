import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (name, platform, density, viewport) in [
    ('desktop', TargetPlatform.linux, 1.0, const Size(1280, 900)),
    ('narrow desktop', TargetPlatform.linux, 1.0, const Size(390, 844)),
    ('portrait foldable', TargetPlatform.android, 3.0, const Size(856, 944)),
    ('landscape foldable', TargetPlatform.android, 3.0, const Size(944, 856)),
  ]) {
    testWidgets('Channel picker snaps to the $name pixel grid', (tester) async {
      tester.view.devicePixelRatio = density;
      tester.view.physicalSize = viewport * density;
      addTearDown(tester.view.reset);
      final selected = <String>[];
      const filter = ValueKey('search-channel-filter');
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 127.6875,
                  top: 48.5,
                  child: TaskSelectionFilter(
                    key: filter,
                    field: 'Channel',
                    options: const {'design': 'design'},
                    selection: const {},
                    valid: () => true,
                    onToggle: selected.add,
                    onClear: () {},
                    onController: (_, _) {},
                    combobox: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final anchor = tester.getRect(find.byKey(filter));
      await tester.tap(find.byKey(filter));
      await tester.pumpAndSettle();
      final panel = find.byType(RaftComboboxPanel);
      final popup = tester.getRect(panel);
      double snap(double coordinate) =>
          (coordinate * density).round() / density;
      expect(popup.left, closeTo(snap(anchor.left), .001));
      expect(popup.top, closeTo(snap(anchor.bottom + 4), .001));
      expect(popup.width, 220);
      final input = find.descendant(
        of: panel,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      await tester.tap(find.byKey(filter));
      await tester.pumpAndSettle();
      await tester.tap(input);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      await tester.tap(find.byKey(filter));
      await tester.pumpAndSettle();
      await tester.tap(find.text('design').hitTestable());
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(selected, ['design']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
