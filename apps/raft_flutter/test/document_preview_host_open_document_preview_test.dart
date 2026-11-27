import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'DocumentPreviewHost and openDocumentPreview explain and download once',
    (tester) async {
      final (workspace, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(workspace.dispose);
      api.routes['GET /attachments/report/preview'] = (_) => {
        'status': 'unsupported',
        'reason': 'too_large',
      };
      var downloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          builder: (_, child) => RaftToastHost(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => RaftButton(
                label: 'Open report',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialog) => AttachmentPreviewDialog(
                    controller: workspace,
                    metadata: const {
                      'id': 'report',
                      'filename': 'report.md',
                      'sizeBytes': AttachmentPreviewFiles.maxBytes + 1,
                    },
                    authorized: () => true,
                    onClose: () => Navigator.of(dialog).pop(),
                    onDownload: () async {
                      downloads++;
                      throw StateError('Download failed');
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open report'));
      await tester.pumpAndSettle();
      expect(downloads, 1);
      expect(find.text('report.md is too large to preview'), findsOneWidget);
      expect(find.text('Downloading the file instead.'), findsOneWidget);
      expect(find.byType(AttachmentPreviewDialog), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('report.md is too large to preview'), findsNothing);
      expect(downloads, 1);

      api.routes['GET /attachments/report/preview'] = (_) => {
        'status': 'ok',
        'data': {'kind': 'text', 'text': 'The report is ready.'},
      };
      await tester.tap(find.text('Open report'));
      await tester.pumpAndSettle();
      expect(find.byType(AttachmentPreviewDialog), findsOneWidget);
      expect(find.text('The report is ready.'), findsOneWidget);
      expect(find.text('Downloading the file instead.'), findsNothing);
      expect(downloads, 1);
    },
  );

  testWidgets('openDocumentPreview downloads silently with previews disabled', (
    tester,
  ) async {
    final (workspace, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(workspace.dispose);
    api.routes['GET /messages/attachment-preview/enabled'] = (_) => {
      'enabled': false,
    };
    api.routes['GET /attachments/report/preview'] = (_) => {
      'status': 'unsupported',
      'reason': 'too_large',
    };
    api.routes['GET /attachments/report/url'] = (_) => {
      'url': 'https://storage.example.invalid/report.md',
    };
    var savePrompts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (_, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: AttachmentView(
            controller: workspace,
            metadata: const {
              'id': 'report',
              'filename': 'report.md',
              'mimeType': 'text/markdown',
              'sizeBytes': AttachmentPreviewFiles.maxBytes + 1,
            },
            files: AttachmentFiles(
              pickDestination: (_, _) async {
                savePrompts++;
                return null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('report.md'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(savePrompts, 1);
    expect(find.byType(AttachmentPreviewDialog), findsNothing);
    expect(find.text('Downloading the file instead.'), findsNothing);
  });
}
