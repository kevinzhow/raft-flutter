import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/thread_window_snapshot.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_message_windows.dart';

Map<String, dynamic> _row(String channel, int seq) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': '$channel row $seq',
  'senderId': 'other',
  'senderType': 'user',
  'createdAt': '2026-10-15T00:00:00Z',
};

class _CountingMap extends MapBase<String, dynamic> {
  _CountingMap(this.backing);
  final Map<String, dynamic> backing;
  bool enabled = false;
  int reads = 0;
  @override
  dynamic operator [](Object? key) {
    if (enabled && key == 'channelCapabilities') reads++;
    return backing[key];
  }

  @override
  Iterable<String> get keys => backing.keys;
  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('Read-only fixture');
  @override
  void clear() => throw UnsupportedError('Read-only fixture');
  @override
  dynamic remove(Object? key) => throw UnsupportedError('Read-only fixture');
}

class _Channel extends RaftChannel {
  _Channel(String id) : super({'id': id, 'type': 'private', 'joined': true}) {
    counted = _CountingMap(super.json);
  }
  late final _CountingMap counted;
  @override
  Map<String, dynamic> get json => counted;
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://cached-window-work.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final injected = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => injected.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => [];
  @override
  Future<dynamic> post(String path, {dynamic data}) async =>
      path.endsWith('/read') ? {'maxReadSeq': 100, 'readStateVersion': 1} : {};
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {
    'messages': [_row(id, 1), _row(id, 2)],
    'threadSummariesByParentMessageId': {},
  };
}

Future<({int reads, int cached, int rows})> _measure(int extraWindows) async {
  final client = _Client();
  final channels = [
    _Channel('alpha'),
    for (var i = 0; i < 60; i++) _Channel('cached-$i'),
  ];
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's', 'role': 'owner'})
    ..channels = channels;
  try {
    w.messageDomain.ledger.switchServer('s');
    // Both controls start with exactly the same admitted bodies and catalog.
    // Creating more presentation windows below does not add ledger rows.
    for (final channel in channels) {
      w.messageWindows.acceptRows(liveWindowWrite, channel.id, [
        _row(channel.id, 1),
        _row(channel.id, 2),
      ], replace: true);
    }
    await w.selectChannel(channels.first, autoRead: false, navigate: false);
    expect(w.messageDomain.messageWindow, isNotNull);
    for (final channel in channels.skip(1).take(extraWindows)) {
      final window = w.messageWindows.channel(channel.id);
      expect(window, isNotNull);
      expect(window!.rows.map((row) => row.id), [
        '${channel.id}-1',
        '${channel.id}-2',
      ]);
    }
    final cached = w.messageWindows.retainedSnapshots.length;
    for (final channel in channels.skip(1)) {
      channel.counted
        ..reads = 0
        ..enabled = true;
    }
    client.injected.add(RaftEvent('message:new', _row('alpha', 3)));
    final reads = channels
        .skip(1)
        .fold<int>(0, (sum, channel) => sum + channel.counted.reads);
    for (final channel in channels.skip(1)) {
      channel.counted.enabled = false;
    }
    expect(w.messageDomain.messages.last.id, 'alpha-3');
    final rows = w.messageDomain.ledger.channelIds.fold<int>(
      0,
      (sum, id) => sum + w.messageDomain.ledger.messages(id).length,
    );
    return (reads: reads, cached: cached, rows: rows);
  } finally {
    w.dispose();
    await client.injected.close();
  }
}

/// What an on-screen image does: read the attachment index, which asks the
/// ledger to drop the incremental record it has applied.
void _readAttachmentIndex(WorkspaceController w) {
  w.attachmentRetentionIndex.retains(
    AttachmentImageKey(
      scope: w.attachmentImageScope,
      channelId: 'alpha',
      attachmentId: 'missing',
      revision: '0',
    ),
  );
}

