import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';

Map<String, dynamic> row(String id, {bool thread = false}) => {
  'id': id, 'messageId': 'message-$id', 'channelId': thread ? 'thread' : 'channel',
  'filename': '$id.txt', 'mimeType': 'text/plain', 'sizeBytes': 1024,
  'createdAt': '2026-10-08T01:30:00Z',
  'source': {'type': thread ? 'thread' : 'channel', 'channelId': thread ? 'thread' : 'channel',
    'parentMessageId': thread ? 'parent' : null, 'parentMessageShortId': thread ? 'parent-short' : null},
  'uploader': {'type': 'user', 'id': 'user', 'name': 'Public user', 'displayName': 'Public user'},
};
void main() {
  test('exact mounted GET envelope and opaque cursor are preserved', () async {
    final calls = <Map<String, dynamic>>[];
    final store = SourceChannelFilesStore(channelId: 'channel', authority: () => 'owner',
      get: (path, {query}) async {
        calls.add({'path': path, 'query': query});
        return calls.length == 1 ? {'files': [row('direct'), row('reply', thread: true)], 'nextCursor': 'opaque+/='}
          : {'files': [row('later')], 'nextCursor': null};
      });
    await store.load(); await store.load(more: true);
    expect(calls, [
      {'path': '/channels/channel/files', 'query': {'limit': 50}},
      {'path': '/channels/channel/files', 'query': {'limit': 50, 'cursor': 'opaque+/='}},
    ]);
    expect(store.files.map((file) => file.id), ['direct', 'reply', 'later']);
    expect(store.files[1].parentMessageId, 'parent');
    expect(store.nextCursor, isNull); store.dispose();
  });
  test('authority change clears data immediately and ignores delayed old response', () async {
    var owner = 'first'; final first = Completer<dynamic>(), second = Completer<dynamic>();
    var requests = 0;
    final store = SourceChannelFilesStore(channelId: 'channel', authority: () => owner,
      get: (_, {query}) => requests++ == 0 ? first.future : second.future);
    final old = store.load();
    owner = 'second'; expect(store.syncAuthority(), true);
    expect(store.files, isEmpty); expect(store.loading, false);
    final fresh = store.load();
    second.complete({'files': [row('current')], 'nextCursor': null}); await fresh;
    first.complete({'files': [row('private-old')], 'nextCursor': 'old'}); await old;
    expect(store.files.single.id, 'current'); expect(store.nextCursor, isNull); store.dispose();
  });
  test('no action admission between authority change and listener synchronization', () async {
    String? owner = 'first';
    final store = SourceChannelFilesStore(channelId: 'channel', authority: () => owner,
      get: (_, {query}) async => {'files': [row('a')], 'nextCursor': null});
    await store.load(); final file = store.files.single;
    expect(store.contains(file), true);
    owner = null; expect(store.contains(file), false);
    store.syncAuthority(); expect(store.files, isEmpty); store.dispose();
  });
  test('duplicate load-more calls cannot race or skip a cursor page', () async {
    final page = Completer<dynamic>(); var calls = 0;
    final store = SourceChannelFilesStore(channelId: 'channel', authority: () => 'owner',
      get: (_, {query}) async => ++calls == 1 ? {'files': [row('first')], 'nextCursor': 'next'} : await page.future);
    await store.load(); final a = store.load(more: true); await store.load(more: true);
    expect(calls, 2);
    page.complete({'files': [row('second')], 'nextCursor': null}); await a;
    expect(store.files.map((file) => file.id), ['first', 'second']); store.dispose();
  });
  test('403 removes earlier private rows; 503 is error rather than false empty success', () async {
    var calls = 0;
    final store = SourceChannelFilesStore(channelId: 'channel', authority: () => 'owner',
      get: (_, {query}) async {
        if (++calls == 1) return {'files': [row('a')], 'nextCursor': 'next'};
        throw ChannelFilesRequestFailure(calls == 2 ? ChannelFilesFailure.unauthorized : ChannelFilesFailure.unavailable);
      });
    await store.load(); await store.load(more: true);
    expect(store.error, ChannelFilesFailure.unauthorized); expect(store.files, isEmpty);
    await store.load(); expect(store.error, ChannelFilesFailure.unavailable);
    expect(store.loading, false); store.dispose();
  });
  test('malformed/out-of-channel direct rows fail closed', () async {
    final bad = row('a')..['channelId'] = 'another';
    final store = SourceChannelFilesStore(channelId: 'channel', authority: () => 'owner',
      get: (_, {query}) async => {'files': [bad], 'nextCursor': null});
    await store.load(); expect(store.error, ChannelFilesFailure.malformed);
    expect(store.files, isEmpty); store.dispose();
  });
  test('dispose rejects delayed payload without notifying or retaining metadata', () async {
    final pending = Completer<dynamic>(); var notices = 0;
    final store = SourceChannelFilesStore(channelId: 'channel', authority: () => 'owner',
      get: (_, {query}) => pending.future)..addListener(() => notices++);
    final request = store.load(); expect(notices, 1); store.dispose();
    pending.complete({'files': [row('private')], 'nextCursor': 'next'}); await request;
    expect(notices, 1); expect(store.files, isEmpty); expect(store.authorized, false);
  });
}
