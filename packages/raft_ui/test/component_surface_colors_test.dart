import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Iterable<Color?> _fills(WidgetTester t, Finder scope) sync* {
  for (final box in t.widgetList<DecoratedBox>(
    find.descendant(of: scope, matching: find.byType(DecoratedBox)),
  )) {
    if (box.decoration case BoxDecoration(:final color)) yield color;
    if (box.decoration case RaftLayeredDecoration(:final base)) yield base.color;
  }
  for (final box in t.widgetList<ColoredBox>(
    find.descendant(of: scope, matching: find.byType(ColoredBox)),
  )) {
    yield box.color;
  }
}

Widget _surfaces(RaftThemePack pack, bool dark) => MaterialApp(
  theme: raftTheme(pack: pack, dark: dark, platform: TargetPlatform.linux),
  home: Scaffold(
    body: Column(
      children: [
        Expanded(
          child: RaftOverflowSheet(
            title: 'Drawer heading',
            onClose: () {},
            children: const [],
          ),
        ),
        Expanded(
          child: RaftDialogCard(
            title: 'Dialog',
            onClose: () {},
            child: const Text('Body'),
          ),
        ),
      ],
    ),
  ),
);

void main() {
  // a57 drawer header/body and Card recipe paints; Brutal dark is Elegant.
  // Raft uses Web v1.21.23 Drawer popup and DialogSurface popover layers.
  for (final (id, dark, body, header, dialog) in raftThemeMatrix([
    (raftThemePackId, false, 0xffffffff, 0xffffffff, 0xffffffff),
    (raftThemePackId, true, 0xff292927, 0xff292927, 0xff292927),
    (elegantThemePackId, false, 0xffffffff, 0xffffffff, 0xffffffff),
    (elegantThemePackId, true, 0xff242422, 0xff242422, 0xff242422),
    (brutalThemePackId, false, 0xfffffaef, 0xffffd440, 0xffffffff),
    (brutalThemePackId, true, 0xff242422, 0xff242422, 0xff242422),
  ], look: (row) => raftLookOf(row.$1))) {
    testWidgets('$id dark=$dark drawer and dialog keep source surfaces', (
      t,
    ) async {
      await t.pumpWidget(_surfaces(packForThemeId(id), dark));
      final sheet = find.byKey(const ValueKey('channel-overflow-sheet'));
      final material = t.widget<Material>(
        find.descendant(of: sheet, matching: find.byType(Material)).first,
      );
      expect(material.color, Color(body));
      expect(
        _fills(t, find.byType(RaftOverflowSheet)),
        contains(Color(header)),
      );
      expect(_fills(t, find.byType(RaftDialogCard)), contains(Color(dialog)));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a live user pack changes surface roles independently', (
    t,
  ) async {
    RaftThemePack pack(String drawer, String header, String dialog) =>
        RaftThemePack.parse(
          jsonEncode({
            'format': raftThemePackFormat,
            'id': 'user:surface-colors',
            'name': {'en': 'Surface colors'},
            'version': '1.0.0',
            'extends': 'raft',
            'modes': {
              for (final mode in ['light', 'dark'])
                mode: {
                  'colors': {
                    'layer-drawer': drawer,
                    'layer-drawer-header': header,
                    'layer-dialog': dialog,
                  },
                },
            },
          }),
        );
    for (final dark in [false, true]) {
      for (final (drawer, header, dialog) in [
        (0xff102030, 0xff304050, 0xff506070),
        (0xff203040, 0xff405060, 0xff607080),
      ]) {
        String hex(int color) => '#${color.toRadixString(16).substring(2)}';
        final custom = pack(hex(drawer), hex(header), hex(dialog));
        expect(custom.warnings, isEmpty);
        await t.pumpWidget(_surfaces(custom, dark));
        await t.pumpAndSettle();
        final sheet = find.byKey(const ValueKey('channel-overflow-sheet'));
        expect(
          t
              .widget<Material>(
                find
                    .descendant(of: sheet, matching: find.byType(Material))
                    .first,
              )
              .color,
          Color(drawer),
        );
        expect(
          _fills(t, find.byType(RaftOverflowSheet)),
          contains(Color(header)),
        );
        expect(_fills(t, find.byType(RaftDialogCard)), contains(Color(dialog)));
      }
    }
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('custom content roles reach mounted bodies dark=$dark', (
      t,
    ) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      final custom = RaftThemePack.parse(
        jsonEncode({
          'format': raftThemePackFormat,
          'id': 'user:content-surfaces',
          'name': {'en': 'Content surfaces'},
          'version': '1.0.0',
          'extends': 'raft',
          'modes': {
            for (final mode in ['light', 'dark'])
              mode: {
                'colors': {
                  'layer-conversation-content': '#123456',
                  'layer-profile-content': '#654321',
                },
              },
          },
        }),
      );
      expect(custom.warnings, isEmpty);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: custom, dark: dark),
          home: Scaffold(
            body: Column(
              children: [
                const RaftConversationSurface(
                  role: RaftConversationSurfaceRole.threadTimeline,
                  child: SizedBox(height: 20, width: 100),
                ),
                const RaftPublicConversationSurface(
                  child: SizedBox(height: 20, width: 100),
                ),
                RaftThreadSearchBar(
                  controller: controller,
                  focusNode: focus,
                  countLabel: '',
                  canStep: false,
                  onChanged: (_) {},
                  onStep: (_) {},
                  onClose: () {},
                ),
                const Expanded(
                  child: RaftExternalIdentityBody(
                    name: 'Author',
                    subtitle: 'External',
                    projectionLabel: 'Source',
                    avatar: SizedBox(width: 32, height: 32),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (final type in [
        RaftConversationSurface,
        RaftPublicConversationSurface,
        RaftThreadSearchBar,
      ]) {
        expect(_fills(t, find.byType(type)), contains(const Color(0xff123456)));
      }
      expect(
        _fills(t, find.byType(RaftExternalIdentityBody)),
        contains(const Color(0xff654321)),
      );
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  }
}
