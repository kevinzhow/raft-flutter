// Debug entrypoint: drives the app's VideoPlayerAttachmentPlayer (ExoPlayer on
// Android, AVPlayer on iOS and macOS) against the host's media server and prints
// the class each failure lands in as `MEDIAFAIL {json}` lines for `adb logcat`.
//
//   tool/flutter build apk --debug --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/media_failure_android_main.dart
//
// Phase 1 runs without a proxy. Phase 2 waits until the OS reports an HTTP proxy
// (host: `adb shell settings put global http_proxy 10.0.2.2:<closed port>`).
// The server is reached through 10.0.2.2 (cleartext is allowed there only).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/media_failure.dart';
import 'package:raft_flutter/platform/system_proxy_bootstrap.dart';
import 'package:raft_flutter/platform/video_player_attachment_player.dart';

const _base = String.fromEnvironment(
  'MEDIA_FAILURE_BASE',
  defaultValue: 'http://10.0.2.2:48611',
);

void _emit(String name, Map<String, Object?> data) =>
    // ignore: avoid_print
    print('MEDIAFAIL ${jsonEncode({'case': name, ...data})}');

Future<void> _run(String name, String path, {bool refresh = false, String? base}) async {
  final player = VideoPlayerAttachmentPlayer();
  var signed = 0;
  Object? thrown;
  try {
    await player
        .open(
          AttachmentSource.network(
            Uri.parse('${base ?? _base}$path'),
            refresh: refresh
                ? () async {
                    signed++;
                    return Uri.parse('${base ?? _base}$path');
                  }
                : null,
          ),
        )
        .timeout(const Duration(seconds: 60));
  } on Object catch (error) {
    thrown = error;
  }
  final failure = thrown is MediaPlaybackException ? thrown.failure : null;
  _emit(name, {
    'error': player.playback.error,
    'kind': failure?.kind.name,
    'proxy': failure?.proxy,
    'resigns': signed,
    'duration': player.playback.duration.inMilliseconds,
    'thrown': thrown == null || failure != null ? null : '$thrown',
  });
  await player.dispose();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DevicePreferences.load();
  await startSystemProxy(
    preferences: DevicePreferences.current,
    origins: [_base],
  );
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('media failure probe')))));
  await Future<void>.delayed(const Duration(seconds: 2));
  final url = Uri.parse(_base);
  _emit('proxy', {'status': '${SystemProxy.instance.status(url)}'});
  if (SystemProxy.instance.status(url).proxy == null) {
    await _run('ok', '/ok.webm');
    await _run('403', '/403', refresh: true);
    await _run('404', '/404');
    await _run('410', '/410');
    await _run('500', '/500');
    await _run('corrupt', '/corrupt.mp4');
    await _run('refused', '/x.mp4', base: 'http://10.0.2.2:1');
    _emit('phase1', {'done': true});
    for (var i = 0; i < 120; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (i % 5 == 0) await SystemProxy.instance.refresh();
      if (SystemProxy.instance.status(url).proxy != null) break;
    }
  }
  _emit('proxy', {'status': '${SystemProxy.instance.status(url)}'});
  await _run('proxy-refused', '/ok.webm');
  _emit('done', {});
}
