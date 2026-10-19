import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/followed_threads_store.dart';
import 'package:raft_flutter/data/resource_snapshot_cache.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_composer.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

class _Cache implements WorkspaceCache {
  final trace = <String>[];
  final records = <String, dynamic>{};
  Completer<void>? gate;
  final entered = Completer<void>();
  void Function(String)? onRead;
  String key(String o, String p, String s, String k, String id) =>
      '$o|$p|$s|$k|$id';

  @override
  Future<dynamic> read(
    String o,
    String p,
    String s,
    String k,
    String id,
  ) async {
    onRead?.call(k);
    return records[key(o, p, s, k, id)];
  }

  @override
  Future<void> write(
    String o,
    String p,
    String s,
    String k,
    String id,
    dynamic value,
  ) async {
    final pending = gate;
    gate = null;
    if (pending != null) {
      entered.complete();
      await pending.future;
    }
    trace.add('write:$p:$s:$k');
    records[key(o, p, s, k, id)] = value;
  }

  @override
  Future<void> revokeServer(String o, String p, String s) async {
    trace.add('purge:$p:$s');
    records.removeWhere((k, _) => k.startsWith('$o|$p|$s|'));
  }

  @override
  Future<void> revokeChannel(String o, String p, String s, String c) async {}
  @override
  Future<void> clearAccount(String o, String p) async {}
  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String o,
    String p,
    String s,
  ) async => [];
  @override
  Future<void> writeTranslations(
    String o,
    String p,
    String s,
    List<Map<String, dynamic>> values,
  ) async {}
  @override
  Future<void> close() async {}
}

class _Images implements AttachmentImageByteStore {
  final identities = <String>[];
  void Function()? onPurge;
  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async => null;
  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async {}
  @override
  Future<void> remove(AttachmentImageStoreKey key) async {}
  @override
  Future<void> purgeChannel(String identity, String channelId) async {}
  @override
  Future<void> purgeIdentity(String identity) async {
    identities.add(identity);
    onPurge?.call();
  }
}

