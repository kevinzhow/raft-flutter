// Web v1.24 openArtifactInPlace / findArtifactPlace (#proj-workspace:#104):
// an Artifact opened from a conversation (its message card or chip, "Saved as
// Artifact", a Files row, the announcement) opens beside that conversation on
// every wide window, whatever the device. Raft Desktop's built-in browser is
// one more thing that can stand in that place, not what makes the place.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview.dart';

import 'support/web_preview_fixture.dart';

typedef _Device = ({
  String name,
  String os,
  TargetPlatform platform,
  bool desktopBrowser,
  bool voiceOver,
});

const _devices = <_Device>[
  (
    name: 'an iPad',
    os: 'ios',
    platform: TargetPlatform.iOS,
    desktopBrowser: false,
    voiceOver: false,
  ),
  (
    name: 'an Android tablet',
    os: 'android',
    platform: TargetPlatform.android,
    desktopBrowser: false,
    voiceOver: false,
  ),
  (
    name: 'Linux with the built-in browser off',
    os: 'linux',
    platform: TargetPlatform.linux,
    desktopBrowser: false,
    voiceOver: false,
  ),
  (
    name: 'macOS with VoiceOver on',
    os: 'macos',
    platform: TargetPlatform.macOS,
    desktopBrowser: true,
    voiceOver: true,
  ),
];

void main() {
  for (final device in _devices) {
    testWidgets('on ${device.name} an Artifact opens beside the conversation '
        'and × closes it', (t) async {
      final voiceOver = ValueNotifier(device.voiceOver);
      addTearDown(voiceOver.dispose);
      final (workspace, _) = (await t.runAsync(
        () => webPreviewFixture(
          os: device.os,
          desktopBrowser: device.desktopBrowser,
          voiceOver: voiceOver,
        ),
      ))!;
      addTearDown(workspace.dispose);
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: device.platform),
          home: Scaffold(
            body: ChannelSideArea(
              controller: workspace,
              child: Builder(
                builder: (context) => Center(
                  child: RaftButton(
                    label: 'Open fixture Artifact',
                    onPressed: () => openWorkspaceArtifact(
                      context,
                      workspace,
                      const ArtifactLinkTarget('fixture'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final opener = find.text('Open fixture Artifact');
      await t.tap(opener);
      await t.pumpAndSettle();

      final viewer = find.byType(ArtifactWorkspaceViewer);
      expect(viewer, findsOneWidget);
      expect(
        ModalRoute.of(t.element(viewer)),
        same(ModalRoute.of(t.element(opener))),
        reason: 'in the page, not on a window over it',
      );
      expect(opener.hitTestable(), findsOneWidget, reason: 'the chat stays');
      expect(
        t.getRect(viewer).left,
        greaterThanOrEqualTo(t.getRect(opener).right),
      );

      await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
      await t.pumpAndSettle();
      expect(viewer, findsNothing);
      expect(opener.hitTestable(), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('on an Android tablet a web page opened after the Artifact '
      'takes its place; closing the page gives the Artifact back', (t) async {
    WebViewPlatform.instance = FakeWebView();
    final (workspace, _) = (await t.runAsync(webPreviewFixture))!;
    addTearDown(workspace.dispose);
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: ChannelSideArea(
            controller: workspace,
            child: Builder(
              builder: (context) => Center(
                child: RaftButton(
                  label: 'Open fixture Artifact',
                  onPressed: () => openWorkspaceArtifact(
                    context,
                    workspace,
                    const ArtifactLinkTarget('fixture'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open fixture Artifact'));
    await t.pumpAndSettle();
    final viewer = find.byType(ArtifactWorkspaceViewer);
    expect(viewer.hitTestable(), findsOneWidget);

    await t.pump(const Duration(milliseconds: 5));
    expect(
      openWebPreviewBeside(
        workspace,
        'https://example.test/page',
        conversationId: 'c1',
      ),
      isTrue,
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('web-preview')), findsOneWidget);
    expect(viewer.hitTestable(), findsNothing);

    WebPreviewStore.of(workspace).close();
    await t.pumpAndSettle();
    expect(viewer.hitTestable(), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
