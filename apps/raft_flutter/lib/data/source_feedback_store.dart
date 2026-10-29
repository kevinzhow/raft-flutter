import 'dart:convert';

import 'package:flutter/foundation.dart';

typedef FeedbackGet = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});

/// Web handsFeedbackTransport writes: a JSON body ([json]) or a multipart
/// form ([form]: fields + `attachments` files), upload progress 0..1, and an
/// abort handle (Web's AbortController signal).
typedef FeedbackPost = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? json,
  SourceFeedbackForm? form,
  ValueChanged<double>? onProgress,
  SourceFeedbackAbort? abort,
});

/// In-memory, account-owned projection (Web keeps no feedback cache either).
/// Errors are the closed hands-feedback FeedbackTransportError set; no
/// server text is ever rendered.
enum SourceFeedbackError {
  unavailable,
  unauthorized,
  notFound,
  rateLimited,
  conflict,
  invalid,
}

/// Web handsFeedbackTransport.feedbackTransportError: response code first,
/// then 401/403, otherwise unavailable.
SourceFeedbackError sourceFeedbackErrorFor(String? code, int? status) =>
    switch (code) {
      'feedback_submission_conflict' ||
      'feedback_comment_conflict' => SourceFeedbackError.conflict,
      'feedback_not_found' => SourceFeedbackError.notFound,
      'feedback_rate_limited' => SourceFeedbackError.rateLimited,
      'feedback_invalid' ||
      'feedback_attachment_too_large' ||
      'feedback_attachment_type_invalid' ||
      'feedback_attachment_count_invalid' ||
      'feedback_upload_invalid' => SourceFeedbackError.invalid,
      _ =>
        status == 401 || status == 403
            ? SourceFeedbackError.unauthorized
            : SourceFeedbackError.unavailable,
    };

/// hands-feedback components.tsx: MAX_FEEDBACK_ATTACHMENTS,
/// MAX_FEEDBACK_ATTACHMENT_BYTES, FEEDBACK_ATTACHMENT_TYPES.
const sourceFeedbackMaxAttachments = 3;
const sourceFeedbackMaxAttachmentBytes = 10 * 1024 * 1024;
const sourceFeedbackAttachmentTypes = [
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
];

/// ComposerInput `maxLength={10_000}` / TextareaCounter limit.
const sourceFeedbackMessageLimit = 10000;

/// A locally picked file (the File the Web input yields).
@immutable
class SourceFeedbackFile {
  const SourceFeedbackFile({
    required this.name,
    required this.contentType,
    required this.bytes,
    this.declaredSize,
  });
  final String name, contentType;

  /// Empty for a file rejected by size before it was read.
  final Uint8List bytes;

  /// The picker's file length when [bytes] were not read.
  final int? declaredSize;
  int get size => declaredSize ?? bytes.length;
}

@immutable
class SourceFeedbackForm {
  const SourceFeedbackForm(this.fields, this.attachments);
  final Map<String, String> fields;
  final List<SourceFeedbackFile> attachments;
}

/// Abort handle for an in-flight write (AbortController).
class SourceFeedbackAbort {
  final _listeners = <VoidCallback>[];
  bool aborted = false;
  void onAbort(VoidCallback listener) =>
      aborted ? listener() : _listeners.add(listener);
  void abort() {
    if (aborted) return;
    aborted = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }
}

enum SourceFeedbackUploadState { ready, uploading, failed }

/// PendingAttachment: a picked file in a composer with its upload state.
@immutable
class SourceFeedbackPending {
  const SourceFeedbackPending(
    this.id,
    this.file, {
    this.progress = 0,
    this.state = SourceFeedbackUploadState.ready,
  });
  final String id;
  final SourceFeedbackFile file;
  final double progress;
  final SourceFeedbackUploadState state;
  SourceFeedbackPending copyWith({
    double? progress,
    SourceFeedbackUploadState? state,
  }) => SourceFeedbackPending(
    id,
    file,
    progress: progress ?? this.progress,
    state: state ?? this.state,
  );
}

enum SourceFeedbackAttachmentIssue { tooMany, unsupported, tooLarge }

/// What a composer banner shows: a transport error or an attachment check
/// (`attachmentTooMany` / `attachmentUnsupported` / `attachmentTooLarge`).
@immutable
class SourceFeedbackProblem {
  const SourceFeedbackProblem.transport(SourceFeedbackError this.error)
    : attachment = null,
      name = null;
  const SourceFeedbackProblem.attachment(
    SourceFeedbackAttachmentIssue this.attachment, [
    this.name,
  ]) : error = null;
  final SourceFeedbackError? error;
  final SourceFeedbackAttachmentIssue? attachment;
  final String? name;
}

