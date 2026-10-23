import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/attachment_preview_summary.dart';
import '../data/workspace_controller.dart';

// Web MessageItem `AttachmentCard` summary line of a document or diff card:
// the card first reads "Document preview" / "Diff preview", then the fetched
// preview names the kind and, for CSV and diffs, the size of the content.

/// The fetched summary of one card, shared through the session cache.
class AttachmentCardSummary extends ChangeNotifier {
  AttachmentCardSummary._(this.attachmentId, this._summaries)
    : value = _summaries.cached(attachmentId);

  /// Starts reading the summary of [attachmentId]; null when [fetch] is off.
  static AttachmentCardSummary? start(
    WorkspaceController w,
    String? attachmentId, {
    required bool fetch,
    AttachmentPreviewSummaries? summaries,
  }) {
    if (attachmentId == null) return null;
    final card = AttachmentCardSummary._(
      attachmentId,
      summaries ?? AttachmentPreviewSummaries.of(w, w.query),
    );
    if (fetch && card.value == null) card._load();
    return card;
  }

  final String attachmentId;
  final AttachmentPreviewSummaries _summaries;
  AttachmentPreviewSummary? value;
  bool _disposed = false;

  Future<void> _load() async {
    final summary = await _summaries.fetch(attachmentId);
    if (_disposed || summary == null) return;
    value = summary;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The texts of a document or diff card for [summary] (null while unknown).
class AttachmentCardText {
  const AttachmentCardText({
    required this.summary,
    required this.meta,
    this.additions,
    this.deletions,
  });

  /// The summary line, and for a diff the +/- counts that follow it.
  final String summary;
  final int? additions, deletions;

  /// The meta label (`CSV preview`, ...); null keeps the card's own (mime).
  final String? meta;

  /// Web `DiffPatchStatsLine`.
  static AttachmentCardText diff(
    BuildContext context,
    AttachmentPreviewSummary? summary,
  ) {
    if (summary == null || !summary.isDiff) {
      return AttachmentCardText(
        summary: raftText(context, 'Diff preview'),
        meta: null,
      );
    }
    return AttachmentCardText(
      summary: [
        _count(context, summary.files, '{count} file', '{count} files'),
        _count(context, summary.hunks, '{count} hunk', '{count} hunks'),
      ].join(' · '),
      meta: null,
      additions: summary.additions,
      deletions: summary.deletions,
    );
  }

  /// Web `DocumentPreviewSummaryLine` and the `DOCUMENT_PREVIEW_LABEL_ID` meta.
  static AttachmentCardText document(
    BuildContext context,
    AttachmentPreviewSummary? summary,
  ) {
    if (summary == null || summary.isDiff) {
      return AttachmentCardText(
        summary: raftText(context, 'Document preview'),
        meta: null,
      );
    }
    final summaryLine = switch (summary.kind) {
      'csv' => [
        summary.truncated
            ? _count(
                context,
                summary.rows,
                'First {count} row',
                'First {count} rows',
              )
            : _count(
                context,
                summary.rows,
                'Preview {count} row',
                'Preview {count} rows',
              ),
        _count(context, summary.columns, '{count} column', '{count} columns'),
      ].join(' · '),
      'markdown' => raftText(context, 'Markdown document'),
      'text' => raftText(context, 'Plain text document'),
      'xlsx' => raftText(context, 'XLSX spreadsheet'),
      _ => raftText(context, 'PDF document'),
    };
    final meta = switch (summary.kind) {
      'csv' => 'CSV preview',
      'markdown' => 'Markdown preview',
      'text' => 'Text preview',
      'xlsx' => 'XLSX preview',
      _ => 'PDF preview',
    };
    return AttachmentCardText(
      summary: summaryLine,
      meta: raftText(context, meta),
    );
  }

  /// `{count} file` / `{count} files` (Web ICU `one` / `other`).
  static String _count(
    BuildContext context,
    int count,
    String one,
    String other,
  ) {
    return raftFormat(context, count == 1 ? one : other, {'count': count});
  }
}
