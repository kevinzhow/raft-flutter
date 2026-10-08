import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/workspace_controller.dart';
import '../platform/attachment_html.dart';

class HtmlAttachmentPreviewDialog extends StatefulWidget {
  const HtmlAttachmentPreviewDialog({
    super.key,
    required this.controller,
    required this.metadata,
    required this.authorized,
    required this.onClose,
    required this.onDownload,
    this.loader,
    this.openExternal,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> metadata;
  final bool Function() authorized;
  final VoidCallback onClose;
  final Future<void> Function() onDownload;
  final AttachmentHtmlLoader? loader;
  final Future<bool> Function(Uri)? openExternal;
  @override
  State<HtmlAttachmentPreviewDialog> createState() => _HtmlPreviewState();
}

class _HtmlPreviewState extends State<HtmlAttachmentPreviewDialog> {
  late final loader = widget.loader ?? AttachmentHtmlLoader();
  CancelToken cancel = CancelToken();
  String? html, error;
  bool loading = true, opening = false;
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
        error = null;
        loading = false;
      });
    } else {
      html = null;
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
    });
    try {
      final uri = await resolve();
      if (uri == null || !current) return;
      final source = await loader.load(
        uri,
        cancel: cancel,
        authorized: () => current,
      );
      if (source != null && current) {
        setState(() => html = raftStaticHtml(source));
      }
    } catch (_) {
      if (current) {
        setState(
          () => error = 'The HTML preview could not be loaded. Download the file to view it.',
        );
      }
    } finally {
      if (current) setState(() => loading = false);
    }
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
    loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 1000,
      height: MediaQuery.sizeOf(context).height * .88,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.metadata['filename'] ?? 'HTML'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: raftText(context, 'Download'),
                  onPressed: current ? widget.onDownload : null,
                  icon: const Icon(Icons.download),
                ),
                IconButton(
                  tooltip: raftText(context, 'Close preview'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  raftText(context, error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : html == null
                  ? Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          RaftButton(
                            label: 'Retry preview',
                            onPressed: current ? load : null,
                          ),
                          RaftButton(
                            label: 'Open interactive preview in browser',
                            busy: opening,
                            onPressed: current && !opening ? interactive : null,
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
      ),
    ),
  );
}
