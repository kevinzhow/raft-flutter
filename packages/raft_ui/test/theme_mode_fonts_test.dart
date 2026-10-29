@Tags(['look-brutal', 'look-elegant'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  test('Brutal dark resolves the complete Elegant dark font family set', () {
    final elegant = RaftTokens.theme(
      pack: packForThemeId(elegantThemePackId),
      dark: true,
    );
    final brutal = RaftTokens.theme(
      pack: packForThemeId(brutalThemePackId),
      dark: true,
    );
    expect(brutal.headingFont, elegant.headingFont);
    expect(brutal.bodyFont, elegant.bodyFont);
    expect(brutal.monoFont, elegant.monoFont);
    expect(brutal.fontFallback, elegant.fontFallback);
    expect(brutal.metrics.headingFontStack, elegant.metrics.headingFontStack);
    expect(brutal.metrics.sansFontStack, elegant.metrics.sansFontStack);
    expect(brutal.metrics.monoFontStack, elegant.metrics.monoFontStack);
  });

  test('explicit system fonts remain ahead of mode fonts', () {
    for (final id in [raftThemePackId, elegantThemePackId, brutalThemePackId]) {
      for (final dark in [false, true]) {
        final t = RaftTokens.theme(
          pack: packForThemeId(id),
          dark: dark,
          systemFonts: true,
          systemFontFamilies: const RaftFontFamilies(
            body: 'User Body',
            heading: 'User Heading',
            mono: 'User Mono',
            fallback: ['User CJK'],
          ),
        );
        expect(t.headingFont, 'User Heading');
        expect(t.bodyFont, 'User Body');
        expect(t.monoFont, 'User Mono');
        final native = id == raftThemePackId;
        final brutalLight = id == brutalThemePackId && !dark;
        expect(
          t.fontFamily('font.messageTime'),
          native || brutalLight ? 'User Mono' : 'User Body',
        );
        expect(
          t.fontFamily('font.messageSubtitle'),
          brutalLight ? 'User Mono' : 'User Body',
        );
        expect(t.fontFamilyFallback('font.messageTime'), ['User CJK']);
        expect(t.fontFamilyFallback('font.messageSubtitle'), ['User CJK']);
      }
    }
  });

  testWidgets('the first Brutal dark frame uses Elegant typography', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(brutalThemePackId), dark: true),
        home: const Scaffold(body: Text('First frame')),
      ),
    );
    final text = tester.widget<Text>(find.text('First frame'));
    final style = DefaultTextStyle.of(tester.element(find.text('First frame')))
        .style
        .merge(text.style);
    expect(style.fontFamily, 'packages/raft_ui/Geist');
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .textTheme
          .titleLarge!
          .fontFamily,
      'packages/raft_ui/Inter',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
