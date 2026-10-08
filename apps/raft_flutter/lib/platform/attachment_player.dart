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
            configuration: Platform.isAndroid
                ? const VideoControllerConfiguration(
                    vo: 'mediacodec_embed',
                    hwdec: 'mediacodec',
                  )
                : const VideoControllerConfiguration(
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
    // media_kit's error stream omits fatal and video-output log events.
    // Preserve their failure without exposing decoder paths or file contents.
    subscriptions.add(
      player.stream.log.listen((event) {
        if (event.level == 'fatal' ||
            (event.level == 'error' &&
                (event.prefix == 'vo' || event.prefix.startsWith('vo/')))) {
          publish(error: true);
        }
      }),
    );
  }
  late final Player player;
  late final VideoController? controller;
  final output = StreamController<AttachmentPlayback>.broadcast();
  final subscriptions = <StreamSubscription<dynamic>>[];
  bool closed = false, failed = false;
  void publish({bool error = false}) {
    if (closed) return;
    failed = failed || error;
    output.add(
      AttachmentPlayback(
        playing: player.state.playing,
        position: player.state.position,
        duration: player.state.duration,
        volume: player.state.volume,
        error: failed,
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
        'autoload-files',
      ]) {
        await native.setProperty(property, 'no');
      }
      // media_kit.open uses an intermediate playlist. Keep external references
      // disabled and load the already-authorized local input directly instead.
      await native.setProperty('pause', 'yes');
      await native.command(['loadfile', file.path, 'replace']);
      return;
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
