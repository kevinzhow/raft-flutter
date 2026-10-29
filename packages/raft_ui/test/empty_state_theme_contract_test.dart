import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('user pack changes empty content without a whole-style fork', (
    tester,
  ) async {
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': raftThemePackFormat,
        'id': 'user:empty-content',
        'name': {'en': 'Empty content'},
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          'light': {
            'colors': {
              'foreground-empty-title': '#123456',
              'foreground-empty-body': '#654321',
            },
            'geometry': {
              'type.emptyTitle.size': 19,
              'type.emptyTitle.line': 26,
              'size.emptyGlyph': 28,
            },
            'font': {'font.emptyTitle': '{fonts.mono}'},
          },
          'dark': {},
        },
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: pack),
        home: const Scaffold(
          body: RaftEmptyState(
            title: 'Empty title',
            detail: 'Empty description',
            glyph: RaftGlyph.search,
          ),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Empty title'));
    final tokens = RaftTokens.of(tester.element(find.text('Empty title')));
    expect(title.style!.fontFamily, tokens.monoFont);
    expect(title.style!.fontSize, 19);
    expect(title.style!.height, 26 / 19);
    expect(title.style!.color, const Color(0xff123456));
    expect(
      tester.widget<Text>(find.text('Empty description')).style!.color,
      const Color(0xff654321),
    );
    final icon = tester.widget<RaftIcon>(find.byType(RaftIcon));
    expect(icon.glyph, RaftGlyph.search); // An explicit caller icon wins.
    expect(icon.size, 28);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
