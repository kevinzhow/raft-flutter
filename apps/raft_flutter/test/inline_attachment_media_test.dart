import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

class _Player implements AttachmentPlayer {
  final events = StreamController<AttachmentPlayback>.broadcast();
  final calls = <String>[];
  final sources = <AttachmentSource>[];
  bool disposed = false;
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  AttachmentPlayback last = const AttachmentPlayback();
  @override
  AttachmentPlayback get playback => last;
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() =>
      const ColoredBox(key: Key('fake-video-surface'), color: Colors.red);
  @override
  Future<void> open(AttachmentSource source) async {
    sources.add(source);
    calls.add('open');
    last = const AttachmentPlayback(duration: Duration(seconds: 125));
    events.add(last);
  }

  @override
  Future<void> toggle() async => calls.add('toggle');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration value) async =>
      calls.add('seek:${value.inSeconds}');
  @override
  Future<void> volume(double value) async =>
      calls.add('volume:${value.round()}');
  @override
  Future<void> dispose() async {
    disposed = true;
    unawaited(events.close());
  }
}

/// Unmount and let the asynchronous player disposal finish.
dynamic _mounted;

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // The sessions own the players; clearing them ends every player.
  _mounted?.attachmentMedia.playerSessions.clear();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('audio timestamps read m:ss and bound unknown values', () {
    expect(raftAudioTimestamp(Duration.zero), '0:00');
    expect(raftAudioTimestamp(const Duration(seconds: 65)), '1:05');
    expect(raftAudioTimestamp(const Duration(milliseconds: 9999)), '0:09');
    expect(raftAudioTimestamp(const Duration(seconds: -3)), '0:00');
  });

  Future<(MessageAdapter, _Player)> mount(
    WidgetTester tester, {
    required Widget Function(dynamic w, Object? files, _Player player) build,
    bool failUrl = false,
  }) async {
    tester.view.physicalSize = const Size(600, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    _mounted = w;
    api.routes['GET /attachments/a1/url'] = (_) => failUrl
        ? throw StateError('no url')
        : {'url': 'https://media.invalid/a1'};
    final player = _Player();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: build(w, null, player)),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return (api, player);
  }

  testWidgets('audio: loads, plays, seeks and sets the volume', (tester) async {
    var downloads = 0;
    final (_, player) = await mount(
      tester,
      build: (w, files, player) => InlineAudioAttachment(
        controller: w,
        metadata: const {
          'id': 'a1',
          'filename': 'standup.mp3',
          'mimeType': 'audio/mpeg',
        },
        authorized: () => true,
        pending: false,
        onDownload: () => downloads++,
        playerFactory: () => player,
      ),
    );
    expect(find.text('standup.mp3'), findsOneWidget);
    expect(find.text('Audio file'), findsOneWidget);
    expect(player.calls, ['open']);
    // Metadata known: 0:00 / 2:05.
    expect(find.text('0:00 / 2:05'), findsOneWidget);
    await tester.tap(find.byKey(const Key('audio-play-toggle')));
    await tester.pump();
    expect(player.calls.last, 'toggle');
    player.events.add(
      const AttachmentPlayback(
        playing: true,
        position: Duration(seconds: 61),
        duration: Duration(seconds: 125),
        volume: 100,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('1:01 / 2:05'), findsOneWidget);
    // Pressing the middle of the seek rail seeks to about half.
    final rail = tester.getRect(find.byKey(const Key('audio-seek')));
    await tester.tapAt(Offset(rail.left + rail.width / 2, rail.center.dy));
    await tester.pump();
    final seek = player.calls.where((c) => c.startsWith('seek:')).last;
    expect(int.parse(seek.substring(5)), inInclusiveRange(61, 64));
    final volume = tester.getRect(find.byKey(const Key('audio-volume')));
    await tester.tapAt(
      Offset(volume.left + volume.width * .25, volume.center.dy),
    );
    await tester.pump();
    expect(player.calls.last, 'volume:25');
    await tester.tap(find.byKey(const Key('audio-download')));
    expect(downloads, 1);
    await unmount(tester);
    expect(player.disposed, isTrue);
  });

  testWidgets('audio: a failed URL read offers Download to view', (
    tester,
  ) async {
    var downloads = 0;
    await mount(
      tester,
      failUrl: true,
      build: (w, files, player) => InlineAudioAttachment(
        controller: w,
        metadata: const {'id': 'a1', 'filename': 'standup.mp3'},
        authorized: () => true,
        pending: false,
        onDownload: () => downloads++,
        playerFactory: () => player,
      ),
    );
    expect(find.text('Download to View'), findsOneWidget);
    // The header download action is hidden once the load failed; the
    // placeholder itself downloads.
    expect(find.byKey(const Key('audio-download')), findsNothing);
    await tester.tap(find.byKey(const Key('audio-placeholder')));
    expect(downloads, 1);
    await unmount(tester);
  });

  testWidgets('an optimistic attachment never reads its URL', (tester) async {
    final (api, player) = await mount(
      tester,
      build: (w, files, player) => InlineAudioAttachment(
        controller: w,
        metadata: const {'id': 'a1', 'filename': 'standup.mp3'},
        authorized: () => true,
        pending: true,
        playerFactory: () => player,
      ),
    );
    expect(api.calls.where((c) => c.path.contains('/attachments/')), isEmpty);
    expect(find.text('Loading standup.mp3'), findsOneWidget);
    expect(find.byKey(const Key('audio-download')), findsNothing);
    expect(player.calls, isEmpty);
    await unmount(tester);
  });
}
