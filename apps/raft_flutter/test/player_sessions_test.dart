// The ownership rules of PlayerSessions: one player per attachment shared by
// every holder (a card and its viewer), disposed when nobody holds it, capped,
// and dropped on an identity change.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/attachment_player_sessions.dart';
import 'package:raft_flutter/platform/memory_release.dart';

class _Player implements AttachmentPlayer {
  _Player(this.name);
  final String name;
  final events = StreamController<AttachmentPlayback>.broadcast();
  var disposed = false, pauses = 0, opened = 0;
  var last = const AttachmentPlayback();
  Object? failOpen;
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  @override
  AttachmentPlayback get playback => last;
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() => const SizedBox();
  @override
  Future<void> open(AttachmentSource source) async {
    final error = failOpen;
    if (error != null) throw error;
    opened++;
  }

  @override
  Future<void> toggle() async {}
  @override
  Future<void> pause() async {
    pauses++;
    last = AttachmentPlayback(
      position: last.position,
      duration: last.duration,
    );
  }

  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
  }
}

AttachmentSource _source() => AttachmentSource.network(Uri.parse('https://x.invalid/a'));

void main() {
  late PlayerSessions sessions;
  var now = DateTime(2026, 10, 13, 12);
  setUp(() {
    now = DateTime(2026, 10, 13, 12);
    sessions = PlayerSessions(now: () => now);
  });
  tearDown(() => sessions.dispose());

  PlayerHold take(
    String key, {
    bool viewer = false,
    List<_Player>? made,
    String? channel,
    Object? scope,
  }) => sessions.acquire(
    key,
    scope: scope,
    channelId: channel,
    viewer: viewer,
    create: () {
      final p = _Player(key);
      made?.add(p);
      return p;
    },
    source: () async => _source(),
  );

  test('a card and its viewer share one player, opened once', () async {
    final made = <_Player>[];
    final card = take('a', made: made);
    final viewer = take('a', viewer: true, made: made);
    await Future.wait([card.ready, viewer.ready]);
    expect(made, hasLength(1));
    expect(identical(card.player, viewer.player), isTrue);
    expect(made.single.opened, 1);
    expect(card.session.viewerOpen, isTrue);
  });

  test('the player is disposed when the last holder is gone, not before', () async {
    final made = <_Player>[];
    final card = take('a', made: made);
    final viewer = take('a', viewer: true, made: made);
    await card.ready;
    card.release();
    await pumpEventQueue();
    expect(made.single.disposed, isFalse, reason: 'the viewer still holds it (card scrolled away)');
    viewer.release();
    await pumpEventQueue();
    expect(made.single.disposed, isTrue);
    expect(sessions.length, 0);
  });

  test('releasing twice counts once', () async {
    final made = <_Player>[];
    final a = take('a', made: made);
    final b = take('a', made: made);
    await a.ready;
    a.release();
    a.release();
    await pumpEventQueue();
    expect(made.single.disposed, isFalse);
    b.release();
    await pumpEventQueue();
    expect(made.single.disposed, isTrue);
  });

  test('the last holder leaving frees the player at once (no linger)', () async {
    final made = <_Player>[];
    final first = take('a', made: made);
    await first.ready;
    first.release();
    await pumpEventQueue();
    expect(made.single.disposed, isTrue);
    expect(sessions.length, 0);
    // The next holder starts a new player.
    final again = take('a', made: made);
    await again.ready;
    expect(made, hasLength(2));
    again.release();
  });

  test('a player that never opened or failed is not kept', () async {
    final made = <_Player>[];
    final hold = sessions.acquire(
      'bad',
      create: () {
        final p = _Player('bad')..failOpen = StateError('no');
        made.add(p);
        return p;
      },
      source: () async => _source(),
    );
    await expectLater(hold.ready, throwsStateError);
    hold.release();
    await pumpEventQueue();
    expect(made.single.disposed, isTrue);
    // A new holder does not inherit the failure.
    final next = take('bad', made: made);
    await next.ready;
    expect(made, hasLength(2));
    next.release();
  });

  test('over the cap the least recently used paused player is evicted', () async {
    final made = <_Player>[];
    final evicted = <String>[];
    final a = take('a', made: made)..onEvicted = () => evicted.add('a');
    await a.ready;
    now = now.add(const Duration(seconds: 1));
    final b = take('b', made: made)..onEvicted = () => evicted.add('b');
    await b.ready;
    now = now.add(const Duration(seconds: 1));
    final c = take('c', made: made);
    await c.ready;
    expect(evicted, ['a']);
    await pumpEventQueue();
    expect(made.first.disposed, isTrue);
    expect(sessions.length, 2);
    b.release();
    c.release();
  });

  test('a playing player or one a viewer holds is never evicted', () async {
    final made = <_Player>[];
    final evicted = <String>[];
    final a = take('a', made: made)..onEvicted = () => evicted.add('a');
    final b = take('b', viewer: true, made: made)..onEvicted = () => evicted.add('b');
    await Future.wait([a.ready, b.ready]);
    (a.player as _Player).last = const AttachmentPlayback(playing: true);
    take('c', made: made);
    // Nothing could be evicted: the cap is exceeded rather than a viewer or a
    // playing video cut.
    expect(evicted, isEmpty);
    expect(sessions.length, 3);
  });

  test('an identity change drops every player', () async {
    final made = <_Player>[];
    final a = take('a', made: made, scope: 'alice');
    await a.ready;
    final other = take('a', made: made, scope: 'bob');
    await other.ready;
    expect(made, hasLength(2));
    await pumpEventQueue();
    expect(made.first.disposed, isTrue);
    expect(a.orphaned, isTrue);
  });

  test('a revoked channel drops its players only', () async {
    final made = <_Player>[];
    final a = take('a', made: made, channel: 'c1');
    final b = take('b', made: made, channel: 'c2');
    await Future.wait([a.ready, b.ready]);
    sessions.invalidateChannel('c1');
    await pumpEventQueue();
    expect(made.first.disposed, isTrue);
    expect(made.last.disposed, isFalse);
  });

  test('releasing while the source is still being resolved opens nothing', () async {
    final gate = Completer<AttachmentSource>();
    final made = <_Player>[];
    final hold = sessions.acquire(
      'slow',
      create: () {
        final p = _Player('slow');
        made.add(p);
        return p;
      },
      source: () => gate.future,
    );
    hold.release();
    gate.complete(_source());
    await pumpEventQueue();
    expect(made.single.opened, 0);
    expect(made.single.disposed, isTrue);
  });

  group('memory trim', () {
    Future<ui.Image> picture(WidgetTester tester, [int side = 16]) async =>
        (await tester.runAsync(() => createTestImage(width: side, height: side, cache: false)))!;

    testWidgets('releases idle stills but not those of a playing or viewed session', (tester) async {
      final image = await picture(tester);
      sessions = PlayerSessions(maxLive: 5, now: () => now);
      final made = <_Player>[];
      final idle = take('idle', made: made);
      final playing = take('playing', made: made);
      final viewed = take('viewed', viewer: true, made: made);
      await Future.wait([idle.ready, playing.ready, viewed.ready]);
      (made[1]).last = const AttachmentPlayback(playing: true);
      for (final key in ['idle', 'playing', 'viewed', 'orphan']) {
        sessions.keepStill(key, image);
      }
      expect(sessions.stillCount, 4);
      final release = RaftMemoryRelease();
      final remove = sessions.installMemoryTrim(release);
      for (final reason in RaftMemoryTrim.values) {
        // Both reasons release the same way; re-add what was released.
        sessions.keepStill('idle', image);
        sessions.keepStill('orphan', image);
        release.trim(reason);
        expect(sessions.hasStill('idle'), isFalse, reason: reason.name);
        expect(sessions.hasStill('orphan'), isFalse, reason: reason.name);
        expect(sessions.hasStill('playing'), isTrue, reason: reason.name);
        expect(sessions.hasStill('viewed'), isTrue, reason: reason.name);
        expect(sessions.stillBytes, 2 * 16 * 16 * 4);
      }
      // Never touches the players themselves.
      expect(made.any((p) => p.disposed), isFalse);
      expect(sessions.length, 3);
      // A card that kept its own copy still has it after the trim.
      sessions.keepStill('idle', image);
      final copy = sessions.stillFor('idle')!;
      release.trim(RaftMemoryTrim.backgrounded);
      expect(copy.debugDisposed, isFalse);
      copy.dispose();
      remove();
      sessions.keepStill('idle', image);
      release.trim(RaftMemoryTrim.pressure);
      expect(sessions.hasStill('idle'), isTrue, reason: 'removed trimmer is not called');
      sessions.dispose(); // before the test ends: leak tracking checks there
      image.dispose();
    });

    testWidgets('keepStill stays within the byte budget, oldest first', (tester) async {
      // 1500 x 1500 x 4 = 9 MB: two do not fit the 16 MiB budget.
      final big = await picture(tester, 1500);
      sessions.keepStill('a', big);
      sessions.keepStill('b', big);
      expect(sessions.hasStill('a'), isFalse);
      expect(sessions.hasStill('b'), isTrue);
      // The newest is kept even if it alone is over budget.
      final huge = await picture(tester, 3000);
      sessions.keepStill('c', huge);
      expect(sessions.stillCount, 1);
      expect(sessions.hasStill('c'), isTrue);
      sessions.dispose();
      big.dispose();
      huge.dispose();
    });

    testWidgets('the still count stays at maxStills', (tester) async {
      final image = await picture(tester, 4);
      for (var i = 0; i < PlayerSessions.maxStills + 5; i++) {
        sessions.keepStill('k$i', image);
      }
      expect(sessions.stillCount, PlayerSessions.maxStills);
      expect(sessions.hasStill('k0'), isFalse);
      sessions.dispose();
      image.dispose();
    });
  });
}
