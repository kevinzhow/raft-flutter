import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final component in ['authSubmit', 'channelJoin', 'standaloneContinue']) {
    testWidgets('$component reads independently authored component metrics', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pack = RaftThemePack.parse(
        jsonEncode({
          'format': raftThemePackFormat,
          'id': 'user:component-button-metrics',
          'name': {'en': 'Component button metrics'},
          'version': '1.0.0',
          'extends': 'raft',
          'modes': {
            'light': {
              'geometry': {
                'size.$component': 61,
                'type.$component.size': 18,
                'type.$component.line': 26,
                'space.${component}Inline': 23,
              },
            },
            'dark': {},
          },
        }),
      );
      var presses = 0;
      final child = switch (component) {
        'authSubmit' => RaftAuthSubmit(
          label: 'Sign in',
          onPressed: () => presses++,
        ),
        'channelJoin' => RaftChannelJoinFooter(
          channelName: 'design',
          label: 'Join',
          onJoin: () => presses++,
        ),
        _ => RaftServerAccessDeniedPage(onContinue: () => presses++),
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack),
          home: Scaffold(body: child),
        ),
      );
      await tester.pumpAndSettle();
      final button = component == 'channelJoin'
          ? find.byType(RaftRecipeButton)
          : find.byType(RaftButton);
      expect(tester.getSize(button).height, 61);
      final label = find.descendant(of: button, matching: find.byType(Text));
      final text = tester.widget<Text>(label);
      final style = DefaultTextStyle.of(tester.element(label)).style
          .merge(text.style);
      expect(style.fontSize, 18);
      expect(style.height, 26 / 18);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(presses, 1);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }
}
