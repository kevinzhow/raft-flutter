// The kinds the app draws itself, as Raft's shell does: text, csv and
// images; anything else that isn't framed has no preview, only a download.
//
// Source: packages/web/src/apps/artifacts/ArtifactContent.tsx at
// v1.24.0-source.1 (`ArtifactDrawnContent`, `parseCsv`, `linesOf`,
// `NoPreview`). Shared ARTIFACT_INLINE_IMAGE_TYPES: an SVG is drawn only as
// an image, never inlined, so its scripts never run; Flutter's codecs draw
// no SVG at all, so one shows "can't be previewed" with its download.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifact_models.dart';
import 'artifact_viewer_parts.dart';

/// Whether the app draws [kind] itself (Web `isArtifactDrawnKind`).
bool artifactDrawnKind(ArtifactKind kind) =>
    kind == ArtifactKind.text ||
    kind == ArtifactKind.csv ||
    kind == ArtifactKind.image;

/// Web `parseCsv`: lines, then commas (no quoting, as Web).
List<List<String>> artifactCsvRows(String text) => [
  for (final line in text.split(RegExp(r'\r?\n')))
    if (line.isNotEmpty) line.split(','),
];

/// Web `linesOf`: a trailing newline adds no empty last line.
List<String> artifactTextLines(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  if (lines.length > 1 && lines.last.isEmpty) lines.removeLast();
  return lines;
}

class ArtifactDrawnContent extends StatefulWidget {
  const ArtifactDrawnContent({
    super.key,
    required this.kind,
    required this.path,
    required this.read,
    this.onDownload,
  });

  final ArtifactKind kind;
  final String path;

  /// The file's bytes (`GET /api/artifacts/:id/files/:path?version=`).
  final Future<Uint8List> Function() read;
  final VoidCallback? onDownload;

  @override
  State<ArtifactDrawnContent> createState() => _ArtifactDrawnContentState();
}

class _ArtifactDrawnContentState extends State<ArtifactDrawnContent> {
  Uint8List? bytes;
  bool failed = false;
  @override
  void dispose() {
    final shown = bytes;
    // ignore: raft_lints/avoid_raw_image_decode -- Only the cache key of the image this viewer drew, to evict it; nothing is decoded.
    if (shown != null) unawaited(MemoryImage(shown).evict());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    try {
      final read = await widget.read();
      if (mounted) setState(() => bytes = read);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Widget noPreview() => ArtifactNoPreview(onDownload: widget.onDownload);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final bytes = this.bytes;
    if (failed) return noPreview();
    if (bytes == null) {
      return ArtifactLoadingSplash(kind: widget.kind, starting: false);
    }
    if (widget.kind == ArtifactKind.image) {
      return Semantics(
        image: true,
        label: widget.path,
        child: InteractiveViewer(
          key: const ValueKey('artifact-viewer-image'),
          child: Center(
            // ignore: raft_lints/avoid_raw_image_decode -- The Artifact's own file at full size for its zoomable viewer; evicted from the ImageCache when the viewer closes (dispose).
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => noPreview(),
            ),
          ),
        ),
      );
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final mono = RaftTypography.mono(t, size: 13, line: 20);
    if (widget.kind == ArtifactKind.csv) {
      final rows = artifactCsvRows(text);
      if (rows.isEmpty) return noPreview();
      final head = rows.first, body = rows.skip(1).toList();
      final columns = rows.fold<int>(
        0,
        (n, row) => row.length > n ? row.length : n,
      );
      TableRow row(List<String> cells, {bool header = false}) => TableRow(
        children: [
          for (var i = 0; i < columns; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RaftSpace.x3,
                vertical: RaftSpace.x2,
              ),
              child: Text(
                i < cells.length ? cells[i] : '',
                softWrap: false,
                style: header
                    ? RaftTypography.body(
                        t,
                        size: 13,
                        line: 20,
                        weight: FontWeight.w600,
                      )
                    : i == 0
                    ? RaftTypography.body(t, size: 13, line: 20)
                    : mono,
              ),
            ),
        ],
      );
      return Semantics(
        label: widget.path,
        child: SingleChildScrollView(
          key: const ValueKey('artifact-viewer-csv'),
          padding: const EdgeInsets.all(RaftSpace.x4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder(
                horizontalInside: BorderSide(color: t.ui.lineHairline),
              ),
              children: [row(head, header: true), for (final r in body) row(r)],
            ),
          ),
        ),
      );
    }
    final lines = artifactTextLines(text);
    return Semantics(
      label: widget.path,
      child: SingleChildScrollView(
        key: const ValueKey('artifact-viewer-text'),
        padding: const EdgeInsets.all(RaftSpace.x4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(lines.join('\n'), style: mono),
        ),
      ),
    );
  }
}

/// "This file can't be previewed here yet." with Download (Web `NoPreview`).
class ArtifactNoPreview extends StatelessWidget {
  const ArtifactNoPreview({super.key, this.onDownload});
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) => ArtifactViewerState(
    key: const ValueKey('artifact-viewer-no-preview'),
    title: raftText(context, 'This file can\'t be previewed here yet.'),
    actionLabel: onDownload == null ? null : raftText(context, 'Download'),
    actionGlyph: RaftGlyph.download,
    onAction: onDownload,
  );
}
