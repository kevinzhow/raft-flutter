import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_messages.dart';
import 'package:raft_flutter/data/channel_repository.dart';

RaftChannel _row(String id, {String type = 'public'}) => RaftChannel({
  'id': id,
  'name': id,
  'serverId': 's1',
  'type': type,
  'joined': true,
  'activityMuted': false,
  'prefsVersion': 2,
  'collapseLongMessages': false,
  'displayPrefsVersion': 2,
});

class _Cache implements WorkspaceCache {
  final saved = <String, dynamic>{};
  final trace = <String>[];
  @override
  Future<dynamic> read(o, p, s, String kind, String id) async => null;
  @override
  Future<void> write(o, p, s, String kind, String id, value) async {
    trace.add('write:$kind');
    saved[kind] = value;
  }

  @override
  Future<void> revokeChannel(o, p, s, String id) async =>
      trace.add('purge:$id');
  @override
  Future<void> revokeServer(o, p, s) async {}
  @override
  Future<void> clearAccount(o, p) async {}
  @override
  Future<List<Map<String, dynamic>>> readTranslations(o, p, s) async => [];
  @override
  Future<void> writeTranslations(o, p, s, entries) async {}
  @override
  Future<void> close() async {}
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
  List<RaftChannel> nextChannels = [_row('c1')], nextDms = [];
  Future<void>? _closing;
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? nextDms : nextChannels;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  void emit(String name, dynamic payload) => bus.add(RaftEvent(name, payload));
  @override
  Future<void> dispose() => _closing ??= _close();
  Future<void> _close() async {
    await bus.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, {required super.cache, super.presentationSource})
    : super(ownsClient: presentationSource == null);
  int notifications = 0, unreadRefreshes = 0, closes = 0;
  void Function()? onUnread, onClose;
  final trace = <String>[];
  @override
  Future<void> refreshUnread() async {
    unreadRefreshes++;
    trace.add('unread');
    onUnread?.call();
  }

  @override
  void closeThread({bool navigate = true}) {
    closes++;
    trace.add('close');
    onClose?.call();
    super.closeThread(navigate: navigate);
  }

  @override
  void notifyListeners() {
    notifications++;
    trace.add('notify');
    super.notifyListeners();
  }
}

class _Fixture {
  _Fixture() {
    root = make();
    addTearDown(() async {
      for (final w in pages.reversed) {
        w.onClose = w.onUnread = null;
        await w.flushCache();
        w.dispose();
      }
      await client.dispose();
    });
  }
  final client = _Client(), cache = _Cache();
  final pages = <_Workspace>[];
  late final _Workspace root;
  _Workspace make({WorkspaceController? source}) {
    final w = _Workspace(client, cache: cache, presentationSource: source);
    pages.add(w);
    w.server = RaftRecord({
      'id': 's1',
      'role': 'member',
      'notificationPrefsVersion': 2,
      'serverPushMuted': false,
    });
    w.servers = [w.server!];
    w.channels = [_row('c1'), _row('c2')];
    w.dms = [_row('d1', type: 'dm')];
    w.channel = w.channels.first;
    if (source == null) w.messageDomain.ledger.switchServer('s1');
    w.notifyListeners(); // Establish sync identity before setting feature flags.
    w.notifications = w.unreadRefreshes = w.closes = 0;
    w.trace.clear();
    return w;
  }
}

Map<String, dynamic> _notification(
  String scope,
  int version, {
  String server = 's1',
  bool muted = true,
}) => {
  'serverId': server,
  'scopeId': scope,
  'prefsVersion': version,
  'prefs': {'activityMuted': muted, 'muteFromSeq': '8'},
};

