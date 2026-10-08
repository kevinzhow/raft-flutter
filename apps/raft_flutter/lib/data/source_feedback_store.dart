import 'package:flutter/foundation.dart';

typedef FeedbackGet = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});

/// In-memory, account-owned projection. No write, attachment, or cache transport.
enum SourceFeedbackError { unavailable, unauthorized, notFound, rateLimited }

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
  const SourceFeedbackAttachment(this.filename, this.size);
  factory SourceFeedbackAttachment.parse(dynamic raw) {
    final v = _map(raw);
    return SourceFeedbackAttachment(
      _string(v, 'filename'),
      _integer(v, 'size_bytes'),
    );
  }
  // Read-only metadata. No URL, private capability, or fetch action is retained.
  final String filename;
  final int size;
}

/// Authority must include origin/principal/server/role/session and view windows.
/// Host calls syncAuthority immediately on every authority notification.
class SourceFeedbackStore extends ChangeNotifier {
  SourceFeedbackStore({
    required this.get,
    required this.authority,
    this.onUnreadChanged,
  }) : _authority = authority();
  final FeedbackGet get;
  final String? Function() authority;
  final ValueChanged<int>? onUnreadChanged;
  String? _authority;
  bool _disposed = false;
  int _listRequest = 0, _detailRequest = 0, _readRevision = 0;
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

  List<SourceFeedbackTicket> get tickets => List.unmodifiable(_tickets);
  SourceFeedbackTicket? get detail => _detail;
  List<SourceFeedbackComment> get comments => List.unmodifiable(_comments);
  List<SourceFeedbackAttachment> get attachments =>
      List.unmodifiable(_attachments);
  String? get selectedId => _selectedId;
  String? get nextCursor => _nextCursor;
  String? get nextCommentCursor => _nextCommentCursor;
  bool get authorized =>
      !_disposed && _authority != null && authority() == _authority;
  List<SourceFeedbackTicket> get visibleTickets => _tickets
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

  Future<void> openTicket(String id) async {
    syncAuthority();
    if (!authorized || !_uuid.hasMatch(id)) return;
    _detailRequest++;
    _selectedId = id;
    _detail = null;
    _comments = [];
    _attachments = [];
    _nextCommentCursor = _retryCommentCursor = null;
    detailLoading = false;
    detailError = null;
    await loadDetail();
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
      final raw = _map(
        await get(
          '/product-feedback/tickets/${Uri.encodeComponent(id)}',
          query: {
            'comment_limit': 100,
            'comment_cursor': ?cursor,
          },
        ),
      );
      final ticket = SourceFeedbackTicket.parse(raw['ticket']);
      final rows = _rows(raw['comments'], SourceFeedbackComment.parse);
      final attachments = _rows(
        raw['attachments'],
        SourceFeedbackAttachment.parse,
      );
      final next = _cursor(raw, 'next_comment_cursor'),
          unread = _integer(raw, 'unread_total');
      if (ticket.id != id || (next != null && next == cursor)) {
        throw const FormatException('Invalid feedback detail scope');
      }
      if (!_accepts(scope) || request != _detailRequest || _selectedId != id) {
        return;
      }
      final merged = <String, SourceFeedbackComment>{
        if (cursor != null)
          for (final comment in _comments) comment.id: comment,
        for (final comment in rows) comment.id: comment,
      };
      _comments = merged.values.toList()
        ..sort((a, b) {
          final time = a.createdAt.compareTo(b.createdAt);
          return time != 0 ? time : a.id.compareTo(b.id);
        });
      _detail = ticket;
      _attachments = attachments;
      _nextCommentCursor = next;
      _retryCommentCursor = null;
      _tickets = _tickets
          .map((t) => t.id == id ? ticket.read() : t)
          .toList(growable: false);
      _readRevision++;
      _publishUnread(unread);
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

  void back() {
    syncAuthority();
    if (!authorized) return;
    _detailRequest++;
    _selectedId = null;
    _detail = null;
    _comments = [];
    _attachments = [];
    _nextCommentCursor = _retryCommentCursor = null;
    detailLoading = false;
    detailError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clear();
    super.dispose();
  }
}
