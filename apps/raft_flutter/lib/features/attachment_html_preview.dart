import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/attachment_image_store.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_html.dart';
import '../platform/attachment_html_webview.dart';
import 'attachment_comments_view.dart';

class HtmlAttachmentPreviewDialog extends StatefulWidget {
  const HtmlAttachmentPreviewDialog({
    super.key,
    required this.controller,
    required this.metadata,
    required this.authorized,
    required this.onClose,
    required this.onDownload,
    this.onShare,
    this.page = false,
    this.loader,
    this.openExternal,
    this.useWebView,
    this.webViewBuilder,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> metadata;
  final bool Function() authorized;
  final VoidCallback onClose;
  final Future<void> Function() onDownload;

  /// The system share sheet; null where the platform has none.
  final Future<void> Function()? onShare;
  final bool page;
  final AttachmentHtmlLoader? loader;
  final Future<bool> Function(Uri)? openExternal;

  /// Show the server's isolated preview URL in the platform WebView (Web
  /// parity). Null selects it wherever a WebView implementation is registered
  /// (Android, iOS, macOS); Linux and Windows fall back to the static preview.
  final bool? useWebView;
  final AttachmentHtmlWebViewBuilder? webViewBuilder;
  @override
  State<HtmlAttachmentPreviewDialog> createState() => _HtmlPreviewState();
}

class _HtmlPreviewState extends State<HtmlAttachmentPreviewDialog> {
  late final loader = widget.loader ?? AttachmentHtmlLoader();
  CancelToken cancel = CancelToken();
  // ignore: raft_lints/avoid_imperative_notice_state -- Preview error: cleared by load()/interactive() and scope loss; link errors are NOT cleared by a later successful link (see inv-a.md, other agent owns the file).
  String? html, error;
  Uri? webUri;
  bool loading = true, opening = false, pageLoading = false;

  /// What the loading stage draws: bytes of the static download, or the
  /// WebView's page-load percent. Waiting (connecting) until the first update.
  final progress = ValueNotifier<RaftTransferProgress?>(
    RaftTransferProgress.connecting,
  );
  int lastReported = -1;

  /// Failures that Retry cannot fix, and whether the browser can still help.
  bool retryable = true, browserOffered = true;
  bool get webView => widget.useWebView ?? attachmentHtmlWebViewSupported;
  bool get current => mounted && widget.authorized();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(scopeChanged);
    unawaited(load());
  }

  void scopeChanged() {
    if (current) return;
    cancel.cancel();
    if (mounted) {
      setState(() {
        html = null;
        webUri = null;
        error = null;
        loading = false;
      });
    } else {
      html = null;
      webUri = null;
    }
  }

  Future<Uri?> resolve() async {
    if (!current) return null;
    final data = await widget.controller.query(
      '/attachments/${widget.metadata['id']}/html-preview-url',
    );
    if (!current || data is! Map || data['url'] is! String) return null;
    return attachmentHtmlPreviewUri(
      data['url'],
      widget.controller.client.origin,
      '${widget.metadata['id']}',
    );
  }

  Future<void> load() async {
    if (!current) return;
    cancel.cancel();
    cancel = CancelToken();
    setState(() {
      loading = true;
      error = null;
      html = null;
      webUri = null;
      retryable = browserOffered = true;
      pageLoading = false;
    });
    progress.value = RaftTransferProgress.connecting;
    lastReported = -1;
    try {
      if (!webView) {
        // A document already opened on this device shows from the cache: no
        // preview-URL request and no download.
        final stored = await storedSource();
        if (!current) return;
        if (stored != null) {
          await showSource(stored);
          return;
        }
      }
      final uri = await resolve();
      if (uri == null || !current) return;
      if (webView) {
        // The WebView cannot read response headers, so the pinned sandbox is
        // verified on a fresh request first; the document's own CSP then
        // applies again when the WebView loads it.
        final isolated = await loader.verify(
          uri,
          cancel: cancel,
          authorized: () => current,
        );
        if (!current) return;
        if (!isolated) throw const AttachmentHtmlNotIsolated();
        setState(() {
          webUri = uri;
          pageLoading = true;
        });
        return;
      }
      final source = await loader.load(
        uri,
        cancel: cancel,
        authorized: () => current,
        onProgress: byteProgress,
      );
      if (source != null && current) {
        unawaited(storeSource(source));
        await showSource(source);
      }
    } catch (e) {
      if (current) fail(e);
    } finally {
      if (current) setState(() => loading = false);
    }
  }

  Future<void> showSource(String source) async {
    // Parsing a multi-megabyte document must not block frames.
    final text = source.length > 256 * 1024
        ? await sanitizeOffThread(source)
        : raftStaticHtml(source);
    if (current) setState(() => html = text);
  }

  /// Only a document that passed the sandbox check is ever stored, so a hit
  /// needs no new request to be as safe as the first open.
  AttachmentImageStoreKey get sourceKey => widget.controller.attachmentMedia.cacheKey(
    widget.metadata,
    'html',
    channelId:
        '${widget.metadata['channelId'] ?? widget.controller.channel?.id ?? ''}',
  );

  Future<String?> storedSource() async {
    final cache = widget.controller.attachmentMedia.diskCache;
    if (cache == null) return null;
    try {
      final bytes = await cache.readPreview(sourceKey);
      return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> storeSource(String source) async {
    final cache = widget.controller.attachmentMedia.diskCache;
    if (cache == null) return;
    try {
      await cache.writePreview(
        sourceKey,
        Uint8List.fromList(utf8.encode(source)),
      );
    } catch (_) {
      // Caching is best effort.
    }
  }

  /// Bytes of the static download, at most one repaint per percent point (or
  /// per 32 KB while the length is unknown).
  void byteProgress(int received, int? total) {
    if (!current) return;
    final step = total == null
        ? received ~/ (32 * 1024)
        : received * 100 ~/ total;
    if (step == lastReported) return;
    lastReported = step;
    progress.value = RaftTransferProgress(received: received, total: total);
  }

  /// WebView page-load percent; only whole-point changes repaint.
  void pageProgress(int percent) {
    if (!current || !pageLoading || percent == lastReported) return;
    lastReported = percent;
    progress.value = RaftTransferProgress.percent(percent);
  }

  /// Static so the isolate closure cannot capture the State (not sendable).
  static Future<String> sanitizeOffThread(String source) =>
      Isolate.run(() => raftStaticHtml(source));

  /// Says why the preview is unavailable and which actions can still help.
  void fail(Object e) {
    var retry = true, browser = true;
    final String message;
    switch (e) {
      case AttachmentHtmlTooLarge():
        retry = false;
        message =
            'This HTML file is too large for the in-app preview. Open it in the browser or download it.';
      case AttachmentHtmlNotIsolated():
        retry = browser = false;
        message =
            'The server did not provide an isolated HTML preview, so it is not shown. Download the file to view it.';
      case DioException(response: final r?)
          when [401, 403].contains(r.statusCode):
        retry = browser = false;
        message = 'You do not have access to this HTML preview.';
      case DioException(response: final r?)
          when [404, 410].contains(r.statusCode):
        retry = browser = false;
        message =
            'The HTML preview is no longer available. Download the file to view it.';
      case DioException(response: != null):
        message =
            'The server could not deliver the HTML preview. Retry, or open it in the browser.';
      case DioException():
        message =
            'The HTML preview could not be loaded because the connection failed. Retry, or open it in the browser.';
      case FormatException():
        retry = false;
        message =
            'This HTML is too complex for the in-app preview. Open it in the browser or download it.';
      case _WebViewFailure():
        message =
            'This device could not display the HTML preview. Open it in the browser or download it.';
      default:
        message =
            'The HTML preview could not be loaded. Download the file to view it.';
    }
    setState(() {
      error = message;
      retryable = retry;
      browserOffered = browser;
      html = null;
      webUri = null;
      pageLoading = false;
    });
  }

  bool webNavigation(String url) {
    final preview = webUri;
    if (!current || preview == null) return false;
    final decision = attachmentHtmlNavigation(
      url,
      preview,
      widget.controller.client.origin,
    );
    switch (decision.action) {
      case AttachmentHtmlNavigationAction.allow:
        // A page that loads again ends the previous link's failure.
        if (error != null) setState(() => error = null);
        return true;
      case AttachmentHtmlNavigationAction.external:
        unawaited(link('${decision.link}'));
      case AttachmentHtmlNavigationAction.block:
        setState(() => error = 'This link is unavailable in the HTML preview.');
    }
    return false;
  }

  Future<void> interactive() async {
    if (!current || opening) return;
    setState(() {
      opening = true;
      error = null;
    });
    try {
      final uri = await resolve();
      if (uri == null || !current) return;
      final isolated = await loader.verify(
        uri,
        cancel: cancel,
        authorized: () => current,
      );
      if (!isolated || !current) throw StateError('Preview unavailable');
      final opened =
          await (widget.openExternal?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && current) {
        setState(() => error = 'The interactive preview could not be opened.');
      }
    } catch (_) {
      if (current) {
        setState(() => error = 'The interactive preview could not be opened.');
      }
    } finally {
      if (current) setState(() => opening = false);
    }
  }

  Future<void> link(String value) async {
    if (!current) return;
    // A new attempt replaces the previous link's failure: it shows again only
    // if this one fails too.
    if (error != null) setState(() => error = null);
    final uri = attachmentHtmlExternalLink(
      value,
      widget.controller.client.origin,
    );
    if (uri == null) {
      setState(() => error = 'This link is unavailable in the HTML preview.');
      return;
    }
    try {
      final opened =
          await (widget.openExternal?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && current) {
        setState(() => error = 'The link could not be opened.');
      }
    } catch (_) {
      if (current) setState(() => error = 'The link could not be opened.');
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(scopeChanged);
    cancel.cancel();
    html = null;
    progress.dispose();
    loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftAttachmentPreviewShell(
    page: widget.page,
    filename: '${widget.metadata['filename'] ?? 'HTML'}',
    onClose: widget.onClose,
    onDownload: current ? widget.onDownload : null,
    onShare: current ? widget.onShare : null,
    commentsBuilder: current && widget.metadata['id'] is String
        ? (_, sheet) => AttachmentCommentsView(
            controller: widget.controller,
            attachmentId: widget.metadata['id'] as String,
            filename: '${widget.metadata['filename'] ?? 'HTML'}',
            authorized: () => current,
            sheet: sheet,
          )
        : null,
    child: Column(
      children: [
        if (error != null && (html != null || webUri != null))
          errorLine(context),
        Expanded(
          child: webUri != null
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: (widget.webViewBuilder ?? webViewBuilder)(
                        context,
                        webUri!,
                        AttachmentHtmlWebViewEvents(
                          onNavigation: webNavigation,
                          onLoaded: () {
                            if (current) setState(() => pageLoading = false);
                          },
                          onProgress: pageProgress,
                          onFailed: (_) {
                            if (current) {
                              fail(const _WebViewFailure());
                            }
                          },
                        ),
                      ),
                    ),
                    if (pageLoading)
                      Positioned.fill(child: transferStage(context)),
                  ],
                )
              : loading
              ? transferStage(context)
              : html == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    // ds-allow: gap between the reason and its actions, the Wrap's own 8px rhythm doubled
                    spacing: 16,
                    children: [
                      if (error != null) errorLine(context, beside: true),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (retryable)
                            RaftButton(
                              label: 'Retry preview',
                              onPressed: current ? load : null,
                            ),
                          if (browserOffered)
                            RaftButton(
                              label: 'Open interactive preview in browser',
                              busy: opening,
                              onPressed: current && !opening
                                  ? interactive
                                  : null,
                            ),
                          RaftButton(
                            label: 'Download file',
                            onPressed: current ? widget.onDownload : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : RaftHtmlPreview(
                  html: html!,
                  onLink: link,
                  onInteractive: interactive,
                  busy: opening,
                ),
        ),
      ],
    ),
  );

  /// The same file transfer panel as the other previews, with Cancel closing
  /// the preview. Opaque, so it also covers the WebView while the page loads.
  Widget transferStage(BuildContext context) {
    final name = '${widget.metadata['filename'] ?? 'HTML'}';
    final size = (widget.metadata['sizeBytes'] as num?)?.toInt();
    final extension = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : 'HTML';
    return RaftPreviewTransferStage(
      filename: name,
      meta: size == null || size <= 0
          ? extension
          : '$extension · ${RaftAttachmentCard.formatSize(size)}',
      progress: progress,
      onCancel: widget.onClose,
    );
  }

  /// Web has no in-repo error state for the HTML preview; the failure reads
  /// like Web's other page errors: a warning banner over a shown page, the
  /// muted mono load-error message when there is no page to show.
  Widget errorLine(BuildContext context, {bool beside = false}) => beside
      ? RaftLoadError(error!, expand: false)
      : RaftErrorBanner(error!, small: true, bold: true);

  static Widget webViewBuilder(
    BuildContext context,
    Uri uri,
    AttachmentHtmlWebViewEvents events,
  ) => AttachmentHtmlWebView(uri: uri, events: events);
}

/// The platform WebView could not show the page itself.
class _WebViewFailure implements Exception {
  const _WebViewFailure();
}