/// validateFeedbackAttachments + localizedAttachmentError.
SourceFeedbackProblem? sourceFeedbackAttachmentProblem(
  List<SourceFeedbackFile> files,
) {
  if (files.length > sourceFeedbackMaxAttachments) {
    return const SourceFeedbackProblem.attachment(
      SourceFeedbackAttachmentIssue.tooMany,
    );
  }
  for (final file in files) {
    if (!sourceFeedbackAttachmentTypes.contains(file.contentType)) {
      return SourceFeedbackProblem.attachment(
        SourceFeedbackAttachmentIssue.unsupported,
        file.name,
      );
    }
  }
  for (final file in files) {
    if (file.size > sourceFeedbackMaxAttachmentBytes) {
      return SourceFeedbackProblem.attachment(
        SourceFeedbackAttachmentIssue.tooLarge,
        file.name,
      );
    }
  }
  return null;
}

/// Reporter close reasons (ReporterClosureReason).
enum SourceFeedbackCloseReason {
  completed('completed'),
  noLongerNeeded('no_longer_needed');

  const SourceFeedbackCloseReason(this.wire);
  final String wire;

  /// defaultReporterClosureReason: resolved -> completed.
  static SourceFeedbackCloseReason defaultFor(String status) =>
      status == 'resolved' ? completed : noLongerNeeded;
}

/// The pending Close ticket confirmation (FeedbackCloseDialog).
@immutable
class SourceFeedbackCloseRequest {
  const SourceFeedbackCloseRequest(this.ticketId, this.reason, this.detail);
  final String ticketId;
  final SourceFeedbackCloseReason reason;

  /// Opened from the ticket conversation (else from an inbox row).
  final bool detail;
}

enum SourceFeedbackRoute { inbox, create, ticket }

/// Live-region announcements (`feedbackCreated`, `replySent`,
/// `ticketClosed`, `uploadCanceled`).
enum SourceFeedbackAnnouncement { created, replySent, closed, uploadCanceled }

class SourceFeedbackFailure implements Exception {
  const SourceFeedbackFailure(this.error);
  final SourceFeedbackError error;
}

enum SourceFeedbackFilter { all, open, resolved }

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) throw const FormatException('Invalid feedback projection');
  return Map<String, dynamic>.from(value);
}

String _string(Map<String, dynamic> value, String key) {
  final raw = value[key];
  if (raw is! String) throw const FormatException('Invalid feedback field');
  return raw;
}

int _integer(Map<String, dynamic> value, String key) {
  final raw = value[key];
  if (raw is! int || raw < 0) {
    throw const FormatException('Invalid feedback count');
  }
  return raw;
}

String? _cursor(Map<String, dynamic> value, String key) {
  final raw = value[key];
  if (raw == null) return null;
  if (raw is! String || raw.isEmpty) {
    throw const FormatException('Invalid feedback cursor');
  }
  return raw;
}

