import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_artifact_place.dart';
import 'package:raft_flutter/features/channel_browser_place.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';
import 'package:raft_flutter/features/web_link_open.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ext_artifact_discussion.dart' show createArtifactDiscussionFixture;
import 'screens/screen_fixture.dart';

const _states = [
  'page',
  'empty',
  'editing',
  'invalid',
  'overflow',
  'narrow',
  'artifact-behind',
  'artifact-front',
  'short-front',
  'long-front',
];

const _webLinkSurfaces = {
  'web-link-choice': 'WebLinkChoiceDialog',
  'web-link-menu': 'showDesktopWebLinkMenu',
  'web-link-setting': 'HowWebLinksOpenSetting',
};

final Map<String, ParityCase> extBrowserCases = {
  for (final state in _states)
    for (final theme in ['light', 'dark'])
      'components.browser.desktop.$state.$theme': const ParityCase(
        widgets: ['raft_flutter:DesktopBrowserPanel'],
        notes: 'Chrome against BrowserPanel with a blank native placeholder.',
        build: _build,
      ),
  for (final surface in _webLinkSurfaces.entries)
    for (final theme in ['light', 'dark'])
      'components.browser.desktop.${surface.key}.$theme': ParityCase(
        widgets: ['raft_flutter:${surface.value}'],
        notes: surface.key == 'web-link-menu'
            ? 'Web uses a Raft UI context menu to visualize the native bridge offer.'
            : 'Desktop web link controls.',
        build: _buildWebLink,
      ),
};

Widget _build(ParityContext ctx) => ctx.frame(
  width: ctx.width,
  height: ctx.height,
  padding: EdgeInsets.zero,
  child: ctx.props['extCase'] == 'artifact-front'
      ? _artifactSwitch(ctx)
      : _BrowserFixture(
          state: ctx.props['extCase'] as String,
          artifactTitle: ctx.props['artifactTitle'] as String?,
        ),
);

Widget _buildWebLink(ParityContext ctx) {
  final wire = ScreenWire(ctx.fixtureData);
  final server = RaftRecord(wire.server());
  final client = ScreenFixtureClient(
    (method, path, query) => path == '/feature-flags/evaluate'
        ? {
            'evaluations': [
              {'key': 'desktop_web_preview_view_v0', 'enabled': true},
            ],
          }
        : wire.common(method, path, query),
    user: wire.me(),
    server: server.id,
  );
  final workspace = WorkspaceController(client)..server = server;
  ctx.onDispose(() {
    workspace.dispose();
    client.dispose();
  });
  WebPreviewStore.of(workspace).platform = const WebPreviewPlatform(
    operatingSystem: 'linux',
  );
  final state = ctx.props['extCase'];
  return Scaffold(
    body: Builder(
      builder: (context) => ColoredBox(
        color: RaftTokens.of(context).ui.layerCanvas,
        child: state == 'web-link-setting'
            ? Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 674,
                  child: HowWebLinksOpenSetting(controller: workspace),
                ),
              )
            : Center(
                child: GestureDetector(
                  key: const ValueKey('browser-link-trigger'),
                  onTap: state == 'web-link-choice'
                      ? () => showWebLinkChoiceDialog(
                          context,
                          desktopBrowser: true,
                        )
                      : null,
                  onSecondaryTapUp: state == 'web-link-menu'
                      ? (details) => showDesktopWebLinkMenu(
                          context,
                          workspace,
                          'https://example.test/guide',
                          'parity-browser',
                          details.globalPosition,
                          () {},
                        )
                      : null,
                  child: const Text('Open guide'),
                ),
              ),
      ),
    ),
  );
}

Widget _artifactSwitch(ParityContext ctx) {
  const conversation = 'parity-browser';
  final fixture = createArtifactDiscussionFixture(ctx);
  ChannelArtifactPlace.of(fixture.workspace)
      .show(conversation, fixture.target, returnFocus: () {});
  WebPreviewStore.of(fixture.workspace).browserTabs
    ..open(conversation, Uri.parse('http://localhost:8040/guide'))
    ..newTab(conversation);
  return Align(
    alignment: Alignment.centerRight,
    child: SizedBox(
      key: const ValueKey('browser-artifact-fixture'),
      width: 480,
      height: double.infinity,
      child: Material(
        type: MaterialType.transparency,
        child: ChannelBrowserPlace(
          workspace: fixture.workspace,
          conversation: conversation,
          collapsed: false,
          expanded: false,
          covering: false,
          onExpand: null,
          headWrapper: (_, _, head) => head,
        ),
      ),
    ),
  );
}

class _BrowserFixture extends StatefulWidget {
  const _BrowserFixture({required this.state, this.artifactTitle});

  final String state;
  final String? artifactTitle;

  @override
  State<_BrowserFixture> createState() => _BrowserFixtureState();
}

class _BrowserFixtureState extends State<_BrowserFixture> {
  static const _conversation = 'parity-browser';
  final _tabs = DesktopBrowserTabs();
  bool get _titleFit =>
      widget.state == 'short-front' || widget.state == 'long-front';

  void _open(String url, {String? title}) {
    final address = Uri.parse(url);
    _tabs.open(_conversation, address);
    if (title == null) return;
    _tabs.report(
      _conversation,
      _tabs.forConversation(_conversation)!.activeId,
      (url: address, title: title, back: false, forward: false, loading: false),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.state == 'overflow' || widget.state == 'narrow') {
      for (var tab = 1; tab < 12; tab++) {
        _open('https://site$tab.test/');
      }
    }
    if (_titleFit) {
      for (final name in ['Alpha', 'Bravo', 'Charlie']) {
        _open('https://${name.toLowerCase()}.test/', title: 'Loopback $name');
      }
    }
    _open(
      'http://localhost:8040/guide',
      title: _titleFit
          ? widget.state == 'short-front'
                ? 'Echo'
                : 'Loopback Delta'
          : null,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RaftTokens.of(context).ui.layerCanvas,
    child: Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: widget.state == 'narrow' ? 224 : 480,
        height: double.infinity,
        child: Material(
          type: MaterialType.transparency,
          child: DesktopBrowserPanel(
            tabs: _tabs,
            conversation: _conversation,
            raftHosts: const {},
            onExpand: _titleFit ? () {} : null,
            onShowArtifact:
                widget.state == 'artifact-behind' || widget.state == 'narrow'
                ? () => _tabs.park(_conversation)
                : null,
            artifactTitle: widget.artifactTitle,
            pageBuilder: (_, _, _, _) => const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}
