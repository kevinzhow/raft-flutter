import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

const _metadata = <String, dynamic>{
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

class _AccessController extends WorkspaceController {
  _AccessController(super.client, {super.ownsClient});
  final denied = <String>{};
  int accessChecks = 0;
  @override
  bool can(String capability, {RaftChannel? resource}) {
    if (capability == 'viewChannel') {
      ++accessChecks;
      if (denied.contains(resource?.id)) return false;
    }
    return super.can(capability, resource: resource);
  }
}

class _Fixture {
  _Fixture() {
    client.user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    w = _AccessController(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = row('channel');
    w.channels = [w.channel!];
    w.messageDomain.ledger.switchServer('server');
    ingest('channel', 'host', '1', attachments: [_metadata]);
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
  }
  final client = _Client();
  late final _AccessController w;
  int loads = 0;
  static RaftChannel row(String id) => RaftChannel({'id': id, 'joined': true});
  void ingest(
    String channel,
    String id,
    String seq, {
    String? thread,
    List<Map<String, dynamic>> attachments = const [],
  }) => w.messageDomain.ledger.ingest([
    {
      'id': id,
      'channelId': channel,
      'seq': seq,
      'content': 'fixture',
      'threadId': thread,
      'attachments': attachments,
    },
  ], expectedGeneration: w.messageDomain.ledger.generation);

  AttachmentImageKey key({
    String channel = 'channel',
    Map<String, dynamic> metadata = _metadata,
    String rendition = 'original',
  }) => AttachmentImageKey.fromMetadata(
    scope: w.attachmentImageScope,
    channelId: channel,
    metadata: metadata,
    rendition: rendition,
  );

  Future<void> load(
    AttachmentImageKey key, {
    WorkspaceController? through,
  }) async {
    final lease = (through ?? w).attachmentMedia.acquireImage(
      key,
      authorized: () => true,
      load: (_) async {
        ++loads;
        return base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
        );
      },
    );
    await lease.lease.ready;
    lease.release();
  }

  bool ready(AttachmentImageKey key) {
    final lease = w.attachmentMedia.peekImage(key, authorized: () => true);
    lease?.release();
    return lease != null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unused media has no history scans, including empty synchronous peeks',
    () {
      final f = _Fixture();
      expect(f.w.debugRetainedAttachmentIndexBuilds, 0);
      expect(f.ready(f.key()), isFalse);
      f.w.notifyListeners();
      expect(f.w.debugRetainedAttachmentIndexBuilds, 0);
    },
  );

  test(
    'notifications recheck admission without rescanning identical ids',
    () async {
      final f = _Fixture();
      await f.load(f.key());
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      final checks = f.w.accessChecks;
      for (var i = 0; i < 4; i++) {
        f.w.notifyListeners();
        expect(f.ready(f.key()), isTrue);
      }
      expect(f.w.accessChecks, greaterThan(checks));
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans);
      expect(f.loads, 1);
    },
  );

  test(
    'silent same-length list writes retain the prior stamp until notified',
    () async {
      final f = _Fixture();
      await f.load(f.key());
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      f.w.channels[0] = _Fixture.row('other');
      expect(f.ready(f.key()), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans);
      f.w.notifyListeners();
      expect(f.ready(f.key()), isFalse);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans + 1);
    },
  );

  test(
    'moving the same admitted id between channel and DM lists reuses scans',
    () async {
      final f = _Fixture();
      await f.load(f.key());
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      f.w.dms = f.w.channels;
      f.w.channels = [];
      f.w.notifyListeners();
      expect(f.ready(f.key()), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans);
    },
  );

  test(
    'admitted id order changes rebuild exactly once without discarding images',
    () async {
      final f = _Fixture();
      f.w.channels.add(_Fixture.row('other'));
      await f.load(f.key());
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      f.w.channels = f.w.channels.reversed.toList();
      f.w.notifyListeners();
      expect(f.ready(f.key()), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans + 1);
      f.w.notifyListeners();
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans + 1);
    },
  );

  test(
    'overridden view permission is re-evaluated at the old notification point',
    () async {
      final f = _Fixture();
      await f.load(f.key());
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      f.w.denied.add('channel');
      f.w.notifyListeners();
      expect(f.ready(f.key()), isFalse);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans + 1);
      f.w.denied.clear();
      f.w.notifyListeners();
      await f.load(f.key());
      expect(f.ready(f.key()), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans + 2);
    },
  );

  test(
    'borrowed media retains the source callback and source scan counter',
    () async {
      final f = _Fixture();
      final borrowed = WorkspaceController(
        f.client,
        presentationSource: f.w,
        ownsClient: false,
        entityDirectory: f.w.entityDirectory,
        followedThreads: f.w.followedThreads,
      );
      addTearDown(borrowed.dispose);
      expect(borrowed.attachmentMedia, same(f.w.attachmentMedia));
      borrowed.channels = [_Fixture.row('other')];
      await f.load(f.key(), through: borrowed);
      expect(f.ready(f.key()), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, 1);
      expect(borrowed.debugRetainedAttachmentIndexBuilds, 0);
      borrowed.notifyListeners();
      borrowed.dispose();
      expect(f.ready(f.key()), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, 1);
    },
  );

  test('independent receivers sharing a client keep separate histories and counters', () async {
    final f = _Fixture();
    await f.load(f.key());
    final editor = _AccessController(f.client, ownsClient: false)
      ..server = f.w.server
      ..channels = [_Fixture.row('channel')];
    addTearDown(editor.dispose);
    editor.messageDomain.ledger.switchServer('server');
    expect(editor.attachmentMedia, isNot(same(f.w.attachmentMedia)));
    await f.load(f.key(), through: editor);
    expect(editor.attachmentMedia.retainedImageCount, 0);
    expect(editor.debugRetainedAttachmentIndexBuilds, 1);
    expect(f.ready(f.key()), isTrue);
    expect(f.w.debugRetainedAttachmentIndexBuilds, 1);
  });

  test(
    'parent thread metadata admits replies and removing the link retires them',
    () async {
      final f = _Fixture();
      f.ingest('channel', 'host', '2', thread: 'thread');
      f.ingest('thread', 'reply', '3', attachments: [_metadata]);
      final key = f.key(channel: 'thread');
      await f.load(key);
      expect(f.ready(key), isTrue);
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      f.ingest('channel', 'host', '4');
      f.w.notifyListeners();
      expect(f.ready(key), isFalse);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans);
    },
  );

  test(
    'one remaining parent keeps the thread image without another history scan',
    () async {
      final f = _Fixture();
      f.ingest('channel', 'host', '2', thread: 'thread');
      f.ingest('channel', 'second', '3', thread: 'thread');
      f.ingest('thread', 'reply', '4', attachments: [_metadata]);
      final key = f.key(channel: 'thread');
      await f.load(key);
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      f.ingest('channel', 'host', '5');
      f.w.notifyListeners();
      expect(f.ready(key), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans);
      f.ingest('channel', 'second', '6');
      f.w.notifyListeners();
      expect(f.ready(key), isFalse);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans);
    },
  );

  test('unreferenced thread history grants no image retention', () async {
    final f = _Fixture();
    f.ingest('orphan', 'reply', '2', attachments: [_metadata]);
    await f.load(f.key(channel: 'orphan'));
    expect(f.w.attachmentMedia.retainedImageCount, 0);
    expect(f.w.debugRetainedAttachmentIndexBuilds, 1);
  });

  test(
    'one attachment id can retain multiple accepted content revisions',
    () async {
      final f = _Fixture();
      const next = {..._metadata, 'contentVersion': 'next'};
      f.ingest('channel', 'second', '2', attachments: [next]);
      await f.load(f.key());
      await f.load(f.key(metadata: next, rendition: 'thumbnail'));
      expect(f.w.attachmentMedia.retainedImageCount, 2);
      expect(f.ready(f.key()), isTrue);
      expect(f.ready(f.key(metadata: next, rendition: 'thumbnail')), isTrue);
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      f.ingest('channel', 'host', '3');
      f.w.notifyListeners();
      expect(f.ready(f.key()), isFalse);
      expect(f.ready(f.key(metadata: next, rendition: 'thumbnail')), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans);
    },
  );

  test(
    'a message outside admission keeps the image and does not rescan history',
    () async {
      final f = _Fixture();
      await f.load(f.key());
      final scans = f.w.debugRetainedAttachmentIndexBuilds;
      f.ingest('not-admitted', 'other', '2');
      expect(f.ready(f.key()), isTrue);
      expect(f.w.debugRetainedAttachmentIndexBuilds, scans);
    },
  );
}
