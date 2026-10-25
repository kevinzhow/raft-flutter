import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

/// Settings surfaces (Web v1.21.23 SettingsPanel.tsx): the Card is
/// `bg-layer-card` and the content div `bg-layer-canvas`. A pack states that
/// with `layer-settings-card` / `layer-settings-content` and the separate
/// `layer-settings-feedback-content` context; without the roles
/// the a57b9dab surfaces stay (card = layer-panel, content = layer-panel, or
/// layer-card in the dark Feedback tab).
void main() {
  RaftTokens tokens(RaftThemePack pack, {bool dark = false}) =>
      RaftTokens.theme(pack: pack, dark: dark);

  test('legacy ordinary and Feedback content keep different dark surfaces', () {
    for (final id in [elegantThemePackId, brutalThemePackId]) {
      final t = tokens(packForThemeId(id), dark: true);
      expect(RaftSettingsCard.decoration(t).color, t.panel);
      // a57b9dab settings_layout.dart:410 uses panel for ordinary content;
      // only feedbackSurface at :351 switches to card in dark mode.
      const frame = RaftSettingsPanelFrame(header: null, child: SizedBox());
      expect(frame.contentSurfaceOf(t), t.panel);
      expect(RaftSettingsPanelFrame.feedbackSurface(t), t.colors['layer-card']);
    }
  });

  test('the roles move the card and the content surface', () {
    final base = tokens(packForThemeId(raftThemePackId), dark: true);
    final t = RaftTokens(
      true,
      {
        ...base.colors,
        'layer-settings-card': base.colors['layer-card']!,
        'layer-settings-content': const Color(0xff123456),
        'layer-settings-feedback-content': const Color(0xff654321),
      },
      tokens: RaftTokenSet.of(raftThemeId(dark: true)),
      mode: RaftModeValues(),
    );
    expect(RaftSettingsCard.decoration(t).color, const Color(0xff242422));
    const frame = RaftSettingsPanelFrame(header: null, child: SizedBox());
    expect(frame.contentSurfaceOf(t), const Color(0xff123456));
    expect(RaftSettingsPanelFrame.feedbackSurface(t), const Color(0xff654321));
  });

  testWidgets('a user pack repaints both mounted settings content surfaces', (
    tester,
  ) async {
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': raftThemePackFormat,
        'id': 'user:settings-surfaces',
        'name': {'en': 'Settings surfaces'},
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          for (final mode in ['light', 'dark'])
            mode: {
              'colors': {
                'layer-settings-content': '#123456',
                'layer-settings-feedback-content': '#654321',
              },
            },
        },
      }),
    );
    expect(pack.warnings, isEmpty);
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack, dark: dark),
          home: Builder(
            builder: (context) => Column(
              children: [
                for (final feedback in [false, true])
                  Expanded(
                    child: RaftSettingsPanelFrame(
                      key: ValueKey(feedback),
                      header: null,
                      contentColor: feedback
                          ? RaftSettingsPanelFrame.feedbackSurface(
                              RaftTokens.of(context),
                            )
                          : null,
                      child: const SizedBox(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final (feedback, color) in [
        (false, const Color(0xff123456)),
        (true, const Color(0xff654321)),
      ]) {
        final paints = tester.widgetList<Material>(
          find.descendant(
            of: find.byKey(ValueKey(feedback)),
            matching: find.byType(Material),
          ),
        );
        expect(paints.last.color, color);
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
