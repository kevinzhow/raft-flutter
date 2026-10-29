import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    for (final scale in [1.0, 3.1]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} $scale DMs mobile and picker are accessible',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          final selected = <RaftActivityView>[];
          Future<void> mount(Widget child) => tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: RaftTextScaling(child: child!),
              ),
              home: Scaffold(body: child),
            ),
          );
          try {
            await mount(
              Align(
                alignment: Alignment.topLeft,
                child: RaftActivityScopeToolbar(
                  view: RaftActivityView.dms,
                  compact: false,
                  sort: 'desc',
                  onView: selected.add,
                  onOpenSwitcher: () {},
                  onSort: (_) {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            final mobile = find.byKey(const ValueKey('activity-view-dms'));
            expect(find.bySemanticsLabel('DMs'), findsOneWidget);
            expect(tester.getRect(mobile).right, lessThanOrEqualTo(390));
            await tester.tap(mobile);
            await tester.pump();
            expect(selected, [RaftActivityView.dms]);
            await mount(
              RaftActivityScopePicker(
                view: RaftActivityView.dms,
                onView: selected.add,
                counts: const {RaftActivityView.dms: 2},
                groups: const [
                  RaftActivityGroup(id: 'room', label: 'Room', count: 19),
                ],
                onGroup: (_) {},
                onClearGroup: () {},
              ),
            );
            await tester.pumpAndSettle();
            final picker = find.byKey(
              const ValueKey('activity-switcher-nav-dms'),
            );
            await tester.ensureVisible(picker);
            await tester.pumpAndSettle();
            final focus = find
                .descendant(of: picker, matching: find.byType(Focus))
                .first;
            tester.widget<Focus>(focus).focusNode!.requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pump();
            expect(selected, [RaftActivityView.dms, RaftActivityView.dms]);
            expect(find.text('19'), findsNothing);
            expect(find.text('2'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    }
  }
}
