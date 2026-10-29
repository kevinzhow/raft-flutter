import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (id, hero, tile, header) in raftThemeMatrix([
    (raftThemePackId, 99.0, 51.0, 35.0),
    (elegantThemePackId, 64.0, 64.0, 36.0),
    (brutalThemePackId, 64.0, 64.0, 36.0),
  ], look: (v) => raftLookOf(v.$1))) {
    testWidgets(
      '$id profile identity keeps the hero separate from account tile',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id)),
            home: const Scaffold(
              body: RaftProfileIdentity(
                name: 'artin',
                handle: '@artin',
                agent: false,
              ),
            ),
          ),
        );
        // Web v1.21.23 AvatarSlot(profile-hero) is 99x99. a57 uses 64x64.
        expect(tester.getSize(find.byType(RaftAvatarSlot)), Size.square(hero));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('$id account tile and header read their separate dimensions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(id)),
          home: const Scaffold(
            body: Column(
              children: [
                RaftAvatarSlot(
                  key: Key('tile'),
                  name: 'artin',
                  agent: false,
                  slot: RaftAvatarSlotContext.profileTile,
                ),
                RaftAvatarSlot(
                  key: Key('header'),
                  name: 'artin',
                  agent: false,
                  slot: RaftAvatarSlotContext.panelHeader,
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('tile'))), Size.square(tile));
      expect(
        tester.getSize(find.byKey(const Key('header'))),
        Size.square(header),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final (width, platform, left, actionExtent) in [
    (390.0, TargetPlatform.linux, 100.0, 44.0),
    (856.0, TargetPlatform.android, 113.0, 32.0),
  ]) {
    testWidgets(
      '$width $platform profile header keeps Web identity and reachable actions',
      (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var back = 0, close = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: Scaffold(
              body: Column(
                children: [
                  RaftPanelHeaderBar(
                    title: 'artin',
                    subtitle: '@artin',
                    profileHandle: true,
                    onBack: () => back++,
                    backTooltip: 'Back to members',
                    iconAlwaysVisible: true,
                    iconSlot: const RaftAvatarSlot(
                      name: 'artin',
                      agent: false,
                      slot: RaftAvatarSlotContext.panelHeader,
                    ),
                    actions: [
                      RaftPanelAction(
                        glyph: RaftGlyph.x,
                        tooltip: 'Close profile',
                        onPressed: () => close++,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        // Web v1.21.23: 56px shell, leading ghost (44/32), gap (8/12),
        // identity outer 37 (35 avatar + transparent used edge), then gap.
        expect(t.getSize(find.byType(RaftPanelHeaderBar)).height, 56);
        expect(t.getTopLeft(find.text('artin')).dx, left);
        final title = t.getRect(find.text('artin'));
        final meta = t.getRect(find.text('@artin'));
        expect(title.height, 22);
        expect(meta.height, 16);
        expect(meta.top, title.bottom);
        expect(t.getSize(find.byType(RaftAvatarSlot)), const Size.square(35));
        expect(
          t.getSize(find.byType(RaftPanelAction).first),
          Size.square(actionExtent),
        );
        await t.tap(find.bySemanticsLabel('Back to members'));
        await t.tap(find.bySemanticsLabel('Close profile'));
        expect([back, close], [1, 1]);
        if (platform == TargetPlatform.android) {
          // Wide touch layout: keep the Web's 32px visual while the shared
          // interactive target still accepts a tap inside Android's 48px area.
          final rect = t.getRect(find.byType(RaftPanelAction).first);
          await t.tapAt(Offset(rect.center.dx, rect.bottom + 4));
          expect(back, 2);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
