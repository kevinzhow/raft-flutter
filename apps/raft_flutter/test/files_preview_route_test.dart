import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/features/source_channel_files_actions.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'support/close_support.dart';

// The Files panel opens a document preview the way the chat does: the native
// page (back button, swipe back) on a compact window, the full-bleed dialog on
// a wide one. The dialog form on a phone left a strip of the dimmed page under
// the comments bar and a different header than the chat's.
SourceChannelFileEntry _file(String name, String mime) =>
    SourceChannelFileEntry(
      {'id': 'f1', 'filename': name, 'mimeType': mime, 'sizeBytes': 1024},
      'm1',
      'c1',
      'c1',
      null,
      'channel',
      '2026-06-22T00:00:00Z',
    );

void main() {
  leakDebt(const ['ValueNotifier<Map<String, dynamic>?>']);
  for (final (size, page) in [
    (const Size(390, 844), true),
    (const Size(1280, 800), false),
  ]) {
    for (final (name, mime, html) in [
      ('review.md', 'text/markdown', false),
      ('report.html', 'text/html', true),
    ]) {
      testWidgets('Files panel ${size.width.toInt()}dp opens $name as the '
          '${page ? 'page' : 'dialog'} route', (t) async {
        final (w, api) = await mountWorkspace(t, size);
        // The preview opens before its content arrives.
        api.hangAll = true;
        final context = t.element(find.byType(WorkspaceView));
        final actions = SourceChannelFilesActions(
          controller: w,
          authorized: (_) => true,
          context: () => context,
        );
        addTearDown(actions.dispose);
        unawaited(actions.preview(_file(name, mime)));
        await frames(t, 6);
        final previewType = html
            ? find.byType(HtmlAttachmentPreviewDialog)
            : find.byType(AttachmentPreviewDialog);
        expect(previewType, findsOneWidget);
        final route = ModalRoute.of(t.element(previewType))!;
        expect(
          route,
          page
              ? isA<RaftPreviewPageRoute<void>>()
              : isA<RaftFullBleedDialogRoute<void>>(),
        );
        // The page wears the phone page header with the back button.
        expect(
          t
              .widget<RaftAttachmentPreviewShell>(
                find.byType(RaftAttachmentPreviewShell),
              )
              .page,
          page,
        );
        expect(
          find.byType(RaftPanelHeaderBar),
          page ? findsWidgets : findsNothing,
        );
        Navigator.of(context, rootNavigator: true).pop();
        await frames(t, 20);
        expect(previewType, findsNothing);
        api.hangAll = false;
      });
    }
  }
}
