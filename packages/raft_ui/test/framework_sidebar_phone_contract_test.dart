import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Sidebar.tsx max-md rows: min-h-11 is retained in short phone windows.
// Tall entry rows have py-2.5 (46px); max-height:600 resets py-0 (44px minimum).
void main() {
  for (final height in [480.0, 844.0]) {
    for (final dark in [false, true]) {
      testWidgets('Raft $dark phone $height retains row minimums', (t) async {
        t.view.physicalSize = Size(390, height);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  RaftNavItem(
                    label: 'engineering',
                    glyph: RaftGlyph.hash,
                    conversationKind: RaftConversationNavKind.channel,
                    onTap: () {},
                  ),
                  RaftNavItem(
                    label: 'Saved',
                    glyph: RaftGlyph.bookmark,
                    role: RaftNavItemRole.saved,
                    count: 5,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        final controls = find.byType(RaftControl);
        expect(t.widget<RaftControl>(controls.at(0)).visualHeight, 44);
        expect(
          t.widget<RaftControl>(controls.at(1)).visualHeight,
          height <= 600 ? 44 : 46,
        );
        final title = t.widget<Text>(find.text('engineering'));
        expect(title.style!.fontSize, 16);
        expect(title.style!.height, 24 / 16);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }
}
