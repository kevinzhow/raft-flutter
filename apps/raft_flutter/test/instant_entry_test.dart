@Tags(['slow'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/incoming_share_picker.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootCache, RootFixture;
import 'workspace_source_location_contract_test.dart' show LocalNotifications;
import 'flutter_test_config.dart' show leakDebt;

// Time-to-first-meaningful-frame harness for the two entry points that must
// feel instant: an incoming Android share and a notification tap. Every
// network read is slow (it completes only after [apiDelay] of virtual time);
// a "frame" is one 16 ms pump. The numbers printed as `METRIC` are the
// before/after figures of the instant-entry change.
const apiDelay = Duration(seconds: 2);
const frameStep = Duration(milliseconds: 16);
const _origin = 'https://fixture.invalid';
const _memory = 'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice';

/// Network reads a cold start makes before its first channel page.
const _startupReads = [
  'GET /auth/me',
  'GET /servers',
  'GET /channels',
  'GET /channels/dm',
  'GET /channels/unread',
  'GET /messages/channel/ca',
];

Map<String, dynamic> _row(String id, String channel, String text) => {
  'id': id,
  'channelId': channel,
  'seq': '1',
  'senderId': 'alice',
  'senderName': 'Alice',
  'content': text,
  'createdAt': '2026-10-10T00:00:00Z',
};

void _routes(RootFixture f) {
  f.overrides['GET /channels'] = (o) {
    final id = o.headers['X-Server-Id'];
    return [
      {
        'id': 'c$id',
        'name': 'general-$id',
        'type': 'channel',
        'serverId': id,
        'joined': true,
        'latestSeq': '1',
      },
      if (id == 'a')
        {
          'id': 'cx',
          'name': 'general-x',
          'type': 'channel',
          'serverId': 'a',
          'joined': true,
          'latestSeq': '1',
        },
      if (id == 'a')
        {
          'id': 'cp',
          'name': 'public-p',
          'type': 'channel',
          'serverId': 'a',
          'joined': false,
          'latestSeq': '1',
        },
    ];
  };
  f.overrides['GET /servers/a/members'] = (_) => [
    {'userId': 'alice', 'displayName': 'Alice'},
    {'userId': 'bob', 'displayName': 'Bob'},
  ];
  f.overrides['POST /channels/dm'] = (_) => {'id': 'dmbob'};
  f.overrides['GET /channels/dmbob'] = (_) => {
    'id': 'dmbob',
    'name': 'bob',
    'type': 'dm',
    'serverId': 'a',
    'joined': true,
    'peerDisplayName': 'Bob',
    'peerId': 'bob',
  };
  f.overrides['GET /messages/channel/dmbob'] = (_) => {
    'messages': [],
    'hasMore': false,
    'hasNewer': false,
  };
  f.overrides['POST /channels/dmbob/read'] = (_) => {};
  f.overrides['GET /channels/dmbob/members'] = (_) => [];
  f.overrides['POST /channels/cp/join'] = (_) => {};
  f.overrides['GET /channels/cp'] = (_) => {
    'id': 'cp',
    'name': 'public-p',
    'type': 'channel',
    'serverId': 'a',
    'joined': true,
  };
  f.overrides['GET /messages/channel/cp'] = (_) => {
    'messages': [],
    'hasMore': false,
    'hasNewer': false,
  };
  f.overrides['POST /channels/cp/read'] = (_) => {};
  f.overrides['GET /channels/cp/members'] = (_) => [];
  f.overrides['GET /channels/cx'] = (_) => {
    'id': 'cx',
    'name': 'general-x',
    'type': 'channel',
    'serverId': 'a',
    'joined': true,
  };
  f.overrides['GET /messages/channel/cx'] = (_) => {
    'messages': [_row('mcx', 'cx', 'Accepted x')],
    'hasMore': false,
    'hasNewer': false,
  };
  f.overrides['GET /messages/context/mcx'] = (_) => {
    'messages': [_row('mcx', 'cx', 'Accepted x')],
    'targetMessageId': 'mcx',
    'hasOlder': false,
    'hasNewer': false,
  };
  f.overrides['POST /channels/cx/read'] = (_) => {};
  f.overrides['GET /channels/cx/members'] = (_) => [];
  f.overrides['GET /channels/cb'] = (_) => {
    'id': 'cb',
    'name': 'general-b',
    'type': 'channel',
    'serverId': 'b',
    'joined': true,
  };
}

/// First process: open Alpha's two channels so their windows are on disk.
Future<RootCache> _firstProcess(
  WidgetTester t, {
  bool bothServers = false,
}) async {
  final f = RootFixture();
  _routes(f);
  await f.mount(t, 'light', 1280);
  await t.tap(find.byKey(const ValueKey('global-server-a')));
  await f.flush(t);
  await t.tap(find.text('general-x').first);
  await f.flush(t);
  expect(find.text('Accepted x'), findsOneWidget);
  if (bothServers) {
    // Beta's channels are on the device too (a cross-server share).
    unawaited(f.workspace(t).selectServer(RaftRecord(f.servers[1])));
    for (var i = 0; i < 4; i++) {
      await f.flush(t);
    }
    unawaited(f.workspace(t).selectServer(RaftRecord(f.servers[0])));
    for (var i = 0; i < 4; i++) {
      await f.flush(t);
    }
  }
  await f.workspace(t).flushCache();
  await f.close(t);
  return f.cache;
}

/// The scene's API gate: every wait opens it after [apiDelay] of virtual time.
Gate? activeGate;

/// Attachment copies that also finish after [apiDelay].
final copyGates = <Gate>[];

class Gate {
  Gate([this.holds = const {}]);

  /// Startup reads a cold start holds; they open together with the gate.
  final Map<String, Completer<dynamic>> holds;
  final done = Completer<void>();
  void open() {
    if (!done.isCompleted) done.complete();
    for (final held in holds.values) {
      if (!held.isCompleted) held.complete(null);
    }
  }
}

/// Wraps the current route so it answers only once [gate] opens.
void slow(RootFixture f, Gate gate, [Iterable<String>? keys]) {
  for (final key in keys ?? List.of(f.adapter.routes.keys)) {
    final route = f.adapter.routes[key];
    if (route == null) continue;
    f.adapter.routes[key] = (o) async {
      await gate.done.future;
      return route(o);
    };
  }
}

/// Every request takes [latency] (a realistic mobile round trip), instead of
/// waiting for a gate: serial awaits then add up.
void latent(RootFixture f, Duration latency) {
  for (final key in List.of(f.adapter.routes.keys)) {
    final route = f.adapter.routes[key]!;
    f.adapter.routes[key] = (o) async {
      await Future<void>.delayed(latency);
      return route(o);
    };
  }
}

/// Frames until [done], opening [gate] once [apiDelay] of virtual time passed.
/// Returns the frame index at which [done] first held (0 = immediately).
Future<int> framesUntil(
  WidgetTester t,
  bool Function() done, {
  Gate? gate,
  int max = 400,
}) async {
  for (var frame = 0; frame <= max; frame++) {
    if (done()) return frame;
    if (frameStep * frame >= apiDelay) {
      (gate ?? activeGate)?.open();
      for (final copy in copyGates) {
        copy.open();
      }
    }
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await t.pump(frameStep);
  }
  return -1;
}

void metric(String name, int frames) => debugPrint(
  'METRIC $name: ${frames < 0 ? 'never' : '$frames frames (${frames * 16} ms)'}',
);

NativeSharing slowSharing(Directory dir, Gate gate) => NativeSharing(
  supported: false,
  incomingDirectory: () async => dir,
  readContent: (_) async* {
    await gate.done.future;
    yield Uint8List.fromList([1, 2, 3]);
  },
);

const _share = IncomingShare(
  text: 'Shared caption',
  files: [
    IncomingSharedFile('content://fixture/photo', 'photo.jpg', 'image/jpeg', 3),
  ],
);

String payload(RootFixture f, String uri) => jsonEncode({
  'origin': _origin,
  'principal': 'alice',
  'serverId': 'a',
  'uri': uri,
});

const _toX = 'raft://v1/servers/a/channels/cx/messages/mcx';

const _coldExtras = [
  'GET /channels/cx',
  'GET /messages/channel/cx',
  'GET /messages/context/mcx',
  'GET /servers/a/members',
  'GET /servers/b/members',
  'GET /channels/public',
];

bool pickerVisible() => find.byType(IncomingSharePicker).evaluate().isNotEmpty;
bool row(String key) =>
    find.byKey(ValueKey('incoming-target-$key')).evaluate().isNotEmpty;
bool text(String value) => find.text(value).evaluate().isNotEmpty;

/// Writes: anything but the app's own read receipts.
Iterable<String> sentAnything(RootFixture f) => f.adapter.calls
    .where(
      (c) =>
          c.method != 'GET' &&
          !c.path.endsWith('/read') &&
          c.path != '/feature-flags/evaluate',
    )
    .map((c) => '${c.method} ${c.path}');

/// A running app on a second process over the device cache of a first one.
/// Every read is slow: warm (settled workspace, then everything slowed) or
/// cold (the startup reads and the rest held until [gate] opens).
class Scene {
  Scene(this.f, this.w, this.gate, this.coordinator, this.notifications);
  final RootFixture f;
  final WorkspaceController w;
  final Gate gate;
  final NativeContentCoordinator? coordinator;
  final LocalNotifications? notifications;
}

Future<Scene> boot(
  WidgetTester t,
  Directory dir, {
  required bool cold,
  NativeSharing? sharing,
  bool coordinator = false,
  bool gated = true,
  bool bothServers = false,
}) async {
  final cache = await _firstProcess(t, bothServers: bothServers);
  final holds = <String, Completer<dynamic>>{
    if (cold)
      for (final key in _startupReads) key: Completer<dynamic>(),
  };
  final gate = Gate(holds);
  final n = coordinator ? LocalNotifications() : null;
  final content = coordinator
      ? NativeContentCoordinator(notifications: n, links: const Stream.empty())
      : null;
  final f = RootFixture(
    cache: cache,
    sharing: sharing,
    contentOverride: content,
  );
  _routes(f);
  f.holds.addAll(holds);
  await f.mount(
    t,
    'light',
    412,
    cachedSession: true,
    settle: !cold,
    preferences: {'$_memory.last': 'alpha', '$_memory.a': '/s/alpha'},
  );
  if (cold) {
    slow(f, gate, _coldExtras);
    await t.pump(frameStep);
  } else {
    for (var i = 0; i < 3; i++) {
      await f.flush(t);
    }
    if (gated) slow(f, gate);
  }
  activeGate = gate;
  addTearDown(() {
    activeGate = null;
    copyGates.clear();
  });
  expect(find.byType(WorkspaceView), findsOneWidget);
  final w = f.workspace(t);
  addTearDown(() async {
    gate.open();
    if (content != null) await t.runAsync(content.dispose);
  });
  return Scene(f, w, gate, content, n);
}

Future<void> settle(WidgetTester t, Scene s, [int frames = 12]) async {
  s.gate.open();
  for (var i = 0; i < frames; i++) {
    await s.f.flush(t);
  }
}

/// Workspace failures are Web's `toast.error`: the view shows them and clears
/// `w.error`, so a test records what was raised instead of reading it later.
List<String> raisedErrors(WorkspaceController w) {
  final seen = <String>[];
  w.addListener(() {
    final e = w.error;
    if (e != null) seen.add(e);
  });
  return seen;
}

void main() {
  // Leak debt (app root, share flow): see docs/development.md, Leak tracking.
  leakDebt(const [
    'IncomingShareStaging',
    'LocalNotifications',
    'ValueNotifier<RaftTransferProgress?>',
  ]);
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('raft-instant-share-');
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  for (final cold in [false, true]) {
    final mode = cold ? 'cold' : 'warm';
    testWidgets(
      'share $mode: picker and cached targets are visible within 2 frames while API and copy are slow, then the hand-off lands in the chosen channel',
      (t) async {
        final copy = Gate();
        copyGates.add(copy);
        final sharing = slowSharing(dir, copy);
        if (cold) sharing.receive(_share);
        final s = await boot(t, dir, cold: cold, sharing: sharing);
        final f = s.f;
        if (!cold) sharing.receive(_share);
        final frames = await framesUntil(t, pickerVisible, gate: null);
        metric('share $mode: picker visible', frames);
        expect(frames, inInclusiveRange(0, 2));
        expect(row('cx') && row('ca'), isTrue, reason: 'cached destinations');
        expect(
          find.byKey(const Key('incoming-share-preparing')),
          findsOneWidget,
        );
        // Per-item progress is shown while the copy is still pending.
        expect(find.text('Preparing 0 of 1 files'), findsOneWidget);
        // Let the page transition finish (the API and the copy stay pending).
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(find.byKey(const ValueKey('incoming-target-cx')));
        await t.pump();
        await t.tap(find.byKey(const Key('incoming-share-continue')));
        await t.pump();
        expect(
          t
              .widget<RaftForwardContinueAction>(
                find.byKey(const Key('incoming-share-continue')),
              )
              .busy,
          isTrue,
          reason: 'waiting for the copy',
        );
        expect(sentAnything(f), isEmpty);
        copy.open();
        s.gate.open();
        final landed = await framesUntil(
          t,
          () =>
              !pickerVisible() &&
              s.w.drafts['cx'] == 'Shared caption' &&
              s.w.uploads().isNotEmpty,
        );
        metric('share $mode: hand-off after API resolves', landed);
        expect(landed, greaterThanOrEqualTo(0));
        final w = s.w;
        expect(w.channel?.id, 'cx');
        expect(w.uploads().single.queued, isTrue);
        expect(w.error, isNull);
        await f.close(t);
      },
    );
  }

  bool composerHasShare(Scene s, String scope) =>
      !pickerVisible() &&
      s.w.channel?.id == scope &&
      s.w.drafts[scope] == 'Shared caption' &&
      s.w.uploads().isNotEmpty;

  /// Polls [done] with the API closed and *no virtual time passing*: real
  /// time lets the inbox's file IO finish, each poll is one zero-length frame.
  /// A hand-off that awaited a request (gated until virtual time advances or
  /// the gate opens) would never get there. Returns the polls it took.
  Future<int> framesClosed(
    WidgetTester t,
    bool Function() done, {
    int max = 60,
  }) async {
    for (var poll = 0; poll <= max; poll++) {
      if (done()) return poll;
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump();
    }
    return -1;
  }

  /// The draft is staged in [scope] and the page left, API still closed.
  /// Returns the zero-time polls the staging took (each sequential file read
  /// or write of the inbox needs one), or -1.
  Future<int> landed(WidgetTester t, Scene s, String scope, {Gate? api}) async {
    final polls = await framesClosed(
      t,
      () =>
          s.w.channel?.id == scope &&
          s.w.drafts[scope] == 'Shared caption' &&
          s.w.uploads().isNotEmpty,
    );
    if (polls < 0) return -1;
    // The page's route animation needs time, not the network.
    for (var i = 0; i < 40 && pickerVisible(); i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    return composerHasShare(s, scope) && !(api ?? s.gate).done.isCompleted
        ? polls
        : -1;
  }

  /// Lets the picker's own directory read finish, then closes the API again
  /// (a new gate): the hand-off that follows has only the device to use.
  Future<Gate> regate(WidgetTester t, Scene s) async {
    await settle(t, s, 6);
    final closed = Gate();
    slow(s.f, closed);
    return closed;
  }

  /// Opens the copy and waits until it has been staged (all on this device).
  Future<void> copyDone(WidgetTester t, Gate copy) async {
    copy.open();
    expect(
      await framesClosed(
        t,
        () => find
            .byKey(const Key('incoming-share-preparing'))
            .evaluate()
            .isEmpty,
      ),
      greaterThanOrEqualTo(0),
    );
  }

  /// The picker with the copy finished (it is on this device), then Continue
  /// on [key]. The API stays closed throughout: what follows is the hand-off
  /// itself.
  Future<void> continueOn(
    WidgetTester t,
    Scene s,
    Gate copy,
    String key,
  ) async {
    await framesUntil(t, pickerVisible, gate: null);
    await copyDone(t, copy);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(ValueKey('incoming-target-$key')));
    await t.pump();
    await t.tap(find.byKey(const Key('incoming-share-continue')));
  }

  for (final cold in [false, true]) {
    final mode = cold ? 'cold' : 'warm';
    testWidgets(
      'share $mode: Continue reaches the composer with every request pending, then the destination is checked behind it',
      (t) async {
        final copy = Gate();
        copyGates.add(copy);
        final sharing = slowSharing(dir, copy);
        if (cold) sharing.receive(_share);
        final s = await boot(t, dir, cold: cold, sharing: sharing);
        if (!cold) sharing.receive(_share);
        await continueOn(t, s, copy, 'cx');
        // Only the copy ended. The API stays closed for this whole wait.
        final polls = await landed(t, s, 'cx');
        metric('share $mode: composer with API closed', polls);
        expect(polls, greaterThanOrEqualTo(0));
        expect(s.gate.done.isCompleted, isFalse);
        final w = s.w;
        expect(w.uploads().single.queued, isTrue);
        // Held until checked: Send is off, nothing is said yet.
        expect(w.sharedBlocked(), isTrue);
        expect(w.shareNoticeFor(), isNull);
        expect(await w.send('hello'), isFalse);
        expect(sentAnything(s.f), isEmpty);
        // The API answers: the destination is confirmed and Send comes back.
        await settle(t, s);
        expect(w.sharedBlocked(), isFalse);
        expect(
          find.byKey(const Key('shared-destination-notice')),
          findsNothing,
        );
        expect(
          s.f.adapter.calls.map((c) => c.path),
          containsAll(['/servers', '/channels/cx']),
        );
        expect(w.drafts['cx'], 'Shared caption');
        expect(sentAnything(s.f), isEmpty);
        await s.f.close(t);
      },
    );
  }

  // iPhone: the Share Extension publishes the files into the shared inbox
  // before it opens the app, so the app receives an already-staged share
  // (a token, no copy). It is the same picker and the same hand-off.
  testWidgets(
    'share iOS: an extension-published share reaches the composer with every request pending',
    (t) async {
      final token = 'a' * 32;
      final folder = Directory('${dir.path}/$token')..createSync();
      File('${folder.path}/item-0').writeAsBytesSync([1, 2, 3]);
      File('${folder.path}/envelope.json').writeAsStringSync(
        jsonEncode({
          'token': token,
          'created': DateTime.now().millisecondsSinceEpoch,
          'pending': true,
          'text': 'Shared caption',
          'files': [
            {
              'file': 'item-0',
              'filename': 'photo.jpg',
              'mimeType': 'image/jpeg',
              'sizeBytes': 3,
            },
          ],
        }),
      );
      final sharing = NativeSharing(
        supported: false,
        incomingDirectory: () async => dir,
      );
      final s = await boot(t, dir, cold: false, sharing: sharing);
      sharing.receive(
        IncomingShare(
          token: token,
          text: 'Shared caption',
          files: const [
            IncomingSharedFile('item-0', 'photo.jpg', 'image/jpeg', 3),
          ],
        ),
      );
      await framesUntil(t, pickerVisible, gate: null);
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const ValueKey('incoming-target-cx')));
      await t.pump();
      await t.tap(find.byKey(const Key('incoming-share-continue')));
      final polls = await landed(t, s, 'cx');
      metric('share iOS: composer with API closed', polls);
      expect(polls, greaterThanOrEqualTo(0));
      expect(s.w.sharedBlocked(), isTrue);
      await settle(t, s);
      expect(s.w.sharedBlocked(), isFalse);
      expect(sentAnything(s.f), isEmpty);
      await s.f.close(t);
    },
  );

  testWidgets(
    'share: a destination the server refuses after the hand-off keeps the draft and files, says so on the composer, and never sends',
    (t) async {
      final copy = Gate();
      copyGates.add(copy);
      final sharing = slowSharing(dir, copy);
      final s = await boot(t, dir, cold: false, sharing: sharing);
      sharing.receive(_share);
      s.f.adapter.statuses['GET /channels/cx'] = 404;
      await continueOn(t, s, copy, 'cx');
      expect(await landed(t, s, 'cx'), greaterThanOrEqualTo(0));
      await settle(t, s);
      final w = s.w;
      expect(w.sharedBlocked(), isTrue);
      expect(
        find.text(
          'This conversation is no longer available. Your draft and files are kept.',
        ),
        findsOneWidget,
      );
      expect(w.drafts['cx'], 'Shared caption');
      expect(w.uploads().single.queued, isTrue);
      expect(await w.send('hello'), isFalse);
      expect(sentAnything(s.f), isEmpty);
      await s.f.close(t);
    },
  );

  testWidgets(
    'share: a server the account lost is reported on the composer after the hand-off; nothing is dropped or sent',
    (t) async {
      final copy = Gate();
      copyGates.add(copy);
      final sharing = slowSharing(dir, copy);
      final s = await boot(t, dir, cold: false, sharing: sharing);
      sharing.receive(_share);
      s.f.adapter.routes['GET /servers'] = (o) async {
        await s.gate.done.future;
        return [s.f.servers[1]];
      };
      await continueOn(t, s, copy, 'cx');
      expect(await landed(t, s, 'cx'), greaterThanOrEqualTo(0));
      await settle(t, s);
      final w = s.w;
      expect(w.sharedBlocked(), isTrue);
      expect(
        find.text(
          'You are no longer a member of this server. Your draft and files are kept.',
        ),
        findsOneWidget,
      );
      expect(w.drafts['cx'], 'Shared caption');
      expect(w.uploads(), isNotEmpty);
      expect(sentAnything(s.f), isEmpty);
      await s.f.close(t);
    },
  );

  testWidgets(
    'share: a destination on another server opens from the device with every request pending',
    (t) async {
      final copy = Gate();
      copyGates.add(copy);
      final sharing = slowSharing(dir, copy);
      final s = await boot(
        t,
        dir,
        cold: false,
        sharing: sharing,
        bothServers: true,
      );
      sharing.receive(_share);
      await framesUntil(t, pickerVisible, gate: null);
      await copyDone(t, copy);
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Beta').last);
      await t.pump(const Duration(milliseconds: 100));
      expect(row('cb'), isTrue, reason: 'Beta destinations from the device');
      await t.tap(find.byKey(const ValueKey('incoming-target-cb')));
      await t.pump();
      await t.tap(find.byKey(const Key('incoming-share-continue')));
      await t.pump();
      final polls = await landed(t, s, 'cb');
      metric('share cross-server: composer with API closed', polls);
      expect(polls, greaterThanOrEqualTo(0));
      final w = s.w;
      expect(w.server?.id, 'b');
      expect(w.drafts['cb'], 'Shared caption');
      expect(w.uploads().single.queued, isTrue);
      expect(w.sharedBlocked(), isTrue);
      await settle(t, s, 20);
      expect(w.server?.id, 'b');
      expect(w.channel?.id, 'cb');
      expect(w.drafts['cb'], 'Shared caption');
      expect(w.sharedBlocked(), isFalse);
      expect(sentAnything(s.f), isEmpty);
      await s.f.close(t);
    },
  );

  testWidgets(
    'share: a brand-new DM opens an optimistic composer and resolves behind it',
    (t) async {
      final copy = Gate();
      copyGates.add(copy);
      final sharing = slowSharing(dir, copy);
      final s = await boot(t, dir, cold: false, sharing: sharing);
      sharing.receive(_share);
      await framesUntil(t, pickerVisible, gate: null);
      final api = await regate(t, s);
      await copyDone(t, copy);
      await t.pump(const Duration(milliseconds: 400));
      final bob = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith(
              'incoming-target-user:bob',
            ),
      );
      expect(bob, findsOneWidget, reason: 'a member without a DM yet');
      await t.tap(bob);
      await t.pump();
      await t.tap(find.byKey(const Key('incoming-share-continue')));
      await t.pump();
      const pendingId = 'pending-dm:user:bob:agent:null';
      final polls = await landed(t, s, pendingId, api: api);
      metric('share new DM: composer with API closed', polls);
      expect(polls, greaterThanOrEqualTo(0));
      final w = s.w;
      expect(w.sharedBlocked(), isTrue);
      expect(api.done.isCompleted, isFalse);
      // The request to create the DM is out, unanswered; nothing else is.
      expect(sentAnything(s.f), everyElement('POST /channels/dm'));
      // The conversation exists: draft, files and selection move to it.
      api.open();
      await settle(t, s, 20);
      expect(w.channel?.id, 'dmbob');
      expect(w.drafts['dmbob'], 'Shared caption');
      expect(w.drafts[pendingId], isNull);
      expect(w.uploads().single.queued, isTrue);
      expect(w.sharedBlocked(), isFalse);
      expect(sentAnything(s.f), [
        'POST /channels/dm',
      ], reason: 'the DM is created; nothing is sent');
      await s.f.close(t);
    },
  );

  testWidgets(
    'share: a DM that cannot be created keeps the draft and files and says so',
    (t) async {
      final copy = Gate();
      copyGates.add(copy);
      final sharing = slowSharing(dir, copy);
      final s = await boot(t, dir, cold: false, sharing: sharing);
      sharing.receive(_share);
      s.f.adapter.statuses['POST /channels/dm'] = 403;
      await framesUntil(t, pickerVisible, gate: null);
      final api = await regate(t, s);
      await copyDone(t, copy);
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key as ValueKey).value}'.startsWith(
                'incoming-target-user:bob',
              ),
        ),
      );
      await t.pump();
      await t.tap(find.byKey(const Key('incoming-share-continue')));
      await t.pump();
      expect(
        await landed(t, s, 'pending-dm:user:bob:agent:null', api: api),
        greaterThanOrEqualTo(0),
      );
      api.open();
      await settle(t, s, 20);
      final w = s.w;
      expect(w.channel?.id, 'pending-dm:user:bob:agent:null');
      expect(w.sharedBlocked(), isTrue);
      expect(
        find.text(
          'Could not open this conversation. Your draft and files are kept.',
        ),
        findsOneWidget,
      );
      expect(w.drafts['pending-dm:user:bob:agent:null'], 'Shared caption');
      expect(w.uploads(), isNotEmpty);
      await s.f.close(t);
    },
  );

  testWidgets(
    'share: a public channel asks to join at once, opens joined from the device, and joins behind the composer',
    (t) async {
      final copy = Gate();
      copyGates.add(copy);
      final sharing = slowSharing(dir, copy);
      final s = await boot(t, dir, cold: false, sharing: sharing);
      sharing.receive(_share);
      await framesUntil(t, pickerVisible, gate: null);
      await copyDone(t, copy);
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const ValueKey('incoming-target-cp')));
      await t.pump();
      await t.tap(find.byKey(const Key('incoming-share-continue')));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 400));
      // The dialog needs no request.
      expect(
        find.text('Join #public-p to add shared content?'),
        findsOneWidget,
      );
      expect(s.gate.done.isCompleted, isFalse);
      await t.tap(find.text('Join Channel').last);
      await t.pump();
      final polls = await landed(t, s, 'cp');
      metric('share public channel: composer with API closed', polls);
      expect(polls, greaterThanOrEqualTo(0));
      final w = s.w;
      expect(w.channel?.joined, isTrue);
      expect(w.sharedBlocked(), isTrue);
      await settle(t, s, 20);
      expect(
        s.f.adapter.calls.where((c) => c.path == '/channels/cp/join'),
        hasLength(1),
      );
      expect(w.sharedBlocked(), isFalse);
      expect(w.drafts['cp'], 'Shared caption');
      expect(sentAnything(s.f), ['POST /channels/cp/join']);
      await s.f.close(t);
    },
  );

  testWidgets(
    'share: a join that fails returns the Join button; the draft and files stay',
    (t) async {
      final copy = Gate();
      copyGates.add(copy);
      final sharing = slowSharing(dir, copy);
      final s = await boot(t, dir, cold: false, sharing: sharing);
      sharing.receive(_share);
      final raised = raisedErrors(s.w);
      s.f.adapter.statuses['POST /channels/cp/join'] = 403;
      await framesUntil(t, pickerVisible, gate: null);
      await copyDone(t, copy);
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const ValueKey('incoming-target-cp')));
      await t.pump();
      await t.tap(find.byKey(const Key('incoming-share-continue')));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Join Channel').last);
      await t.pump();
      await settle(t, s, 20);
      final w = s.w;
      expect(w.channel?.joined, isFalse);
      expect(w.sharedBlocked(), isFalse);
      expect(w.drafts['cp'], 'Shared caption');
      expect(w.uploads(), isNotEmpty);
      expect(raised, contains('Could not join this channel.'));
      await s.f.close(t);
    },
  );

  testWidgets('share: a failed copy keeps the picker and names the file', (
    t,
  ) async {
    final copy = Gate();
    copyGates.add(copy);
    final sharing = NativeSharing(
      supported: false,
      incomingDirectory: () async => dir,
      readContent: (_) async* {
        await copy.done.future;
        throw const FormatException('provider gone');
      },
    );
    final s = await boot(t, dir, cold: false, sharing: sharing);
    sharing.receive(_share);
    expect(await framesUntil(t, pickerVisible), inInclusiveRange(0, 2));
    copy.open();
    await settle(t, s, 6);
    // The page stays and says which file failed and why; nothing is toasted
    // behind it, and nothing is left in the private inbox.
    expect(pickerVisible(), isTrue);
    expect(find.text('photo.jpg could not be read.'), findsOneWidget);
    expect(s.w.error, isNull);
    expect(dir.listSync(), isEmpty);
    await t.pageBack();
    await settle(t, s, 3);
    expect(pickerVisible(), isFalse);
    expect(s.w.error, isNull);
    await s.f.close(t);
  });

  for (final cold in [false, true]) {
    final mode = cold ? 'cold' : 'warm';
    testWidgets(
      'notification $mode: known channel opens within 2 frames while API is slow and settles on the message',
      (t) async {
        final s = await boot(t, dir, cold: cold, coordinator: true);
        final f = s.f;
        final before = cold ? null : f.workspace(t).navigation.index;
        s.notifications!.onTap!(payload(f, _toX));
        bool opened() =>
            find.byType(WorkspaceView).evaluate().isNotEmpty &&
            f.workspace(t).location.entityId == 'cx';
        final frames = await framesUntil(t, opened);
        metric('notification $mode: destination open', frames);
        expect(frames, inInclusiveRange(0, 2));
        final page = await framesUntil(t, () => text('general-x'));
        metric('notification $mode: channel page painted', page);
        expect(page, inInclusiveRange(0, 2));
        await settle(t, s);
        final w = f.workspace(t);
        expect(w.location.entityId, 'cx');
        expect(w.location.messageId, 'mcx');
        expect(text('Accepted x'), isTrue);
        expect(w.error, isNull);
        if (before != null) expect(w.navigation.index, before + 1);
        await f.close(t);
      },
    );
  }

  for (final cold in [false, true]) {
    final mode = cold ? 'cold' : 'warm';
    testWidgets(
      'notification $mode: a channel unknown to the device shows its loading shell within 2 frames and resolves',
      (t) async {
        final s = await boot(t, dir, cold: cold, coordinator: true);
        final f = s.f;
        f.adapter.routes['GET /channels/cnew'] = (o) async {
          await s.gate.done.future;
          return {
            'id': 'cnew',
            'name': 'fresh-room',
            'type': 'channel',
            'serverId': 'a',
            'joined': true,
          };
        };
        f.adapter.routes['GET /messages/channel/cnew'] = (o) async {
          await s.gate.done.future;
          return {
            'messages': [_row('mnew', 'cnew', 'Brand new')],
            'hasMore': false,
            'hasNewer': false,
          };
        };
        f.adapter.routes['GET /messages/context/mnew'] = (o) async {
          await s.gate.done.future;
          return {
            'messages': [_row('mnew', 'cnew', 'Brand new')],
            'targetMessageId': 'mnew',
            'hasOlder': false,
            'hasNewer': false,
          };
        };
        f.adapter.routes['POST /channels/cnew/read'] = (_) => {};
        f.adapter.routes['GET /channels/cnew/members'] = (_) => [];
        s.notifications!.onTap!(
          payload(f, 'raft://v1/servers/a/channels/cnew/messages/mnew'),
        );
        final frames = await framesUntil(
          t,
          () => find.byType(RaftChannelResolutionBody).evaluate().isNotEmpty,
        );
        metric('notification $mode: unknown channel shell', frames);
        expect(frames, inInclusiveRange(0, 2));
        expect(f.workspace(t).location.entityId, 'cnew');
        await settle(t, s);
        final w = f.workspace(t);
        expect(w.location.entityId, 'cnew');
        expect(w.channel?.id, 'cnew');
        expect(text('Brand new'), isTrue);
        expect(find.byType(RaftChannelResolutionBody), findsNothing);
        expect(w.error, isNull);
        await f.close(t);
      },
    );
  }

  for (final unknown in [false, true]) {
    final id = unknown ? 'cnew' : 'cx';
    testWidgets(
      'notification: ${unknown ? 'unknown' : 'known'} channel the server refuses is reverted and reported',
      (t) async {
        final s = await boot(t, dir, cold: false, coordinator: true);
        final f = s.f;
        for (final key in [
          'GET /channels/$id',
          'GET /messages/channel/$id',
          'GET /messages/context/m$id',
        ]) {
          f.adapter.routes[key] = (o) async {
            await s.gate.done.future;
            f.adapter.statuses[key] = 403;
            return {'error': 'Forbidden'};
          };
        }
        final w = f.workspace(t);
        final raised = raisedErrors(w);
        final before = w.location, index = w.navigation.index;
        s.notifications!.onTap!(
          payload(f, 'raft://v1/servers/a/channels/$id/messages/m$id'),
        );
        expect(
          await framesUntil(t, () => f.workspace(t).location.entityId == id),
          inInclusiveRange(0, 2),
        );
        await settle(t, s);
        expect(w.location, before);
        expect(w.navigation.index, index);
        expect(raised.join('\n'), contains('unavailable'));
        await f.close(t);
      },
    );
  }

  testWidgets(
    'notification: a workspace the account no longer belongs to is reverted and reported',
    (t) async {
      final s = await boot(t, dir, cold: false, coordinator: true);
      final f = s.f;
      f.adapter.routes['GET /servers'] = (o) async {
        await s.gate.done.future;
        return [f.servers[1]];
      };
      final w = f.workspace(t);
      final raised = raisedErrors(w);
      final before = w.location, index = w.navigation.index;
      s.notifications!.onTap!(payload(f, _toX));
      expect(
        await framesUntil(t, () => f.workspace(t).location.entityId == 'cx'),
        inInclusiveRange(0, 2),
      );
      await settle(t, s);
      expect(w.location.entityId, isNot('cx'));
      expect(w.navigation.index, index);
      expect(w.location, before);
      expect(raised.join('\n'), contains('unavailable'));
      await f.close(t);
    },
  );

  // Serial-await profile: each request costs one 300 ms round trip.
  testWidgets('latency profile: 300 ms per request and per copy', (t) async {
    const rtt = Duration(milliseconds: 300);
    final sharing = NativeSharing(
      supported: false,
      incomingDirectory: () async => dir,
      readContent: (_) async* {
        await Future<void>.delayed(rtt);
        yield Uint8List.fromList([1, 2, 3]);
      },
    );
    final s = await boot(
      t,
      dir,
      cold: false,
      sharing: sharing,
      coordinator: true,
      gated: false,
    );
    latent(s.f, rtt);
    sharing.receive(_share);
    metric(
      'latency 300 ms, share warm: picker visible',
      await framesUntil(t, pickerVisible),
    );
    metric(
      'latency 300 ms, share warm: target rows visible',
      await framesUntil(t, () => row('cx')),
    );
    await t.pageBack();
    await settle(t, s, 8);
    s.notifications!.onTap!(payload(s.f, _toX));
    metric(
      'latency 300 ms, notification warm: destination open',
      await framesUntil(t, () => s.w.location.entityId == 'cx'),
    );
    metric(
      'latency 300 ms, notification warm: loaded and settled',
      await framesUntil(
        t,
        () =>
            !s.w.messageDomain.state.channelLoading &&
            s.w.location.messageId == 'mcx',
      ),
    );
    await settle(t, s, 8);
    await t.pump(const Duration(seconds: 3));
    await s.f.close(t);
    await t.pump(const Duration(seconds: 3));
  });
}
