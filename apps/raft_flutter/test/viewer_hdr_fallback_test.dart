// Regressions (CodexMac repros): when the HDR native-view player fails to start,
// the viewer must resume the shared player it paused for the handoff; and the
// handoff must carry the shared player's volume (a muted video stays muted).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/attachment_stream.dart';
import 'package:raft_ui/raft_ui.dart';

class Client extends RaftClient {
  Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'url': 'https://example.invalid/signed',
  };
}

class Player implements AttachmentPlayer {
  Player({
    this.fail = false,
    this.native = false,
    this.playing = false,
    this.level = 100,
  });
  final bool fail, native;
  bool playing, closed = false;
  double level;
  final events = StreamController<AttachmentPlayback>.broadcast();
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  @override
  AttachmentPlayback get playback => AttachmentPlayback(
    volume: level,
    playing: playing,
    position: const Duration(seconds: 4),
    duration: const Duration(seconds: 60),
    hasFrame: true,
    videoSize: const Size(1920, 1080),
  );
  @override
  bool get usesPlatformView => native;
  @override
  Widget video() => const SizedBox(key: Key('real-contract-picture'));
  @override
  Future<void> open(AttachmentSource s) async {
    if (fail) throw StateError('HDR renderer cannot open');
  }

  @override
  Future<void> pause() async {
    playing = false;
    events.add(playback);
  }

  @override
  Future<void> toggle() async {
    playing = !playing;
    events.add(playback);
  }

  @override
  Future<void> seek(Duration d) async {}
  @override
  Future<void> volume(double v) async {
    level = v;
  }

  @override
  Future<void> dispose() async {
    closed = true;
    await events.close();
  }
}

void main() {
  testWidgets(
    'failed HDR refinement preserves the already-playing shared stream',
    (t) async {
      final c = Client();
      final w = WorkspaceController(c);
      final base = Player(playing: true),
          native = Player(fail: true, native: true);
      final key = attachmentMediaKey({'id': 'a', 'filename': 'clip.mp4'});
      final card = w.attachmentMedia.playerSessions.acquire(
        key,
        scope: w.attachmentImageScope,
        create: () => base,
        source: () async => AttachmentSource.network(
          Uri.parse('https://example.invalid/signed'),
        ),
      );
      await card.ready;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: AttachmentPreviewDialog(
            controller: w,
            metadata: {'id': 'a', 'filename': 'clip.mp4'},
            authorized: () => true,
            onClose: () {},
            onDownload: () async {},
            playerFactory: () => native,
            hdrDetector: (_) async => true,
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      final stillPlaying = base.playing;
      expect(find.byKey(const Key('real-contract-picture')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      card.release();
      w.dispose();
      await c.dispose();
      expect(
        stillPlaying,
        isTrue,
        reason: 'HDR is a refinement; failure should fall back to uninterrupted SDR playback.',
      );
    },
  );

  testWidgets('HDR handoff preserves the muted shared stream', (t) async {
    final c = Client();
    final w = WorkspaceController(c);
    final base = Player(playing: true, level: 0), native = Player(native: true);
    final key = attachmentMediaKey({'id': 'a', 'filename': 'clip.mp4'});
    final card = w.attachmentMedia.playerSessions.acquire(
      key,
      scope: w.attachmentImageScope,
      create: () => base,
      source: () async =>
          AttachmentSource.network(Uri.parse('https://example.invalid/signed')),
    );
    await card.ready;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: AttachmentPreviewDialog(
          controller: w,
          metadata: {'id': 'a', 'filename': 'clip.mp4'},
          authorized: () => true,
          onClose: () {},
          onDownload: () async {},
          playerFactory: () => native,
          hdrDetector: (_) async => true,
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final volume = native.playback.volume;
    await t.pumpWidget(const SizedBox());
    card.release();
    w.dispose();
    await c.dispose();
    expect(
      volume,
      0,
      reason: 'Opening HDR preview must not unmute a muted video.',
    );
  });
}
