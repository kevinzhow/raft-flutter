// Reproduction for the Android single-pane Activity bug (candidate C): memory
// trimming (MessageHistoryMemory._releaseBodies) turns a conversation's held
// tail window into a context window (contextNewer / hasNewer flip), so live
// message:new events are no longer revealed (retainsLiveTail is false). The
// Activity tap on the new message must still show it with the newest messages,
// not loading, and a second tap/locate must recover.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/reading_positions.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;

class _Client extends HistoryClient {
  int end = 1000;
  int contextCalls = 0;

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    final last = before != null ? before.toInt() - 1 : end;
    final first = after != null ? after.toInt() + 1 : (last - limit + 1);
    final from = first.clamp(1, end);
    final to = (after != null ? from + limit - 1 : last).clamp(0, end);
    return {
      'messages': [for (var n = from; n <= to; n++) row(id, n)],
      'historyLimited': false,
    };
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final context = RegExp(r'^/messages/context/(\w+)-(\d+)$').firstMatch(path);
    if (context == null) return {};
    contextCalls++;
    final channel = context[1]!, target = int.parse(context[2]!);
    final from = (target - 15).clamp(1, end), to = (target + 15).clamp(1, end);
    return {
      'messages': [for (var n = from; n <= to; n++) row(channel, n)],
      'targetMessageId': '$channel-$target',
      'hasOlder': from > 1,
      'hasNewer': to < end,
    };
  }
}

void main() {
  // viewing: the conversation is still the selected one (hidden pane / app
  // backgrounded) when trimmed; otherwise the user already moved to another.
  for (final viewing in [true, false]) {
    test(
      'after memory release, a jump to a new message shows it with the newest messages; viewing=$viewing',
      () async {
        final db = DriftWorkspaceCache(NativeDatabase.memory()),
            client = _Client();
        final w = receiver(client, db);
        w.channels = [
          ...w.channels,
          RaftChannel({'id': 'other', 'type': 'private', 'joined': true}),
        ];
        try {
          await w.selectChannel(w.channels.first, autoRead: false);
          for (var n = 0; n < 19; n++) {
            await w.messageDomain.older();
          }
          // The reader had scrolled far up when leaving.
          w.messageDomain.saveReadingAnchor(
            'chat',
            ReadingAnchor('chat-43', -13),
          );
          await w.flushCache();
          if (!viewing) {
            client.end = 5;
            await w.selectChannel(w.channels.last, autoRead: false);
            client.end = 1000;
          } else {
            w.foreground = false;
          }
          await db.messageHistory.memory.maintain();
          final trimmed =
              'isContext=${w.messageWindows.isContext('chat')} '
              'contextHasNewer=${w.messageWindows.contextHasNewer('chat')} '
              'visible=${w.messageWindows.rows('chat').length}';

          // One new message arrives on the server and over the socket.
          client.end = 1001;
          client.arrivals.add(RaftEvent('message:new', row('chat', 1001)));
          await w.flushCache();
          w.foreground = true;

          for (final attempt in [1, 2]) {
            await w.jumpToMessage('chat', 'chat-1001', navigate: false);
            await db.messageHistory.reads.settled;
            final ids = w.messageDomain.messages.map((m) => m.id).toList();
            final reason =
                'attempt $attempt after trim [$trimmed]: '
                'channel=${w.channel?.id} loading=${w.messageDomain.state.channelLoading} '
                'hasNewer=${w.messageDomain.state.hasNewer} '
                'visible=${ids.isEmpty ? ids : '${ids.first}..${ids.last} (${ids.length})'} '
                'contextGETs=${client.contextCalls}';
            expect(w.channel?.id, 'chat', reason: reason);
            expect(
              w.messageDomain.state.channelLoading,
              isFalse,
              reason: reason,
            );
            expect(ids, contains('chat-1001'), reason: reason);
            expect(ids.last, 'chat-1001', reason: reason);
            expect(w.messageDomain.state.hasNewer, isFalse, reason: reason);
            expect(w.messageDomain.state.highlightedMessageId, 'chat-1001');
          }
        } finally {
          await w.flushCache();
          w.dispose();
          await client.arrivals.close();
          await db.close();
        }
      },
    );
  }
}
