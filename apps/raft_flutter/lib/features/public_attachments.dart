// Attachments of the Public server page (Web ReadOnlyMessageAttachments.tsx):
// inline images, previewable documents and downloadable files of a message
// the visitor may read without an account. The bytes come only from the public
// attachment route (`GET /public/servers/:slug/attachments/:id`), which
// reauthorizes every request; nothing here calls the member attachment API
// (`/attachments/:id/url`, previews, comments).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../platform/attachment_files.dart';
import '../platform/attachment_http.dart';
import '../platform/attachment_preview_files.dart';
import '../platform/native_sharing.dart' show SharedFileLease;
import 'attachment_preview_dialog.dart' show attachmentPreviewRoute;

/// `PublicAttachment`: file metadata only; storage and thumbnail URLs are
/// never projected.
@immutable
class PublicAttachment {
  const PublicAttachment({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.width,
    this.height,
  });

  static PublicAttachment? tryParse(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['filename'] is! String) {
      return null;
    }
    double? dimension(Object? v) =>
        v is num && v.isFinite && v > 0 ? v.toDouble() : null;
    return PublicAttachment(
      id: value['id'] as String,
      filename: value['filename'] as String,
      mimeType: '${value['mimeType'] ?? ''}',
      sizeBytes: (value['sizeBytes'] as num?)?.toInt() ?? 0,
      width: dimension(value['width']),
      height: dimension(value['height']),
    );
  }

  final String id, filename, mimeType;
  final int sizeBytes;
  final double? width, height;

  String get normalizedMime => mimeType.split(';').first.trim().toLowerCase();
}

/// Raster types the public route serves inline (the server's allowlist);
/// everything else is a file card.
const _inlineImageTypes = {
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
};

bool publicInlineImage(PublicAttachment a) =>
    _inlineImageTypes.contains(a.normalizedMime);

/// What a file card opens in the read-only preview.
enum PublicPreviewKind { markdown, text, pdf }

/// Web `MARKDOWN_PREVIEW_PAYLOAD_BYTE_LIMIT` / `TEXT_PREVIEW_BYTE_LIMIT`.
const publicMarkdownPreviewLimit = 64 * 1024;
const publicTextPreviewLimit = 96 * 1024;

const _textMimeTypes = {
  'text/plain',
  'application/json',
  'application/xml',
  'application/yaml',
  'application/x-yaml',
  'application/toml',
  'application/x-sh',
};
const _textMimeExclusions = {'text/markdown', 'text/csv', 'text/html'};
const _textExtensions = [
  '.txt', '.text', '.log', '.ini', '.conf', '.cfg', '.properties', '.toml', //
  '.yaml', '.yml', '.json', '.xml', '.sql', '.gradle', //
  '.sh', '.bash', '.zsh', //
  '.kt', '.kts', '.java', '.swift', '.ets', //
  '.ts', '.tsx', '.js', '.jsx', '.mjs', //
  '.py', '.rb', '.go', '.rs', '.c', '.h', '.cpp', '.hpp',
];
const _legacyExcel = ['.xls', '.xlt', '.xla', '.xlm', '.xlc', '.xlw'];

/// Web `readOnlyPreviewKind`: which preview a file card opens, null for
/// download-only. Active content (HTML, SVG) is never previewed, even when its
/// MIME claims to be text; a file over the preview cap is a download rather
/// than a silently truncated preview.
PublicPreviewKind? publicPreviewKind(PublicAttachment a) {
  final name = a.filename.toLowerCase(), mime = a.normalizedMime;
  if (mime == 'text/html' ||
      RegExp(r'\.html?$').hasMatch(name) ||
      name.endsWith('.xhtml') ||
      mime.contains('html')) {
    return null;
  }
  if (name.endsWith('.svg') ||
      name.endsWith('.svgz') ||
      mime == 'image/svg+xml') {
    return null;
  }
  if (name.endsWith('.pdf') || mime == 'application/pdf') {
    return PublicPreviewKind.pdf;
  }
  if (name.endsWith('.md') ||
      name.endsWith('.markdown') ||
      mime == 'text/markdown' ||
      mime == 'text/x-markdown') {
    return a.sizeBytes <= publicMarkdownPreviewLimit
        ? PublicPreviewKind.markdown
        : null;
  }
  final text =
      _textExtensions.any(name.endsWith) ||
      _textMimeTypes.contains(mime) ||
      (mime.startsWith('text/') && !_textMimeExclusions.contains(mime));
  final csv =
      !_legacyExcel.any(name.endsWith) &&
      (name.endsWith('.csv') ||
          mime == 'text/csv' ||
          mime == 'application/csv' ||
          mime == 'application/vnd.ms-excel') &&
      a.sizeBytes <= 5 * 1024 * 1024;
  if (text || csv) {
    return a.sizeBytes <= publicTextPreviewLimit
        ? PublicPreviewKind.text
        : null;
  }
  return null;
}

