import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';
import 'package:raft_flutter/platform/attachment_html_webview_data.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'attachment_html_test.dart'
    show PendingHtmlLoader, waitForHtmlCompletion;
import 'message_presentation_test.dart' show fixture;
import 'support/fake_webview.dart';

class _Data implements AttachmentHtmlWebData {
  @override
  Future<void> lockDown() async {}
  @override
  Future<void> purge() async {}
}

void main() {
  testWidgets(
    'production HTML preview drag posts a bounded content-region anchor',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      try {
        t.view.physicalSize = const Size(856, 944);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        FakeWebView.reset();
        WebViewPlatform.instance = FakeWebView();
        FakeWebView.evaluate = (source) async {
          final start =
              source.indexOf('const command = ') + 'const command = '.length;
          final end = source.indexOf(';\n', start);
          final command = jsonDecode(source.substring(start, end)) as Map;
          final size = command['host'] as List? ?? [536, 888];
          final geometry = {
            'viewportWidth': size[0],
            'viewportHeight': size[1],
            'visibleWidth': size[0],
            'visibleHeight': size[1],
            'scrollX': 0,
            'scrollY': 100,
            'documentWidth': 1000,
            'documentHeight': 2000,
          };
          return jsonEncode({
            'version': 1,
            'request': command['request'],
            'geometry': geometry,
            if (command['operation'] == 'capture')
              'region': {
                'x': 20,
                'y': 130,
                'w': 120,
                'h': 80,
                'viewportWidth': size[0],
                'documentWidth': 1000,
                'documentHeight': 2000,
                'quote': 'Activation details',
              },
          });
        };
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 3));
        });
        api.routes['GET /attachments/a/html-preview-url'] = (_) => {
          'url': 'https://example.invalid/api/attachments/a/html-preview?previewToken=opaque',
        };
        api.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [
            {'key': 'attachment_comments_v0', 'enabled': true},
          ],
        };
        api.routes['GET /attachments/a/comments'] = (_) => {
          'comments': [],
          'viewer': {'canComment': true},
        };
        api.routes['POST /attachments/a/comments'] = (_) => {};
        api.routes['GET /unread'] = (_) => [];
        final loader = PendingHtmlLoader();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: TargetPlatform.linux),
            home: Scaffold(
              body: HtmlAttachmentPreviewDialog(
                controller: w,
                metadata: const {'id': 'a', 'filename': 'report.html'},
                authorized: () => true,
                onClose: () {},
                onDownload: () async {},
                loader: loader,
                useWebView: true,
                webViewBuilder: (_, uri, events) => AttachmentHtmlWebView(
                  uri: uri,
                  events: events,
                  dataFor: (_) => _Data(),
                ),
              ),
            ),
          ),
        );
        await waitForHtmlCompletion(t, () => FakeWebView.loads.isNotEmpty);
        FakeWebView.finish(FakeWebView.loads.last);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('attachment-preview-mode')));
        await t.pumpAndSettle();
        final overlay = find.byKey(const ValueKey('html-region-capture'));
        expect(overlay, findsOneWidget);
        final origin = t.getTopLeft(overlay);
        final drag = await t.startGesture(
          origin + const Offset(20, 30),
          kind: PointerDeviceKind.mouse,
        );
        await drag.moveTo(origin + const Offset(140, 110));
        await drag.up();
        await t.pumpAndSettle();
        expect(find.text('Activation details'), findsOneWidget);
        await t.enterText(
          find.byType(EditableText).last,
          'Discuss this region',
        );
        await t.pump();
        await t.tap(find.byTooltip('Remove Anchor'));
        await t.pump();
        expect(find.text('Activation details'), findsNothing);
        expect(
          t
              .widget<EditableText>(find.byType(EditableText).last)
              .controller
              .text,
          'Discuss this region',
        );
        final again = await t.startGesture(
          origin + const Offset(20, 30),
          kind: PointerDeviceKind.mouse,
        );
        await again.moveTo(origin + const Offset(140, 110));
        await again.up();
        await t.pumpAndSettle();
        expect(find.text('Activation details'), findsOneWidget);
        await t.tap(find.byTooltip('Send'));
        await t.pumpAndSettle();
        final post = api.calls.singleWhere(
          (o) => o.method == 'POST' && o.path == '/attachments/a/comments',
        );
        expect(post.data['anchor']['type'], 'html-region');
        expect(post.data['anchor']['data']['x'], 20);
        expect(post.data['anchor']['data']['y'], 130);
        expect(post.data['anchor']['data']['w'], 120);
        expect(post.data['anchor']['data']['h'], 80);
        expect(post.data['anchor']['data']['quote'], 'Activation details');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