class _Slot implements ServerPageSlot {
  @override
  final snapshot = FieldSnapshot(identity: 'old', fields: const {});
  @override
  bool needsRevalidate = false;
  @override
  int attached = 0;
  @override
  void attach() => attached++;
  @override
  void detach() => attached--;
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  final selections = <String?>[];
  void Function(String?)? onSelect;
  Completer<dynamic>? sidebarReply;
  Completer<void>? sidebarEntered;
  Future<void>? _closing;
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  void selectServer(String? id) {
    selections.add(id);
    onSelect?.call(id);
    super.selectServer(id);
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    if (path.endsWith('/sidebar-order') && sidebarReply != null) {
      sidebarEntered!.complete();
      return sidebarReply!.future;
    }
    return Future<dynamic>.value({});
  }

  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async => [];
  @override
  void connect() {}
  @override
  Future<void> dispose() => _closing ??= _close();
  Future<void> _close() async {
    await ingress.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(
    super.client, {
    required super.cache,
    required super.attachmentImageStore,
    required super.entityDirectory,
    required super.followedThreads,
    super.composer,
    super.presentationSource,
    super.discardSharedScope,
    bool owns = false,
  }) : super(ownsClient: owns);
  bool closed = false;
  int notices = 0;
  void Function()? onNotice;
  Future<void> Function(RaftRecord)? selectionOverride;
  final selections = <String>[];
  @override
  void notifyListeners() {
    notices++;
    onNotice?.call();
    super.notifyListeners();
  }

  @override
  Future<void> selectServer(
    RaftRecord next, {
    void Function()? onHydrated,
    void Function()? onCacheMiss,
  }) {
    selections.add(next.id);
    return selectionOverride?.call(next) ??
        super.selectServer(
          next,
          onHydrated: onHydrated,
          onCacheMiss: onCacheMiss,
        );
  }

  @override
  Future<void> refreshMessageSyncFlag() async {}
  @override
  Future<void> refreshUnread() async {}
  @override
  void dispose() {
    if (closed) return;
    closed = true;
    super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    client.user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    client.selections.clear();
    addTearDown(() async {
      client.onSelect = null;
      for (final release in releases) {
        if (!release.isCompleted) release.complete();
      }
      for (final w in pages.reversed) {
        w.onNotice = null;
        if (!w.closed) {
          await w.flushCache();
          w.dispose();
        }
      }
      for (final d in directories) {
        d.dispose();
      }
      for (final f in followed) {
        f.dispose();
      }
      await client.dispose();
    });
  }

  final client = _Client();
  final cache = _Cache();
  final images = _Images();
  final pages = <_Workspace>[];
  final directories = <WorkspaceEntityDirectory>[];
  final followed = <FollowedThreadsStore>[];
  final releases = <Completer<void>>[];
  _Workspace make({
    bool owns = false,
    WorkspaceController? source,
    WorkspaceComposer? composer,
    _Cache? device,
    _Images? media,
    Future<void> Function(String, String, String, String?)? discard,
    bool seed = true,
  }) {
    final directory = WorkspaceEntityDirectory(
      scope: () => null,
      query: (_) async => [],
      events: const Stream<RaftEvent>.empty(),
    );
    directories.add(directory);
    final following = FollowedThreadsStore(
      scope: () => null,
      query: (_) async => {'threads': <dynamic>[]},
      command: (_, _) async => {},
    );
    followed.add(following);
    final w = _Workspace(
      client,
      cache: device ?? cache,
      attachmentImageStore: media ?? images,
      entityDirectory: directory,
      followedThreads: following,
      presentationSource: source,
      composer: composer,
      owns: owns,
      discardSharedScope: discard,
    );
    pages.add(w);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    w.servers = [
      w.server!,
      RaftRecord({'id': 's2', 'role': 'owner'}),
    ];
    w.channel = RaftChannel({'id': 'c1', 'joined': true});
    w.channels = [w.channel!];
    if (seed) {
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest([
        {'id': 'm1', 'channelId': 'c1', 'seq': '1', 'content': 'retained'},
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {'m1'};
    }
    return w;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('active server revocation keeps its synchronous phase order', () async {
    final f = _Fixture();
    final trace = <String>[];
    late _Workspace w;
    w = f.make(
      owns: true,
      discard: (o, p, s, c) async {
        trace.add('discard');
        expect(w.servers.map((r) => r.id), ['s2']);
        expect(w.channel?.id, 'c1');
        expect(w.messageDomain.messages.single.id, 'm1');
      },
    );
    w.saveDraft('authored');
    await w.flushCache();
    f.cache.trace.clear();
    expect(
      w.readState.consumeUpdate(
        {
          'serverId': 's1',
          'scopeId': 'c1',
          'maxReadSeq': 1,
          'readStateVersion': 1,
        },
        serverId: 's1',
        principalId: 'alice',
      ),
      'accepted',
    );
    expect(
      w.reactionViewer.accept({
        'serverId': 's1',
        'messageId': 'm1',
        'viewerVersion': 1,
        'reactedEmojis': ['smile'],
      }, serverId: 's1'),
      'accepted',
    );
    w.resourceSnapshots.keepServerPage('saved', _Slot(), () {
      trace.add('pages');
      expect(w.messageDomain.messages, isEmpty);
      expect(w.readState.state('s1', 'alice', 'c1'), isNull);
      expect(w.reactionViewer.reacted('m1'), {'smile'});
    });
    w.loading = w.messageDomain.state.channelLoading =
        w.messageDomain.state.threadLoading = true;
    w.error = 'old error';
    final channelVersion = w.messageDomain.channelGeneration;
    final threadVersion = w.messageDomain.threadGeneration;
    f.images.onPurge = () {
      trace.add('media');
      expect(w.server?.id, 's1');
      expect(w.messageDomain.messages.single.id, 'm1');
      expect(w.drafts['c1'], 'authored');
    };
    f.client.onSelect = (id) {
      trace.add('client:$id');
      expect(w.server, isNull);
      expect(w.channel, isNull);
      expect(w.messageDomain.messages, isEmpty);
      expect(w.drafts, isEmpty);
      expect(w.messageDomain.channelGeneration, channelVersion + 1);
      expect(w.messageDomain.threadGeneration, threadVersion + 1);
      expect(w.reactionViewer.reacted('m1'), isNull);
      expect(w.loading, isTrue);
    };
    w.onNotice = () {
      trace.add('notify');
      expect(
        w.loading ||
            w.messageDomain.state.channelLoading ||
            w.messageDomain.state.threadLoading,
        isFalse,
      );
    };
    w.revokeServer('s1');
    expect(trace, ['discard', 'media', 'pages', 'client:null', 'notify']);
    expect(w.error, isNull);
    expect(f.client.selections, [null]);
    await w.flushCache();
    expect(f.cache.trace, ['purge:alice:s1', 'write:alice::servers']);
  });

  test('inactive revocation keeps the active windows and composer', () async {
    final f = _Fixture();
    final w = f.make(owns: true);
    w.saveDraft('authored');
    await w.flushCache();
    f.cache.trace.clear();
    final generation = w.messageDomain.channelGeneration;
    w.revokeServer('s2');
    expect(w.server?.id, 's1');
    expect(w.messageDomain.messages.single.id, 'm1');
    expect(w.messageDomain.channelGeneration, generation);
    expect(w.drafts['c1'], 'authored');
    expect(w.servers.map((s) => s.id), ['s1']);
    expect(f.client.selections, isEmpty);
    expect(f.images.identities, hasLength(1));
    await w.flushCache();
    expect(f.cache.trace, ['purge:alice:s2', 'write:alice::servers']);
  });

  test('no principal means no server revocation effects', () async {
    final f = _Fixture();
    final w = f.make();
    f.client.user = null;
    final notices = w.notices;
    w.revokeServer('s1');
    expect(w.server?.id, 's1');
    expect(w.notices, notices);
    expect(f.images.identities, isEmpty);
    expect(f.cache.trace, isEmpty);
  });

  test(
    'accepted device writes precede purge under the captured identity',
    () async {
      final f = _Fixture();
      final w = f.make();
      final release = Completer<void>();
      f.releases.add(release);
      f.cache.gate = release;
      w.saveDraft('accepted before purge');
      await f.cache.entered.future;
      w.revokeServer('s2');
      f.client.user = RaftRecord({'id': 'bob'});
      f.client.selectServer('s3');
      release.complete();
      await w.flushCache();
      expect(f.cache.trace, [
        'write:alice:s1:draft',
        'purge:alice:s2',
        'write:alice::servers',
      ]);
    },
  );

  test(
    'each direct command retains its existing repeated-revocation behavior',
    () async {
      final f = _Fixture();
      final w = f.make();
      w.revokeServer('s2');
      w.revokeServer('s2');
      await w.flushCache();
      expect(f.images.identities, hasLength(2));
      expect(f.cache.trace.where((s) => s.startsWith('purge:')), hasLength(2));
    },
  );

  test(
    'presentation-source revocation runs one local path and one shared reset',
    () async {
      final f = _Fixture();
      final root = f.make();
      root.saveDraft('source draft');
      await root.flushCache();
      final localCache = _Cache();
      final page = f.make(source: root, device: localCache, seed: false);
      final generation = root.messageDomain.channelGeneration;
      final rootNotices = root.notices, pageNotices = page.notices;
      page.revokeServer('s1');
      expect(page.server, isNull);
      expect(root.server?.id, 's1');
      expect(root.channel?.id, 'c1');
      expect(root.messageDomain.channelGeneration, generation + 1);
      expect(root.messageDomain.ledger.messages('c1'), isEmpty);
      expect(root.drafts['c1'], 'source draft');
      expect(root.notices, rootNotices);
      expect(page.notices, pageNotices + 1);
      expect(f.images.identities, isEmpty);
      expect(f.client.selections, isEmpty);
      await page.flushCache();
      expect(localCache.trace, ['purge:alice:s1', 'write:alice::servers']);
    },
  );

  test('independent editor revokes once without resetting source windows or drafts', () async {
    final f = _Fixture();
    final root = f.make();
    root.saveDraft('source draft');
    await root.flushCache();
    final localCache = _Cache(), localImages = _Images();
    final editor = f.make(
      device: localCache,
      media: localImages,
      composer: root.composer,
    );
    final rootGeneration = root.messageDomain.channelGeneration;
    final editorGeneration = editor.messageDomain.channelGeneration;
    final notices = editor.notices;
    editor.revokeServer('s1');
    expect(editor.server, isNull);
    expect(editor.messageDomain.channelGeneration, editorGeneration + 1);
    expect(editor.messageDomain.messages, isEmpty);
    expect(editor.notices, notices + 1);
    expect(root.messageDomain.channelGeneration, rootGeneration);
    expect(root.messageDomain.messages.single.id, 'm1');
    expect(root.drafts['c1'], 'source draft');
    expect(f.images.identities, isEmpty);
    expect(localImages.identities, hasLength(1));
    expect(f.client.serverId, 's1');
    expect(f.client.selections, isEmpty);
    await editor.flushCache();
    expect(localCache.trace, ['purge:alice:s1', 'write:alice::servers']);
  });

  test('borrowed selection reaches the source override exactly once', () async {
    final f = _Fixture();
    final root = f.make();
    final page = f.make(source: root, seed: false);
    final nested = f.make(source: page, seed: false);
    var calls = 0;
    root.selectionOverride = (_) async {
      calls++;
    };
    await nested.selectServer(RaftRecord({'id': 's2'}));
    expect(calls, 1);
    expect(root.selections, ['s2']);
    expect(f.client.selections, isEmpty);
    expect(root.messageDomain.messages.single.id, 'm1');
  });

  test(
    'ordinary server selection resets the old projection before cached reads',
    () async {
      final f = _Fixture();
      final w = f.make(owns: true);
      w.unread = {'c1': 4};
      w.mentions = {'c1'};
      w.newFlags = {'c1'};
      w.messageDomain.state.historyLimited =
          w.messageDomain.state.threadHistoryLimited = true;
      w.messageDomain.state.highlightedMessageId = 'm1';
      w.messageSync.consumeNew({'id': 'm1', 'channelId': 'c1', 'seq': 1});
      w.resourceSnapshots.write(
        'saved',
        FieldSnapshot(identity: 'old', fields: {'value': 1}),
      );
      final generation = w.messageDomain.channelGeneration;
      var checked = false;
      f.cache.onRead = (kind) {
        if (kind != 'channels') return;
        checked = true;
        expect(w.channel, isNull);
        expect(w.messageDomain.messages, isEmpty);
        expect(w.unread, isEmpty);
        expect(w.mentions, isEmpty);
        expect(w.newFlags, isEmpty);
        expect(
          w.messageDomain.state.historyLimited ||
              w.messageDomain.state.threadHistoryLimited,
          isFalse,
        );
        expect(w.messageDomain.state.highlightedMessageId, isNull);
        expect(w.messageSync.messages('c1'), isEmpty);
        expect(w.resourceSnapshots.read<FieldSnapshot>('saved', 'old'), isNull);
        expect(w.messageDomain.channelGeneration, generation + 1);
      };
      await w.selectServer(RaftRecord({'id': 's2', 'role': 'owner'}));
      expect(checked, isTrue);
      expect(f.client.selections, ['s2']);
    },
  );

  test(
    'a pending sidebar response cannot republish after server revocation',
    () async {
      final f = _Fixture();
      final w = f.make(owns: true);
      f.client.sidebarReply = Completer<dynamic>();
      f.client.sidebarEntered = Completer<void>();
      final loading = w.loadSidebar();
      await f.client.sidebarEntered!.future;
      w.revokeServer('s1');
      f.client.sidebarReply!.complete({
        'channelOrder': ['private'],
      });
      await loading;
      expect(w.sidebarOrder, isEmpty);
      await w.flushCache();
      expect(f.cache.trace.where((s) => s.endsWith(':sidebar-order')), isEmpty);
    },
  );
}