/// Message one is published. Message two is committed, then an attachment
/// read asks to drop it, and only then do windows observe that notification.
Future<({int reads, int alphaReads, int cached})> _measureAttachmentGap(
  int extraWindows,
) async {
  final client = _Client();
  final channels = [
    _Channel('alpha'),
    for (var i = 0; i < 60; i++) _Channel('cached-$i'),
  ];
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's', 'role': 'owner'})
    ..channels = channels;
  try {
    w.messageDomain.ledger.switchServer('s');
    for (final channel in channels) {
      w.messageWindows.acceptRows(liveWindowWrite, channel.id, [
        _row(channel.id, 1),
        _row(channel.id, 2),
      ], replace: true);
    }
    await w.selectChannel(channels.first, autoRead: false, navigate: false);
    expect(w.messageDomain.messageWindow, isNotNull);
    for (final channel in channels.skip(1).take(extraWindows)) {
      expect(w.messageWindows.channel(channel.id), isNotNull);
    }
    client.injected.add(RaftEvent('message:new', _row('alpha', 3)));
    expect(w.messageDomain.messages.last.id, 'alpha-3');
    w.messageDomain.ledger.ingest([
      _row('alpha', 4),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    _readAttachmentIndex(w);
    for (final channel in channels) {
      channel.counted
        ..reads = 0
        ..enabled = true;
    }
    w.notifyListeners();
    final unrelated = channels
        .skip(1)
        .fold<int>(0, (sum, channel) => sum + channel.counted.reads);
    return (
      reads: unrelated,
      alphaReads: channels.first.counted.reads,
      cached: w.messageWindows.retainedSnapshots.length,
    );
  } finally {
    w.dispose();
    await client.injected.close();
  }
}

void main() {
  test(
    'unrelated cached windows add no authority reads to a new message',
    () async {
      final one = await _measure(0);
      final many = await _measure(50);
      expect(one.cached, 1);
      expect(many.cached, 51);
      expect(one.rows, 123);
      expect(many.rows, one.rows);
      expect(
        many.reads,
        lessThanOrEqualTo(one.reads),
        reason:
            'Identical 61-channel catalog, 123 ledger bodies and alpha event; '
            'only cached presentation windows changed from ${one.cached} to '
            '${many.cached}. Unrelated capability reads grew from '
            '${one.reads} to ${many.reads}.',
      );
    },
  );

  test(
    'an attachment read between messages does not widen the next refresh',
    () async {
      final one = await _measureAttachmentGap(0);
      final many = await _measureAttachmentGap(50);
      expect(one.cached, 1);
      expect(many.cached, 51);
      expect(one.alphaReads, greaterThan(0));
      expect(many.alphaReads, greaterThan(0));
      expect(one.reads, 0);
      expect(many.reads, 0);
    },
  );

  test('an evicted cached window reloads its accepted rows', () async {
    final client = _Client();
    final channels = [
      _Channel('alpha'),
      for (var i = 0; i < cachedConversationWindowLimit; i++)
        _Channel('cached-$i'),
    ];
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = channels;
    try {
      w.messageDomain.ledger.switchServer('s');
      for (final channel in channels) {
        w.messageWindows.acceptRows(liveWindowWrite, channel.id, [
          _row(channel.id, 1),
          _row(channel.id, 2),
        ], replace: true);
      }
      await w.selectChannel(channels.first, autoRead: false, navigate: false);
      expect(w.messageDomain.messageWindow, isNotNull);
      for (final channel in channels.skip(1)) {
        expect(w.messageWindows.channel(channel.id), isNotNull);
      }
      final held = w.messageWindows.retainedSnapshots
          .map((snapshot) => snapshot.channelId)
          .toSet();
      expect(held, contains('alpha'));
      expect(held, isNot(contains('cached-0')));
      expect(held.length, cachedConversationWindowLimit);
      final restored = w.messageWindows.channel('cached-0');
      expect(restored, isNotNull);
      expect(restored!.retired, isFalse);
      expect(restored.rows.map((row) => row.id), ['cached-0-1', 'cached-0-2']);
    } finally {
      w.dispose();
      await client.injected.close();
    }
  });
}
