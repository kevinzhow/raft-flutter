import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('unanchored comments retain selection and have no jump button', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 420,
            child: RaftAttachmentCommentsPanel(
              filename: 'public.txt',
              comments: const [
                RaftAttachmentCommentView(
                  id: 'plain',
                  senderName: 'Public Human',
                  content: 'Unanchored body',
                  timestamp: '10:30',
                ),
              ],
              composer: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(RaftMessageBody),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
    expect(find.byType(RaftInteractive), findsNothing);
    expect(t.takeException(), isNull);
  });
  for (final (family, dark) in const [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family dark=$dark comments own jump, pending anchor, write gate and loading recipe',
      (t) async {
        var jumps = 0, removes = 0;
        Widget host({bool loading = false, bool blocked = false}) =>
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: SizedBox(
                  width: 390,
                  height: 420,
                  child: RaftAttachmentCommentsPanel(
                    filename: 'public.txt',
                    comments: loading
                        ? null
                        : [
                            RaftAttachmentCommentView(
                              id: 'public',
                              senderName: 'Public Human',
                              content: 'Public comment',
                              timestamp: '10:30',
                              anchorLabel: 'L2–4',
                              onJump: () => ++jumps,
                            ),
                          ],
                    blockedMessage: blocked ? 'Channel archived' : null,
                    composer: RaftComposer(
                      variant: RaftComposerVariant.compact,
                      accessoryRow: RaftCommentAnchorChip(
                        label: 'L2–4',
                        removeLabel: 'Remove anchor',
                        onRemove: () => ++removes,
                      ),
                      onSend: (_) async => true,
                    ),
                  ),
                ),
              ),
            );
        await t.pumpWidget(host());
        await t.tap(find.text('Public Human'));
        expect(jumps, 1);
        // Source's entire card is a button, including its Markdown body.
        await t.tap(find.text('Public comment', findRichText: true));
        expect(jumps, 2);
        expect(
          find.descendant(
            of: find.byType(RaftMessageBody),
            matching: find.byType(SelectionArea),
          ),
          findsNothing,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(jumps, 3);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        expect(jumps, 4);
        await t.drag(
          find.text('Public comment', findRichText: true),
          const Offset(0, -40),
        );
        expect(
          jumps,
          4,
          reason: 'Scrolling the comment list is not an anchor jump',
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(removes, 1);
        await t.tap(find.bySemanticsLabel('Remove anchor'));
        expect(removes, 2);
        await t.pumpWidget(host(blocked: true));
        expect(find.byType(RaftComposer), findsNothing);
        expect(find.text('Channel archived'), findsOneWidget);
        await t.pumpWidget(host(loading: true));
        expect(find.byType(RaftSpinner), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
