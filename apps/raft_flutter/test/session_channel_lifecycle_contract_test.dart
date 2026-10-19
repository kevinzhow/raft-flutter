import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/shared_draft_attachment.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

import 'app_global_server_selector_test.dart' show RootCache;

class _Cache extends RootCache {
  final trace = <String>[];
  Completer<void>? barrier;
  final entered = Completer<void>();

  @override
  Future<void> write(
    String o,
    String p,
    String s,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (kind == 'barrier') {
      entered.complete();
      await barrier!.future;
    }
    trace.add('write:$p:$s:$kind:$id');
    await super.write(o, p, s, kind, id, value);
  }

  @override
  Future<void> revokeChannel(String o, String p, String s, String id) async {
    trace.add('purge:$p:$s:$id');
    await super.revokeChannel(o, p, s, id);
  }
}

class _Images implements AttachmentImageByteStore {
  final purged = <String>[];
  void Function(String)? onPurge;
  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async => null;
  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async {}
  @override
  Future<void> remove(AttachmentImageStoreKey key) async {}
  @override
  Future<void> purgeIdentity(String identity) async {}
  @override
  Future<void> purgeChannel(String identity, String id) {
    purged.add(id);
    onPurge?.call(id);
    return Future<void>.value();
  }
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
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

class _Workspace extends WorkspaceController {
  _Workspace(
    super.client, {
    required super.cache,
    required super.attachmentImageStore,
    super.presentationSource,
  }) : super(ownsClient: false);
  void Function()? onClose;
  bool closed = false;
  @override
  void closeThread({bool navigate = true}) {
    onClose?.call();
    super.closeThread(navigate: navigate);
  }