List<T> _rows<T>(dynamic value, T Function(dynamic) parse) {
  if (value is! List) throw const FormatException('Invalid feedback page');
  return value.map(parse).toList(growable: false);
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

@immutable
class SourceFeedbackTicket {
  const SourceFeedbackTicket({
    required this.id,
    required this.kind,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
    required this.unread,
    required this.unreadCount,
    required this.attachmentCount,
    required this.commentCount,
    this.closureReason,
  });
  factory SourceFeedbackTicket.parse(dynamic raw) {
    final v = _map(raw), id = _string(_map(raw), 'id');
    final status = _string(v, 'status'), kind = _string(v, 'kind');
    if (!_uuid.hasMatch(id) ||
        !['open', 'in_progress', 'resolved', 'closed'].contains(status) ||
        !['feedback', 'bug', 'crash'].contains(kind) ||
        v['unread'] is! bool) {
      throw const FormatException('Invalid feedback ticket');
    }
    return SourceFeedbackTicket(
      id: id,
      kind: kind == 'feedback' ? 'feedback' : 'bug',
      status: status,
      message: _string(v, 'message'),
      createdAt: _integer(v, 'created_at'),
      updatedAt: _integer(v, 'updated_at'),
      unread: v['unread'] as bool,
      unreadCount: _integer(v, 'unread_count'),
      attachmentCount: _integer(v, 'attachment_count'),
      commentCount: _integer(v, 'comment_count'),
      closureReason: v['closure_reason'] is String
          ? v['closure_reason'] as String
          : null,
    );
  }
  final String id, kind, status, message;
  final int createdAt, updatedAt, unreadCount, attachmentCount, commentCount;
  final bool unread;
  final String? closureReason;

  /// Source components.js419: title and open aria-label use only the first line.
  String get title => message.split('\n').first;

  /// An unread flag always renders a badge, even with a zero projected count.
  int get badgeCount => unreadCount < 1 ? 1 : unreadCount;
  String get badgeLabel => unreadCount > 99 ? '99+' : '$badgeCount';
  SourceFeedbackTicket read() => SourceFeedbackTicket(
    id: id,
    kind: kind,
    status: status,
    message: message,
    createdAt: createdAt,
    updatedAt: updatedAt,
    unread: false,
    unreadCount: 0,
    attachmentCount: attachmentCount,
    commentCount: commentCount,
    closureReason: closureReason,
  );
}

@immutable
class SourceFeedbackComment {
  const SourceFeedbackComment(
    this.id,
    this.authorType,
    this.body,
    this.createdAt,
  );
  factory SourceFeedbackComment.parse(dynamic raw) {
    final v = _map(raw), author = _string(_map(raw), 'author_type');
    if (!['reporter', 'staff', 'system'].contains(author)) {
      throw const FormatException('Invalid feedback author');
    }
    return SourceFeedbackComment(
      _string(v, 'id'),
      author,
      _string(v, 'body'),
      _integer(v, 'created_at'),
    );
  }
  final String id, authorType, body;
  final int createdAt;
}

@immutable
class SourceFeedbackAttachment {
  const SourceFeedbackAttachment(
    this.filename,
    this.size, {
    this.contentType = 'application/octet-stream',
    this.id = '',
  });
  factory SourceFeedbackAttachment.parse(dynamic raw) {
    final v = _map(raw);
    return SourceFeedbackAttachment(
      _string(v, 'filename'),
      _integer(v, 'size_bytes'),
      id: v['id'] is String ? v['id'] as String : '',
      contentType: v['content_type'] is String
          ? v['content_type'] as String
          : 'application/octet-stream',
    );
  }
  // Metadata and the attachment's id; the bytes are read on demand through the
  // account-authenticated route, never from a stored URL or capability.
  final String filename, contentType, id;
  final int size;
}

/// One authoritative GET /product-feedback/tickets/:id read.
@immutable
class _Detail {
  const _Detail(
    this.ticket,
    this.comments,
    this.attachments,
    this.next,
    this.unread,
  );
  factory _Detail.parse(dynamic value, String id, String? cursor) {
    final raw = _map(value);
    final ticket = SourceFeedbackTicket.parse(raw['ticket']);
    final next = _cursor(raw, 'next_comment_cursor');
    if (ticket.id != id || (next != null && next == cursor)) {
      throw const FormatException('Invalid feedback detail scope');
    }
    return _Detail(
      ticket,
      _rows(raw['comments'], SourceFeedbackComment.parse),
      _rows(raw['attachments'], SourceFeedbackAttachment.parse),
      next,
      _integer(raw, 'unread_total'),
    );
  }
  final SourceFeedbackTicket ticket;
  final List<SourceFeedbackComment> comments;
  final List<SourceFeedbackAttachment> attachments;
  final String? next;
  final int unread;
}

List<SourceFeedbackComment> _sortedComments(
  Iterable<SourceFeedbackComment> comments,
) => comments.toList()
  ..sort((a, b) {
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.id.compareTo(b.id);
  });

/// Authority must include origin/principal/server/role/session and view windows.
/// Host calls syncAuthority immediately on every authority notification.
///
/// Writes follow hands-feedback FeedbackWorkspace: create, reply and close
/// are confirmed (never optimistic). Each POST is followed by the detail GET
/// the Web transport performs, and only that authoritative detail updates
/// the conversation, the inbox row and the unread total.
class SourceFeedbackStore extends ChangeNotifier {
  SourceFeedbackStore({
    required this.get,
    required this.authority,
    this.post,
    this.newId,
    this.onUnreadChanged,
  }) : _authority = authority();
  final FeedbackGet get;
  final FeedbackPost? post;

  /// `crypto.randomUUID()` for submission ids and pending attachment ids.
  final String Function()? newId;
  final String? Function() authority;
  final ValueChanged<int>? onUnreadChanged;
  String? _authority;
  bool _disposed = false;
  int _listRequest = 0, _detailRequest = 0, _readRevision = 0, _ids = 0;
  List<SourceFeedbackTicket> _tickets = [];
  SourceFeedbackTicket? _detail;
  List<SourceFeedbackComment> _comments = [];
  List<SourceFeedbackAttachment> _attachments = [];
  String? _selectedId, _nextCursor, _nextCommentCursor;
  String? _retryListCursor, _retryCommentCursor;
  int? unreadTotal;
  bool listLoading = false, detailLoading = false;
  SourceFeedbackError? listError, detailError;
  SourceFeedbackFilter filter = SourceFeedbackFilter.all;

  // New feedback (NewFeedbackForm state; fresh on every open).
  bool _creating = false;
  String newKind = 'feedback', newMessage = '';
  List<SourceFeedbackPending> newAttachments = const [];
  bool newSending = false;
  SourceFeedbackProblem? newError;
  ({String fingerprint, String id})? _createSubmission;
  SourceFeedbackAbort? _createAbort;

  // Ticket conversation (FeedbackTicket state; drafts survive per ticket).
  final Map<String, String> _replyDrafts = {};
  List<SourceFeedbackPending> replyAttachments = const [];
  bool replySending = false;
  SourceFeedbackProblem? actionError;
  ({String fingerprint, String id})? _commentSubmission;
  SourceFeedbackAbort? _actionAbort;

  // Close ticket confirmation, from the conversation or an inbox row.
  SourceFeedbackCloseRequest? closeRequest;
  bool closing = false;
  SourceFeedbackError? _inboxCloseError;
  SourceFeedbackAbort? _inboxCloseAbort;

  SourceFeedbackAnnouncement? announcement;
  int announcementRevision = 0;

  List<SourceFeedbackTicket> get tickets => List.unmodifiable(_tickets);
  SourceFeedbackTicket? get detail => _detail;
  List<SourceFeedbackComment> get comments => List.unmodifiable(_comments);
  List<SourceFeedbackAttachment> get attachments =>
      List.unmodifiable(_attachments);
  String? get selectedId => _selectedId;
  String? get nextCursor => _nextCursor;
  String? get nextCommentCursor => _nextCommentCursor;
  bool get canWrite => post != null;
  SourceFeedbackRoute get route => _selectedId != null
      ? SourceFeedbackRoute.ticket
      : _creating
      ? SourceFeedbackRoute.create
      : SourceFeedbackRoute.inbox;
  String get reply => _replyDrafts[_selectedId] ?? '';

  /// FeedbackCloseDialog `error`: the conversation's action error (only
  /// while the dialog is open) or the inbox close error.
  SourceFeedbackError? get closeError => closeRequest == null
      ? null
      : closeRequest!.detail
      ? actionError?.error
      : _inboxCloseError;
  bool get authorized =>
      !_disposed && _authority != null && authority() == _authority;
  List<SourceFeedbackTicket> get visibleTickets => ticketsForFilter(filter);

  List<SourceFeedbackTicket> ticketsForFilter(SourceFeedbackFilter filter) =>
      _tickets
          .where(
            (t) => switch (filter) {
              SourceFeedbackFilter.all => true,
              SourceFeedbackFilter.open =>
                t.status == 'open' || t.status == 'in_progress',
              SourceFeedbackFilter.resolved =>
                t.status == 'resolved' || t.status == 'closed',
            },
          )
          .toList(growable: false);

  String _nextId() => newId?.call() ?? 'local-${++_ids}';

  void _resetNew() {
    _createAbort?.abort();
    _createAbort = null;
    _createSubmission = null;
    newKind = 'feedback';
    newMessage = '';
    newAttachments = const [];
    newSending = false;
    newError = null;
  }

  void _resetConversation() {
    _actionAbort?.abort();
    _actionAbort = null;
    _commentSubmission = null;
    replyAttachments = const [];
    replySending = false;
    actionError = null;
    if (closeRequest?.detail ?? false) closeRequest = null;
    if (closeRequest == null) closing = false;
  }

  void _clear() {
    _listRequest++;
    _detailRequest++;
    _readRevision++;
    _tickets = [];
    _detail = null;
    _comments = [];
    _attachments = [];
    _selectedId = _nextCursor = _nextCommentCursor = null;
    _retryListCursor = _retryCommentCursor = null;
    unreadTotal = null;
    listLoading = detailLoading = false;
    listError = detailError = null;
    filter = SourceFeedbackFilter.all;
    _creating = false;
    _resetNew();
    _resetConversation();
    _replyDrafts.clear();
    _inboxCloseAbort?.abort();
    _inboxCloseAbort = null;
    _inboxCloseError = null;
    closeRequest = null;
    closing = false;
    announcement = null;
  }

  bool syncAuthority() {
    if (_disposed) return false;
    final next = authority();
    if (_authority == next) return false;
    _authority = next;
    _clear();
    notifyListeners();
    return true;
  }

  bool _accepts(String? scope) => authorized && _authority == scope;
  void setFilter(SourceFeedbackFilter value) {
    syncAuthority();
    if (!authorized || filter == value) return;
    filter = value;
    notifyListeners();
  }

  SourceFeedbackError _error(Object e) =>
      e is SourceFeedbackFailure ? e.error : SourceFeedbackError.unavailable;

  void _publishUnread(int count) {
    unreadTotal = count;
    onUnreadChanged?.call(count);
  }

  void _announce(SourceFeedbackAnnouncement value) {
    announcement = value;
    announcementRevision++;
  }

  /// limit20 and cursor are the mounted inbox contract; filtering is local.
  Future<void> loadList({bool more = false, bool retry = false}) async {
    syncAuthority();
    if (!authorized || listLoading) return;
    final cursor = retry
        ? _retryListCursor
        : more
        ? _nextCursor
        : null;
    if (more && cursor == null) return;
    final scope = _authority,
        request = ++_listRequest,
        readRevision = _readRevision;
    listLoading = true;
    listError = null;
    notifyListeners();
    if (!_accepts(scope) || request != _listRequest) {
      syncAuthority();
      return;
    }
    try {
      final raw = _map(
        await get(
          '/product-feedback/tickets',
          query: {'limit': 20, 'cursor': ?cursor},
        ),
      );
      final rows = _rows(raw['tickets'], SourceFeedbackTicket.parse);
      final next = _cursor(raw, 'next_cursor'),
          unread = _integer(raw, 'unread_total');
      if (next != null && next == cursor) {
        throw const FormatException('Repeated feedback cursor');
      }
      if (!_accepts(scope) || request != _listRequest) return;
      // Detail GET advanced the read-through cursor after this list began.
      // Its old total and ticket unread flags cannot overwrite that receipt.
      if (readRevision != _readRevision) return;
      final merged = <String, SourceFeedbackTicket>{
        if (cursor != null)
          for (final ticket in _tickets) ticket.id: ticket,
        for (final ticket in rows) ticket.id: ticket,
      };
      _tickets = merged.values.toList(growable: false);
      _nextCursor = next;
      _retryListCursor = null;
      _publishUnread(unread);
    } catch (e) {
      if (_accepts(scope) && request == _listRequest) {
        final error = _error(e);
        if (error == SourceFeedbackError.unauthorized) {
          _clear();
        }
        listError = error;
        _retryListCursor = cursor;
        if (error == SourceFeedbackError.unauthorized) notifyListeners();
      }
    } finally {
      if (_accepts(scope) && request == _listRequest) {
        listLoading = false;
        notifyListeners();
      } else {
        syncAuthority();
      }
    }
  }

  /// FeedbackInbox onSelectTicket: the row summary is the first frame
  /// (previewTicketDetail) until the detail GET answers.
  Future<void> openTicket(String id) async {
    syncAuthority();
    if (!authorized || !_uuid.hasMatch(id)) return;
    _show(id, preview: _tickets.where((t) => t.id == id).firstOrNull);
    await loadDetail();
  }

  void _show(String id, {SourceFeedbackTicket? preview}) {
    _detailRequest++;
    _creating = false;
    _resetNew();
    _resetConversation();
    _selectedId = id;
    _detail = preview;
    _comments = [];
    _attachments = [];
    _nextCommentCursor = _retryCommentCursor = null;
    detailLoading = false;
    detailError = null;
  }

  void _applyDetail(_Detail result, {String? cursor}) {
    final merged = <String, SourceFeedbackComment>{
      if (cursor != null)
        for (final comment in _comments) comment.id: comment,
      for (final comment in result.comments) comment.id: comment,
    };
    _comments = _sortedComments(merged.values);
    _detail = result.ticket;
    _attachments = result.attachments;
    _nextCommentCursor = result.next;
  }

  /// Every detail GET, including comment pages, advances the source read cursor.
  Future<void> loadDetail({bool more = false, bool retry = false}) async {
    syncAuthority();
    final id = _selectedId;
    if (!authorized || id == null || detailLoading) return;
    final cursor = retry
        ? _retryCommentCursor
        : more
        ? _nextCommentCursor
        : null;
    if (more && cursor == null) return;
    final scope = _authority, request = ++_detailRequest;
    detailLoading = true;
    detailError = null;
    notifyListeners();
    if (!_accepts(scope) || request != _detailRequest || _selectedId != id) {
      syncAuthority();
      return;
    }
    try {
      final result = _Detail.parse(
        await get(
          '/product-feedback/tickets/${Uri.encodeComponent(id)}',
          query: {
            'comment_limit': 100,
            'comment_cursor': ?cursor,
          },
        ),
        id,
        cursor,
      );
      if (!_accepts(scope) || request != _detailRequest || _selectedId != id) {
        return;
      }
      _applyDetail(result, cursor: cursor);
      _retryCommentCursor = null;
      _markRead(id, result.ticket);
      _publishUnread(result.unread);
    } catch (e) {
      if (_accepts(scope) && request == _detailRequest && _selectedId == id) {
        final error = _error(e);
        if (error == SourceFeedbackError.unauthorized ||
            error == SourceFeedbackError.notFound) {
          _detail = null;
          _comments = [];
          _attachments = [];
          _nextCommentCursor = null;
        }
        if (error == SourceFeedbackError.unauthorized) {
          _clear();
          listError = error;
        }
        detailError = error;
        _retryCommentCursor = cursor;
        if (error == SourceFeedbackError.unauthorized) notifyListeners();
      }
    } finally {
      if (_accepts(scope) && request == _detailRequest && _selectedId == id) {
        detailLoading = false;
        notifyListeners();
      } else {
        syncAuthority();
      }
    }
  }

  /// onReadSuccess: the inbox row reads as read once a detail GET commits.
  void _markRead(String id, SourceFeedbackTicket ticket) {
    _tickets = _tickets
        .map((t) => t.id == id ? ticket.read() : t)
        .toList(growable: false);
    _readRevision++;
  }

  /// FeedbackInbox `upsertTicket`: a created or closed ticket moves to the
  /// top of the inbox without a list refetch.
  void _upsert(SourceFeedbackTicket ticket) {
    _tickets = [ticket, ..._tickets.where((t) => t.id != ticket.id)];
  }

  void back() {
    syncAuthority();
    if (!authorized) return;
    _detailRequest++;
    _selectedId = null;
    _creating = false;
    _resetNew();
    _resetConversation();
    _detail = null;
    _comments = [];
    _attachments = [];
    _nextCommentCursor = _retryCommentCursor = null;
    detailLoading = false;
    detailError = null;
    notifyListeners();
  }

  /// The authoritative read every write ends with (comment_limit 100).
  Future<_Detail> _readAfterWrite(String id) async => _Detail.parse(
    await get(
      '/product-feedback/tickets/${Uri.encodeComponent(id)}',
      query: {'comment_limit': 100},
    ),
    id,
    null,
  );

  ({String fingerprint, String id}) _stableSubmission(
    ({String fingerprint, String id})? previous,
    String fingerprint,
  ) => previous?.fingerprint == fingerprint
      ? previous!
      : (fingerprint: fingerprint, id: _nextId());

  static List<Object> _fileFingerprint(SourceFeedbackFile file) => [
    file.name,
    file.contentType,
    file.size,
  ];

  List<SourceFeedbackPending> _uploading(List<SourceFeedbackPending> items) => [
    for (final item in items)
      item.copyWith(state: SourceFeedbackUploadState.uploading, progress: 0),
  ];

  List<SourceFeedbackPending> _failed(List<SourceFeedbackPending> items) => [
    for (final item in items)
      item.state == SourceFeedbackUploadState.uploading
          ? item.copyWith(state: SourceFeedbackUploadState.failed)
          : item,
  ];

  List<SourceFeedbackPending> _progress(
    List<SourceFeedbackPending> items,
    double value,
  ) => [
    for (final item in items) item.copyWith(progress: value.clamp(0, 1)),
  ];

  /// Shared chooser check: the combined list must pass, else nothing is
  /// added and the banner explains why.
  (List<SourceFeedbackPending>, SourceFeedbackProblem?) _choose(
    List<SourceFeedbackPending> current,
    List<SourceFeedbackFile> selected,
  ) {
    final problem = sourceFeedbackAttachmentProblem([
      for (final item in current) item.file,
      ...selected,
    ]);
    if (problem != null) return (current, problem);
    return ([
      ...current,
      for (final file in selected) SourceFeedbackPending(_nextId(), file),
    ], null);
  }

  // ------------------------------------------------------------ create

  /// FeedbackInbox "New feedback": a fresh NewFeedbackForm.
  void startNew() {
    syncAuthority();
    if (!authorized || !canWrite) return;
    _detailRequest++;
    _selectedId = null;
    _detail = null;
    _comments = [];
    _attachments = [];
    _resetConversation();
    _resetNew();
    _creating = true;
    notifyListeners();
  }

  void setNewKind(String kind) {
    if (route != SourceFeedbackRoute.create || newKind == kind) return;
    newKind = kind == 'bug' ? 'bug' : 'feedback';
    notifyListeners();
  }

  void setNewMessage(String value) {
    if (route != SourceFeedbackRoute.create || newMessage == value) return;
    newMessage = value;
    notifyListeners();
  }

  void addNewAttachments(List<SourceFeedbackFile> files) {
    if (route != SourceFeedbackRoute.create || newSending || files.isEmpty) {
      return;
    }
    final (next, problem) = _choose(newAttachments, files);
    newAttachments = next;
    newError = problem;
    notifyListeners();
  }

  void removeNewAttachment(String id) {
    if (newSending) return;
    newAttachments = [
      for (final item in newAttachments)
        if (item.id != id) item,
    ];
    notifyListeners();
  }

  /// Cancel: aborts an in-flight submit (attachments back to ready, the
  /// form stays), otherwise returns to the inbox.
  void cancelNew() {
    if (route != SourceFeedbackRoute.create) return;
    if (newSending) {
      _createAbort?.abort();
      _createAbort = null;
      newSending = false;
      newAttachments = [
        for (final item in newAttachments)
          item.copyWith(state: SourceFeedbackUploadState.ready, progress: 0),
      ];
      _announce(SourceFeedbackAnnouncement.uploadCanceled);
      notifyListeners();
      return;
    }
    back();
  }

  bool get canSubmitNew => newMessage.trim().isNotEmpty && !newSending;

  /// NewFeedbackForm.submit: POST /product-feedback (multipart), then the
  /// detail GET; the created ticket opens and joins the top of the inbox.
  Future<void> submitNew() async {
    syncAuthority();
    final message = newMessage.trim();
    if (!authorized || post == null || !canSubmitNew) return;
    final files = [for (final item in newAttachments) item.file];
    final problem = sourceFeedbackAttachmentProblem(files);
    if (problem != null) {
      newError = problem;
      notifyListeners();
      return;
    }
    final scope = _authority;
    newSending = true;
    newError = null;
    newAttachments = _uploading(newAttachments);
    _createAbort?.abort();
    final abort = _createAbort = SourceFeedbackAbort();
    final submission = _createSubmission = _stableSubmission(
      _createSubmission,
      jsonEncode([newKind, message, for (final f in files) _fileFingerprint(f)]),
    );
    notifyListeners();
    bool live() => !abort.aborted && _accepts(scope) && _createAbort == abort;
    try {
      final created = _map(
        await post!(
          '/product-feedback',
          form: SourceFeedbackForm({
            'type': newKind == 'feedback' ? 'idea' : 'problem',
            'message': message,
            'submission_id': submission.id,
            'may_contact': 'false',
          }, files),
          onProgress: (value) {
            if (!live()) return;
            newAttachments = _progress(newAttachments, value);
            notifyListeners();
          },
          abort: abort,
        ),
      );
      if (!live()) return;
      final id = _string(created, 'id');
      final result = await _readAfterWrite(id);
      if (!live()) return;
      _publishUnread(result.unread);
      _createAbort = null;
      _resetNew();
      _upsert(result.ticket);
      _show(id);
      _applyDetail(result);
      _announce(SourceFeedbackAnnouncement.created);
      notifyListeners();
      // FeedbackTicket mounts and reads the ticket again (its read receipt
      // marks the row read); the created detail stays on screen meanwhile.
      await loadDetail();
    } catch (e) {
      if (!live()) return;
      newSending = false;
      newError = SourceFeedbackProblem.transport(_error(e));
      newAttachments = _failed(newAttachments);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ reply

  void setReply(String value) {
    final id = _selectedId;
    if (id == null || reply == value) return;
    _replyDrafts[id] = value;
    notifyListeners();
  }

  void addReplyAttachments(List<SourceFeedbackFile> files) {
    if (_selectedId == null || replySending || files.isEmpty) return;
    final (next, problem) = _choose(replyAttachments, files);
    replyAttachments = next;
    actionError = problem;
    notifyListeners();
  }

  void removeReplyAttachment(String id) {
    if (replySending) return;
    replyAttachments = [
      for (final item in replyAttachments)
        if (item.id != id) item,
    ];
    notifyListeners();
  }

  bool get canSendReply =>
      reply.trim().isNotEmpty &&
      !replySending &&
      (_detail?.status ?? 'closed') != 'closed';

  /// FeedbackTicket.send: POST .../comments (multipart), then the detail
  /// GET replaces the conversation and clears the draft.
  Future<bool> sendReply() async {
    syncAuthority();
    final id = _selectedId, body = reply.trim();
    if (!authorized || post == null || id == null || !canSendReply) {
      return false;
    }
    final files = [for (final item in replyAttachments) item.file];
    final problem = sourceFeedbackAttachmentProblem(files);
    if (problem != null) {
      actionError = problem;
      notifyListeners();
      return false;
    }
    final scope = _authority;
    replySending = true;
    actionError = null;
    replyAttachments = _uploading(replyAttachments);
    _actionAbort?.abort();
    final abort = _actionAbort = SourceFeedbackAbort();
    final submission = _commentSubmission = _stableSubmission(
      _commentSubmission,
      jsonEncode([body, for (final f in files) _fileFingerprint(f)]),
    );
    notifyListeners();
    bool live() =>
        !abort.aborted &&
        _accepts(scope) &&
        _actionAbort == abort &&
        _selectedId == id;
    try {
      await post!(
        '/product-feedback/tickets/${Uri.encodeComponent(id)}/comments',
        form: SourceFeedbackForm({
          'body': body,
          'submission_id': submission.id,
        }, files),
        onProgress: (value) {
          if (!live()) return;
          replyAttachments = _progress(replyAttachments, value);
          notifyListeners();
        },
        abort: abort,
      );
      if (!live()) return false;
      final result = await _readAfterWrite(id);
      if (!live()) return false;
      _publishUnread(result.unread);
      _detailRequest++;
      detailLoading = false;
      _applyDetail(result);
      _replyDrafts.remove(id);
      replyAttachments = const [];
      _commentSubmission = null;
      replySending = false;
      _actionAbort = null;
      _announce(SourceFeedbackAnnouncement.replySent);
      notifyListeners();
      return true;
    } catch (e) {
      if (!live()) return false;
      replySending = false;
      actionError = SourceFeedbackProblem.transport(_error(e));
      replyAttachments = _failed(replyAttachments);
      notifyListeners();
      return false;
    }
  }

  // ------------------------------------------------------------ close

  /// ReporterCloseSplitButton onChoose: opens the confirmation.
  void requestClose(String ticketId, SourceFeedbackCloseReason reason) {
    syncAuthority();
    if (!authorized || !canWrite || closing) return;
    final detail = _selectedId == ticketId;
    if (detail) {
      actionError = null;
    } else {
      _inboxCloseError = null;
    }
    closeRequest = SourceFeedbackCloseRequest(ticketId, reason, detail);
    notifyListeners();
  }

  /// FeedbackCloseDialog onOpenChange(false): ignored while closing.
  void dismissClose() {
    if (closing || closeRequest == null) return;
    if (!closeRequest!.detail) _inboxCloseError = null;
    closeRequest = null;
    notifyListeners();
  }

  /// POST .../close {reason}, then the detail GET. From the conversation the
  /// ticket also moves to the top of the inbox (onTicketUpdated); from a row
  /// it is replaced in place.
  Future<void> confirmClose() async {
    syncAuthority();
    final request = closeRequest;
    if (!authorized || post == null || request == null || closing) return;
    final scope = _authority, id = request.ticketId;
    closing = true;
    if (request.detail) {
      actionError = null;
      _actionAbort?.abort();
    } else {
      _inboxCloseError = null;
      _inboxCloseAbort?.abort();
    }
    final abort = SourceFeedbackAbort();
    if (request.detail) {
      _actionAbort = abort;
    } else {
      _inboxCloseAbort = abort;
    }
    notifyListeners();
    bool live() =>
        !abort.aborted &&
        _accepts(scope) &&
        closeRequest == request &&
        (!request.detail || _selectedId == id);
    try {
      await post!(
        '/product-feedback/tickets/${Uri.encodeComponent(id)}/close',
        json: {'reason': request.reason.wire},
        abort: abort,
      );
      if (!live()) return;
      final result = await _readAfterWrite(id);
      if (!live()) return;
      _publishUnread(result.unread);
      if (request.detail) {
        _detailRequest++;
        detailLoading = false;
        _applyDetail(result);
        _upsert(result.ticket);
        _actionAbort = null;
      } else {
        _tickets = [
          for (final t in _tickets) t.id == id ? result.ticket : t,
        ];
        _inboxCloseAbort = null;
      }
      closing = false;
      closeRequest = null;
      _announce(SourceFeedbackAnnouncement.closed);
      notifyListeners();
    } catch (e) {
      if (!live()) return;
      closing = false;
      if (request.detail) {
        actionError = SourceFeedbackProblem.transport(_error(e));
      } else {
        _inboxCloseError = _error(e);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _clear();
    super.dispose();
  }
}
