import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('self mention uses the existing brand fill dark=$dark', (
      t,
    ) async {
      final theme = raftTheme(dark: dark);
      final tokens = theme.extension<RaftTokens>()!;
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RaftReferenceChip(
                label: '@artin',
                fontSize: 16,
                appearance: RaftReferenceAppearance(
                  RaftReferenceKind.selfMention,
                ),
              ),
            ),
          ),
        ),
      );
      final box = t.widget<RaftCssBox>(find.byType(RaftCssBox));
      expect(box.fill, tokens.colors['brand-400']);
      expect(box.fill, isNotNull);
      expect(box.insetRingWidth, greaterThan(0));
      expect(
        t.getSize(find.byType(RaftReferenceChip)).height,
        closeTo(19.2, .001),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('source reference chip geometry and activation dark=$dark', (
      t,
    ) async {
      var taps = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => Align(
                alignment: Alignment.topLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      raftReferenceSpan(
                        context,
                        label: '#design',
                        href: 'raft-ref://channel/design',
                        base: const TextStyle(fontSize: 16),
                        appearance: const RaftReferenceAppearance(
                          RaftReferenceKind.channel,
                        ),
                        onTap: () => taps++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final text = t.widget<Text>(find.text('#design'));
      expect(text.style!.fontSize, 14); // 0.875em of the 16px message.
      expect(text.style!.height! * text.style!.fontSize!, 20);
      expect(t.getSize(find.byType(RaftReferenceChip)).height, 22);
      final semantics = t.ensureSemantics();
      expect(find.bySemanticsLabel('#design'), findsOneWidget);
      await t.tap(find.text('#design'));
      expect(taps, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 2);
      semantics.dispose();
    });
    testWidgets('source chip grows with large CJK text dark=$dark', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.1)),
            child: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RaftReferenceChip(
                  label: '#中文频道',
                  fontSize: 18,
                  appearance: RaftReferenceAppearance(
                    RaftReferenceKind.channel,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        t.getSize(find.byType(RaftReferenceChip)).height,
        greaterThanOrEqualTo(62),
      );
      expect(t.takeException(), isNull);
    });
  }
}
