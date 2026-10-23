// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the
// attachment preview surfaces - image lightbox, document host, HTML host and
// the attachment comments panel - NOT official cases. Ids are
// `components.thread-ext.attachment.<surface>[.<platform>].<theme>`,
// dispatched on props like tool/parity-ext/host/ThreadAttachmentCases.tsx.
//
// Each case mounts the REAL Flutter widget the app pushes as a route
// (AttachmentImageLightbox, AttachmentPreviewDialog,
// HtmlAttachmentPreviewDialog) or embeds (AttachmentCommentsView) at the case
// viewport; header cases clip the same strip the React host selects.
//
// Data: tool/parity-ext/fixtures/threadattachments.json
// (fixtures['ext:threadattachments']); routes and the case's `routeSet` are
// answered by [_AttachmentClient] exactly like tool/parity-ext/run answers
// them for the React page.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_comments_view.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/features/media_image_page.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/platform/attachment_html.dart';
import 'package:raft_ui/raft_ui.dart'
    show RaftFamily, RaftGlyph, RaftLightboxIconAction;

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:threadattachments'] as Map<String, dynamic>;

Map<String, dynamic> _map(Object? value) =>
    Map<String, dynamic>.from(value as Map);

/// Answers the fixture routes, `{"$pending": true}` never completing and
/// `{"$status": n}` failing, like the React page's `page.route` handlers.
class _AttachmentClient extends ParityFakeClient {
  _AttachmentClient({required super.user, required super.routes});

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) {
    final answer = routes['$method $path'];
    if (answer is Map && answer[r'$pending'] == true) {
      requests.add('$method $path');
      return Completer<dynamic>().future;
    }
    if (answer is Map && answer[r'$status'] != null) {
      requests.add('$method $path');
      return Future<dynamic>.error(
        RaftApiException('fixture error', status: answer[r'$status'] as int),
      );
    }
    return super.request(
      method,
      path,
      data: data,
      query: query,
      authorized: authorized,
      retried: retried,
      cancellation: cancellation,
      onSendProgress: onSendProgress,
      headers: headers,
      acceptServerExit: acceptServerExit,
      receiveTimeout: receiveTimeout,
    );
  }
}

/// The fixture's base routes plus the case's `routeSet` overrides, plus the
/// preview endpoints the native dialogs read (Web reads the same data through
/// `fetchAttachmentPreviewSummary` / `openMediaPreview`).
Map<String, dynamic> _routes(ParityContext ctx) {
  final fx = _fx(ctx);
  final routeSet = ctx.props['routeSet'] as String?;
  final routes = <String, dynamic>{
    ..._map(fx['routes']),
    if (routeSet != null && routeSet.isNotEmpty)
      ..._map(_map(fx['routeSets'])[routeSet]),
  };
  for (final doc in _map(fx['documents']).values) {
    final d = _map(doc);
    final id = _map(d['attachment'])['id'];
    routes['GET /attachments/$id/preview'] = {
      'status': 'ok',
      'data': d['preview'],
      'truncated': d['truncated'],
    };
  }
  // The reference server has attachment comments on (`attachment_comments_v0`).
  routes['POST /feature-flags/evaluate'] = {
    'evaluations': [
      {'key': 'attachment_comments_v0', 'enabled': true},
    ],
  };
  final htmlId = _map(fx['html'])['id'];
  routes['GET /attachments/$htmlId/html-preview-url'] = {
    'url':
        'https://parity-fixture.invalid/api/attachments/$htmlId/html-preview?previewToken=parity',
  };
  return routes;
}

WorkspaceController _workspace(ParityContext ctx) {
  final base = ParityThreadFixture(ctx.fixtureData);
  final client = _AttachmentClient(user: base.authUser, routes: _routes(ctx));
  final w = WorkspaceController(client)
    ..server = RaftRecord(base.serverRecord)
    ..channels = [
      RaftChannel({
        'id': 'channel-design',
        'serverId': 'visual-server',
        'name': 'design',
        'type': 'channel',
        'joined': true,
      }),
    ];
  w.channel = w.channels.first;
  return w;
}

Map<String, dynamic> _doc(ParityContext ctx) =>
    _map(_map(_fx(ctx)['documents'])[ctx.props['doc'] ?? 'text']);

MemoryImage _dataImage(String url) =>
    MemoryImage(base64Decode(url.split(',').last));
MemoryImage _image(Map<String, dynamic> image) =>
    _dataImage(image['url'] as String);
MemoryImage _thumbnail(Map<String, dynamic> image) =>
    _dataImage(image['thumbnailUrl'] as String);

/// Window clip like the React host's header selector: the top-left `size` of
/// the full-viewport lightbox.
Widget _clip(ParityContext ctx, Size window, Widget child) => Align(
  alignment: Alignment.topLeft,
  child: ctx.target(
    SizedBox.fromSize(
      size: window,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: ctx.width,
          maxWidth: ctx.width,
          minHeight: ctx.height,
          maxHeight: ctx.height,
          child: child,
        ),
      ),
    ),
  ),
);

Widget _viewport(ParityContext ctx, Widget child) => Align(
  alignment: Alignment.topLeft,
  child: ctx.target(
    SizedBox(width: ctx.width, height: ctx.height, child: child),
  ),
);

