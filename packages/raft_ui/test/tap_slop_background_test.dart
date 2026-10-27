import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    for (final enabled in [false, true]) {
      testWidgets(
        'topbar background yields to expanded search dark=$dark enabled=$enabled',
        (t) async {
          t.view.physicalSize = const Size(856, 944);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
          var searches = 0;
          var doubles = 0;
          var drags = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: Column(
                  children: [
                    RaftWorkspaceTopBar(
                      workspace: const SizedBox(width: 100, height: 32),
                      onSearch: () => searches++,
                      onDoubleTap: enabled ? () => doubles++ : null,
                      onDragStart: enabled ? () => drags++ : null,
                    ),
                  ],
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final search = t.getRect(find.byKey(const Key('topbar-search')));
          final expanded = Offset(search.center.dx, 1);
          expect(search.contains(expanded), isFalse);
          await t.tapAt(expanded);
          await t.pumpAndSettle();
          expect(searches, 1);
          expect(doubles, 0);
          await t.tapAt(expanded);
          await t.pump(const Duration(milliseconds: 50));
          await t.tapAt(expanded);
          await t.pumpAndSettle();
          expect(searches, 3);
          expect(doubles, 0, reason: 'expanded controls own their pointers');
          await t.dragFrom(expanded, const Offset(25, 0));
          await t.pumpAndSettle();
          expect(drags, 0);
          const blank = Offset(800, 24);
          await t.tapAt(blank);
          await t.pump(const Duration(milliseconds: 50));
          await t.tapAt(blank);
          await t.pumpAndSettle();
          expect(doubles, enabled ? 1 : 0);
          await t.dragFrom(blank, const Offset(25, 0));
          await t.pumpAndSettle();
          expect(drags, enabled ? 1 : 0);
          expect(searches, 3);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
