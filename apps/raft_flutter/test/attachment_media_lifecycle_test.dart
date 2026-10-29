import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/attachment_url_cache.dart';
import 'package:raft_flutter/data/cache_clear.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/attachment_player_sessions.dart';
import 'package:raft_flutter/platform/memory_release.dart';

const _metadata = {
  'id': 'image',
  'mimeType': 'image/png',
  'width': 16,
  'height': 16,
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );

  final calls = <String>[];
  VoidCallback? onDispose;
  bool closed = false;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add(path);
    return path.endsWith('/enabled')
        ? {'enabled': true}
        : {'url': 'https://storage.invalid/image'};
  }

  @override
  Future<void> dispose() async {
    if (closed) return;
    closed = true;
    onDispose?.call();
    await super.dispose();
  }
}

class _Urls extends AttachmentUrlCache {
  VoidCallback? onDispose;
  @override
  void dispose() {
    onDispose?.call();
    super.dispose();
  }
}

class _Store implements AttachmentImageByteStore {
  void Function(String)? onPurge;
  final purged = Completer<void>();
  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async => null;
  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async {}
  @override
  Future<void> remove(AttachmentImageStoreKey key) async {}
  @override
  Future<void> purgeChannel(String identity, String channelId) async {}
  @override
  Future<void> purgeIdentity(String identity) {
    onPurge?.call(identity);
    return purged.future;
  }
}

class _Player implements AttachmentPlayer {
  final events = StreamController<AttachmentPlayback>.broadcast();
  VoidCallback? onDispose;
  bool disposed = false;
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  @override
  AttachmentPlayback get playback => const AttachmentPlayback();
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() => const SizedBox();
  @override
  Future<void> open(AttachmentSource source) async {}
  @override
  Future<void> toggle() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    onDispose?.call();
    await events.close();
  }
}

class _Fixture {
  _Fixture() {
    client.user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    source =
        WorkspaceController(
            client,
            attachmentImageStore: store,
            attachmentUrls: urls,
          )
          ..server = RaftRecord({'id': 'server', 'role': 'owner'})
          ..channel = RaftChannel({'id': 'channel', 'joined': true});
    source.channels = [source.channel!];
    source.messageDomain.ledger.switchServer('server');
    source.messageDomain.ledger.ingest([
      {
        'id': 'message',
        'channelId': 'channel',
        'seq': '1',
        'attachments': [_metadata],
      },
    ], expectedGeneration: source.messageDomain.ledger.generation);
    key = AttachmentImageKey.fromMetadata(
      scope: source.attachmentImageScope,
      channelId: 'channel',
      metadata: _metadata,
    );
    addTearDown(() async {
      source.dispose();
      await client.dispose();
      if (!store.purged.isCompleted) store.purged.complete();
    });
  }

  final client = _Client();
  final store = _Store();
  final urls = _Urls();
  late final WorkspaceController source;
  late final AttachmentImageKey key;
  int loads = 0;