/// Header strip height: `h-14` plus the border (`border-b-2` always on the
/// image lightbox; the preview shell has `border-b`, `-2` only in brutal).
double _headerHeight(ParityContext ctx) =>
    56 + (ctx.family == RaftFamily.brutal || ctx.props['host'] == 'image' ? 2 : 1);

class _NeverHtmlLoader extends AttachmentHtmlLoader {
  @override
  Future<String?> load(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int received, int? total)? onProgress,
  }) => Completer<String?>().future;
}

Widget _surface(ParityContext ctx) {
  final host = ctx.props['host'] as String;
  final fx = _fx(ctx);
  final headerOnly = (ctx.caseJson['capture'] as Map)['crop'] == 'element';
  Widget framed(Widget child) => headerOnly
      ? _clip(ctx, Size(ctx.width, _headerHeight(ctx)), child)
      : _viewport(ctx, child);
  switch (host) {
    case 'image':
      final images = (fx['images'] as List)
          .take(int.parse('${ctx.props['images'] ?? 1}'))
          .map(_map)
          .toList();
      final current = images[int.parse('${ctx.props['index'] ?? 0}')];
      final routeSet = ctx.props['routeSet'] as String?;
      final index = int.parse('${ctx.props['index'] ?? 0}');
      return framed(
        AttachmentImageLightbox(
          title: current['filename'] as String,
          zoom: TransformationController(),
          onClose: () {},
          actions: [
            RaftLightboxIconAction(
              key: const ValueKey('attachment-download'),
              glyph: RaftGlyph.download,
              label: 'Download',
              onPressed: () {},
            ),
          ],
          gallery: AttachmentLightboxGallery(
            index: index,
            thumbnails: [for (final image in images) _thumbnail(image)],
            onSelect: (_) {},
          ),
          child: AttachmentLightboxImage(
            imageKey: ValueKey('attachment-image-${current['id']}'),
            zoom: TransformationController(),
            image: routeSet == null || routeSet.isEmpty
                ? _image(current)
                : null,
            // Web falls back to the thumbnail while the original loads or
            // when it fails.
            placeholder: _thumbnail(current),
            previewFailed: routeSet == 'image-error',
            title: current['filename'] as String,
          ),
        ),
      );
    case 'document':
      final attachment = _map(_doc(ctx)['attachment']);
      return framed(
        AttachmentPreviewDialog(
          controller: _workspace(ctx),
          metadata: attachment,
          authorized: () => true,
          onClose: () {},
          onDownload: () async {},
        ),
      );
    case 'html':
      return framed(
        HtmlAttachmentPreviewDialog(
          controller: _workspace(ctx),
          metadata: _map(fx['html']),
          authorized: () => true,
          onClose: () {},
          onDownload: () async {},
          loader: _NeverHtmlLoader(),
        ),
      );
    case 'panel':
      final attachment = _map(_doc(ctx)['attachment']);
      final mobile = ctx.props['platform'] == 'mobile';
      return Align(
        alignment: Alignment.topLeft,
        child: ctx.target(
          Material(
            child: SizedBox(
              width: mobile ? 390 : 320,
              height: mobile ? 360 : 742,
              child: AttachmentCommentsView(
                controller: _workspace(ctx),
                attachmentId: attachment['id'] as String,
                filename: attachment['filename'] as String,
              ),
            ),
          ),
        ),
      );
  }
  throw StateError('unknown attachment host $host');
}

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:AttachmentImageLightbox',
    'raft_flutter:AttachmentPreviewDialog',
    'raft_flutter:HtmlAttachmentPreviewDialog',
    'raft_flutter:AttachmentCommentsView',
    'raft_ui:RaftAttachmentLightbox',
    'raft_ui:RaftAttachmentCommentsPanel',
  ],
  notes: 'Extension suite (not official). Real preview routes at the case viewport.',
  settle: const Duration(milliseconds: 900),
  build: _surface,
  // Decoding a MemoryImage needs the real event loop, not the fake clock.
  interact: (t, ctx) async {
    final fx = _fx(ctx);
    if (ctx.props['host'] != 'image') return;
    final routeSet = ctx.props['routeSet'] as String?;
    if (routeSet != null && routeSet.isNotEmpty) return;
    final context = t.element(find.byType(AttachmentLightboxImage).first);
    for (final image in (fx['images'] as List).map(_map)) {
      await t.runAsync(() => precacheImage(_image(image), context));
      await t.runAsync(() => precacheImage(_thumbnail(image), context));
    }
    await t.pump();
  },
);

const _desktop = [
  'image.single',
  'image.gallery',
  'image.gallery-first',
  'image.header',
  'image.loading',
  'image.error',
  'doc.text',
  'doc.csv',
  'doc.xlsx',
  'doc.markdown',
  'doc.header',
  'doc.header-long',
  'doc.header-pdf',
  'doc.comments',
  'html.preparing',
  'html.header',
  'comments.list',
  'comments.empty',
  'comments.loading',
  'comments.blocked',
  'comments.error',
];
const _mobile = [
  'image.single',
  'image.gallery',
  'doc.text',
  'doc.csv',
  'html.preparing',
  'comments.list',
];

/// Every extension attachment-preview case, keyed by id (3 themes each).
final Map<String, ParityCase> extThreadAttachmentCases = {
  for (final (suffix, surfaces) in [('', _desktop), ('.mobile', _mobile)])
    for (final surface in surfaces)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.thread-ext.attachment.$surface$suffix.$theme': _case,
};
