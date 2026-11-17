import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

class ChannelActivityWindow {
  final messages = <String, RaftMessage>{};
  final bumps = <String, String>{};
  final refresh = RaftIdleTimer(yieldToAnimation: false);
  String? nextCursor;
  bool hasMore = false, historyLimited = false;
  bool loading = false, loadingOlder = false;
  int generation = 0;
}

int _time(Object? value) =>
    DateTime.tryParse('$value')?.millisecondsSinceEpoch ?? 0;

int channelActivityKey(RaftMessage message, Object? summary, String? bump) {
  var key = _time(message.json['createdAt']);
  for (final stamp in [
    if (summary is Map) summary['lastReplyAt'],
    bump,
    message.json['activityAt'],
  ]) {
    final time = _time(stamp);
    if (time > key) key = time;
  }
  return key;
}

/// Web channelActivityStore.buildActivityTimeline. The seq copy owns content;
/// the page keeps activityAt and the oldest loaded boundary independently.
List<RaftMessage> buildChannelActivityTimeline(
  String channelId,
  List<RaftMessage> seqMessages,
  ChannelActivityWindow? window,
  Map<String, dynamic> summaries,
) {
  final byId = <String, RaftMessage>{...?window?.messages};
  for (final message in seqMessages) {
    if (message.channelId == channelId) byId[message.id] = message;
  }
  final keys = <String, int>{};
  for (final message in byId.values) {
    var key = channelActivityKey(
      message,
      summaries[message.id],
      window?.bumps[message.id],
    );
    final paged = _time(window?.messages[message.id]?.json['activityAt']);
    if (paged > key) key = paged;
    keys[message.id] = key;
  }
  final rows = byId.values.toList()
    ..sort((a, b) {
      final activity = keys[a.id]!.compareTo(keys[b.id]!);
      if (activity != 0) return activity;
      if (!a.json.containsKey('seq')) return b.json.containsKey('seq') ? 1 : 0;
      if (!b.json.containsKey('seq')) return -1;
      return a.seq.compareTo(b.seq);
    });
  if (window?.hasMore == true) {
    final floor = rows.indexWhere((m) => window!.messages.containsKey(m.id));
    if (floor > 0) return rows.sublist(floor);
  }
  return rows;
}

class ChannelActivityStore extends ChangeNotifier {
  ChannelActivityStore(this.read, {this.acceptSummaries});
  final Future<dynamic> Function(String id, String? before) read;
  final void Function(String id, dynamic summaries)? acceptSummaries;
  final windows = <String, ChannelActivityWindow>{};
  final _retained = <String, int>{};
  int _generation = 0;
  bool _ended = false;

  VoidCallback retain(String id) {
    _retained[id] = (_retained[id] ?? 0) + 1;
    final retainedWindow = windows.putIfAbsent(id, ChannelActivityWindow.new);
    unawaited(loadLatest(id));
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (!identical(windows[id], retainedWindow)) return;
      final left = (_retained[id] ?? 1) - 1;
      if (left > 0) {
        _retained[id] = left;
      } else {
        _retained.remove(id);
        windows.remove(id)?.refresh.cancel();
      }
    };
  }

  bool _current(String id, ChannelActivityWindow window, int generation) =>
      !_ended &&
      identical(windows[id], window) &&
      window.generation == generation;

  void _accept(String id, ChannelActivityWindow window, Map page) {
    final raw = page['messages'];
    if (raw is List) {
      for (final value in raw.whereType<Map>()) {
        if (value['id'] is! String || value['channelId'] != id) continue;
        final prior = window.messages[value['id']];
        window.messages[value['id']] = RaftMessage({
          ...?prior?.json,
          ...Map<String, dynamic>.from(value),
          if (value['activityAt'] == null && prior?.json['activityAt'] != null)
            'activityAt': prior!.json['activityAt'],
        });
      }
    }
    acceptSummaries?.call(id, page['threadSummariesByParentMessageId']);
  }

  void _cursor(ChannelActivityWindow window, Map page) {
    window.nextCursor = page['nextCursor'] as String?;
    window.hasMore = page['hasMore'] == true;
    window.historyLimited = page['historyLimited'] == true;
  }

  Future<void> loadLatest(String id) async {
    final window = windows[id];
    if (_ended || window == null) return;
    final generation = window.generation = ++_generation;
    window.loading = true;
    window.loadingOlder = false;
    notifyListeners();
    try {
      final page = await read(id, null);
      if (!_current(id, window, generation)) return;
      if (page is! Map) throw const FormatException('Invalid activity page');
      final keepOlder = window.messages.isNotEmpty && window.nextCursor != null;
      _accept(id, window, page);
      if (!keepOlder) _cursor(window, page);
      window.loading = false;
      notifyListeners();
    } catch (_) {
      if (!_current(id, window, generation)) return;
      window.loading = false;
      notifyListeners();
    }
  }

  Future<void> loadOlder(String id) async {
    final window = windows[id];
    if (_ended ||
        window == null ||
        window.loading ||
        window.loadingOlder ||
        !window.hasMore ||
        window.nextCursor == null) {
      return;
    }
    final generation = window.generation;
    window.loadingOlder = true;
    notifyListeners();
    try {
      final page = await read(id, window.nextCursor);
      if (!_current(id, window, generation)) return;
      if (page is! Map) throw const FormatException('Invalid activity page');
      _accept(id, window, page);
      _cursor(window, page);
    } catch (_) {
      if (!_current(id, window, generation)) return;
    }
    window.loadingOlder = false;
    notifyListeners();
  }

  void noteReply(
    String parentId,
    String? at,
    String? channelId, {
    required bool Function(String id, String parent) inSeq,
  }) {
    if (at == null) return;
    channelId ??= windows.entries
        .where((e) => e.value.messages.containsKey(parentId))
        .firstOrNull
        ?.key;
    final window = windows[channelId];
    if (window == null || channelId == null) return;
    if (_time(window.bumps[parentId]) >= _time(at)) return;
    window.bumps[parentId] = at;
    notifyListeners();
    if (window.messages.containsKey(parentId) ||
        inSeq(channelId, parentId) ||
        window.refresh.isActive) {
      return;
    }
    final id = channelId;
    window.refresh.start(const Duration(milliseconds: 500), () {
      if (identical(windows[id], window)) unawaited(loadLatest(id));
    });
  }

  void patch(Map<String, dynamic> row) {
    final window = windows[row['channelId']];
    final old = window?.messages[row['id']];
    if (old == null) return;
    window!.messages[old.id] = RaftMessage({...old.json, ...row});
    notifyListeners();
  }

  void reset() {
    for (final window in windows.values) {
      window.refresh.cancel();
    }
    windows.clear();
    _retained.clear();
    if (!_ended) notifyListeners();
  }

  @override
  void dispose() {
    _ended = true;
    reset();
    super.dispose();
  }
}
