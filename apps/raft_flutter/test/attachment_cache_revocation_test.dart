import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => [];
  @override
  Future<void> dispose() async {
    await bus.close();
    await super.dispose();
  }
}

/// Revoked workspace data takes the cached attachments with it, also when no
/// image was decoded in this session (a fresh start with a warm disk).
void main() {
  late Directory root;
  late AttachmentDiskCache cache;
  late _Client client;
  late WorkspaceController w;
  AttachmentImageStoreKey key(String id, {String channel = 'channel'}) =>
      w.attachmentMedia.cacheKey(
        {'id': id, 'mimeType': 'application/pdf'},
        'file',
        channelId: channel,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-revocation');
    cache = AttachmentDiskCache(() async => root);
    client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    w = WorkspaceController(client, attachmentImageStore: cache)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
    w.channels = [
      w.channel!,
      RaftChannel({'id': 'other', 'joined': true}),
    ];
    await cache.write(key('a'), Uint8List(8));
    await cache.write(key('b', channel: 'other'), Uint8List(8));
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
    await root.delete(recursive: true);
  });

  test('a removed channel purges its stored attachments only', () async {
    expect(
      w.attachmentMedia.retainedImageCount,
      0,
      reason: 'no decoded image this session',
    );
    client.bus.add(
      const RaftEvent('channel:removed', {'channelId': 'channel'}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await cache.contains(key('a')), isFalse);
    expect(await cache.contains(key('b', channel: 'other')), isTrue);
  });

  test('a revoked server purges everything stored for that server', () async {
    final otherServer = AttachmentImageStoreKey(
      identity: AttachmentImageKey.identityOf(
        'https://example.invalid',
        'alice',
        'server-2',
      ),
      channelId: 'channel',
      entry: '["z","r","file"]',
    );
    await cache.write(otherServer, Uint8List(8));
    w.revokeServer('server');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await cache.contains(key('a')), isFalse);
    expect(await cache.contains(key('b', channel: 'other')), isFalse);
    expect(await cache.contains(otherServer), isTrue);
  });
}
