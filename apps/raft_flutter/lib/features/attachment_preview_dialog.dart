import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/attachment_player.dart';
import '../platform/attachment_preview_files.dart';
import '../platform/native_sharing.dart';

String? attachmentPreviewKind(Map<String, dynamic> metadata) {
  final name = '${metadata['filename'] ?? ''}'.toLowerCase();
  final mime = '${metadata['mimeType'] ?? ''}'
      .toLowerCase()
      .split(';')
      .first
      .trim();
  bool ext(List<String> values) => values.any(name.endsWith);
  if (ext(['.pdf']) || mime == 'application/pdf') return 'pdf';
  if (ext(['.mp4', '.webm', '.mov']) ||
      ['video/mp4', 'video/webm', 'video/quicktime'].contains(mime)) {
    return 'video';
  }
  if (ext([
        '.mp3',
        '.wav',
        '.m4a',
        '.aac',
        '.ogg',
        '.oga',
        '.opus',
        '.weba',
        '.flac',
      ]) ||
      [
        'audio/mpeg',
        'audio/mp3',
        'audio/wav',
        'audio/x-wav',
        'audio/wave',
        'audio/aac',
        'audio/mp4',
        'audio/x-m4a',
        'audio/ogg',
        'audio/opus',
        'audio/webm',
        'audio/flac',
        'audio/x-flac',
      ].contains(mime)) {
    return 'audio';
  }
  if (ext(['.diff', '.patch']) ||
      ['text/x-diff', 'text/x-patch', 'application/x-patch'].contains(mime)) {
    return null;
  }
  if (ext(['.html', '.htm']) || mime == 'text/html') return null;
  final size = metadata['sizeBytes'];
  if (!ext(['.xls', '.xlt', '.xla', '.xlm', '.xlc', '.xlw']) &&
      (ext(['.csv']) ||
          [
            'text/csv',
            'application/csv',
            'application/vnd.ms-excel',
          ].contains(mime)) &&
      (size is! num || size <= 5 * 1024 * 1024)) {
    return 'document';
  }
  if ((ext(['.xlsx']) ||
          mime ==
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') &&
      (size is! num || size <= 10 * 1024 * 1024)) {
    return 'document';
  }
  if (ext(['.md', '.markdown']) ||
      ['text/markdown', 'text/x-markdown'].contains(mime)) {
    return 'document';
  }
  if (mime.startsWith('text/') && !['text/csv', 'text/html'].contains(mime) ||
      [
        'application/json',
        'application/xml',
        'application/yaml',
        'application/x-yaml',
        'application/toml',
        'application/x-sh',
      ].contains(mime) ||
      ext([
        '.txt',
        '.text',
        '.log',
        '.ini',
        '.conf',
        '.cfg',
        '.properties',
        '.toml',
        '.yaml',
        '.yml',
        '.json',
        '.xml',
        '.sql',
        '.gradle',
        '.sh',
        '.bash',
        '.zsh',
        '.kt',
        '.kts',
        '.java',
        '.swift',
        '.ets',
        '.ts',
        '.tsx',
        '.js',
        '.jsx',
        '.mjs',
        '.py',
        '.rb',
        '.go',
        '.rs',
        '.c',
        '.h',
        '.cpp',
        '.hpp',
      ])) {
    return 'document';
  }
  return null;
}

class AttachmentPreviewDialog extends StatefulWidget {
  const AttachmentPreviewDialog({
    super.key,
    required this.controller,
    required this.metadata,
    required this.authorized,
    required this.onClose,
    required this.onDownload,
    this.files,
    this.pdf,
    this.playerFactory,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> metadata;
  final bool Function() authorized;
  final VoidCallback onClose;
  final Future<void> Function() onDownload;
  final AttachmentPreviewFiles? files;
  final NativePdfRenderer? pdf;
  final AttachmentPlayer Function()? playerFactory;
  @override
  State<AttachmentPreviewDialog> createState() =>
      _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends State<AttachmentPreviewDialog>
    with WidgetsBindingObserver {
  final cancel = CancelToken();
  SharedFileLease? lease;
  AttachmentPlayer? player;
  StreamSubscription<AttachmentPlayback>? playbackEvents;
  AttachmentPlayback playback = const AttachmentPlayback();
  Map<String, dynamic>? document;
  Uint8List? pageBytes;
  int page = 0, pageCount = 0, request = 0;
  bool loading = true, truncated = false, invalidated = false;
  String? error;
  Future<void>? cleanup;
  String get kind => attachmentPreviewKind(widget.metadata) ?? 'unsupported';
  bool get current =>
      mounted && !invalidated && !cancel.isCancelled && widget.authorized();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(scopeChanged);
    load();
  }

  void scopeChanged() {
    if (!widget.authorized()) {
      invalidated = true;
      if (pageBytes != null) unawaited(MemoryImage(pageBytes!).evict());
      setState(() {
        document = null;
        pageBytes = null;
      });
      cancel.cancel();
      if (player != null) unawaited(player!.pause().catchError((_) {}));
      unawaited(releaseInputs());
      widget.onClose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && player != null) {
      unawaited(action((p) => p.pause()));
    }
  }

  Future<void> load() async {
    final ticket = ++request;
    try {
      if (!current) return;
      if (kind == 'document') {
        final value = await widget.controller.query(
          '/attachments/${widget.metadata['id']}/preview',
        );
        if (!current || ticket != request) return;
        if (value is! Map ||
            value['status'] != 'ok' ||
            value['data'] is! Map ||
            ![
              'text',
              'markdown',
              'csv',
              'xlsx',
            ].contains(value['data']['kind'])) {
          throw const FormatException('The file cannot be previewed.');
        }
        setState(() {
          document = Map<String, dynamic>.from(value['data']);
          truncated = value['truncated'] == true;
        });
      } else if (['pdf', 'audio', 'video'].contains(kind)) {
        final value = await widget.controller.query(
          '/attachments/${widget.metadata['id']}/url',
          query: {'disposition': 'inline'},
        );
        if (!current || ticket != request) return;
        final prepared = await (widget.files ?? AttachmentPreviewFiles()).load(
          value['url'] as String,
          '${widget.metadata['filename'] ?? 'attachment'}',
          cancel: cancel,
          authorized: () => current,
        );
        if (!current || ticket != request || prepared == null) {
          await prepared?.dispose();
          return;
        }
        lease = prepared;
        if (kind == 'pdf') {
          await loadPage(0);
        } else {
          player =
              (widget.playerFactory ??
              () => NativeAttachmentPlayer(video: kind == 'video'))();
          playbackEvents = player!.changes.listen((value) {
            if (!current) return;
            setState(() {
              playback = value;
              if (value.error) {
                error = 'The media could not be played. Download the original file.';
                unawaited(player!.pause().catchError((_) {}));
              }
            });
          });
          await player!.open(lease!.file);
        }
      } else {
        throw const FormatException('The file cannot be previewed.');
      }
    } catch (_) {
      if (current && ticket == request) {
        setState(
          () => error = 'Preview unavailable. Download the original file.',
        );
      }
    } finally {
      if (current && ticket == request) setState(() => loading = false);
    }
  }

  Future<void> loadPage(int next) async {
    if (!current || lease == null) return;
    setState(() => loading = true);
    try {
      final value = await (widget.pdf ?? NativePdfRenderer()).render(
        lease!.file,
        next,
        cancel: cancel,
        authorized: () => current,
      );
      if (!current) return;
      if (pageBytes != null) unawaited(MemoryImage(pageBytes!).evict());
      setState(() {
        page = next;
        pageBytes = value.bytes;
        pageCount = value.pageCount;
      });
    } catch (_) {
      if (current) {
        setState(
          () => error =
              'The PDF could not be opened. Download the original file.',
        );
      }
    } finally {
      if (current) setState(() => loading = false);
    }
  }

  Future<void> action(Future<void> Function(AttachmentPlayer) run) async {
    if (!current || player == null) return;
    try {
      await run(player!);
    } catch (_) {
      if (current) {
        setState(
          () => error =
              'The media could not be played. Download the original file.',
        );
      }
    }
  }

  @override
  void dispose() {
    invalidated = true;
    request++;
    cancel.cancel();
    widget.controller.removeListener(scopeChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (pageBytes != null) unawaited(MemoryImage(pageBytes!).evict());
    pageBytes = null;
    unawaited(releaseInputs());
    super.dispose();
  }

  Future<void> releaseInputs() => cleanup ??= () async {
    final heldPlayer = player, heldLease = lease;
    try {
      await playbackEvents?.cancel();
      await heldPlayer?.dispose();
    } catch (_) {
      // A failing native decoder must not retain its private file.
    } finally {
      await heldLease?.dispose();
    }
  }();

  @override
  Widget build(BuildContext context) => RaftAttachmentLightbox(
    title: '${widget.metadata['filename'] ?? ''}',
    onClose: widget.onClose,
    footer: Column(mainAxisSize: MainAxisSize.min, children: [
      if (current && kind == 'pdf' && pageCount > 0)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          RaftIconButton(glyph: RaftGlyph.chevronLeft, tooltip: 'Previous page', visualSize: 28,
            minimumTargetSize: 48, variant: RaftControlVariant.ghost,
            onPressed: !loading && page > 0 ? () => loadPage(page - 1) : null),
          Text('${page + 1} / $pageCount'),
          RaftIconButton(glyph: RaftGlyph.chevronRight, tooltip: 'Next page', visualSize: 28,
            minimumTargetSize: 48, variant: RaftControlVariant.ghost,
            onPressed: !loading && page + 1 < pageCount ? () => loadPage(page + 1) : null),
        ]),
      RaftTextButton(label: 'Download original', glyph: RaftGlyph.download,
        onPressed: current ? widget.onDownload : null, variant: RaftControlVariant.ghost),
    ]),
    child: Column(children: [
      Expanded(child: !current ? const SizedBox.shrink()
          : loading ? const Center(child: RaftSpinner())
          : error != null ? Center(child: Text(raftText(context, error!)))
          : document != null ? RaftDocumentPreview(data: document!, truncated: truncated)
          : kind == 'pdf' && pageBytes != null
              ? InteractiveViewer(child: Image.memory(pageBytes!, fit: BoxFit.contain))
          : kind == 'video' && player != null ? player!.video()
          : const Center(child: Icon(Icons.music_note, size: 72))),
      if (current && player != null && !loading && error == null)
        RaftMediaControls(playing: playback.playing, position: playback.position,
          duration: playback.duration, volume: playback.volume,
          onPlayPause: () => action((p) => p.toggle()),
          onSeek: (v) => action((p) => p.seek(v)), onVolume: (v) => action((p) => p.volume(v))),
    ]),
  );
}
