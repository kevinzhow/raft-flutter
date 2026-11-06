import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html.dart';
import 'package:raft_ui/raft_ui.dart';

import 'linux_dependency_fixture.dart';
import 'message_presentation_test.dart' show fixture;
import 'attachment_html_test.dart' show waitForHtmlCompletion;

class _Loader extends AttachmentHtmlLoader {
  int loaded = 0, verified = 0;
  @override
  Future<String?> load(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int, int?)? onProgress,
  }) async {
    loaded++;
    return '<h1>Fallback report</h1><script>hidden()</script>';
  }

  @override
  Future<bool> verify(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    verified++;
    return true;
  }
}

void main() {
  testWidgets(
    'missing WebKit keeps static reading; install and retry restores native preview',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      try {
        final host = DependencyHost()..bind();
        addTearDown(host.unbind);
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        addTearDown(() => t.pumpWidget(const SizedBox()));
        api.routes['GET /attachments/a/html-preview-url'] = (_) => {
          'url': 'https://example.invalid/api/attachments/a/html-preview?previewToken=opaque',
        };
        final loader = _Loader();
        var nativeCreated = 0;
        var pageDelivered = false;
        Widget dialog() => MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: HtmlAttachmentPreviewDialog(
              controller: w,
              metadata: const {'id': 'a', 'filename': 'report.html'},
              authorized: () => true,
              onClose: () {},
              onDownload: () async {},
              useWebView: true,
              loader: loader,
              webViewBuilder: (context, uri, events) {
                nativeCreated++;
                if (!pageDelivered) {
                  pageDelivered = true;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => events.onLoaded(),
                  );
                }
                return const Text('Native interactive document');
              },
            ),
          ),
        );
        await t.pumpWidget(dialog());
        await waitForHtmlCompletion(
          t,
          () => loader.loaded > 0 || nativeCreated > 0,
        );
        await t.pumpAndSettle();
        expect(nativeCreated, 0);
        expect(
          find.textContaining('Fallback report', findRichText: true),
          findsOneWidget,
        );
        expect(find.byType(RaftHtmlRegionCommentSurface), findsNothing);
        expect(
          find.byKey(const Key('linux-dependency-notice-webkit')),
          findsOneWidget,
        );
        host.installed.add('webkit');
        await t.tap(find.byKey(const Key('linux-dependency-retry-webkit')));
        await waitForHtmlCompletion(t, () => nativeCreated > 0);
        await t.pumpAndSettle();
        expect(find.text('Native interactive document'), findsOneWidget);
        expect(
          find.byKey(const Key('linux-dependency-notice-webkit')),
          findsNothing,
        );
        expect(loader.verified, 1);
        await t.pumpWidget(const SizedBox());
        pageDelivered = false;
        await t.pumpWidget(dialog());
        await waitForHtmlCompletion(t, () => loader.verified == 2);
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('linux-dependency-notice-webkit')),
          findsNothing,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