/// Where a public page's attachment bytes live (Web `ReadOnlyAttachmentUrls`).
@immutable
class PublicAttachmentUrls {
  const PublicAttachmentUrls({required this.api, required this.slug});

  /// The API origin, without a trailing slash.
  final String api;
  final String slug;

  String _base(String id) =>
      '${api.replaceFirst(RegExp(r'/$'), '')}/public/servers/${Uri.encodeComponent(slug)}/attachments/${Uri.encodeComponent(id)}';
  String inline(String id) => _base(id);
  String download(String id) => '${_base(id)}?download=1';
  String pdfPreview(String id) => '${_base(id)}?disposition=inline';
}

/// Reads [url] as UTF-8 text, refusing anything over [maxBytes] or not valid
/// UTF-8 (null). Anonymous: the shared storage client carries no credentials.
Future<String?> fetchPublicText(String url, int maxBytes) async {
  final response = await AttachmentHttp.shared.get<ResponseBody>(
    url,
    options: Options(responseType: ResponseType.stream),
  );
  final declared = int.tryParse(
    response.headers.value(Headers.contentLengthHeader) ?? '',
  );
  if (declared != null && declared > maxBytes) return null;
  final chunks = BytesBuilder(copy: false);
  var total = 0;
  await for (final chunk in response.data!.stream) {
    total += chunk.length;
    if (total > maxBytes) return null;
    chunks.add(chunk);
  }
  try {
    return utf8.decode(chunks.takeBytes());
  } on FormatException {
    return null;
  }
}

typedef PublicTextFetch = Future<String?> Function(String url, int maxBytes);

/// The attachments of one public message: inline images in a gallery, then
/// every other file as a card (Web `ReadOnlyMessageAttachments`).
class PublicAttachments extends StatelessWidget {
  const PublicAttachments({
    super.key,
    required this.attachments,
    required this.urls,
    this.files,
    this.fetchText = fetchPublicText,
  });
  final List<PublicAttachment> attachments;
  final PublicAttachmentUrls urls;
  final AttachmentFiles? files;
  final PublicTextFetch fetchText;

  @override
  Widget build(BuildContext context) {
    final images = [
      for (final a in attachments)
        if (publicInlineImage(a)) a,
    ];
    final others = [
      for (final a in attachments)
        if (!publicInlineImage(a)) a,
    ];
    if (images.isEmpty && others.isEmpty) return const SizedBox.shrink();
    return RaftAttachmentStack(
      key: const ValueKey('public-message-attachments'),
      gallery: images.isEmpty
          ? null
          : RaftAttachmentGallery(
              dimensions: [
                for (final a in images) (width: a.width, height: a.height),
              ],
              itemBuilder: (index, extent, fit) => _PublicImageCard(
                key: ValueKey('public-attachment-${images[index].id}'),
                image: images[index],
                extent: extent,
                fit: fit,
                urls: urls,
                onOpen: () => _openImages(context, images, index),
                files: files,
              ),
            ),
      others: [
        for (final a in others)
          _PublicFileCard(
            key: ValueKey('public-attachment-${a.id}'),
            attachment: a,
            urls: urls,
            files: files,
            fetchText: fetchText,
          ),
      ],
    );
  }

