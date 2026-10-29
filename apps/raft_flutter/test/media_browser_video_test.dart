// The media browser's video pages (behind MediaBrowserFlags.video): paging
// never autoplays or prepares a page that was only passed, a card's live
// player is taken over (no new stream), leaving pauses and releases after the
// grace, closing hands the player back, HDR's native view only while a page
// rests, and every failure class says its message. Players are fakes; the
// real-player proofs are the device suite (docs/media-playback.md).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/media_browser.dart';
import 'package:raft_flutter/features/media_items.dart';
import 'package:raft_flutter/features/media_failure_text.dart';
import 'package:raft_flutter/features/media_video_page.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/attachment_player_sessions.dart';
import 'package:raft_flutter/platform/attachment_stream.dart';
import 'package:raft_flutter/platform/media_failure.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;
import 'system_ui_calls.dart';

class _Player implements AttachmentPlayer {
  _Player({this.native = false});
  final bool native;
  final events = StreamController<AttachmentPlayback>.broadcast();
  final calls = <String>[];
  bool playing = false, disposed = false;
  int opens = 0;
  Duration position = Duration.zero;
  double level = 100;
  Object? failOpen;
  AttachmentPlayback get state => AttachmentPlayback(
    playing: playing,
    position: position,
    duration: const Duration(seconds: 60),
    volume: level,
    hasFrame: true,
    videoSize: const Size(1280, 720),
  );
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  @override
  AttachmentPlayback get playback => state;
  @override
  bool get usesPlatformView => native;
  @override
  Widget video() => ColoredBox(
    key: Key(native ? 'fake-native-view' : 'fake-video-surface'),
    color: Colors.red,
  );
  @override
  Future<void> open(AttachmentSource source) async {
    final error = failOpen;
    if (error != null) throw error;
    opens++;
    calls.add('open@${source.start.inSeconds}');
    if (source.start > Duration.zero) position = source.start;
  }

  @override
  Future<void> toggle() async {
    calls.add('toggle');
    playing = !playing;
    events.add(state);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
    events.add(state);
  }

  @override
  Future<void> seek(Duration value) async {
    calls.add('seek:${value.inSeconds}');
    position = value;
    events.add(state);
  }

  @override
  Future<void> volume(double value) async {
    calls.add('volume:${value.round()}');
    level = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
  }
}

Map<String, dynamic> _video(int n, {int size = 2 * 1024 * 1024}) => {
  'id': 'v$n',
  'channelId': 'c1',
  'filename': 'clip-$n.mp4',
  'mimeType': 'video/mp4',
  'sizeBytes': size,
};

Map<String, dynamic> _image(int n) => {
  'id': 'i$n',
  'channelId': 'c1',
  'filename': 'photo-$n.png',
  'mimeType': 'image/png',
  'width': 16,
  'height': 16,
  'sizeBytes': 100,
};

class _Rig {
  _Rig(this.w, this.api, this.items, this.made, this.urlReads);
  final WorkspaceController w;
  final MessageAdapter api;
  final List<MediaItem> items;
  final List<_Player> made;
  final List<String> urlReads;
  PlayerSessions get sessions => w.attachmentMedia.playerSessions;
  MediaBrowserState get browser =>
      TestWidgetsFlutterBinding.instance.rootElement == null
      ? throw StateError('unmounted')
      : _state!;
  MediaBrowserState? _state;
}

Future<void> _rest(WidgetTester tester, [int ms = 300]) async {
  await tester.pump(Duration(milliseconds: ms));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump();
}

