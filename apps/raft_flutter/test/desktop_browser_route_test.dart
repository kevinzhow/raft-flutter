import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/feature_flag_client_facts.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/web_link_open.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (os, desktop, preview, canOpen) in [
    ('macos', true, false, true),
    ('windows', true, false, true),
    ('linux', true, false, true),
    ('linux', false, true, false),
    ('android', true, false, false),
  ]) {
    test(
      '$os desktop=$desktop single-page=$preview routes HTTP=$canOpen',
      () async {
        debugDefaultTargetPlatformOverride = switch (os) {
          'macos' => TargetPlatform.macOS,
          'windows' => TargetPlatform.windows,
          'linux' => TargetPlatform.linux,
          _ => TargetPlatform.android,
        };
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({});
        DevicePreferences.adopt(await SharedPreferences.getInstance());
        addTearDown(DevicePreferences.reset);
        final (workspace, _) = await fixture('member');
        addTearDown(workspace.dispose);
        FeatureFlagMemory.write(
          [
            workspace.client.origin,
            workspace.client.user?.id,
            workspace.server?.id,
            workspace.server?.string('role'),
          ],
          {
            RaftFeatureFlags.desktopWebPreviewView: desktop,
            ChannelSideFlags.webPreviewKey: preview,
          },
        );
        final store = WebPreviewStore.of(workspace);
        store.platform = WebPreviewPlatform(
          operatingSystem: os,
          webViewAvailable: true,
        );
        expect(webPreviewAvailable(workspace), canOpen);
        expect(
          openWebPreviewBeside(
            workspace,
            'http://localhost:8080/',
            conversationId: 'c1',
          ),
          canOpen,
        );
        expect(store.page, isNull);
        expect(store.browserTabs.forConversation('c1') != null, canOpen);
      },
    );
  }
}
