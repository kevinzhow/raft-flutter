import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// SidebarRowsSkeleton + Tailwind animate-pulse: 2s cycle, opacity .5 at
// midpoint, source18px avatar and 8px vertical padding => stable34px rows.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Home loading pulse preserves source layout and retires ticker ${dark ? 'dark' : 'light'}',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: const Scaffold(
              body: SizedBox(
                width: 320,
                child: RaftChatSidebarLoadingRows(rows: 4),
              ),
            ),
          ),
        );
        await t.pump();
        final fade = find.descendant(
          of: find.byType(RaftChatSidebarLoadingRows),
          matching: find.byType(FadeTransition),
        );
        double opacity() => t.widget<FadeTransition>(fade).opacity.value;
        expect(opacity(), 1);
        expect(t.getSize(find.byType(RaftChatSidebarLoadingRows)).height, 136);
        await t.pump(const Duration(seconds: 1));
        expect(opacity(), closeTo(.5, .001));
        expect(t.getSize(find.byType(RaftChatSidebarLoadingRows)).height, 136);
        await t.pump(const Duration(seconds: 1));
        expect(opacity(), closeTo(1, .001));
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        expect(t.binding.transientCallbackCount, 0);
        expect(t.takeException(), isNull);
      },
    );
  }
}
