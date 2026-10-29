// Debug/profile-only entrypoint: the production RaftApp on perf-lab fixtures
// with a channel of video attachments served by an external S3-like range
// server (tool/video-parity-range-server).
// No login. Never built into the release app.
//
//   tool/video-parity-range-server <dir: portrait.mp4 landscape.mp4 landscape2.mp4 corrupt.mp4> 8791
//   tool/flutter build linux --profile -t integration_test/video_parity_main.dart \
//     --dart-define=VP_BASE=http://127.0.0.1:8791 --dart-define=VP_MOBILE=false
//
// Opening the channel route directly (the default) showed an empty channel on
// this build: start from the home list with `--dart-define=VP_LOC=/s/lab` and
// tap the channel.
//
// Android: `adb reverse tcp:8791 tcp:8791` and VP_MOBILE=true; the isolated
// package is `app.raft.raft_flutter.linkperf` (see attachment_progress_main).
import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/android_performance_hint.dart';

import 'support/video_fixture.dart';

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment(
    'VP_BASE',
    defaultValue: 'http://127.0.0.1:8791',
  );
  final fixture = await buildVideoFixture(
    base: base,
    mobile: const bool.fromEnvironment('VP_MOBILE'),
    clips: parityClips,
    location: const String.fromEnvironment(
      'VP_LOC',
      defaultValue: '/s/lab/channel/vp',
    ),
    mode: const String.fromEnvironment('VP_MODE', defaultValue: 'light'),
    theme: const String.fromEnvironment('VP_THEME', defaultValue: 'brutal'),
  );
  runApp(fixture.app);
}
