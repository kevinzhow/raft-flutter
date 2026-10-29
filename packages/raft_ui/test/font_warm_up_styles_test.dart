import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    test(
      'warm-up styles cover chrome combinations ${dark ? 'dark' : 'light'}',
      () {
        final theme = raftTheme(dark: dark);
        final styles = raftFontWarmUpStyles(theme);
        final t = RaftTokens.theme(dark: dark);
        bool covers(TextStyle wanted) => styles.any(
          (s) =>
              s.fontFamily == wanted.fontFamily &&
              s.fontWeight == wanted.fontWeight &&
              s.fontStyle == wanted.fontStyle &&
              (s.fontVariations ?? const []).toString() ==
                  (wanted.fontVariations ?? const []).toString(),
        );
        // The inline thread replies, the transfer chip and the headings used in
        // the heading family resolve their fonts the first time they scroll in
        // unless the idle warm-up has done it.
        final thread = RaftInlineThreadRecipe(t);
        expect(covers(thread.sender), isTrue);
        expect(covers(thread.preview), isTrue);
        expect(covers(thread.summary), isTrue);
        expect(
          covers(
            RaftTypography.mono(
              t,
              size: 11,
              line: 14,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          isTrue,
        );
        expect(covers(RaftTypography.heading(t, size: 16, line: 22)), isTrue);
      },
    );
  }
}
