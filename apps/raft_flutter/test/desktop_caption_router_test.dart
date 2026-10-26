import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  const channel = MethodChannel(DesktopTitleBarController.channelName);
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'status' || call.method == 'setIntegrated'
              ? {
                  'height': 48.0,
                  'customControls': true,
                  'fullscreen': false,
                  'active': true,
                  'maximized': false,
                  'buttonLayout': ':minimize,maximize,close',
                }
              : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  tearDownAll(() => DesktopTitleBarController.platform.state.dispose());
  testWidgets(
    'Linux custom caption retains an initial channel link during startup',
    (t) async {
      final f = RootFixture();
      try {
        await f.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/channel/ca'));
        await f.flush(t);
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(f.workspace(t).channel?.id, 'ca');
        expect(find.text('Accepted a', findRichText: true), findsWidgets);
        expect(find.byType(RaftComposer), findsOneWidget);
        expect(find.byKey(const Key('desktop-caption-close')), findsOneWidget);
      } finally {
        await f.close(t);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets(
    'Linux selector entry retains the Router and editor under the custom row',
    (t) async {
      final f = RootFixture();
      try {
        await f.mount(t, 'light', 1280);
        final router = find.byWidgetPredicate((w) => w is Router);
        final original = t.state(router);
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await f.flush(t);
        expect(t.state(router), same(original));
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(f.workspace(t).channel?.id, 'ca');
        expect(find.text('Accepted a', findRichText: true), findsWidgets);
        expect(find.byType(RaftComposer), findsOneWidget);
        expect(find.byKey(const Key('desktop-caption-close')), findsOneWidget);
      } finally {
        await f.close(t);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
