import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';
import 'package:raft_flutter/data/channel_repository.dart';
import 'package:raft_flutter/data/conversation_read_repository.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/sidebar_repository.dart';
import 'package:raft_flutter/data/task_discussion_read.dart';
import 'package:raft_flutter/data/workspace_channels.dart';
import 'package:raft_flutter/data/workspace_domain_ports.dart';
import 'package:raft_flutter/data/workspace_session_context.dart';

RaftChannel _channel(String id, {String type = 'channel'}) =>
    RaftChannel({'id': id, 'name': id, 'type': type, 'joined': true});

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://channels-domain.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
}

/// Real channel/read repositories, with the same lazy callback wiring as the
/// composition root. Cross-domain work is observed at the frozen typed ports.
class _Fixture extends Fake
    implements
        WorkspaceSessionContext,
        WorkspaceTransportPort,
        WorkspacePresentationReadPort,
        WorkspaceMessageRowsPort,
        WorkspaceWindowFactsPort,
        WorkspaceMessagePrefetchPort,
        WorkspaceSessionEffectsPort {
  _Fixture({
    SidebarRepository? sharedSidebar,
    ReadStateLedger? sourceReadState,
  }) {
    final directory = ChannelRepository(
      client,
      channels: () => owner.channels,
      dms: () => owner.dms,
      generation: () => generation,
      identity: syncIdentity,
      isDisposed: () => disposed,
      revokedChannels: () => revoked,
      acceptLists: (channels, dms, {required readmit}) =>
          owner.acceptChannelLists(channels, dms, readmit: readmit),
      reloadLists: () => owner.refreshChannels(),
      reloadRow: (id) => owner.refreshChannel(id),
      revokeChannel: (id) => revoked.add(id),
      closeDeniedThread: (_) {},
      changed: changed,
      setError: (value) => trace.add('error:$value'),
      quietFailure: (_) => false,
      patchSelected: (patch) {
        if (channel != null) channel = patch(channel!);
      },
    );
    final reads = ConversationReadRepository(
      client,
      readState: () => owner.effectiveReadState,
      revokedChannels: () => revoked,
      channelId: () => channel?.id,
      threadChannelId: () => threadChannelId,
      mobileNavigation: () => mobileNavigation,
      mayMarkRead: (id) => owner.mayMarkRead(id),
      markRead: (id) => owner.markRead(id),
      channelRows: () => [...owner.channels, ...owner.dms],
      messages: (_) => [],
      isContext: (_) => false,
      hasNewer: () => hasNewer,
      save: (kind, id, value) async {
        trace.add('save:$kind');
        saved.add(value);
      },
      changed: changed,
      prefetch: () => owner.prefetchLikelyChannels(),
    );
    final sidebar =
        sharedSidebar ??
        SidebarRepository(
          client,
          order: () => owner.sidebarOrder,
          setOrder: (value) => owner.sidebarOrder = value,
          serverId: () => server?.id,
          loadAuthority: syncIdentity,
          isDisposed: () => disposed,
          readDevice: () async => null,
          saveDevice: (_) async {},
          changed: changed,
          reload: () => owner.loadSidebar(),
        );
    owner = WorkspaceChannels(
      context: this,
      transport: this,
      presentation: this,
      messages: this,
      windows: this,
      messagePrefetch: this,
      sessionEffects: this,
      directory: directory,
      reads: reads,
      sidebar: sidebar,
      effectiveReadState: () => sourceReadState ?? reads.localReadState,
      refreshUnread: () async => trace.add('refreshUnread'),
    );
    addTearDown(client.dispose);
  }

  late final WorkspaceChannels owner;
  final trace = <String>[];
  final saved = <dynamic>[];
  final prefetched = <String>[];
  final revoked = <String>{}, denied = <String>{}, accepted = <String>{};
  final servers = [
    RaftRecord({'id': 's', 'role': 'owner'}),
  ];
  Future<void> Function(RaftChannel, bool Function())? prefetch;
  String identityValue = 'original';
  int changedCount = 0;
  @override
  final client = _Client();
  @override
  final receiverKey = Object();
  @override
  bool disposed = false;
  @override
  RaftRecord? server = RaftRecord({'id': 's', 'role': 'owner'});
  @override
  WorkspaceSessionIdentity get identity => (
    origin: client.origin,
    generation: client.generation,
    principalId: client.user?.id,
    serverId: client.serverId,
    role: server?.string('role'),
  );
  @override
  String syncIdentity() => identityValue;
  @override
  String? panelIdentity() => disposed ? null : identityValue;
  @override
  bool isChannelRevoked(String id) => revoked.contains(id);
  @override
  bool can(String capability, {RaftChannel? resource}) =>
      !denied.contains(resource?.id);
  @override
  void changed() {
    changedCount++;
    trace.add('changed');
  }

  @override
  bool loading = false, foreground = true, mobileNavigation = false;
  @override
  bool mainPresented = true, chatTabPresented = true, threadPresented = true;
  @override
  RaftChannel? channel = _channel('open');
  @override
  RaftLocation location = RaftLocation.parse('/s/demo/channel/open');
  @override
  bool hasNewer = false, channelLoading = false;
  @override
  String? threadChannelId, threadParentChannelId, threadParentMessageId;
  @override
  int generation = 1;
  @override
  bool hasAcceptedWindow(String channelId) => accepted.contains(channelId);
  @override
  Future<void> prefetchAcceptedTail(
    RaftChannel candidate, {
    required bool Function() stillCurrent,
  }) async {
    prefetched.add(candidate.id);
    await prefetch?.call(candidate, stillCurrent);
  }

  @override
  bool syncCoreNotificationPrefsEnabled = false;
  @override
  void ensureSyncIdentity() => trace.add('ensureIdentity');
  @override
  void patchServerRows(RaftRecord Function(RaftRecord) patch) {
    trace.add('patchServers');
    for (var i = 0; i < servers.length; i++) {
      servers[i] = patch(servers[i]);
    }
    trace.add('patchSelectedServer');
    if (server != null) server = patch(server!);
  }
}

