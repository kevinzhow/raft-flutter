import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final appearance in raftThemeMatrix([
    const RaftAppearance(),
    const RaftAppearance(mode: ThemeMode.dark),
  ])) {
    testWidgets(
      'system message is compact, centered and one-line ${appearance.mode}',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            darkTheme: raftTheme(dark: true),
            themeMode: appearance.mode,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: RaftSystemMessage(
                    content: 'Public system event ${'long text ' * 40}',
                    timestamp: '12:34',
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(RaftAvatar), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        expect(find.byType(FilterChip), findsNothing);
        final title = t.widget<Text>(
          find.textContaining('Public system event'),
        );
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
        expect(title.style!.fontSize, 12);
        final clock = t.widget<Text>(find.text('12:34'));
        expect(clock.style!.fontSize, 11);
        // Web v1.21.12 (raft-ui 0.5.52): the note owns a `pt-[3px]` (brutal
        // `pt-0`) lead-in and no bottom padding; the next row completes the
        // seam (`data-follows-system`). 0.5.27 had py-1.5 plus mb-1.
        expect(t.getSize(find.byType(RaftSystemMessage)).height, 21);
        expect(t.takeException(), isNull);
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: RaftSystemMessage(
                  content: 'Short event',
                  timestamp: '12:34',
                ),
              ),
            ),
          ),
        );
        final a = t.getRect(find.text('12:34')),
            b = t.getRect(find.text('Short event'));
        expect((a.left + b.right) / 2, closeTo(160, .1));
      },
    );
  }
}