Map<String, dynamic> _display(
  String scope,
  num version, {
  String server = 's1',
  bool collapse = true,
}) => {
  'serverId': server,
  'scopeId': scope,
  'prefsVersion': version,
  'prefs': {'collapseLongMessages': collapse},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('direct list assignment preserves aliases and does not adopt selection or notify', () {
    final f = _Fixture(), w = f.root;
    final selected = w.channel;
    final channels = [_row('replacement')], dms = [_row('d2', type: 'dm')];
    w.channels = channels;
    w.dms = dms;
    expect(identical(w.channels, channels), isTrue);
    expect(identical(w.dms, dms), isTrue);
    channels.add(_row('added'));
    w.dms.removeWhere((c) => c.id == 'd2');
    expect(w.channels.map((c) => c.id), ['replacement', 'added']);
    expect(dms, isEmpty);
    expect(identical(w.channel, selected), isTrue);
    expect(w.notifications, 0);
  });

  test('borrowed presentation lists remain independent under assignments and reset', () {
    final f = _Fixture(), page = f.make(source: f.root);
    final own = [_row('page')];
    page.channels = own;
    final sourceRows = f.root.channels;
    f.root.resetServerProjection();
    expect(f.root.channels, isEmpty);
    expect(f.root.dms, isEmpty);
    expect(identical(page.channels, own), isTrue);
    expect(page.channels.single.id, 'page');
    expect(sourceRows.map((c) => c.id), ['c1', 'c2']);
    expect((f.root.notifications, page.notifications), (0, 0));
  });

  test('list acceptance revokes against old rows, then publishes and queues the new directory', () async {
    final f = _Fixture(), w = f.root;
    w.channel = w.channels.last;
    w.messageDomain.state.threadParent = RaftMessage({
      'id': 'parent',
      'channelId': 'c2',
      'threadChannelId': 't2',
    });
    w.threadChannelId = 't2';
    w.composer.drafts['c2'] = 'keep authored text';
    w.onClose = () {
      expect(w.channels.map((c) => c.id), ['c1', 'c2']);
      expect(w.sessionScope.revokedChannels, containsAll(['c2', 't2']));
    };
    final kept = w.channels.first;
    await w.refreshChannels();
    await w.flushCache();
    expect(w.channels.map((c) => c.id), ['c1']);
    expect(identical(w.channels.single, kept), isTrue);
    expect(w.channel, isNull);
    expect(w.threadChannelId, isNull);
    expect(w.closes, 1);
    expect(w.composer.drafts['c2'], 'keep authored text');
    final saved = f.cache.saved['channels'] as Map;
    expect([for (final row in saved['channels'] as List) row['id']], ['c1']);
    expect(
      f.cache.trace.indexOf('purge:c2'),
      lessThan(f.cache.trace.indexOf('write:channels')),
    );
    expect(w.trace.first, 'close');
    expect(w.trace.last, 'notify');
  });

  for (final held in ['pending-dm', 'share']) {
    test(
      'an unlisted $held destination stays selected after directory acceptance',
      () async {
        final f = _Fixture(), w = f.root;
        final selected = held == 'pending-dm'
            ? WorkspaceMessages.pendingDm(
                key: 'peer',
                serverId: 's1',
                name: 'peer',
              )
            : _row('share');
        w.channel = selected;
        if (held == 'share') w.holdShared(selected.id);
        w.composer.drafts[selected.id] = 'my draft';
        await w.refreshChannels();
        expect(identical(w.channel, selected), isTrue);
        expect(w.composer.drafts[selected.id], 'my draft');
        expect(w.channels.map((c) => c.id), ['c1']);
        expect(w.dms, isEmpty);
        if (held == 'share') expect(w.sharedBlocked(), isTrue);
      },
    );
  }

  test('activity mute delegates to source and patches its selected copy before notifying', () {
    final f = _Fixture(), source = f.root, page = f.make(source: f.root);
    final local = page.channels;
    source.channel = _row('c1');
    page.setActivityMuteState('c1', {'activityMuted': true, 'prefsVersion': 7});
    expect(source.channels.first.json['activityMuted'], isTrue);
    expect(source.channel!.json['prefsVersion'], 7);
    expect(source.notifications, 1);
    expect(identical(page.channels, local), isTrue);
    expect(page.channels.first.json['activityMuted'], isFalse);
    expect(page.notifications, 0);
    expect(source.unreadRefreshes, 0);
  });

  test('legacy notification patches rows and selection before unread; old versions still refresh unread', () {
    final f = _Fixture(), w = f.root;
    w.channel = _row('c1');
    w.onUnread = () {
      expect(w.channels.first.json['activityMuted'], isTrue);
      expect(w.channel!.json['activityMuted'], isTrue);
    };
    f.client.emit('notification_prefs:updated', _notification('c1', 3));
    final accepted = w.channels.first;
    f.client.emit(
      'notification_prefs:updated',
      _notification('c1', 2, muted: false),
    );
    expect(identical(w.channels.first, accepted), isTrue);
    expect(w.channel!.json['prefsVersion'], 3);
    expect(w.trace, ['unread', 'notify', 'unread', 'notify']);
    expect(w.dms.single.json['activityMuted'], isFalse);
  });

  test('sync-core notification duplicate keeps the event notification but skips unread', () {
    final f = _Fixture(), w = f.root;
    w.syncCoreNotificationPrefsEnabled = true;
    f.client.emit('notification_prefs:updated', _notification('c1', 3));
    final accepted = w.channels;
    f.client.emit(
      'notification_prefs:updated',
      _notification('c1', 3, muted: false),
    );
    expect(identical(w.channels, accepted), isTrue);
    expect(w.channels.first.json['activityMuted'], isTrue);
    expect(w.trace, ['unread', 'notify', 'notify']);
  });

  test(
    'revoked channel preference does not refresh unread or patch any row',
    () {
      final f = _Fixture(), w = f.root;
      final held = w.channels;
      w.sessionScope.revokedChannels.add('c1');
      f.client.emit('notification_prefs:updated', _notification('c1', 3));
      expect(identical(w.channels, held), isTrue);
      expect(w.trace, ['notify']);
    },
  );

  test(
    'server preferences remain separate from channel revocation and versions',
    () {
      final f = _Fixture(), w = f.root;
      final held = w.channels;
      w.sessionScope.revokedChannels.add('s1');
      f.client.emit('notification_prefs:updated', {
        'serverId': 's1',
        'scopeId': 's1',
        'prefsVersion': 4,
        'prefs': {'serverPushMuted': true},
      });
      f.client.emit('notification_prefs:updated', {
        'serverId': 's1',
        'scopeId': 's1',
        'prefsVersion': 3,
        'prefs': {'serverPushMuted': false},
      });
      expect(w.server!.json['serverPushMuted'], isTrue);
      expect(w.servers.single.json['notificationPrefsVersion'], 4);
      expect(identical(w.channels, held), isTrue);
      expect(w.trace, ['unread', 'notify', 'unread', 'notify']);
    },
  );

  test(
    'foreign notification and malformed display payload retain list identity',
    () {
      final f = _Fixture(), w = f.root;
      final held = w.channels;
      f.client.emit(
        'notification_prefs:updated',
        _notification('c1', 3, server: 's2'),
      );
      f.client.emit('message_display_prefs:updated', {
        ..._display('c1', 4),
        'prefs': {'collapseLongMessages': 'true'},
      });
      expect(identical(w.channels, held), isTrue);
      expect(w.unreadRefreshes, 0);
      expect(w.notifications, 2);
    },
  );

  test('display version is truncated and older row versions preserve objects but copy lists', () {
    final f = _Fixture(), w = f.root;
    w.channel = _row('c1');
    f.client.emit('message_display_prefs:updated', _display('c1', 3.9));
    final firstList = w.channels, accepted = w.channels.first;
    expect(w.channel!.json['displayPrefsVersion'], 3);
    expect(w.channel!.json['collapseLongMessages'], isTrue);
    f.client.emit(
      'message_display_prefs:updated',
      _display('c1', 2, collapse: false),
    );
    expect(identical(w.channels, firstList), isFalse);
    expect(identical(w.channels.first, accepted), isTrue);
    expect(w.unreadRefreshes, 0);
    expect(w.notifications, 2);
  });

  test(
    'unknown display scope still copies lists without replacing unrelated rows',
    () {
      final f = _Fixture(), w = f.root;
      final held = w.channels, first = w.channels.first;
      f.client.emit('message_display_prefs:updated', _display('unknown', 3));
      expect(identical(w.channels, held), isFalse);
      expect(identical(w.channels.first, first), isTrue);
      expect(w.notifications, 1);
      expect(w.unreadRefreshes, 0);
    },
  );

  test('display keeps its original nullable-server acceptance boundary', () {
    final f = _Fixture(), w = f.root;
    final held = w.channels;
    f.client.emit(
      'message_display_prefs:updated',
      _display('c1', 3, server: 's2'),
    );
    expect(identical(w.channels, held), isTrue);
    f.client.serverId = null;
    f.client.emit(
      'message_display_prefs:updated',
      _display('c1', 3, server: 's2'),
    );
    expect(w.channels.first.json['collapseLongMessages'], isTrue);
    expect(w.notifications, 2);
  });

  test('revoked display scope is ignored before lists are copied', () {
    final f = _Fixture(), w = f.root;
    final held = w.channels;
    w.sessionScope.revokedChannels.add('c1');
    f.client.emit('message_display_prefs:updated', _display('c1', 3));
    expect(identical(w.channels, held), isTrue);
    expect(w.notifications, 1);
  });

  test(
    'public static display helpers keep their record and row identity contract',
    () {
      final parsed = ChannelRepository.readMessageDisplayPrefsUpdate(
        _display('c1', 3.9),
      );
      expect(parsed, (
        serverId: 's1',
        channelId: 'c1',
        collapse: true,
        version: 3,
      ));
      expect(
        ChannelRepository.readMessageDisplayPrefsUpdate({'serverId': 3}),
        isNull,
      );
      final held = _row('c1');
      final ignored = ChannelRepository.applyMessageDisplayPrefsToChannel(
        held,
        collapse: true,
        version: 1,
      );
      expect(identical(ignored, held), isTrue);
      final next = ChannelRepository.applyMessageDisplayPrefsToChannel(
        held,
        collapse: true,
      );
      expect(next.json['displayPrefsVersion'], 2);
      expect(next.json['collapseLongMessages'], isTrue);
    },
  );
}
