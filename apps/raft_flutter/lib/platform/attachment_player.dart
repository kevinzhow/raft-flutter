import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class AttachmentPlayback {
  const AttachmentPlayback({
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.error = false,
  });
  final bool playing, error;
  final Duration position, duration;
  final double volume;
}

abstract interface class AttachmentPlayer {
  Stream<AttachmentPlayback> get changes;
  Widget video();
  Future<void> open(File file);
  Future<void> toggle();
  Future<void> pause();
  Future<void> seek(Duration value);
  Future<void> volume(double value);
  Future<void> dispose();
}

class NativeAttachmentPlayer implements AttachmentPlayer {
  NativeAttachmentPlayer({bool video = true}) {
    MediaKit.ensureInitialized();
    player = Player(
      configuration: const PlayerConfiguration(
        protocolWhitelist: ['file'],
        libass: false,
      ),
    );
    controller = video
        ? VideoController(
            player,
            configuration: const VideoControllerConfiguration(
              enableHardwareAcceleration: false,
            ),
          )
        : null;
    for (final stream in <Stream<dynamic>>[
      player.stream.playing,
      player.stream.position,
      player.stream.duration,
      player.stream.volume,
    ]) {
      subscriptions.add(stream.listen((_) => publish()));
    }
    subscriptions.add(player.stream.error.listen((_) => publish(error: true)));
  }
  late final Player player;
  late final VideoController? controller;
  final output = StreamController<AttachmentPlayback>.broadcast();
  final subscriptions = <StreamSubscription<dynamic>>[];
  bool closed = false;
  void publish({bool error = false}) {
    if (closed) return;
    output.add(
      AttachmentPlayback(
        playing: player.state.playing,
        position: player.state.position,
        duration: player.state.duration,
        volume: player.state.volume,
        error: error,
      ),
    );
  }

  @override
  Stream<AttachmentPlayback> get changes => output.stream;
  @override
  Widget video() => Video(
    controller: controller!,
    controls: NoVideoControls,
    pauseUponEnteringBackgroundMode: true,
    resumeUponEnteringForegroundMode: false,
  );
  @override
  Future<void> open(File file) async {
    final native = player.platform;
    if (native is NativePlayer) {
      for (final property in const [
        'cache-on-disk',
        'cache',
        'access-references',
        'load-scripts',
        'ytdl',
        'sub-auto',
        'audio-file-auto',
      ]) {
        await native.setProperty(property, 'no');
      }
    }
    await player.open(Media(file.uri.toString()), play: false);
  }

  @override
  Future<void> toggle() => player.playOrPause();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration value) => player.seek(value);
  @override
  Future<void> volume(double value) => player.setVolume(value);
  @override
  Future<void> dispose() async {
    if (closed) return;
    closed = true;
    for (final s in subscriptions) {
      await s.cancel();
    }
    await player.dispose();
    await output.close();
  }
}
