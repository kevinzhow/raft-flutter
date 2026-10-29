import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

/// Settings sidebar rows (Web SettingsSidebarList: raft-ui SidebarItem
/// `text-subhead font-medium`, `data-active:font-bold`): the weights come from
/// the existing `type.sidebarItem.weight` / `type.sidebarItemActive.weight`
/// (Raft 500 / 700); size and line from `type.settingsSidebarItem.*` when the
/// pack sets them, else the a57b9dab recipe (Elegant 13, Brutal 14).
Widget _host(RaftTokens tokens) => MaterialApp(
  theme: raftTheme().copyWith(extensions: [tokens]),
  home: Scaffold(
    body: RaftSettingsSidebarList(
      activeId: 'a',
      groups: [
        RaftSettingsNavGroup('Personal', [
          RaftSettingsNavEntry(
            id: 'a',
            label: 'Account',
            glyph: RaftGlyph.user,
            onTap: () {},
          ),
          RaftSettingsNavEntry(
            id: 'b',
            label: 'Appearance',
            glyph: RaftGlyph.user,
            onTap: () {},
          ),
        ]),
      ],
    ),
  ),
);

TextStyle _style(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets('Raft: 700 for the active row, 500 for the others', (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      _host(RaftTokens.theme(pack: packForThemeId(raftThemePackId))),
    );
    expect(_style(t, 'Account').fontWeight, FontWeight.w700);
    expect(_style(t, 'Appearance').fontWeight, FontWeight.w500);
  });

  testWidgets(
    'settingsSidebarItem and settingsGroupLabel tokens move the rows',
    (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      final base = RaftTokens.theme(pack: packForThemeId(raftThemePackId));
      final tokens = RaftTokens(
        false,
        base.colors,
        tokens: RaftTokenSet.of(raftThemeId(dark: false)),
        mode: RaftModeValues(
          geometry: {
            'type.settingsSidebarItem.size': 15,
            'type.settingsSidebarItem.line': 20,
            'type.settingsGroupLabel.size': 13,
            'type.settingsGroupLabel.line': 18,
          },
        ),
      );
      await t.pumpWidget(_host(tokens));
      expect(_style(t, 'Account').fontSize, 15);
      expect(_style(t, 'Account').height! * 15, closeTo(20, .001));
      expect(_style(t, 'Personal').fontSize, 13);
    },
  );

  testWidgets('without the tokens the a57b9dab recipe sizes stay', (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      _host(RaftTokens.theme(pack: packForThemeId(elegantThemePackId))),
    );
    expect(_style(t, 'Account').fontSize, 13);
    expect(_style(t, 'Personal').fontSize, 10);
    await t.pumpWidget(
      _host(RaftTokens.theme(pack: packForThemeId(brutalThemePackId))),
    );
    await t.pump(const Duration(seconds: 1));
    expect(_style(t, 'Account').fontSize, 14);
  });
}
