import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final appearance in [
    const RaftAppearance(light: RaftFamily.brutal),
    const RaftAppearance(light: RaftFamily.elegant),
    const RaftAppearance(light: RaftFamily.elegant, mode: ThemeMode.dark),
  ]) {
    testWidgets(
      'system message is compact, centered and one-line ${appearance.light} ${appearance.mode}',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(appearance.light),
            darkTheme: raftTheme(appearance.light, dark: true),
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
        expect(
          clock.style!.fontSize,
          appearance.light == RaftFamily.brutal ? 12 : 11,
        );
        expect(
          t.getSize(find.byType(RaftSystemMessage)).height,
          appearance.light == RaftFamily.brutal ? 32 : 34,
        );
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
