import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'removing the comment entry retires capture and does not revive a pending section',
    (t) async {
      final enabled = ValueNotifier(true);
      final session = RaftAttachmentCommentState();
      addTearDown(enabled.dispose);
      addTearDown(session.dispose);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.android),
          home: ValueListenableBuilder(
            valueListenable: enabled,
            builder: (context, on, _) => RaftAttachmentPreviewShell(
              filename: 'guide.md',
              onClose: () {},
              commentSession: session,
              commentsOpenInitially: true,
              commentsBuilder: on ? (_, _) => const Text('Comments') : null,
              child: const RaftDocumentPreview(
                data: {
                  'kind': 'markdown',
                  'markdown': '# Heading\n\nSection paragraph.',
                },
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Section paragraph.', findRichText: true));
      await t.pump();
      expect(session.pendingAnchor?['type'], 'md-section');
      enabled.value = false;
      await t.pumpAndSettle();
      expect(session.commentMode, isFalse);
      expect(session.pendingAnchor, isNull);
      await t.tap(find.text('Section paragraph.', findRichText: true));
      await t.pump();
      expect(session.pendingAnchor, isNull);
      enabled.value = true;
      await t.pumpAndSettle();
      expect(session.commentMode, isFalse);
      expect(session.pendingAnchor, isNull);
    },
  );
  testWidgets(
    'the same preview can switch from Markdown back to numbered rows',
    (t) async {
      final session = RaftAttachmentCommentState()..commentMode = true;
      addTearDown(session.dispose);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
      Widget host(Map<String, dynamic> data) => MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftAttachmentCommentScope(
            state: session,
            child: RaftDocumentPreview(data: data),
          ),
        ),
      );
      await t.pumpWidget(
        host({'kind': 'markdown', 'markdown': '# Guide\n\nBody.'}),
      );
      await t.pumpAndSettle();
      expect(
        session.jump({
          'type': 'md-section',
          'data': {'headingId': 'guide'},
        }),
        isTrue,
      );
      await t.pump(const Duration(seconds: 3));
      await t.pumpWidget(
        host({
          'kind': 'csv',
          'headers': ['Name'],
          'rows': [
            ['one'],
            ['two'],
            ['three'],
          ],
        }),
      );
      await t.pumpAndSettle();
      expect(
        session.jump({
          'type': 'csv-rows',
          'data': {'start': 2},
        }),
        isTrue,
      );
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(seconds: 3));
      expect(
        session.jump({
          'type': 'md-section',
          'data': {'headingId': 'guide'},
        }),
        isFalse,
      );
    },
  );
}
