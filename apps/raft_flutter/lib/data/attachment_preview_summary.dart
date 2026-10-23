import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:raft_client/raft_client.dart';

// Web `components/message/attachmentPreviewSummaryCache.ts`: the summary line
// of a document or diff card comes from `GET /attachments/:id/preview`. The
// answer for an attachment never changes, so it is cached for the session and
// concurrent askers share one request (a channel full of documents would
// otherwise scale requests with attachments and trip the download limiter).

/// What a card shows of `GET /attachments/:id/preview` (`status: ok`).
class AttachmentPreviewSummary {
  const AttachmentPreviewSummary({
    required this.kind,
    this.rows = 0,
    this.columns = 0,
    this.truncated = false,
    this.files = 0,
    this.hunks = 0,
    this.additions = 0,
    this.deletions = 0,
  });

  /// `csv`, `xlsx`, `markdown`, `text`, `pdf` or `diff`.
  final String kind;

  /// CSV: rows carried by the preview and the file's column count.
  final int rows, columns;

  /// The preview holds only a prefix of the file.
  final bool truncated;

  /// Diff stats.
  final int files, hunks, additions, deletions;

  bool get isDiff => kind == 'diff';

  /// Null for a refusal (`unsupported`) or a payload this client cannot read.
  static AttachmentPreviewSummary? parse(dynamic response) {
    if (response is! Map || response['status'] != 'ok') return null;
    final data = response['data'];
    if (data is! Map) return null;
    final kind = data['kind'];
    int count(dynamic value) =>
        value is num && value.isFinite ? value.toInt() : 0;
    switch (kind) {
      case 'diff':
        final stats = data['stats'];
        if (stats is! Map) return null;
        return AttachmentPreviewSummary(
          kind: 'diff',
          files: count(stats['files']),
          hunks: count(stats['hunks']),
          additions: count(stats['additions']),
          deletions: count(stats['deletions']),
        );
      case 'csv':
        return AttachmentPreviewSummary(
          kind: 'csv',
          rows: data['rows'] is List ? (data['rows'] as List).length : 0,
          columns: count(data['columnCount']),
          truncated: response['truncated'] == true,
        );
      case 'xlsx' || 'markdown' || 'text' || 'pdf':
        return AttachmentPreviewSummary(
          kind: kind as String,
          truncated: response['truncated'] == true,
        );
    }
    return null;
  }
}

/// The session's summaries of one workspace controller.
class AttachmentPreviewSummaries {
  AttachmentPreviewSummaries._(this._query);

  static final _all = Expando<AttachmentPreviewSummaries>('preview summaries');

  /// The summaries of the session [owner] (the workspace controller) holds;
  /// [query] reads a path through it.
  static AttachmentPreviewSummaries of(
    Object owner,
    Future<dynamic> Function(String path) query,
  ) => _all[owner] ??= AttachmentPreviewSummaries._(query);

  /// Summaries over a scripted [query].
  @visibleForTesting
  static AttachmentPreviewSummaries testing(
    Future<dynamic> Function(String path) query,
  ) => AttachmentPreviewSummaries._(query);

  final Future<dynamic> Function(String path) _query;
  final _cache = <String, AttachmentPreviewSummary>{};
  final _flights = <String, Future<AttachmentPreviewSummary?>>{};

  AttachmentPreviewSummary? cached(String attachmentId) => _cache[attachmentId];

  /// The summary, or null when there is none (refused, unreadable, failed).
  /// A refusal other than the transient `unavailable` is final for the session
  /// only in the sense that it is not asked again while the card is alive;
  /// failures are not cached.
  Future<AttachmentPreviewSummary?> fetch(String attachmentId) {
    final known = _cache[attachmentId];
    if (known != null) return Future.value(known);
    return _flights[attachmentId] ??= _load(attachmentId).whenComplete(() {
      // A block body: returning the removed future would make this wait for itself.
      _flights.remove(attachmentId);
    });
  }

  Future<AttachmentPreviewSummary?> _load(String attachmentId) async {
    try {
      final summary = AttachmentPreviewSummary.parse(
        await _query('/attachments/$attachmentId/preview'),
      );
      if (summary != null) _cache[attachmentId] = summary;
      return summary;
    } on RaftApiException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
