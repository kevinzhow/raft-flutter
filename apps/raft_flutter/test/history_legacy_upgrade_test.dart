import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

/// Upgrade from the previous release's on-disk message windows: the old
/// `workspace_cache` kind `window` / `thread-window` rows must reach the new
/// message-history store without losing a row.

const _origin = 'https://history.invalid';
MessageHistoryScope _scope(String channel) => MessageHistoryScope(
  origin: _origin,
  principal: 'alice',
  server: 'one',
  channel: channel,
  parentChannel: channel,
  authority: 'member-chat',
);

Map<String, dynamic> _row(String channel, int seq) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': 'Saved $seq 中文',
};

Map<String, dynamic> _legacyWindow(
  String channel,
  int first,
  int last, {
  bool hasMore = false,
}) => {
  'version': 1,
  'windowKind': 'tail',
  'authority': 'member-chat',
  'parentChannelId': channel,
  'channelId': channel,
  'messages': [for (var n = first; n <= last; n++) _row(channel, n)],
  'hasMore': hasMore,
  'historyLimited': false,
};

void main() {
  late DriftWorkspaceCache cache;
  setUp(() => cache = DriftWorkspaceCache(NativeDatabase.memory()));
  tearDown(() => cache.close());

  Future<void> seedOld(String channel, Map<String, dynamic> window) =>
      cache.customStatement(
        'INSERT INTO workspace_cache(origin,principal,server,kind,id,payload) VALUES(?,?,?,?,?,?)',
        [_origin, 'alice', 'one', 'window', channel, jsonEncode(window)],
      );

  test('a migrated legacy window keeps every row it had', () async {
    await seedOld('chat', _legacyWindow('chat', 1, 30));
    final history = cache.messageHistory;
    while (await history.migrateLegacy(_scope('chat'), limit: 4) > 0) {}
    final page = await history.readPage(_scope('chat'));
    expect(page, isNotNull);
    expect(page!.rows.map((m) => m['id']), [
      for (var n = 1; n <= 30; n++) 'chat-$n',
    ]);
  });
}
