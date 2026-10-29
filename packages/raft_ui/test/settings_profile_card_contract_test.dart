import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (id, extent, radius, titleSize, titleLine, metaSize, metaLine)
      in raftThemeMatrix([
        // Web v1.21.23 SettingsProfileCard uses text-mono-code: 13px/20px.
        (raftThemePackId, 51.0, 10.0, 17.0, 22.0, 13.0, 20.0),
        (elegantThemePackId, 64.0, 0.0, 18.0, 22.5, 14.0, 20.0),
        (brutalThemePackId, 64.0, 0.0, 18.0, 22.5, 14.0, 20.0),
      ], look: (v) => raftLookOf(v.$1))) {
    testWidgets(
      '$id settings identity keeps the tile centered and source typography',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id)),
            home: const Scaffold(
              body: RaftSettingsProfileCard(
                title: 'artin',
                subtitle: '@artin',
                avatar: RaftAvatarSlot(
                  name: 'artin',
                  agent: false,
                  slot: RaftAvatarSlotContext.profileTile,
                ),
                child: Text('Fields stay owned by their form'),
              ),
            ),
          ),
        );
        final avatar = t.getRect(find.byType(RaftAvatarSlot));
        expect(avatar.size, Size.square(extent));
        // Web SettingsProfileCard keeps a 64px cell around the smaller 51px tile.
        expect(avatar.left, 17 + (64 - extent) / 2);
        final context = t.element(find.byType(RaftSettingsProfileCard));
        final tokens = RaftTokens.of(context);
        expect(
          RaftSettingsCard.decoration(tokens).borderRadius ?? BorderRadius.zero,
          BorderRadius.circular(radius),
        );
        final title = t.widget<Text>(find.text('artin')).style!;
        final meta = t.widget<Text>(find.text('@artin')).style!;
        expect(title.fontSize, titleSize);
        expect(title.height! * titleSize, titleLine);
        expect(meta.fontSize, metaSize);
        expect(meta.height! * metaSize, metaLine);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
