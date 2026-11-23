import 'package:flutter/material.dart';
import 'package:raft_flutter/features/channel_artifact_place.dart';
import 'package:raft_flutter/features/channel_browser_place.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ext_artifact_discussion.dart' show createArtifactDiscussionFixture;

const _states = [
  'page',
  'empty',
  'editing',
  'invalid',
  'overflow',
  'narrow',
  'artifact-behind',
  'artifact-front',
];

final Map<String, ParityCase> extBrowserCases = {
  for (final state in _states)
    for (final theme in ['light', 'dark'])
      'components.browser.desktop.$state.$theme': const ParityCase(
        widgets: ['raft_flutter:DesktopBrowserPanel'],
        notes: 'Chrome against BrowserPanel with a blank native placeholder.',
        build: _build,
      ),
};

Widget _build(ParityContext ctx) => ctx.frame(
  width: ctx.width,
  height: ctx.height,
  padding: EdgeInsets.zero,
  child: ctx.props['extCase'] == 'artifact-front'
      ? _artifactSwitch(ctx)
      : _BrowserFixture(state: ctx.props['extCase'] as String),
);

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
  const _BrowserFixture({required this.state});

  final String state;

  @override
  State<_BrowserFixture> createState() => _BrowserFixtureState();
}

class _BrowserFixtureState extends State<_BrowserFixture> {
  static const _conversation = 'parity-browser';
  final _tabs = DesktopBrowserTabs();

  @override
  void initState() {
    super.initState();
    if (widget.state == 'overflow' || widget.state == 'narrow') {
      for (var tab = 1; tab < 12; tab++) {
        _tabs.open(_conversation, Uri.parse('https://site$tab.test/'));
      }
    }
    _tabs.open(_conversation, Uri.parse('http://localhost:8040/guide'));
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
            onShowArtifact:
                widget.state == 'artifact-behind' || widget.state == 'narrow'
                ? () => _tabs.park(_conversation)
                : null,
            pageBuilder: (_, _, _, _) => const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}
