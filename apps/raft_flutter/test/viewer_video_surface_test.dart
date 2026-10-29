// Which video surface each place asks for on Android, iOS and macOS: a card
// and the full-screen viewer of an SDR video share one texture player (one
// stream); only an HDR video gets the plugin's native view (SurfaceView,
// AVPlayerLayer) in the viewer, as a player of its own that takes over at the
// card's position and hands it back on close.
import 'dart:async';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'message_presentation_test.dart' show fixture;
import 'flutter_test_config.dart' show leakDebt;

class _Platform extends VideoPlayerPlatform {
  final types = <VideoViewType>[];
  final sources = <String>[];
  final calls = <String>[];
  var position = Duration.zero;
  var disposed = 0;
  final _streams = <int, StreamController<VideoEvent>>{};
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    types.add(options.viewType);
    sources.add('${options.dataSource.sourceType.name}:${options.dataSource.uri}',
    );
    final id = types.length - 1;
    _streams[id] = StreamController<VideoEvent>()
      ..add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(1920, 1080),
          duration: const Duration(seconds: 10),
        ),
      );
    return id;
  }

  @override
  Future<void> dispose(int playerId) async => disposed++;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;
  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async => calls.add('pause');
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool prevents,
  ) async {}
  @override
  Future<void> seekTo(int playerId, Duration to) async {
    calls.add('seek:${to.inSeconds}');
    position = to;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Widget buildView(int playerId) => const SizedBox(key: Key('picture'));
}

class _Files extends AttachmentPreviewFiles {
  _Files(this.lease);
  final SharedFileLease lease;
  @override
  Future<SharedFileLease?> load(
    String url,
    String filename, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int, int)? onProgress,
  }) async => lease;
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  var urls = 0;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    urls++;
    return {'url': 'https://example.invalid/signed'};
  }
}

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<VideoPlayerController?>', 'VideoPlayerController',
  ]);
  late _Platform fake;
  late VideoPlayerPlatform previous;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    fake = _Platform();
    VideoPlayerPlatform.instance = fake;
  });
  tearDown(() => VideoPlayerPlatform.instance = previous);
  final system = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  });

  Future<WorkspaceController> mountViewer(
    WidgetTester tester,
    String filename, {
    HdrDetector? hdr,
  }) async {
    final client = _Client();
    final w = WorkspaceController(client);
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: AttachmentPreviewDialog(
          controller: w,
          metadata: {'id': 'a', 'filename': filename},
          authorized: () => true,
          onClose: () {},
          onDownload: () async {},
          hdrDetector: hdr ?? (_) async => false,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return w;
  }

  testWidgets('an SDR video in the viewer streams its URL on the shared texture', (
    tester) async {
    final w = await mountViewer(tester, 'clip.mp4');
    expect(fake.types, [VideoViewType.textureView]);
    // Streamed from the signed URL: nothing was downloaded to a local file.
    expect(fake.sources, ['network:https://example.invalid/signed']);
    expect(find.byType(RaftVideoViewer), findsOneWidget);
    expect(find.byKey(const Key('picture')), findsOneWidget);
    // Closing the viewer gives the player back; with no card it is freed.
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 10 && fake.disposed == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(fake.disposed, 1);
    expect(w.attachmentMedia.playerSessions.length, 0);
  }, variant: system,
  );

  testWidgets('an HDR video gets a native-view player at the shared position', (
    tester,
  ) async {
    final w = await mountViewer(tester, 'clip.mp4', hdr: (_) async => true);
    for (var i = 0; i < 60 && fake.types.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // The shared texture player first, then a platform-view player of its own.
    expect(fake.types, [VideoViewType.textureView, VideoViewType.platformView]);
    expect(debugLastHdrHandoff, isNotNull);
    // Closing frees the native-view player and the shared one (no card).
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 10 && fake.disposed < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(fake.disposed, 2);
    expect(w.attachmentMedia.playerSessions.length, 0);
  }, variant: system);

  testWidgets('an audio attachment in the viewer plays the cached file, no picture', (
    tester) async {
    final dir = Directory.systemTemp.createTempSync('viewer-audio');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/tone.wav')..writeAsBytesSync([1, 2, 3]);
    final lease = SharedFileLease(file, lifetime: const Duration(hours: 1));
    final client = _Client();
    final w = WorkspaceController(client);
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: AttachmentPreviewDialog(
          controller: w,
          metadata: const {'id': 'a', 'filename': 'tone.wav'},
          authorized: () => true,
          onClose: () {},
          onDownload: () async {},
          files: _Files(lease),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(fake.types, [VideoViewType.textureView]);
    expect(fake.sources.single, startsWith('file:'));
    await tester.pumpWidget(const SizedBox());
    // The viewer disposes its player and the cached file's lease.
    var present = true;
    for (var i = 0; i < 30 && present; i++) {
      present = (await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return file.exists();
      }))!;
      await tester.pump();
    }
    expect(present, false);
  }, variant: system,
  );

  testWidgets(
    'only the viewer creates a player and closing it releases that player',
    (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    api.routes['GET /attachments/a1/url'] = (_) => {
      'url': 'https://media.invalid/a1',
    };
    const meta = {
      'id': 'a1',
      'filename': 'walkthrough.mp4',
      'mimeType': 'video/mp4',
      'sizeBytes': 1000000,
    };
    final context = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: context,
        theme: raftTheme(),
        home: Scaffold(
          body: InlineVideoAttachment(
            controller: w,
            metadata: meta,
            authorized: () => true,
            pending: false,
            onOpenPreview: () => context.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => AttachmentPreviewDialog(
                  controller: w,
                  metadata: meta,
                  authorized: () => true,
                  onClose: () => context.currentState!.pop(),
                  onDownload: () async {},
                  hdrDetector: (_) async => false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(fake.types,
        isEmpty,
        reason: 'a timeline card never opens a player',
      );
      expect(w.attachmentMedia.playerSessions.created, 0);
    await tester.tap(find.byKey(const Key('inline-video-poster-card')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(RaftVideoViewer), findsOneWidget);
    expect(fake.types, [VideoViewType.textureView,
      ], reason: 'only the viewer creates a playback session');
    expect(w.attachmentMedia.playerSessions.created, 1);
    // Close at once, mid-way and fully: the viewer releases its only hold.
    context.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RaftVideoViewer), findsNothing);
      for (var i = 0; i < 50 && fake.disposed == 0; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(fake.disposed, 1);
      expect(w.attachmentMedia.playerSessions.length, 0);
    await tester.pumpWidget(const SizedBox());
    w.attachmentMedia.playerSessions.clear();
    await tester.pump(const Duration(milliseconds: 50));
  }, variant: system,
  );
}