  WorkspaceAttachmentImageLease image(WorkspaceController controller) =>
      controller.attachmentMedia.acquireImage(
        key,
        authorized: () => true,
        load: (_) async {
          loads++;
          return base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
          );
        },
      );

  PlayerHold player(WorkspaceController controller, _Player player) =>
      controller.attachmentMedia.playerSessions.acquire(
        'video',
        scope: source.attachmentImageScope,
        channelId: 'channel',
        create: () => player,
        source: () async => AttachmentSource.network(
          Uri.parse('https://storage.invalid/video'),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a borrowed page shares media and cannot dispose the source media',
    () async {
      final f = _Fixture();
      final hooks = CacheClear.instance.names;
      final borrowed = WorkspaceController(
        f.client,
        presentationSource: f.source,
        ownsClient: false,
        entityDirectory: f.source.entityDirectory,
        followedThreads: f.source.followedThreads,
      );
      addTearDown(borrowed.dispose);
      expect(CacheClear.instance.names, hooks);

      final image = f.image(borrowed);
      final provider = await image.lease.ready;
      image.release();
      final fromSource = f.source.attachmentMedia.peekImage(
        f.key,
        authorized: () => true,
      )!;
      expect(fromSource.lease.value, same(provider));
      fromSource.release();
      expect(f.loads, 1);
      expect(
        borrowed.attachmentMedia.playerSessions,
        same(f.source.attachmentMedia.playerSessions),
      );
      final player = _Player();
      final hold = f.player(borrowed, player);
      await hold.ready;
      await borrowed.attachmentMedia.url('image', channelId: 'channel');
      await f.source.attachmentMedia.url('image', channelId: 'channel');
      expect(await borrowed.attachmentMedia.previewEnabled(), isTrue);
      expect(await f.source.attachmentMedia.previewEnabled(), isTrue);
      expect(f.client.calls, [
        '/attachments/image/url',
        '/messages/attachment-preview/enabled',
      ]);
      expect(borrowed.attachmentMedia.debugUrls, same(f.urls));

      borrowed.dispose();
      expect(CacheClear.instance.names, hooks);
      expect(f.client.closed, isFalse);
      expect(player.disposed, isFalse);
      expect(hold.orphaned, isFalse);
      expect(f.urls.length, 1);
      final stillReady = f.source.attachmentMedia.peekImage(
        f.key,
        authorized: () => true,
      )!;
      expect(stillReady.lease.value, same(provider));
      stillReady.release();
      hold.release();
    },
  );

  test('server revocation purges the old identity before resetting it and hides media immediately', () async {
    final f = _Fixture();
    final image = f.image(f.source);
    await image.lease.ready;
    final player = _Player();
    final hold = f.player(f.source, player);
    await hold.ready;
    await f.source.attachmentMedia.url('image', channelId: 'channel');
    final observations = <Object?>[];
    f.store.onPurge = (identity) {
      observations.add([identity, f.client.serverId, f.source.server?.id]);
    };
    f.source.addListener(() {
      observations.add('notified');
      expect(f.source.server, isNull);
      expect(image.lease.active, isFalse);
      expect(hold.orphaned, isTrue);
      expect(f.urls.length, 0);
    });

    f.source.revokeServer('server');
    expect(observations, [
      [AttachmentImageKey.storeIdentity(f.key.scope), 'server', 'server'],
      'notified',
    ]);
    expect(f.client.serverId, isNull);
    expect(player.disposed, isTrue);
    expect(
      f.store.purged.isCompleted,
      isFalse,
      reason: 'slow disk cleanup cannot keep revoked media visible',
    );
    image.release();
    hold.release();
    f.store.purged.complete();
  });

  test('dispose unregisters memory hooks before releasing media, then closes the client once', () async {
    final hooksBefore = CacheClear.instance.names;
    final f = _Fixture();
    final image = f.image(f.source);
    await image.lease.ready;
    final player = _Player();
    final hold = f.player(f.source, player);
    await hold.ready;
    await f.source.attachmentMedia.url('image', channelId: 'channel');
    expect(RaftMemoryRelease.instance.snapshot(), contains('attachmentImages'));
    expect(RaftMemoryRelease.instance.snapshot(), contains('playerSessions'));
    final order = <String>[];
    f.urls.onDispose = () {
      order.add('urls');
      expect(f.source.attachmentMedia.retainedImageCount, 0);
      expect(image.lease.active, isFalse);
      expect(CacheClear.instance.names, hooksBefore);
      final snapshot = RaftMemoryRelease.instance.snapshot();
      expect(snapshot, isNot(contains('attachmentImages')));
      expect(snapshot, isNot(contains('playerSessions')));
      expect(player.disposed, isFalse);
    };
    player.onDispose = () {
      order.add('player');
      expect(f.urls.length, 0);
    };
    f.client.onDispose = () {
      order.add('client');
      expect(player.disposed, isTrue);
    };

    f.source.dispose();
    f.source.dispose();
    expect(order, ['urls', 'player', 'client']);
    expect(hold.orphaned, isTrue);
    image.release();
    hold.release();
    RaftMemoryRelease.instance.trim(RaftMemoryTrim.pressure);
    expect(order, ['urls', 'player', 'client']);
  });
}
