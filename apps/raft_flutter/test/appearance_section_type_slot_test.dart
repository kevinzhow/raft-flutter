import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/appearance_section.dart';
import 'package:raft_ui/raft_ui.dart';

/// Appearance cards: the Raft look reads the `subhead` / `footnote` / `caption`
/// slots of the pack (Web v1.21.23 AppearanceSection: `text-subhead
/// font-semibold`, `text-footnote`, `text-caption`), so a user pack moves them;
/// the pre-theme looks keep a57b9dab's 14 / 12 / 11 hierarchy
/// (`appearance.layout`).
void main() {
  Future<RaftAppearanceSectionRecipe> mount(
    WidgetTester t,
    RaftThemePack pack,
  ) async {
    late RaftTokens tokens;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: pack),
        home: Builder(
          builder: (context) {
            tokens = RaftTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    return RaftAppearanceSectionRecipe(tokens);
  }

  testWidgets('Raft draws the slots, a user pack moves them', (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    var r = await mount(t, packForThemeId(raftThemePackId));
    expect(
      [r.heading.fontSize, r.description.fontSize, r.annotation.fontSize],
      [15, 13, 12],
    );
    r = await mount(
      t,
      RaftThemePack.parse(
        jsonEncode({
          'format': 'raft-theme/1',
          'id': 'user:appearance-fixture',
          'name': 'Appearance fixture',
          'version': '1.0.0',
          'extends': 'raft',
          'modes': {
            'light': {
              'type': {
                'subhead': [21, 27, 400, 0],
                'footnote': [19, 25, 400, 0],
                'caption': [17, 23, 500, 0],
              },
            },
            'dark': <String, Object?>{},
          },
        }),
      ),
    );
    expect(
      [r.heading.fontSize, r.description.fontSize, r.annotation.fontSize],
      [21, 19, 17],
    );
    expect(r.heading.height! * r.heading.fontSize!, closeTo(27, .001));
    // Web `Preview`: text-footnote font-bold, from the footnote slot.
    expect(
      [r.previewLabel.fontSize, r.previewLabel.fontWeight],
      [19, FontWeight.w700],
    );
  });

  for (final id in [elegantThemePackId, brutalThemePackId]) {
    testWidgets('$id keeps the a57b9dab 14 / 12 / 11 hierarchy', (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      final r = await mount(t, packForThemeId(id));
      expect(
        [r.heading.fontSize, r.description.fontSize, r.annotation.fontSize],
        [14, 12, 11],
      );
    });
  }
}
