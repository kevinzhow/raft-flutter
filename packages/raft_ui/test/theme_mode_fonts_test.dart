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
