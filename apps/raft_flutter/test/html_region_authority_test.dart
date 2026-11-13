import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html_webview_events.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_html_test.dart'
    show PendingHtmlLoader, waitForHtmlCompletion;
import 'message_presentation_test.dart' show fixture;

class _Geometry implements RaftHtmlRegionController {
  @override
  bool active = true;
  final captures = <Completer<RaftHtmlRegionLocation?>>[];
  @override
  Future<RaftHtmlRegionLocation?> capture(Rect local, Size host) {
    final p = Completer<RaftHtmlRegionLocation?>();
    captures.add(p);
    return p.future;
  }

  int jumps = 0;
  @override
  Future<RaftHtmlRegionLocation?> jump(RaftHtmlRegion r, Size host) async {
    jumps++;
    return result();
  }

  @override
  Future<RaftHtmlGeometry?> measure(Size host) async => null;
  @override
  Future<RaftHtmlGeometry?> scrollBy(Offset d, Size host) async => null;
  RaftHtmlRegionLocation result() => const RaftHtmlRegionLocation(
    RaftHtmlGeometry(
      viewport: Size(500, 500),
      visible: Size(500, 500),
      scroll: Offset.zero,
      document: Size(500, 3000),
    ),
    RaftHtmlRegion(
      rect: Rect.fromLTWH(20, 30, 120, 80),
      viewportWidth: 500,
      document: Size(500, 3000),
      quote: 'Private HTML passage',
    ),
  );
}

void main() {
  for (final scenario in [
    'flag-off',
    'readonly',
    'permission',
    'server',
    'attachment',
    'close',
    'stored-touch',
  ]) {
    testWidgets('production HTML comments authority: $scenario', (t) async {
      t.view.physicalSize = scenario == 'stored-touch'
          ? const Size(390, 844)
          : const Size(856, 944);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
      for (final id in ['a', 'b']) {
        api.routes['GET /attachments/$id/html-preview-url'] = (_) => {
          'url':
              'https://example.invalid/api/attachments/$id/html-preview?previewToken=test',
        };
      }
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'attachment_comments_v0', 'enabled': scenario != 'flag-off'},
        ],
      };
      api.routes['GET /attachments/a/comments'] = (_) => {
        'comments': scenario == 'stored-touch'
            ? [
                {
                  'id': 'web-comment',
                  'senderId': 'alice',
                  'senderType': 'user',
                  'content': 'Web comment',
                  'createdAt': '2026-11-04T00:00:00Z',
                  'anchor': {
                    'type': 'html-region',
                    'data': {
                      'x': 20,
                      'y': 30,
                      'w': 120,
                      'h': 80,
                      'viewportWidth': 500,
                      'documentWidth': 500,
                      'documentHeight': 3000,
                      'quote': 'Stored region',
                    },
                  },
                },
              ]
            : [],
        'viewer': {'canComment': scenario != 'readonly', 'reason': 'read_only'},
      };
      api.routes['GET /attachments/b/comments'] = (_) => {
        'comments': [],
        'viewer': {'canComment': true},
      };
      api.routes['POST /attachments/a/comments'] = (_) => {};
      api.routes['GET /unread'] = (_) => [];
      bool allowed = true;
      var id = 'a';
      final controllers = <String, _Geometry>{};
      final events = <String, AttachmentHtmlWebViewEvents>{};
      Widget view() => MaterialApp(
        theme: raftTheme().copyWith(
          platform: scenario == 'stored-touch'
              ? TargetPlatform.android
              : TargetPlatform.linux,
        ),
        home: Scaffold(
          body: HtmlAttachmentPreviewDialog(
            controller: w,
            metadata: {'id': id, 'filename': '$id.html'},
            authorized: () => allowed,
            onClose: () {},
            onDownload: () async {},
            loader: PendingHtmlLoader(),
            useWebView: true,
            webViewBuilder: (_, uri, event) {
              events[uri.path] = event;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await t.pumpWidget(view());
      await waitForHtmlCompletion(t, () => events.isNotEmpty);
      final old = events.values.first;
      final native = _Geometry();
      controllers['a'] = native;
      old.onGeometryReady!(native);
      old.onLoaded();
      await t.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('attachment-preview-mode'));
      if (scenario == 'flag-off') {
        // The flag is retired in Web 1.24: answering it off changes nothing.
        expect(toggle, findsOneWidget);
        return;
      }
      await t.tap(toggle);
      await t.pumpAndSettle();
      final surface = t.widget<RaftHtmlRegionCommentSurface>(
        find.byType(RaftHtmlRegionCommentSurface),
      );
      final context = t.element(find.byType(RaftHtmlRegionCommentSurface));
      final session = RaftAttachmentCommentScope.read(context)!;
      expect(surface.enabled, isTrue);
      if (scenario == 'stored-touch') {
        expect(find.byKey(const ValueKey('html-region-capture')), findsNothing);
        await t.tap(find.text('Stored region').first);
        await t.pump();
        await t.pump();
        expect(native.jumps, 1);
        expect(find.byKey(const ValueKey('html-region-flash')), findsOneWidget);
        final panel = t.widget<RaftAttachmentCommentsPanel>(
          find.byType(RaftAttachmentCommentsPanel),
        );
        expect(panel.sheet?.expanded, isFalse);
        await t.pump(const Duration(seconds: 2));
        return;
      }
      final capture = session; // This is the production shell's own session.
      if (scenario == 'readonly') {
        capture.pushAnchor(native.result().region.anchor);
        await t.pump();
        expect(find.byType(EditableText), findsNothing);
        expect(
          api.calls.where(
            (c) => c.path == '/attachments/a/comments' && c.method == 'POST',
          ),
          isEmpty,
        );
        return;
      }
      final gesture = await t.startGesture(
        t.getTopLeft(find.byKey(const ValueKey('html-region-capture'))) +
            const Offset(20, 30),
      );
      await gesture.up();
      await t.pump();
      expect(native.captures.length, 1);
      if (scenario == 'permission') {
        allowed = false;
        w.notifyListeners();
        await t.pump();
      }
      if (scenario == 'server') {
        w.server = RaftRecord({'id': 'other', 'role': 'owner'});
        w.notifyListeners();
        await t.pump();
      }
      if (scenario == 'attachment') {
        id = 'b';
        await t.pumpWidget(view());
        await waitForHtmlCompletion(t, () => events.length == 2);
      }
      if (scenario == 'close') await t.pumpWidget(const SizedBox());
      native.captures.single.complete(native.result());
      old.onGeometryReady!(_Geometry());
      old.onLoaded();
      old.onProgress?.call(50);
      await t.pump();
      expect(capture.pendingAnchor, isNull);
      expect(find.text('Private HTML passage'), findsNothing);
      if (scenario != 'attachment' && scenario != 'close') {
        expect(find.byType(RaftHtmlRegionCommentSurface), findsNothing);
      }
      if (scenario == 'attachment') {
        expect(
          t
              .widget<RaftHtmlRegionCommentSurface>(
                find.byType(RaftHtmlRegionCommentSurface),
              )
              .controller,
          isNull,
        );
      }
      expect(
        api.calls.where(
          (c) => c.path == '/attachments/a/comments' && c.method == 'POST',
        ),
        isEmpty,
      );
      expect(t.takeException(), isNull);
    });
  }
}
