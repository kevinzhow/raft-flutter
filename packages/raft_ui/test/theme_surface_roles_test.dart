import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  // a57b9dab: design_primitives.dart:141-145, measured at 390/1280.
  // Raft: Web v1.21.23 Sidebar.tsx:3806, mobile canvas / desktop sidebar.
  for (final (id, dark, phone, desktop) in raftThemeMatrix([
    (raftThemePackId, false, 0xffffffff, 0xfffffaef),
    (raftThemePackId, true, 0xff1b1b19, 0xff0d0d0b),
    (elegantThemePackId, false, 0xfff8f8f7, 0xfff8f8f7),
    (elegantThemePackId, true, 0xff0d0d0b, 0xff0d0d0b),
    (brutalThemePackId, false, 0xffffffff, 0xfffffaef),
    (brutalThemePackId, true, 0xff0d0d0b, 0xff0d0d0b),
  ], look: (v) => raftLookOf(v.$1))) {
    for (final width in [390.0, 1280.0]) {
      testWidgets('$id dark=$dark sidebar surface @$width', (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id), dark: dark),
            home: const Scaffold(
              body: RaftMountedSidebarFrame(
                header: SizedBox(height: 40),
                body: SizedBox.expand(),
              ),
            ),
          ),
        );
        final fill = find
            .descendant(
              of: find.byType(RaftMountedSidebarFrame),
              matching: find.byType(ColoredBox),
            )
            .first;
        expect(
          t.widget<ColoredBox>(fill).color,
          Color(width < 768 ? phone : desktop),
        );
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