void main() {
  test(
    'read qualification preserves folded, hidden, preview and task routes',
    () {
      final f = _Fixture(), w = f.owner;
      expect(w.mayMarkRead('open'), true);
      f.foreground = false;
      expect(w.mayMarkRead('open'), false);
      f.foreground = true;
      f.chatTabPresented = false;
      expect(w.mayMarkRead('open'), false);
      f.chatTabPresented = true;
      f.hasNewer = true;
      expect(w.mayMarkRead('open'), false);
      f.hasNewer = false;
      f.channelLoading = true;
      expect(w.mayMarkRead('open'), false);
      f.channelLoading = false;
      f.location = RaftLocation.parse('/s/demo/activity?open=channel:open');
      expect(w.mayMarkRead('open'), true);
      f.location = RaftLocation.parse(
        '/s/demo/channel/open?thread=open:parent',
      );
      f.mobileNavigation = true;
      expect(w.mayMarkRead('open'), false);
      f.threadChannelId = 'thread';
      f.threadParentChannelId = 'open';
      f.threadParentMessageId = 'parent';
      expect(w.mayMarkRead('thread'), true);
      f.location = RaftLocation.parse('/s/demo/tasks');
      expect(w.mayMarkRead('thread'), false);
      admitTaskDiscussion(f.receiverKey);
      expect(w.mayMarkRead('thread'), true);
      f.threadPresented = false;
      expect(w.mayMarkRead('thread'), false);
      expect(w.mayMarkRead('unrelated'), false);
    },
  );

  test(
    'open-time clear persists together and reconciles only without a receipt',
    () {
      final f = _Fixture(), w = f.owner;
      w.unread = {'open': 3};
      w.mentions = {'open'};
      w.newFlags = {'open'};
      w.readPosts['open'] = 7;
      w.setTimelineAtBottom('open', false);
      final before = w.beginOpenRead('open', optimistic: true);
      expect(before, 7);
      expect(w.scrolledAway.away('open'), false);
      expect(w.unread['open'], 0);
      expect(w.mentions, isEmpty);
      expect(w.newFlags, isEmpty);
      expect(f.trace, ['save:unread']);
      expect(f.saved, [
        {'open': 0},
      ]);
      expect(f.changedCount, 0);
      w.reconcileOpenRead('open', before, optimistic: true);
      expect(f.trace.last, 'refreshUnread');
      f.trace.clear();
      w.readPosts['open'] = 8;
      w.reconcileOpenRead('open', before, optimistic: true);
      w.reconcileOpenRead('open', 8, optimistic: false);
      f.disposed = true;
      w.reconcileOpenRead('open', 8, optimistic: true);
      expect(f.trace, isEmpty);
    },
  );

  test(
    'prefetch keeps order, limit, admission, sequential and session guards',
    () async {
      final f = _Fixture(), w = f.owner;
      w.channels = [
        _channel('open'),
        _channel('revoked'),
        _channel('denied'),
        _channel('accepted'),
        _channel('quiet'),
        _channel('one'),
        _channel('two'),
      ];
      w.dms = [_channel('dm', type: 'dm')];
      w.unread = {
        for (final c in [...w.channels, ...w.dms]) c.id: 1,
        'quiet': 0,
      };
      f.revoked.add('revoked');
      f.denied.add('denied');
      f.accepted.add('accepted');
      f.loading = true;
      await w.prefetchLikelyChannels();
      expect(f.prefetched, isEmpty);
      f.loading = false;
      final entered = Completer<void>(), release = Completer<void>();
      f.prefetch = (c, current) async {
        if (c.id == 'one') {
          entered.complete();
          await release.future;
        }
        expect(current(), true);
      };
      final first = w.prefetchLikelyChannels(limit: 2);
      await entered.future;
      await w.prefetchLikelyChannels();
      expect(f.prefetched, ['one']);
      release.complete();
      await first;
      expect(f.prefetched, ['one', 'two']);
      f.prefetch = null;
      await w.prefetchLikelyChannels();
      expect(f.prefetched, ['one', 'two', 'dm']);
      await w.prefetchLikelyChannels();
      expect(f.prefetched, ['one', 'two', 'dm']);
      expect(w.unread['one'], 1);
      expect(f.channel?.id, 'open');
      expect(f.changedCount, 0);
      w.clearSessionPrefetch();
      await w.prefetchLikelyChannels(limit: 1);
      expect(f.prefetched.last, 'one');
    },
  );

  for (final change in ['identity', 'generation', 'role', 'dispose']) {
    test(
      'prefetch stops after $change changes during the first candidate',
      () async {
        final f = _Fixture(), w = f.owner;
        w.channels = [_channel('one'), _channel('two')];
        w.unread = {'one': 1, 'two': 1};
        f.prefetch = (_, current) async {
          switch (change) {
            case 'identity':
              f.identityValue = 'changed';
            case 'generation':
              f.generation++;
            case 'role':
              f.server = RaftRecord({'id': 's', 'role': 'member'});
            case 'dispose':
              f.disposed = true;
          }
          expect(current(), false);
        };
        await w.prefetchLikelyChannels();
        expect(f.prefetched, ['one']);
      },
    );
  }

  test(
    'failed prefetch releases the in-flight guard but retains the once mark',
    () async {
      final f = _Fixture(), w = f.owner;
      w.channels = [_channel('one'), _channel('two')];
      w.unread = {'one': 1, 'two': 1};
      f.prefetch = (_, _) async => throw StateError('request construction');
      await expectLater(w.prefetchLikelyChannels(), throwsStateError);
      f.prefetch = null;
      await w.prefetchLikelyChannels();
      expect(f.prefetched, ['one', 'two']);
    },
  );

  test(
    'preferences patch servers before selection then use the public refresh',
    () {
      final f = _Fixture(), w = f.owner;
      w.consumeNotificationPrefs({
        'serverId': 's',
        'scopeId': 's',
        'prefs': {'serverPushMuted': true},
        'prefsVersion': 3,
      });
      expect(f.trace, [
        'ensureIdentity',
        'patchServers',
        'patchSelectedServer',
        'refreshUnread',
      ]);
      expect(f.servers.single.json['serverPushMuted'], true);
      expect(f.server!.json['notificationPrefsVersion'], 3);
      expect(f.changedCount, 0);
      f.trace.clear();
      w.consumeNotificationPrefs({
        'serverId': 'other',
        'scopeId': 'other',
        'prefs': {'serverPushMuted': false},
      });
      expect(f.trace, ['ensureIdentity']);
    },
  );

  test(
    'versioned channel preferences and identity reset reuse the one reducer',
    () {
      final f = _Fixture(), w = f.owner;
      w.channels = [_channel('one')];
      f.channel = w.channels.single;
      f.syncCoreNotificationPrefsEnabled = true;
      Map<String, dynamic> payload(bool muted) => {
        'serverId': 's',
        'scopeId': 'one',
        'prefs': {'activityMuted': muted},
        'prefsVersion': 3,
      };
      w.consumeNotificationPrefs(payload(true));
      w.consumeNotificationPrefs(payload(false));
      expect(w.channels.single.json['activityMuted'], true);
      expect(f.trace.where((e) => e == 'refreshUnread'), hasLength(1));
      w.resetNotificationPrefsIdentity();
      w.consumeNotificationPrefs(payload(false));
      expect(w.channels.single.json['activityMuted'], false);
    },
  );

  test(
    'Files authority follows the selected row and revocation, not a visit',
    () {
      final f = _Fixture(), w = f.owner;
      final held = RaftChannel({
        ..._channel('one').json,
        'channelCapabilities': {'viewChannel': true},
      });
      w.channels = [held];
      final fromList = w.channelFilesAuthority('one');
      expect(fromList, isNotNull);
      f.channel = _channel('unrelated');
      expect(w.channelFilesAuthority('one'), fromList);
      f.channel = RaftChannel({
        ...held.json,
        'channelCapabilities': {'viewChannel': false},
      });
      expect(w.channelFilesAuthority('one'), isNot(fromList));
      f.revoked.add('one');
      expect(w.channelFilesAuthority('one'), isNull);
      f.revoked.clear();
      f.denied.add('one');
      expect(w.channelFilesAuthority('one'), isNull);
      f.denied.clear();
      f.disposed = true;
      expect(w.channelFilesAuthority('one'), isNull);
    },
  );

  test(
    'borrowed repositories keep local sidebar, saved counters and read ledger',
    () {
      final source = _Fixture();
      final borrowed = _Fixture(
        sharedSidebar: source.owner.sidebar,
        sourceReadState: source.owner.localReadState,
      );
      source.owner.assignSidebarOrder({
        'pinned': ['one'],
      });
      source.owner.savedChanged();
      expect(borrowed.owner.sidebar, same(source.owner.sidebar));
      expect(borrowed.owner.sidebarOrder, isEmpty);
      expect(borrowed.owner.savedRevision, 0);
      expect(
        borrowed.owner.effectiveReadState,
        same(source.owner.localReadState),
      );
      expect(
        borrowed.owner.localReadState,
        isNot(same(source.owner.localReadState)),
      );
      borrowed.owner.readPosts['one'] = 4;
      borrowed.owner.setTimelineAtBottom('one', false);
      borrowed.owner.resetDirectoryAndUnreadProjection();
      expect(borrowed.owner.readPosts['one'], 4);
      expect(borrowed.owner.scrolledAway.away('one'), true);
      expect(source.owner.sidebarOrder, {
        'pinned': ['one'],
      });
      expect(source.changedCount, 1);
      expect(borrowed.changedCount, 0);
    },
  );
}
