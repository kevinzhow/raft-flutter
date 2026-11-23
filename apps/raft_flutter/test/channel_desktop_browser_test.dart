import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_flutter/features/channel_artifact_place.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/web_preview_fixture.dart';

void main() {
  testWidgets('closing an Artifact returns focus while uncovering a browser', (
    tester,
  ) async {
    final (workspace, _) = (await tester.runAsync(
      () => webPreviewFixture(flag: false, os: 'linux', desktopBrowser: true),
    ))!;
    addTearDown(workspace.dispose);
    final opener = FocusNode();
    addTearDown(opener.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ChannelSideArea(
            controller: workspace,
            child: Focus(focusNode: opener, child: const SizedBox.expand()),
          ),
        ),
      ),
    );
    openWebPreviewBeside(
      workspace,
      'https://example.test/preview',
      conversationId: 'c1',
    );
    await tester.pumpAndSettle();
    ChannelArtifactPlace.of(workspace).show(
      'c1',
      const ArtifactLinkTarget('fixture'),
      returnFocus: opener.requestFocus,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artifact-viewer-close')));
    await tester.pumpAndSettle();
    final focused = opener.hasFocus;
    await tester.pumpWidget(const SizedBox());
    expect(focused, isTrue);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('the side area switches between the Artifact and an empty tab', (
    tester,
  ) async {
    final (workspace, _) = (await tester.runAsync(
      () => webPreviewFixture(flag: false, os: 'linux', desktopBrowser: true),
    ))!;
    addTearDown(workspace.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: ChannelSideArea(
            controller: workspace,
            child: Builder(
              builder: (context) => RaftButton(
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
    );
    final tabs = WebPreviewStore.of(workspace).browserTabs;
    const closeBrowser = ValueKey('browser-close');
    const switchToBrowser = ValueKey('switch-to-browser');
    const closeArtifact = ValueKey('artifact-viewer-close');
    const address = 'https://example.test/preview';
    expect(
      openWebPreviewBeside(workspace, address, conversationId: 'c1'),
      isTrue,
    );
    await tester.pump();
    tabs.newTab('c1');
    await tester.pump();
    final emptyTab = tabs.forConversation('c1')!.activeId;
    expect(find.byKey(closeBrowser), findsOneWidget);
    await tester.tap(find.text('Open fixture Artifact'));
    await tester.pump();
    expect(find.byKey(closeBrowser).hitTestable(), findsNothing);
    expect(find.byKey(switchToBrowser).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(switchToBrowser));
    await tester.pump();
    expect(tabs.forConversation('c1')!.activeId, emptyTab);
    expect(find.byKey(closeBrowser).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(closeBrowser));
    await tester.pump();
    expect(tabs.forConversation('c1'), isNull);
    await tester.tap(find.byKey(closeArtifact));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.byKey(closeArtifact), findsNothing);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('an inactive tab can be closed with a middle click', (
    tester,
  ) async {
    final (workspace, _) = (await tester.runAsync(
      () => webPreviewFixture(os: 'linux', desktopBrowser: true),
    ))!;
    addTearDown(workspace.dispose);
    final tabs = WebPreviewStore.of(workspace).browserTabs
      ..open('c1', Uri.parse('https://example.test/'))
      ..open('c1', Uri.parse('https://example.test/other'));
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChannelSideArea(
            controller: workspace,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('browser-tab-1')),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await tester.pump();
    expect(tabs.forConversation('c1')!.tabs.map((tab) => tab.id), [2]);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
}
