import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_content_tokens.dart';
import 'package:raft_ui/src/panel_layout.dart' show raftCssBaseline;

/// Web MarkdownContent / raft-ui InlineCode appearance="message" colours,
/// checked against the official React captures (visual parity cases
/// components.thread.message-row.*).
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('message markdown inline code and link colours $family/$dark', (
      t,
    ) async {
      late MarkdownStyleSheetLike sheet;
      final theme = raftTheme(family, dark: dark);
      final tokens = theme.extension<RaftTokens>()!;
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              final s = MessageContentRecipe(
                tokens,
                mountedMessage: true,
              ).stylesheet(context);
              sheet = (code: s.code!, link: s.a!);
              return const SizedBox();
            },
          ),
        ),
      );
      if (family == RaftFamily.brutal) {
        // `bg-black/5 text-black`: #f2f2f2 on white, pure black ink.
        expect(sheet.code.color, const Color(0xff000000));
        expect(
          Color.alphaBlend(sheet.code.backgroundColor!, Colors.white),
          isSameColorAs(const Color(0xfff2f2f2)),
        );
      } else {
        // `bg-fill-muted text-foreground-strong`.
        expect(sheet.code.color, tokens.strong);
        expect(sheet.code.backgroundColor, tokens.colors['fill-muted']);
      }
      // Tailwind 4 `text-blue-700` / `dark:text-blue-300`.
      expect(
        sheet.link.color,
        dark ? const Color(0xff8ec5ff) : const Color(0xff1447e6),
      );
    });
  }

  testWidgets('reference chip label sits on the Blink line-box baseline', (
    t,
  ) async {
    final theme = raftTheme(RaftFamily.brutal);
    final tokens = theme.extension<RaftTokens>()!;
    // Real face metrics: the test font's whole-pixel ascent would hide the
    // rounding difference.
    await t.runAsync(() async {
      ByteData data;
      try {
        data = await rootBundle.load(
          'packages/raft_ui/assets/fonts/HankenGrotesk.ttf',
        );
      } on FlutterError {
        data = await rootBundle.load('assets/fonts/HankenGrotesk.ttf');
      }
      await (FontLoader(tokens.bodyFont)..addFont(Future.value(data))).load();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RaftReferenceChip(
              fontFamily: tokens.bodyFont,
              label: '#607',
              appearance: const RaftReferenceAppearance(
                RaftReferenceKind.task,
                taskStatus: RaftMessageTaskStatus.inProgress,
              ),
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
    final label = find.text('#607');
    final text = t.widget<Text>(label);
    final paragraph = t.renderObject<RenderParagraph>(label);
    final lineBox = t.renderObject<RenderBox>(
      find.ancestor(of: label, matching: find.byType(SizedBox)).first,
    );
    final top =
        paragraph.localToGlobal(Offset.zero).dy -
        lineBox.localToGlobal(Offset.zero).dy;
    final painter = TextPainter(
      text: TextSpan(text: '#607', style: text.style),
      strutStyle: text.strutStyle,
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);
    final baseline =
        top + painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    expect(baseline, moreOrLessEquals(raftCssBaseline(text.style!)));
    expect(lineBox.size.height, moreOrLessEquals(15 * text.style!.height!));
  });
}

typedef MarkdownStyleSheetLike = ({TextStyle code, TextStyle link});
