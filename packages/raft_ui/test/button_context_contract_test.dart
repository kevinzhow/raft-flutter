import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets(
        'button physical override preserves axis and font preference $id/$dark',
        (t) async {
          addTearDown(() => t.pumpWidget(const SizedBox()));
          for (final axis in [
            RaftButtonSize.xs,
            RaftButtonSize.sm,
            RaftButtonSize.md,
            RaftButtonSize.lg,
            RaftButtonSize.inline,
          ]) {
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(
                  pack: packForThemeId(id),
                  dark: dark,
                  systemFonts: true,
                  systemFontFamilies: const RaftFontFamilies(
                    body: 'User Body',
                    heading: 'User Heading',
                    mono: 'User Mono',
                    fallback: ['User CJK'],
                  ),
                ),
                home: Scaffold(
                  body: Center(
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 19, height: 2),
                      child: RaftButton(
                        label: 'Continue',
                        uiSize: axis,
                        physicalHeight: 60,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            final label = find.text('Continue');
            final style = DefaultTextStyle.of(t.element(label)).style;
            final tokens = RaftTokens.of(t.element(label));
            final native = id == raftThemePackId;
            expect(style.fontFamily, 'User Body');
            expect(style.fontFamilyFallback, ['User CJK']);
            expect(
              style.fontSize,
              axis == RaftButtonSize.inline
                  ? 19
                  : tokens.size('type.button.${axis.name}.size', fallback: -1),
            );
            if (axis == RaftButtonSize.inline ||
                (axis == RaftButtonSize.xs && !native)) {
              expect(
                style.height,
                2,
                reason: 'Ambient line survives fixed physical height.',
              );
            }
            // Inline ignores the physical override just like CSS h-auto.
            expect(
              t.getSize(find.byType(RaftButton)).height,
              axis == RaftButtonSize.inline ? 38 : 60,
            );
            expect(t.takeException(), isNull);
          }
        },
      );
    }
  }
}
