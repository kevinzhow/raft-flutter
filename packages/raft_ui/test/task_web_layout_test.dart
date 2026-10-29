import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'task_typography_test.dart' show loadTaskFonts;

void main() {
  testWidgets('task card matches Web body type and keeps status activation', (
    tester,
  ) async {
    await loadTaskFonts(tester);
    final theme = raftTheme(pack: packForThemeId(raftThemePackId));
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 358,
              child: RaftTaskCard(
                title: 'Align the tabbar capture crops',
                number: '214',
                status: 'todo',
                channel: 'design',
                description: 'Both providers must agree.',
                onTap: () => opened++,
              ),
            ),
          ),
        ),
      ),
    );
    // Web v1.21.23 TaskCardTitle: text-body (16/24), weight 600.
    final title = tester.widget<Text>(
      find.text('Align the tabbar capture crops'),
    );
    expect(title.style!.fontSize, 16);
    expect(title.style!.height, 1.5);
    expect(title.style!.fontWeight, FontWeight.w600);
    await tester.tap(find.text('Align the tabbar capture crops'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('task section keeps a full-width unframed trigger above cards', (
    tester,
  ) async {
    await loadTaskFonts(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(raftThemePackId)),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 358,
              child: RaftTaskSection(
                status: 'todo',
                count: 1,
                triggerKey: Key('trigger'),
                children: [SizedBox(key: Key('task'), height: 40)],
              ),
            ),
          ),
        ),
      ),
    );
    // Actual Web DOM: no section inset, min-height 32 + product gap 10.
    expect(tester.getRect(find.byKey(const Key('trigger'))).height, 32);
    expect(tester.getTopLeft(find.byKey(const Key('task'))).dx, 0);
    expect(tester.getTopLeft(find.byKey(const Key('task'))).dy, 42);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
