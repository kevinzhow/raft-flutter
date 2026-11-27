import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_html_test.dart'
    show PendingHtmlLoader, waitForHtmlCompletion;
import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets('attachmentPreviewExternalLink refuses a deployment alias', (
    tester,
  ) async {
    final (workspace, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(workspace.dispose);
    api.routes['GET /public/client-config'] = (_) => {
      'appHosts': ['deployment.example.com'],
    };
    api.routes['GET /attachments/a/html-preview-url'] = (_) => {
      'url': 'https://example.invalid/api/attachments/a/html-preview?previewToken=opaque',
    };
    final loader = PendingHtmlLoader();
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: HtmlAttachmentPreviewDialog(
            controller: workspace,
            metadata: const {'id': 'a', 'filename': 'demo.html'},
            authorized: () => true,
            onClose: () {},
            onDownload: () async {},
            loader: loader,
            useWebView: false,
            openExternal: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await waitForHtmlCompletion(tester, () => loader.loadStarted.isCompleted);
    loader.pending.complete(
      '<a href="https://deployment.example.com/path">App alias</a> '
      '<a href="https://other.example.org/path">Reference</a>',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('App alias', findRichText: true));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(
      find.text('This link is unavailable in the HTML preview.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reference', findRichText: true));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'other.example.org');
  });
}
