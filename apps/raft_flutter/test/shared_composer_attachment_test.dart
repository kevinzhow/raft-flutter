import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/shared_draft_attachment.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/composer_attachments_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'queued shared file remains sendable in new composer ${dark ? 'dark' : 'light'}',
      (tester) async {
        final shared = UploadDraft.shared(
          SharedDraftAttachment(
            reference: const {'token': 'fixture', 'file': 'photo'},
            filename: 'photo.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 3,
            openRead: () => Stream.value([1, 2, 3]),
            release: () async {},
          ),
          key: 0,
        );
        final uploading = UploadDraft('file.txt', Uint8List(3), key: 1);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Builder(
              builder: (context) {
                final item = composerAttachmentFor(context, shared);
                expect(item.status, RaftComposerAttachmentStatus.ready);
                expect(item.preview, isNull);
                expect(composerSendBlockTitle(context, [shared]), isNull);
                expect(composerSendBlockNotice(context, [shared]), isNull);
                expect(
                  composerSendBlockTitle(context, [shared, uploading]),
                  isNotNull,
                );
                return Scaffold(
                  body: RaftComposerAttachments(
                    items: [item],
                    onRemove: (_) {},
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('photo.jpg'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
