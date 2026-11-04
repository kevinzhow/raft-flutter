import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/html_region_comment_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      if (id == brutalThemePackId && dark) continue;
      for (final scale in [1.0, 2.0, 3.1]) {
        testWidgets(
          '$id/$dark/$scale HTML region HUD and marker fit narrow pointer viewport',
          (t) async {
            t.view.physicalSize = const Size(390, 844);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(
                  pack: packForThemeId(id),
                  dark: dark,
                ).copyWith(platform: TargetPlatform.linux),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(body: htmlRegionCommentPreview()),
              ),
            );
            await t.pumpAndSettle();
            final hud = find.byType(RaftHtmlRegionHint);
            expect(hud, findsOneWidget);
            final before = t.getRect(find.byType(RaftMessageBody));
            await t.tap(find.text('Jump to stored region'));
            await t.pump();
            await t.pump();
            expect(
              find.byKey(const ValueKey('html-region-flash')),
              findsOneWidget,
            );
            expect(t.getRect(find.byType(RaftMessageBody)), before);
            expect(t.getRect(hud).left, greaterThanOrEqualTo(0));
            expect(t.getRect(hud).right, lessThanOrEqualTo(390));
            expect(t.takeException(), isNull);
            await t.pump(const Duration(seconds: 2));
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
