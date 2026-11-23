import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/feature_flag_client_facts.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../message_presentation_test.dart' show MessageAdapter, fixture;

/// A member's workspace with channel `c1` on screen, `web_preview_v0`
/// [flag] (remembered on the device, so the first read already has it), on a
/// device whose operating system is [os].
Future<(WorkspaceController, MessageAdapter)> webPreviewFixture({
  bool flag = true,
  String os = 'android',
  bool desktopBrowser = false,
  ValueListenable<bool>? voiceOver,
}) async {
  SharedPreferences.setMockInitialValues({});
  DevicePreferences.adopt(await SharedPreferences.getInstance());
  final (w, api) = await fixture('member');
  FeatureFlagMemory.write(
    [
      w.client.origin,
      w.client.user?.id,
      w.server?.id,
      w.server?.string('role'),
    ],
    {
      ChannelSideFlags.webPreviewKey: flag,
      RaftFeatureFlags.desktopWebPreviewView: desktopBrowser,
    },
  );
  final off = voiceOver ?? ValueNotifier(false);
  if (voiceOver == null) addTearDown((off as ValueNotifier<bool>).dispose);
  WebPreviewStore.of(w).platform = WebPreviewPlatform(
    operatingSystem: os,
    voiceOver: off,
  );
  // Read the flag now: its first read asks the server (a 404 here), which
  // must be over before a widget test starts counting timers.
  ChannelSideFlags.of(w);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return (w, api);
}
