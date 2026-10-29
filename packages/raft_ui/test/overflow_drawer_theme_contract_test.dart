import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (pack, lightWidth) in raftThemeMatrix([
    (raftThemePackId, 420.0),
    (elegantThemePackId, 448.0),
    (brutalThemePackId, 544.0),
  ], look: (v) => raftLookOf(v.$1))) {
    for (final dark in [false, true]) {
      testWidgets(
        '$pack/$dark drawer uses source width and keeps phone/page bounds',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
          final limit = dark && pack == brutalThemePackId ? 448.0 : lightWidth;
          for (final (viewport, page, expected) in [
            (1280.0, false, limit),
            (390.0, false, 390.0),
            (1280.0, true, 1280.0),
          ]) {
            tester.view.physicalSize = Size(viewport, 800);
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(pack: packForThemeId(pack), dark: dark),
                home: Scaffold(
                  body: RaftOverflowSheet(
                    title: '#work',
                    onClose: () {},
                    page: page,
                    children: const [],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('channel-overflow-sheet')))
                  .width,
              expected,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