  void _openImages(
    BuildContext context,
    List<PublicAttachment> images,
    int at,
  ) {
    final page = RaftAdaptiveWorkspace.compactOf(context);
    Navigator.of(context, rootNavigator: true).push(
      attachmentPreviewRoute(
        context,
        page,
        (_) => _PublicImageViewer(
          images: images,
          initial: at,
          urls: urls,
          page: page,
          files: files,
        ),
      ),
    );
  }
}

/// Saves a public attachment through the platform picker (`?download=1`).
Future<void> downloadPublicAttachment(
  BuildContext context,
  PublicAttachment a,
  PublicAttachmentUrls urls, {
  AttachmentFiles? files,
}) async {
  final cancel = CancelToken();
  try {
    final saved = await (files ?? AttachmentFiles()).save(
      url: urls.download(a.id),
      filename: a.filename,
      mimeType: a.mimeType.isEmpty ? 'application/octet-stream' : a.mimeType,
      cancel: cancel,
      authorized: () => context.mounted,
      onProgress: (_, _) {},
    );
    if (saved != null && context.mounted) {
      showRaftToast(
        context,
        raftFormat(context, 'Saved {name}', {'name': a.filename}),
        tone: RaftToastRecipeTone.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showRaftToast(
        context,
        raftText(
          context,
          userErrorText(
            error,
            fallback: 'Download failed. Try again.',
            where: 'public attachment download',
          ),
        ),
      );
    }
  }
}

class _PublicImageCard extends StatelessWidget {
  const _PublicImageCard({
    super.key,
    required this.image,
    required this.extent,
    required this.fit,
    required this.urls,
    required this.onOpen,
    this.files,
  });
  final PublicAttachment image;
  final Size extent;
  final BoxFit fit;
  final PublicAttachmentUrls urls;
  final VoidCallback onOpen;
  final AttachmentFiles? files;

  @override
  Widget build(BuildContext context) => RaftAttachmentCard(
    filename: image.filename,
    mimeType: image.mimeType,
    sizeBytes: image.sizeBytes,
    imageExtent: extent,
    imageWidth: image.width,
    imageHeight: image.height,
    onOpen: onOpen,
    // ignore: raft_lints/avoid_raw_image_decode -- Public bytes are plain URLs with no member image repository; the picture is decoded at the card's own extent (cacheWidth).
    preview: Image.network(
      urls.inline(image.id),
      cacheWidth: (extent.width * MediaQuery.devicePixelRatioOf(context))
          .ceil(),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const RaftLoadError(
        'Preview unavailable. Download the original file.',
        expand: false,
      ),
    ),
  );
}

class _PublicFileCard extends StatefulWidget {
  const _PublicFileCard({
    super.key,
    required this.attachment,
    required this.urls,
    required this.fetchText,
    this.files,
  });
  final PublicAttachment attachment;
  final PublicAttachmentUrls urls;
  final PublicTextFetch fetchText;
  final AttachmentFiles? files;

  @override
  State<_PublicFileCard> createState() => _PublicFileCardState();
}

class _PublicFileCardState extends State<_PublicFileCard> {
  bool loading = false;
  PublicAttachment get a => widget.attachment;
  PublicPreviewKind? get kind => publicPreviewKind(a);

  Future<void> download() =>
      downloadPublicAttachment(context, a, widget.urls, files: widget.files);

  /// Same shape as the member opener: the card shows its pending state while
  /// the bytes load, and anything that turns out not to be previewable falls
  /// back to the download it would have been.
  Future<void> open() async {
    final preview = kind;
    if (preview == null) return download();
    if (preview == PublicPreviewKind.pdf) {
      return _show(
        _PublicPdfPreview(
          attachment: a,
          url: widget.urls.pdfPreview(a.id),
          onDownload: download,
        ),
      );
    }
    setState(() => loading = true);
    try {
      final limit = preview == PublicPreviewKind.markdown
          ? publicMarkdownPreviewLimit
          : publicTextPreviewLimit;
      final text = await widget.fetchText(widget.urls.inline(a.id), limit);
      if (!mounted) return;
      if (text == null || text.trim().isEmpty) {
        await download();
        return;
      }
      final shown = preview == PublicPreviewKind.markdown ? text.trim() : text;
      await _show(
        _PublicDocumentPreview(
          attachment: a,
          data: preview == PublicPreviewKind.markdown
              ? {'kind': 'markdown', 'markdown': shown}
              : {'kind': 'text', 'text': shown},
          copyText: shown,
          onDownload: download,
        ),
      );
    } catch (_) {
      if (mounted) await download();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _show(Widget preview) {
    final page = RaftAdaptiveWorkspace.compactOf(context);
    return Navigator.of(context, rootNavigator: true).push(
      attachmentPreviewRoute(
        context,
        page,
        (_) => _PreviewHost(page: page, child: preview),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = kind != null;
    return RaftAttachmentCard(
      filename: a.filename,
      mimeType: a.mimeType,
      sizeBytes: a.sizeBytes,
      metaLabel: a.mimeType.isEmpty ? raftText(context, 'file') : a.mimeType,
      previewAffordance: preview,
      previewPending: loading,
      onOpen: loading ? null : () => unawaited(open()),
    );
  }
}

/// Gives a preview its close action and its page/dialog form.
class _PreviewHost extends InheritedWidget {
  const _PreviewHost({required this.page, required super.child});
  final bool page;
  static bool pageOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PreviewHost>()?.page ?? false;
  @override
  bool updateShouldNotify(_PreviewHost old) => page != old.page;
}

class _PublicDocumentPreview extends StatelessWidget {
  const _PublicDocumentPreview({
    required this.attachment,
    required this.data,
    required this.copyText,
    required this.onDownload,
  });
  final PublicAttachment attachment;
  final Map<String, dynamic> data;
  final String copyText;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => RaftDismissScope(
    onDismiss: () => Navigator.of(context).maybePop(),
    child: RaftAttachmentPreviewShell(
      filename: attachment.filename,
      page: _PreviewHost.pageOf(context),
      canvas: true,
      copyText: copyText,
      onClose: () => Navigator.of(context).maybePop(),
      onDownload: onDownload,
      // The member preview minus everything that needs a session: no comments.
      child: RaftDocumentPreview(data: data),
    ),
  );
}

/// PDF pages come from a private local copy of the public file, rendered by
/// the platform (the member viewer's path, without its cache and comments).
class _PublicPdfPreview extends StatefulWidget {
  const _PublicPdfPreview({
    required this.attachment,
    required this.url,
    required this.onDownload,
  });
  final PublicAttachment attachment;
  final String url;
  final VoidCallback onDownload;

  @override
  State<_PublicPdfPreview> createState() => _PublicPdfPreviewState();
}

class _PublicPdfPreviewState extends State<_PublicPdfPreview> {
  final cancel = CancelToken();
  SharedFileLease? lease;
  Uint8List? pageBytes;
  int page = 0, pageCount = 0;
  bool loading = true;
  // ignore: raft_lints/avoid_imperative_notice_state -- Preview failure panel: terminal for the dialog's life (the PDF is fetched once), gone with the dialog.
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(start());
  }

  Future<void> start() async {
    try {
      lease = await AttachmentPreviewFiles().load(
        widget.url,
        widget.attachment.filename,
        cancel: cancel,
        authorized: () => mounted,
      );
      if (lease == null || !mounted) return;
      await loadPage(0);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Preview unavailable. Download the original file.';
        });
      }
    }
  }

  Future<void> loadPage(int next) async {
    if (lease == null) return;
    setState(() => loading = true);
    try {
      final value = await NativePdfRenderer().render(
        lease!.file,
        next,
        cancel: cancel,
        authorized: () => mounted,
      );
      if (!mounted) return;
      setState(() {
        page = next;
        pageBytes = value.bytes;
        pageCount = value.pageCount;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'The PDF could not be opened. Download the original file.';
        });
      }
    }
  }

  @override
  void dispose() {
    cancel.cancel();
    final held = lease;
    if (held != null) unawaited(held.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftDismissScope(
    onDismiss: () => Navigator.of(context).maybePop(),
    child: RaftAttachmentPreviewShell(
      filename: widget.attachment.filename,
      page: _PreviewHost.pageOf(context),
      onClose: () => Navigator.of(context).maybePop(),
      onDownload: widget.onDownload,
      child: Column(
        children: [
          Expanded(
            child: loading && pageBytes == null
                ? const Center(child: RaftSpinner())
                : error != null
                ? RaftLoadError(
                    error!,
                    actions: [
                      RaftLoadErrorAction(
                        label: 'Download original',
                        glyph: RaftGlyph.download,
                        onPressed: widget.onDownload,
                      ),
                    ],
                  )
                : pageBytes == null
                ? const SizedBox.shrink()
                : InteractiveViewer(
                    child: RaftSizedImage.memory(
                      pageBytes!,
                      fit: BoxFit.contain,
                      zoom: raftZoomableImageScale,
                      evictOnDispose: true,
                    ),
                  ),
          ),
          if (pageCount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RaftIconButton(
                  glyph: RaftGlyph.chevronLeft,
                  tooltip: 'Previous page',
                  visualSize: 28,
                  minimumTargetSize: 48,
                  variant: RaftControlVariant.ghost,
                  onPressed: !loading && page > 0
                      ? () => unawaited(loadPage(page - 1))
                      : null,
                ),
                Text('${page + 1} / $pageCount'),
                RaftIconButton(
                  glyph: RaftGlyph.chevronRight,
                  tooltip: 'Next page',
                  visualSize: 28,
                  minimumTargetSize: 48,
                  variant: RaftControlVariant.ghost,
                  onPressed: !loading && page + 1 < pageCount
                      ? () => unawaited(loadPage(page + 1))
                      : null,
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

/// The lightbox of a public message's images: Web hands the shared lightbox
/// plain public URLs and supplies no comment context.
class _PublicImageViewer extends StatefulWidget {
  const _PublicImageViewer({
    required this.images,
    required this.initial,
    required this.urls,
    required this.page,
    this.files,
  });
  final List<PublicAttachment> images;
  final int initial;
  final PublicAttachmentUrls urls;
  final bool page;
  final AttachmentFiles? files;

  @override
  State<_PublicImageViewer> createState() => _PublicImageViewerState();
}

class _PublicImageViewerState extends State<_PublicImageViewer> {
  late int index = widget.initial;
  PublicAttachment get current => widget.images[index];

  void step(int by) {
    final next = index + by;
    if (next >= 0 && next < widget.images.length) setState(() => index = next);
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.images.length > 1;
    void close() => Navigator.of(context).maybePop();
    return RaftDismissScope(
      onDismiss: close,
      child: RaftAttachmentLightbox(
        title: current.filename,
        page: widget.page,
        onClose: close,
        meta: many ? Text('${index + 1} / ${widget.images.length}') : null,
        shortcuts: many
            ? {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    step(-1),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    step(1),
              }
            : const {},
        actions: [
          if (many) ...[
            RaftLightboxIconAction(
              key: const ValueKey('public-image-previous'),
              glyph: RaftGlyph.chevronLeft,
              label: raftText(context, 'Previous image'),
              onPressed: index > 0 ? () => step(-1) : null,
            ),
            RaftLightboxIconAction(
              key: const ValueKey('public-image-next'),
              glyph: RaftGlyph.chevronRight,
              label: raftText(context, 'Next image'),
              onPressed: index + 1 < widget.images.length
                  ? () => step(1)
                  : null,
            ),
          ],
          RaftLightboxIconAction(
            key: const ValueKey('public-image-download'),
            glyph: RaftGlyph.download,
            label: raftText(context, 'Download'),
            onPressed: () => unawaited(
              downloadPublicAttachment(
                context,
                current,
                widget.urls,
                files: widget.files,
              ),
            ),
          ),
        ],
        child: InteractiveViewer(
          maxScale: 8,
          // ignore: raft_lints/avoid_raw_image_decode -- Public bytes are plain URLs with no member image repository; decoded at twice the screen width, the zoom cap of this viewer.
          child: Image.network(
            widget.urls.inline(current.id),
            cacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context) *
                        2)
                    .ceil(),
            key: ValueKey('public-image-${current.id}'),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const RaftLoadError(
              'Preview unavailable. Download the original file.',
              expand: false,
            ),
          ),
        ),
      ),
    );
  }
}