  @override
  void dispose() {
    if (closed) return;
    closed = true;
    super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    addTearDown(() async {
      if (cache.barrier?.isCompleted == false) cache.barrier!.complete();
      for (final w in pages.reversed) {
        w.onClose = null;
        if (!w.closed) {
          await w.flushCache();
          w.dispose();
        }
      }
      await client.dispose();
    });
  }
  final client = _Client(), cache = _Cache(), images = _Images();
  final pages = <_Workspace>[];
  _Workspace make({WorkspaceController? source, bool seed = true}) {
    final w =
        _Workspace(
            client,
            cache: cache,
            attachmentImageStore: images,
            presentationSource: source,
          )
          ..server = RaftRecord({'id': 's1', 'role': 'owner'})
          ..channel = RaftChannel({'id': 'c1', 'joined': true});
    w.channels = [
      w.channel!,
      RaftChannel({'id': 'other', 'joined': true}),
    ];
    if (seed) {
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest([
        {
          'id': 'parent',
          'channelId': 'c1',
          'seq': '1',
          'threadChannelId': 't1',
          'content': 'parent',
        },
        {'id': 'reply', 'channelId': 't1', 'seq': '1', 'content': 'private'},
        {'id': 'safe', 'channelId': 'other', 'seq': '1', 'content': 'safe'},
      ], expectedGeneration: w.messageDomain.ledger.generation);
      for (final (scope, id) in [
        ('c1', 'parent'),
        ('t1', 'reply'),
        ('other', 'safe'),
      ]) {
        w.messageDomain.visibleIds[scope] = {id};
        w.unread[scope] = 1;
        w.readState.consumeUpdate(
          {
            'serverId': 's1',
            'scopeId': scope,
            'maxReadSeq': 1,
            'readStateVersion': 1,
          },
          serverId: 's1',
          principalId: 'alice',
        );
      }
    }
    pages.add(w);
    return w;
  }
}

SharedDraftAttachment _file() => SharedDraftAttachment(
  reference: const {'fixture': 'local-file'},
  filename: 'local.txt',
  mimeType: 'text/plain',
  sizeBytes: 1,
  openRead: () => Stream.value([1]),
  release: () async {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final source in ['message', 'summary', 'other-summary']) {
    test(
      'discovers $source thread before clearing its parent ledger',
      () async {
        final f = _Fixture(), w = f.make();
        if (source != 'message') {
          w.messageDomain.ledger
              .message('c1', 'parent')!
              .remove('threadChannelId');
          if (source == 'other-summary') w.channel = w.channels.last;
          w.messageDomain.threadSummaries = {
            'parent': {'parentMessageId': 'parent', 'threadChannelId': 't1'},
          };
          w.channel = w.channels.first;
        }
        f.images.onPurge = (id) {
          expect(w.sessionScope.revokedChannels, contains(id));
          expect(
            w.messageDomain.ledger.messages(id),
            isNotEmpty,
            reason: 'media revocation precedes the scope ledger clear',
          );
          expect(w.readState.state('s1', 'alice', id), isNotNull);
        };
        w.messageDomain.rejectHistoryRead('c1');
        expect(f.images.purged, ['c1', 't1']);
        expect(w.messageDomain.ledger.messages('c1'), isEmpty);
        expect(w.messageDomain.ledger.messages('t1'), isEmpty);
        expect(w.messageDomain.ledger.messages('other').single['id'], 'safe');
        expect(w.unread, {'other': 1});
        expect(w.readState.state('s1', 'alice', 't1'), isNull);
        expect(w.readState.state('s1', 'alice', 'other'), isNotNull);
        await w.flushCache();
        expect(f.cache.trace.where((x) => x.startsWith('purge:')), [
          'purge:alice:s1:c1',
          'purge:alice:s1:t1',
        ]);
      },
    );
  }

  test(
    'thread closure follows retirement and precedes queued draft snapshot',
    () async {
      final f = _Fixture(), w = f.make();
      w.messageDomain.state.threadParent = RaftMessage(
        w.messageDomain.ledger.message('c1', 'parent')!,
      );
      w.threadChannelId = 't1';
      w.composer.drafts['thread:parent'] = 'author text';
      final upload = UploadDraft('private.txt', Uint8List(1), key: 1);
      w.composer.uploads.byScope['thread:parent'] = [upload];
      w.onClose = () {
        expect(upload.cancel.cancelled, isTrue);
        expect(w.messageDomain.ledger.messages('t1'), isEmpty);
        expect(w.readState.state('s1', 'alice', 't1'), isNull);
        w.composer.drafts['thread:parent'] = 'text at closure';
        expect(f.cache.trace.where((x) => x.startsWith('purge:')), isEmpty);
      };
      w.messageDomain.rejectHistoryRead('c1');
      expect(w.messageDomain.state.threadParent, isNull);
      expect(w.threadChannelId, isNull);
      await w.flushCache();
      expect(
        await f.cache.read(
          f.client.origin,
          'alice',
          's1',
          'draft',
          'thread:parent',
        ),
        allOf(
          containsPair('text', 'text at closure'),
          containsPair('files', isEmpty),
          containsPair('shareTokens', isNull),
        ),
      );
    },
  );

  test(
    'queued purge uses captured identity and post-retirement author text',
    () async {
      final f = _Fixture(), w = f.make();
      await w.stageSharedDraft('author text', [
        _file(),
      ], sourceToken: 'fixture-share');
      final upload = w.uploads().single;
      await w.flushCache();
      await f.cache.write(f.client.origin, 'bob', 's2', 'draft', 'c1', {
        'text': 'other identity',
      });
      f.cache.trace.clear();
      f.cache.barrier = Completer<void>();
      w.deviceStore.write('barrier', '', true);
      await f.cache.entered.future;
      w.messageDomain.rejectHistoryRead('c1');
      expect(upload.cancel.cancelled, isTrue);
      expect(w.composer.uploads.byScope['c1'], isNull);
      f.client.user = RaftRecord({'id': 'bob'});
      f.client.selectServer('s2');
      w.composer.drafts['c1'] = 'new identity text';
      f.cache.barrier!.complete();
      await w.flushCache();
      expect(
        await f.cache.read(f.client.origin, 'alice', 's1', 'draft', 'c1'),
        allOf(
          containsPair('text', 'author text'),
          containsPair('files', isEmpty),
          containsPair('shareTokens', isNull),
        ),
      );
      expect(await f.cache.read(f.client.origin, 'bob', 's2', 'draft', 'c1'), {
        'text': 'other identity',
      });
      expect(f.cache.trace.where((x) => x.startsWith('purge:')), [
        'purge:alice:s1:c1',
        'purge:alice:s1:t1',
      ]);
    },
  );

  test(
    'refused shared destination keeps authored files and blocks send',
    () async {
      final f = _Fixture(), w = f.make();
      await w.stageSharedDraft('share text', [
        _file(),
      ], sourceToken: 'fixture-share');
      w.holdShared('c1');
      await w.flushCache();
      final before = await f.cache.read(
        f.client.origin,
        'alice',
        's1',
        'draft',
        'c1',
      );
      w.messageDomain.rejectHistoryRead('c1');
      expect(w.channel?.id, 'c1');
      expect(w.sharedBlocked(), isTrue);
      expect(
        w.shareNoticeFor(),
        'This conversation is no longer available. Your draft and files are kept.',
      );
      expect(w.drafts['c1'], 'share text');
      expect(w.uploads().single.local, isNotNull);
      expect(w.messageDomain.ledger.messages('c1'), isEmpty);
      await w.flushCache();
      expect(
        await f.cache.read(f.client.origin, 'alice', 's1', 'draft', 'c1'),
        before,
      );
    },
  );

  test(
    'borrowed presentation read rejection goes to its window owner once',
    () {
      final f = _Fixture(),
          root = f.make(),
          borrowed = f.make(source: root, seed: false);
      borrowed.messageDomain.rejectHistoryRead('c1');
      expect(f.images.purged, ['c1', 't1']);
      expect(root.sessionScope.revokedChannels, {'c1', 't1'});
      expect(borrowed.sessionScope.revokedChannels, isEmpty);
      expect(borrowed.messageDomain.ledger.messages('t1'), isEmpty);
    },
  );

  test(
    'shared-client independent windows each retire once and stay independent',
    () {
      final f = _Fixture(), first = f.make(), second = f.make();
      expect(identical(first.messageWindows, second.messageWindows), isFalse);
      f.client.bus.add(const RaftEvent('channel:removed', {'channelId': 'c1'}));
      expect(f.images.purged, ['c1', 't1', 'c1', 't1']);
      for (final w in [first, second]) {
        expect(w.sessionScope.revokedChannels, {'c1', 't1'});
        expect(w.messageDomain.ledger.messages('t1'), isEmpty);
        expect(w.messageDomain.ledger.messages('other').single['id'], 'safe');
      }
      first.dispose();
      second.messageDomain.rejectHistoryRead('other');
      expect(f.images.purged.last, 'other');
      expect(second.sessionScope.revokedChannels, contains('other'));
    },
  );
}