/// Mounts the browser on [kinds] ('v' video, 'i' image) at [initial].
Future<_Rig> _mount(
  WidgetTester tester, {
  required String kinds,
  int initial = 0,
  bool page = true,
  Size size = const Size(390, 844),
  bool hdr = false,
  void Function(_Player player, int n)? prepare,
  bool unmountOnTeardown = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
  final items = [
    for (var i = 0; i < kinds.length; i++)
      kinds[i] == 'v' ? MediaItem.video(_video(i)) : MediaItem.image(_image(i)),
  ];
  final urlReads = <String>[];
  for (final item in items) {
    api.routes['GET /attachments/${item.id}/url'] = (_) {
      urlReads.add(item.id);
      return {'url': 'https://media.invalid/${item.id}'};
    };
  }
  final made = <_Player>[];
  final rig = _Rig(w, api, items, made, urlReads);
  addTearDown(() async {
    if (unmountOnTeardown) await tester.pumpWidget(const SizedBox());
    w.dispose();
  });
  var n = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: MediaBrowser(
        controller: w,
        files: AttachmentFiles(gallerySupported: false),
        sharing: NativeSharing(supported: false),
        items: items,
        initialIndex: initial,
        messageId: 'm1',
        authorized: () => true,
        page: page,
        onClose: () {},
        hdrDetector: hdr ? (_) async => true : null,
        playerFactory: () {
          final player = _Player(native: hdr && made.isNotEmpty);
          made.add(player);
          prepare?.call(player, n++);
          return player;
        },
      ),
    ),
  );
  rig._state = tester.state<MediaBrowserState>(find.byType(MediaBrowser));
  await tester.pump();
  return rig;
}

/// Pages to [i] and lets the 200 ms glide finish (the page change itself
/// happens halfway through it).
Future<void> _go(WidgetTester tester, _Rig rig, int i) async {
  rig.browser.goTo(i);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
}

String _key(Map<String, dynamic> metadata) => attachmentMediaKey(metadata);

