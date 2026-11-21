import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

@immutable
class ThreadOutlineItem {
  const ThreadOutlineItem({
    required this.id,
    required this.seq,
    required this.senderId,
    required this.senderName,
    required this.preview,
    required this.createdAt,
    required this.attachmentCount,
  });

  static ThreadOutlineItem? read(Object? value) {
    if (value is! Map || value['id'] is! String) return null;
    final seq = BigInt.tryParse('${value['seq']}');
    if (seq == null) return null;
    final row = RaftRecord(Map<String, dynamic>.from(value));
    return ThreadOutlineItem(
      id: row.id,
      seq: seq,
      senderId: row.string('senderId'),
      senderName: row.string('senderName'),
      preview: row.string('preview'),
      createdAt: DateTime.tryParse(row.string('createdAt')),
      attachmentCount: row.json['attachmentCount'] as int? ?? 0,
    );
  }

  final String id, senderId, senderName, preview;
  final BigInt seq;
  final DateTime? createdAt;
  final int attachmentCount;
}

/// Web's outline is a separate, memory-only index. The chat window still
/// owns reply bodies and navigation.
class ThreadOutline extends ChangeNotifier {
  ThreadOutline({
    required this.channelId,
    required this.userId,
    this.preferredTimezone,
    this.preferredTimeFormat,
    required this._query,
    required this._isCurrent,
    required this._position,
  });

  final String channelId;
  final String? userId;
  final String? preferredTimezone, preferredTimeFormat;
  final Future<Object?> Function(String, {Map<String, dynamic>? query}) _query;
  final bool Function() _isCurrent;
  final ({String? jump, BigInt? reading}) Function() _position;
  List<ThreadOutlineItem> _items = const [];
  List<ThreadOutlineItem> get items => current ? _items : const [];
  bool _hasMore = false, _disposed = false;
  BigInt? _visibleTop;
  String? _leadingId;

  void updateVisibleTop({BigInt? seq, String? leadingId}) {
    if (!current || (_visibleTop == seq && _leadingId == leadingId)) return;
    final previous = currentId;
    _visibleTop = seq;
    _leadingId = leadingId;
    if (currentId != previous) notifyListeners();
    unawaited(_loadToVisibleTop());
  }

  String? get currentId {
    final (:jump, :reading) = _position();
    if (jump != null && items.any((item) => item.id == jump)) return jump;
    final leading = _leadingId;
    if (leading != null) {
      return items.firstOrNull?.id == leading ? leading : null;
    }
    final top = _visibleTop ?? reading;
    if (top != null) {
      return items.reversed.where((item) => item.seq <= top).firstOrNull?.id;
    }
    return items.lastOrNull?.id;
  }

  Future<void>? _newestRead, _olderRead;
  int _revision = 0;

  bool get current => !_disposed && _isCurrent();

  bool hasReplies(String parentId) =>
      items.where((item) => item.id != parentId).take(4).length == 4;

  Future<void> load() =>
      _newestRead ??= _read(null)
          .then((_) => _loadToVisibleTop())
          .whenComplete(() {
            _newestRead = null;
          });

  Future<void> _loadToVisibleTop() async {
    // The Web outline caps a single catch-up at ten pages.
    for (
      var page = 0;
      page < 10 && current && _hasMore && items.isNotEmpty;
      page++
    ) {
      final top = _leadingId == null ? _visibleTop : BigInt.zero;
      final before = items.first.seq;
      if (top == null || before <= top) return;
      await loadOlder();
      if (items.isEmpty || items.first.seq >= before) return;
    }
  }

  Future<void> loadOlder() {
    if (!_hasMore || items.isEmpty) return Future.value();
    return _olderRead ??= _read(items.first.seq).whenComplete(() {
      _olderRead = null;
    });
  }

  Future<void> _read(BigInt? before) async {
    final revision = before == null ? ++_revision : _revision;
    try {
      final response = await _query(
        '/messages/channel/$channelId/human-outline',
        query: {'limit': 200, if (before != null) 'before': '$before'},
      );
      if (!current || revision != _revision || response is! Map) return;
      final raw = response['items'];
      if (raw is! List) return;
      final page = raw.reversed.map(ThreadOutlineItem.read).nonNulls.toList();
      _items = List.unmodifiable(
        before == null
            ? [
                ...page,
                ..._items.where(
                  (item) => page.isNotEmpty && item.seq > page.last.seq,
                ),
              ]
            : [...page, ..._items],
      );
      _hasMore = response['hasMore'] == true;
      notifyListeners();
    } catch (_) {
      // Web keeps the previously accepted outline on a failed request.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void note(RaftEvent event) {
    final row = event.payload;
    if (!current || row is! Map) return;
    final message = RaftMessage(Map<String, dynamic>.from(row));
    if (event.name == 'message:updated' &&
        message.retracted &&
        (message.channelId == channelId || message.threadId == channelId)) {
      final next = _items.where((item) => item.id != message.id).toList();
      if (next.length == _items.length) return;
      _items = List.unmodifiable(next);
      notifyListeners();
    }
    if (event.name != 'message:new' ||
        message.channelId != channelId ||
        message.string('senderType') != 'user' ||
        message.string('messageType') == 'system' ||
        row['delegatedBy'] != null ||
        row['delegatedByAgentId'] != null ||
        message.retracted ||
        message.seq <= BigInt.zero ||
        _items.any((item) => item.id == message.id)) {
      return;
    }
    final content = String.fromCharCodes(message.content.runes.take(1000))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    _items = List.unmodifiable(
      [
        ..._items,
        ThreadOutlineItem(
          id: message.id,
          seq: message.seq,
          senderId: message.senderId,
          senderName: message.string('senderName'),
          preview: String.fromCharCodes(content.runes.take(400)),
          createdAt: message.createdAt,
          attachmentCount: (row['attachments'] as List?)?.length ?? 0,
        ),
      ]..sort((a, b) => a.seq.compareTo(b.seq)),
    );
    notifyListeners();
  }
}