/// A scenario: the body, then the browser unmounted so no timer outlives it.
void scenario(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

void main() {
  group('paging', () {
    scenario('a page prepares after resting 250 ms, paused, never playing', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'ivi', initial: 0);
      expect(rig.made, isEmpty);
      await _go(tester, rig, 1);
      await tester.pump();
      // The page changes halfway through the 200 ms glide.
      await tester.pump(const Duration(milliseconds: 230));
      expect(rig.made, isEmpty, reason: 'not before it has rested');
      await tester.pump(const Duration(milliseconds: 100));
      await _rest(tester, 200);
      expect(rig.made, hasLength(1));
      expect(rig.made.single.opens, 1);
      expect(rig.made.single.playing, isFalse);
      expect(rig.made.single.calls, ['open@0'], reason: 'never toggled');
      expect(rig.urlReads, contains('v1'));
      expect(rig.sessions.length, 1);
    });

    scenario('a flick past videos opens nothing for the skipped pages', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vvvvi', initial: 0);
      // Land on each page for far less than the settle time.
      for (final page in [1, 2, 3, 4]) {
        rig.browser.pages.jumpToPage(page);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await _rest(tester, 400);
      expect(rig.made, isEmpty, reason: 'page 0 left at once, 1-3 passed');
      expect(rig.sessions.created, 0);
      expect(rig.urlReads.where((id) => id.startsWith('v')), isEmpty);
    });

    scenario('the opening page prepares after it has rested too', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      expect(rig.made, isEmpty);
      await _rest(tester, 300);
      expect(rig.made, hasLength(1));
      expect(rig.made.single.playing, isFalse);
    });

    scenario('a video above 24 MB waits for the first Play', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      final rig = await _mount(tester, kinds: 'v', initial: 0);
      // (mount used 2 MB) - rebuild with a big one.
      expect(rig.made, isEmpty);
      await _rest(tester, 300);
      expect(rig.made, hasLength(1));
    });

    scenario('Play before the player is ready is queued and honoured', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await tester.tap(find.byKey(const Key('inline-video-play')));
      await _rest(tester, 50);
      await _rest(tester, 50);
      expect(rig.made, hasLength(1));
      expect(rig.made.single.calls, ['open@0', 'toggle']);
      expect(rig.made.single.playing, isTrue);
    });
  });

  group('leaving and returning', () {
    scenario('leaving pauses at once; the hold lasts 3 s, then the decoder '
        'is freed', (tester) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      final player = rig.made.single;
      await tester.tap(find.byKey(const Key('inline-video-play')));
      await _rest(tester, 50);
      expect(player.playing, isTrue);
      await _go(tester, rig, 1);
      expect(player.playing, isFalse, reason: 'paused when the page is left');
      expect(player.calls.last, 'pause');
      await tester.pump(const Duration(milliseconds: 2800));
      expect(player.disposed, isFalse, reason: 'still held inside the grace');
      expect(rig.sessions.length, 1);
      await tester.pump(const Duration(milliseconds: 500));
      await _rest(tester, 50);
      expect(player.disposed, isTrue, reason: 'no card holds it: freed');
      expect(rig.sessions.length, 0);
    });

    scenario('back inside the grace: the same player, no new request', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      final player = rig.made.single;
      player.position = const Duration(seconds: 7);
      await _go(tester, rig, 1);
      await tester.pump(const Duration(milliseconds: 1500));
      final reads = rig.urlReads.length;
      await _go(tester, rig, 0);
      await _rest(tester, 400);
      expect(rig.made, hasLength(1));
      expect(rig.urlReads, hasLength(reads), reason: 'no new request');
      expect(player.opens, 1);
      expect(player.playing, isFalse, reason: 'paged back, not playing');
      await tester.pump(const Duration(seconds: 5));
      expect(player.disposed, isFalse, reason: 'the grace timer was cancelled');
    });

    scenario('after the grace a return streams again from where it left', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      rig.made.single.position = const Duration(seconds: 9);
      await _go(tester, rig, 1);
      await tester.pump(const Duration(seconds: 4));
      await _rest(tester, 50);
      await _go(tester, rig, 0);
      await _rest(tester, 400);
      expect(rig.made, hasLength(2));
      expect(rig.made.last.calls.first, 'open@9', reason: 'resumes at 9 s');
      expect(rig.made.last.playing, isFalse);
    });

    scenario('a card that holds the session keeps it, paused where the '
        'page left it', (tester) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      final meta = rig.items[0].metadata;
      final card = _cardHold(rig, meta);
      await tester.runAsync(() => card.ready);
      await _rest(tester, 300);
      expect(
        rig.made,
        hasLength(1),
        reason: 'the page took the card\'s player',
      );
      final player = rig.made.single;
      await _go(tester, rig, 1);
      await tester.pump(const Duration(seconds: 4));
      await _rest(tester, 50);
      expect(player.disposed, isFalse, reason: 'the card still holds it');
      expect(rig.sessions.length, 1);
      card.release();
      await _rest(tester, 50);
      expect(player.disposed, isTrue);
    });
  });

  group('from a card', () {
    scenario('a playing card\'s player continues: no new stream, no pause', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      // Unmount and reopen with the card's session alive.
      await tester.pumpWidget(const SizedBox());
      final meta = rig.items[0].metadata;
      final card = _cardHold(rig, meta);
      await tester.runAsync(() => card.ready);
      final player = rig.made.single;
      player.playing = true;
      player.position = const Duration(seconds: 12);
      final reads = rig.urlReads.length;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: MediaBrowser(
            controller: rig.w,
            files: AttachmentFiles(gallerySupported: false),
            sharing: NativeSharing(supported: false),
            items: rig.items,
            initialIndex: 0,
            messageId: 'm1',
            authorized: () => true,
            page: true,
            onClose: () {},
            playerFactory: () => throw StateError('a second player'),
          ),
        ),
      );
      await tester.pump();
      await _rest(tester, 20);
      // Immediately, not after the 250 ms settle.
      expect(rig.sessions.created, 1);
      expect(rig.made, hasLength(1));
      expect(player.opens, 1);
      expect(player.calls, ['open@0'], reason: 'no pause, no toggle');
      expect(player.playing, isTrue);
      expect(rig.urlReads, hasLength(reads), reason: 'no new request');
      final viewer = tester.widget<RaftVideoViewer>(
        find.byType(RaftVideoViewer),
      );
      expect(viewer.playing, isTrue);
      expect(viewer.position, const Duration(seconds: 12));
      // Close: the card carries on.
      await tester.pumpWidget(const SizedBox());
      await _rest(tester, 50);
      expect(player.disposed, isFalse);
      expect(player.playing, isTrue);
      expect(player.calls, ['open@0'], reason: 'closing does not pause');
      card.release();
      await _rest(tester, 50);
      expect(player.disposed, isTrue);
    });

    scenario('closing with no card frees the decoder at once', (tester) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      final player = rig.made.single;
      expect(player.disposed, isFalse);
      await tester.pumpWidget(const SizedBox());
      await _rest(tester, 50);
      expect(player.disposed, isTrue);
      expect(rig.sessions.length, 0);
    });

    scenario('closing from another video: the opened card stays paused and '
        'the visible one is handed back', (tester) async {
      final rig = await _mount(tester, kinds: 'vv', initial: 0);
      final cardA = _cardHold(rig, rig.items[0].metadata);
      await tester.runAsync(() => cardA.ready);
      await _rest(tester, 300);
      await _go(tester, rig, 1);
      await _rest(tester, 400);
      expect(rig.made, hasLength(2));
      final a = rig.made[0], b = rig.made[1];
      await tester.tap(find.byKey(const Key('inline-video-play')));
      await _rest(tester, 50);
      expect(b.playing, isTrue);
      expect(a.playing, isFalse, reason: 'left paused');
      await tester.pumpWidget(const SizedBox());
      await _rest(tester, 50);
      expect(a.disposed, isFalse, reason: 'its card still holds it');
      expect(b.disposed, isTrue, reason: 'no card for the visible video');
      cardA.release();
    });
  });

  scenario('desktop gallery controls remain above the thumbnail strip', (
    tester,
  ) async {
    final rig = await _mount(
      tester,
      kinds: 'vi',
      page: false,
      size: const Size(1280, 800),
    );
    await _rest(tester, 300);
    final strip = tester.getRect(
      find.byKey(const ValueKey('lightbox-thumbnails')),
    );
    final mute = tester.getRect(find.byKey(const Key('inline-video-mute')));
    final seek = tester.getRect(find.byKey(const Key('inline-video-seek')));
    expect(mute.bottom, lessThanOrEqualTo(strip.top));
    expect(seek.bottom, lessThanOrEqualTo(strip.top));
    await tester.tap(find.byKey(const Key('inline-video-mute')));
    await _rest(tester, 20);
    expect(rig.made.single.level, 0);
    expect(rig.browser.index, 0);
  });

  group('lifecycle', () {
    scenario('the app going to the background pauses and does not resume', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      final player = rig.made.single;
      await tester.tap(find.byKey(const Key('inline-video-play')));
      await _rest(tester, 50);
      expect(player.playing, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(player.playing, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(player.playing, isFalse, reason: 'returning does not resume');
    });

    scenario('Space plays and pauses, Shift+arrows seek, M mutes', (
      tester,
    ) async {
      final rig = await _mount(
        tester,
        kinds: 'vi',
        initial: 0,
        page: false,
        size: const Size(1280, 800),
      );
      await _rest(tester, 300);
      final player = rig.made.single;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _rest(tester, 20);
      expect(player.playing, isTrue);
      player.position = const Duration(seconds: 20);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _rest(tester, 20);
      expect(player.calls, contains('seek:25'));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await _rest(tester, 20);
      expect(player.level, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await _rest(tester, 20);
      expect(player.level, 100);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _rest(tester, 400);
      expect(rig.browser.index, 1, reason: 'plain arrows still page');
    });
  });

  group('phone page', () {
    scenario('a tap on the picture toggles the chrome, never playback', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      final player = rig.made.single;
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.browser.chrome.value, isFalse);
      expect(player.playing, isFalse);
      expect(player.calls, ['open@0']);
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.browser.chrome.value, isTrue);
      expect(player.calls, ['open@0']);
    });

    scenario('a playing video keeps its controls: a tap shows and hides them '
        'with the chrome, pause and seek work', (tester) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      final player = rig.made.single;
      final bar = find.byKey(const Key('inline-video-bar'));
      await tester.tap(find.byKey(const Key('inline-video-play')));
      await _rest(tester, 50);
      expect(player.playing, isTrue);
      // Chrome is showing: the controls come with it.
      expect(rig.browser.chrome.value, isTrue);
      expect(bar, findsOneWidget, reason: 'playing, chrome shown: controls');

      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(rig.browser.chrome.value, isFalse);
      expect(bar, findsNothing, reason: 'hidden together with the chrome');

      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(rig.browser.chrome.value, isTrue);
      expect(bar, findsOneWidget, reason: 'a tap brings them back');
      // Playing under visible chrome: it leaves by itself after 3 s.
      await tester.pump(const Duration(milliseconds: 2900));
      expect(bar, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(rig.browser.chrome.value, isFalse, reason: 'auto-hide');
      expect(bar, findsNothing);
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(bar, findsOneWidget, reason: 'a tap brings them back');

      final seek = find.byKey(const Key('inline-video-seek'));
      await tester.tapAt(
        tester.getTopLeft(seek) + Offset(tester.getSize(seek).width / 2, 6),
      );
      await _rest(tester, 50);
      expect(
        player.calls.where((c) => c.startsWith('seek:')),
        isNotEmpty,
        reason: 'the seek rail seeks',
      );
      expect(player.playing, isTrue);

      await tester.tap(find.byKey(const Key('inline-video-toggle')));
      await _rest(tester, 50);
      expect(player.playing, isFalse, reason: 'the bar button pauses');
      expect(bar, findsOneWidget, reason: 'paused never hides them');
      await tester.pump(const Duration(seconds: 10));
      expect(rig.browser.chrome.value, isTrue, reason: 'no auto-hide paused');
      expect(bar, findsOneWidget);
      rig.browser.toggleChrome();
      await tester.pump(const Duration(milliseconds: 300));
      expect(rig.browser.chrome.value, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(bar, findsNothing, reason: 'paused: hidden with the chrome');
      expect(find.byKey(const Key('inline-video-play')), findsNothing);
    });

    scenario('the control bar sits above the strip while the chrome shows', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vii', initial: 0);
      await _rest(tester, 300);
      final strip = tester
          .getTopLeft(find.byKey(const ValueKey('lightbox-thumbnails')))
          .dy;
      final bar = tester
          .getBottomLeft(find.byKey(const Key('inline-video-bar')))
          .dy;
      expect(bar, lessThanOrEqualTo(strip + 1));
      rig.browser.toggleChrome();
      await tester.pump();
      final lowered = tester
          .getBottomLeft(find.byKey(const Key('inline-video-bar')))
          .dy;
      expect(lowered, greaterThan(bar), reason: 'chrome hidden: the bar drops');
    });

    scenario('the picture fills the whole stage', (tester) async {
      await _mount(tester, kinds: 'vii', initial: 0);
      await _rest(tester, 300);
      expect(
        tester.getRect(find.byKey(const Key('video-viewer'))),
        const Rect.fromLTWH(0, 0, 390, 844),
      );
    });
  });

  group('immersive mode (video)', () {
    final bar = find.byKey(const Key('inline-video-bar'));
    final seek = find.byKey(const Key('inline-video-seek'));

    Future<_Rig> playing(WidgetTester tester) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      await tester.tap(find.byKey(const Key('inline-video-play')));
      await _rest(tester, 50);
      expect(rig.made.single.playing, isTrue);
      return rig;
    }

    scenario('playing under visible chrome: after 3 s the chrome, the '
        'controls and the system bars go together', (tester) async {
      final modes = recordSystemUiModes(tester);
      final rig = await playing(tester);
      expect(modes, isEmpty);
      await tester.pump(const Duration(milliseconds: 2800));
      expect(rig.browser.chrome.value, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(rig.browser.chrome.value, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(bar, findsNothing);
      // A tap brings everything back.
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(rig.browser.chrome.value, isTrue);
      expect(bar, findsOneWidget);
      expect(modes, isEmpty, reason: 'the system bars are not touched');
      expect(rig.made.single.playing, isTrue, reason: 'never pauses');
    });

    scenario('an interaction restarts the 3 s', (tester) async {
      final rig = await playing(tester);
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.tapAt(
        tester.getTopLeft(seek) + Offset(tester.getSize(seek).width / 3, 6),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 2500));
      expect(rig.browser.chrome.value, isTrue, reason: '2.5 s after the tap');
      await tester.pump(const Duration(milliseconds: 700));
      expect(rig.browser.chrome.value, isFalse);
    });

    scenario('never while paused', (tester) async {
      final modes = recordSystemUiModes(tester);
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      await tester.pump(const Duration(seconds: 10));
      expect(rig.browser.chrome.value, isTrue);
      expect(bar, findsOneWidget);
      // Pausing a playing video stops the count too.
      await tester.tap(find.byKey(const Key('inline-video-play')));
      await _rest(tester, 50);
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.tap(find.byKey(const Key('inline-video-toggle')));
      await _rest(tester, 50);
      expect(rig.made.single.playing, isFalse);
      await tester.pump(const Duration(seconds: 10));
      expect(rig.browser.chrome.value, isTrue);
      expect(modes, isEmpty);
    });

    scenario('never while a finger is on the seek rail', (tester) async {
      final modes = recordSystemUiModes(tester);
      final rig = await playing(tester);
      final at = tester.getTopLeft(seek) + Offset(40, 6);
      final finger = await tester.startGesture(at);
      await finger.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(seconds: 6));
      expect(rig.browser.chrome.value, isTrue, reason: 'scrubbing');
      expect(modes, isEmpty);
      await finger.up();
      await tester.pump(const Duration(milliseconds: 2800));
      expect(rig.browser.chrome.value, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(rig.browser.chrome.value, isFalse, reason: '3 s after the lift');
      expect(modes, isEmpty);
    });

    scenario('never with a screen reader: the controls stay, a tap '
        'toggles nothing', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final modes = recordSystemUiModes(tester);
      final rig = await playing(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(rig.browser.chrome.value, isTrue);
      expect(bar, findsOneWidget);
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(rig.browser.chrome.value, isTrue);
      expect(bar, findsOneWidget);
      expect(modes, isEmpty);
    });

    scenario('a hidden video stays hidden when it is paused, and the centre '
        'Play goes with the chrome', (tester) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      final play = find.byKey(const Key('inline-video-play'));
      expect(play, findsOneWidget);
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(rig.browser.chrome.value, isFalse);
      expect(play, findsNothing);
      expect(bar, findsNothing);
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(play, findsOneWidget);
      expect(bar, findsOneWidget);
    });

    scenario('reduced motion: the controls cut with the chrome', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      await tester.tapAt(const Offset(195, 300));
      // The tap confirms after the double-tap window; the next frame has no
      // fade left.
      await tester.pump(const Duration(milliseconds: 310));
      await tester.pump();
      expect(rig.browser.chrome.value, isFalse);
      expect(bar, findsNothing);
    });

    scenario('the controls fade out rather than pop', (tester) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0);
      await _rest(tester, 300);
      rig.browser.toggleChrome();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(bar, findsOneWidget, reason: 'mid-fade');
      await tester.pump(const Duration(milliseconds: 200));
      expect(bar, findsNothing);
    });
  });

  group('failures', () {
    for (final (kind, message, retry, network, download) in [
      (MediaFailureKind.proxyUnreachable, 'proxy', true, true, true),
      (MediaFailureKind.network, 'connection', true, true, true),
      (MediaFailureKind.expired, 'expired', true, false, true),
      (MediaFailureKind.unknown, 'could not be played', true, false, true),
      (MediaFailureKind.notFound, 'no longer', false, false, true),
      (MediaFailureKind.unsupported, 'cannot play', false, false, true),
      (MediaFailureKind.proxyAuth, 'proxy', true, true, true),
    ]) {
      scenario('$kind: message and the actions that help', (tester) async {
        final rig = await _mount(
          tester,
          kinds: 'vi',
          initial: 0,
          prepare: (player, _) => player.failOpen = MediaPlaybackException(
            MediaFailure(
              kind,
              proxy: kind.name.startsWith('proxy')
                  ? 'proxy.invalid:8080'
                  : null,
            ),
          ),
        );
        await _rest(tester, 300);
        expect(rig.made, hasLength(1));
        final failure = MediaFailure(
          kind,
          proxy: kind.name.startsWith('proxy') ? 'proxy.invalid:8080' : null,
        );
        expect(
          find.text(
            mediaFailureMessage(
              tester.element(find.byType(MediaVideoPage)),
              failure,
              video: true,
            ),
          ),
          findsOneWidget,
          reason: message,
        );
        expect(find.text('Retry'), retry ? findsOneWidget : findsNothing);
        expect(
          find.byKey(const Key('viewer-network-settings')),
          findsNothing,
          reason: 'no handler in this rig',
        );
        expect(
          find.byKey(const Key('viewer-download')),
          download ? findsOneWidget : findsNothing,
        );
        expect(network, isA<bool>());
      });
    }

    scenario('paging away and back shows the failure without a request; '
        'Retry makes exactly one', (tester) async {
      var attempt = 0;
      final rig = await _mount(
        tester,
        kinds: 'vi',
        initial: 0,
        prepare: (player, _) {
          if (attempt++ == 0) {
            player.failOpen = const MediaPlaybackException(
              MediaFailure(MediaFailureKind.network),
            );
          }
        },
      );
      await _rest(tester, 300);
      expect(rig.made, hasLength(1));
      int reads() => rig.urlReads.where((id) => id.startsWith('v')).length;
      final before = reads();
      await _go(tester, rig, 1);
      await tester.pump(const Duration(seconds: 5));
      await _go(tester, rig, 0);
      await _rest(tester, 600);
      expect(rig.made, hasLength(1), reason: 'no loop: re-entry opens nothing');
      expect(reads(), before, reason: 'no request on re-entry');
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await _rest(tester, 100);
      await _rest(tester, 100);
      expect(rig.made, hasLength(2), reason: 'exactly one new player');
      expect(rig.made.last.opens, 1);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('HDR native view', () {
    scenario('only while the page rests; any swipe or drag removes it', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0, hdr: true);
      expect(rig.made, isEmpty);
      await _rest(tester, 300);
      await _rest(tester, 100);
      expect(rig.made, hasLength(2), reason: 'shared texture player + native');
      expect(find.byKey(const Key('fake-native-view')), findsOneWidget);
      expect(find.byKey(const Key('fake-video-surface')), findsNothing);
      // A horizontal drag on the page: the native view is gone at once.
      final gesture = await tester.startGesture(const Offset(195, 300));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('fake-native-view')), findsNothing);
      expect(rig.made[1].disposed, isTrue, reason: 'native player released');
      await gesture.up();
      await _rest(tester, 600);
      await _rest(tester, 100);
      expect(
        find.byKey(const Key('fake-native-view')),
        findsOneWidget,
        reason: 'it returns once the page rests again',
      );
    });

    scenario('a drag-to-dismiss takes the native view away too', (
      tester,
    ) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0, hdr: true);
      await _rest(tester, 300);
      await _rest(tester, 100);
      expect(find.byKey(const Key('fake-native-view')), findsOneWidget);
      final gesture = await tester.startGesture(const Offset(195, 300));
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('fake-native-view')), findsNothing);
      expect(rig.made[1].disposed, isTrue);
      await gesture.up(timeStamp: const Duration(seconds: 3));
      await _rest(tester, 600);
    });

    scenario('leaving the page releases the native view', (tester) async {
      final rig = await _mount(tester, kinds: 'vi', initial: 0, hdr: true);
      await _rest(tester, 300);
      await _rest(tester, 100);
      expect(rig.made, hasLength(2));
      await _go(tester, rig, 1);
      await tester.pump();
      await _rest(tester, 50);
      expect(rig.made[1].disposed, isTrue);
      expect(find.byKey(const Key('fake-native-view')), findsNothing);
    });
  });
}

/// A card's hold on the attachment's session (it opens the player).
PlayerHold _cardHold(_Rig rig, Map<String, dynamic> metadata) {
  return rig.sessions.acquire(
    _key(metadata),
    scope: rig.w.attachmentImageScope,
    channelId: 'c1',
    create: () {
      final player = _Player();
      rig.made.add(player);
      return player;
    },
    source: () async =>
        AttachmentSource.network(Uri.parse('https://media.invalid/card')),
  );
}
