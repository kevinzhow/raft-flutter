import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'artifacts/artifact_session.dart';
import 'artifacts/artifact_viewer_page.dart';
import 'channel_artifact_place.dart';
import 'channel_side_card.dart';
import 'channel_side_layout.dart';
import 'channel_side_web_preview.dart';
import 'desktop_browser_native_page.dart';
import 'desktop_browser_panel.dart';
import 'desktop_browser_tabs.dart';

class ChannelBrowserPanes {
  static final _owners = Expando<ChannelBrowserPanes>();

  static ChannelBrowserPanes of(WorkspaceController workspace) =>
      _owners[workspace] ??= ChannelBrowserPanes();

  final _keys = <String, GlobalKey>{};

  void update(
    DesktopBrowserTabs tabs,
    String? active, {
    required bool enabled,
  }) {
    if (!enabled) {
      _keys.clear();
      return;
    }
    _keys.removeWhere(
      (conversation, _) => tabs.forConversation(conversation) == null,
    );
    if (active != null && tabs.forConversation(active) != null) {
      _keys[active] = _keys.remove(active) ?? GlobalKey();
    }
    if (_keys.length > 2) _keys.remove(_keys.keys.first);
  }

  GlobalKey? keyFor(String conversation) => _keys[conversation];

  Iterable<Widget> parked(WorkspaceController workspace, String? active) sync* {
    for (final MapEntry(key: conversation, value: key) in _keys.entries) {
      if (conversation != active) {
        yield Positioned.fill(
          key: ValueKey(conversation),
          child: Offstage(
            child: TickerMode(
              enabled: false,
              child: channelBrowserPanel(
                key: key,
                workspace: workspace,
                conversation: conversation,
                showing: false,
                parked:
                    workspace.section != 'chat' ||
                    workspace.channel?.id != conversation,
              ),
            ),
          ),
        );
      }
    }
  }
}

DesktopBrowserPanel channelBrowserPanel({
  required Key? key,
  required WorkspaceController workspace,
  required String conversation,
  required bool showing,
  bool parked = false,
  bool covering = false,
  bool expanded = false,
  bool collapsed = false,
  String? artifactTitle,
  VoidCallback? onShowArtifact,
  VoidCallback? onExpand,
  ChannelSideHeadWrapper? headWrapper,
}) {
  final preview = WebPreviewStore.of(workspace);
  final hosts = raftAppHostnames(workspace);
  return DesktopBrowserPanel(
    key: key,
    tabs: preview.browserTabs,
    conversation: conversation,
    raftHosts: hosts,
    showing: showing,
    covering: covering,
    expanded: expanded,
    collapsed: collapsed,
    artifactTitle: artifactTitle,
    onShowArtifact: onShowArtifact,
    onExpand: onExpand,
    headWrapper: headWrapper,
    pageBuilder: (context, tab, visible, events) => DesktopBrowserNativePage(
      tab: tab,
      visible: visible,
      parked: parked,
      events: events,
      raftHosts: hosts,
      session: preview.browserSession,
    ),
  );
}

class ChannelBrowserPlace extends StatelessWidget {
  const ChannelBrowserPlace({
    super.key,
    required this.workspace,
    required this.conversation,
    required this.covering,
    required this.collapsed,
    required this.expanded,
    required this.onExpand,
    required this.headWrapper,
    this.showing = true,
    this.browserKey,
  });

  final WorkspaceController workspace;
  final String conversation;
  final bool covering, collapsed, expanded;
  final bool showing;
  final VoidCallback? onExpand;
  final ChannelSideHeadWrapper headWrapper;
  final GlobalKey? browserKey;

  @override
  Widget build(BuildContext context) {
    final tabs = WebPreviewStore.of(workspace).browserTabs;
    final artifacts = ChannelArtifactPlace.of(workspace);
    return ListenableBuilder(
      listenable: tabs.placement,
      builder: (context, _) => ListenableBuilder(
        listenable: artifacts,
        builder: (context, _) {
          final browser = tabs.forConversation(conversation);
          final artifact = artifacts.forConversation(conversation);
          final browserInFront =
              browser != null &&
              (artifact == null || browser.inFrontOf(artifact.openedAt));
          return Stack(
            fit: StackFit.expand,
            children: [
              if (artifact != null)
                Offstage(
                  offstage: browserInFront,
                  child: ExcludeFocus(
                    excluding: browserInFront,
                    child: TickerMode(
                      enabled: !browserInFront,
                      child: ArtifactWorkspaceViewer(
                        key: ValueKey(artifact.target),
                        session: ArtifactSession.of(workspace),
                        target: artifact.target,
                        seed: artifact.seed,
                        page: covering,
                        inline: true,
                        collapsed: collapsed,
                        onClose: () => artifacts.close(conversation),
                        onShownTitle: (title) => artifacts.rename(
                          conversation,
                          artifact.target,
                          title,
                        ),
                        headerLeading: browser == null
                            ? null
                            : BrowserSwitchChip(
                                key: const ValueKey('switch-to-browser'),
                                glyph: RaftGlyph.globe,
                                label: raftFormat(
                                  context,
                                  browser.tabs.length == 1
                                      ? 'Back to browser, {count} tab'
                                      : 'Back to browser, {count} tabs',
                                  {'count': '${browser.tabs.length}'},
                                ),
                                count: browser.tabs.length,
                                onPressed: () => tabs.raise(conversation),
                              ),
                        wrapHeader: (context, head) => headWrapper(
                          context,
                          ChannelSideSection.artifact,
                          head,
                        ),
                        headerActions: [
                          if (onExpand != null)
                            raftConversationHeaderToggle(
                              key: const ValueKey('inline-artifact-expand'),
                              glyph: expanded
                                  ? RaftGlyph.minimize2
                                  : RaftGlyph.maximize2,
                              label: raftText(
                                context,
                                expanded ? 'Restore' : 'Expand',
                              ),
                              pressed: expanded,
                              onPressed: onExpand,
                              desktopBar: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (browser != null)
                Offstage(
                  offstage: !browserInFront,
                  child: TickerMode(
                    enabled: browserInFront,
                    child: KeyedSubtree(
                      key: const ValueKey('channel-desktop-browser'),
                      child: channelBrowserPanel(
                        key: browserKey,
                        workspace: workspace,
                        conversation: conversation,
                        showing: showing && browserInFront,
                        covering: covering,
                        expanded: expanded,
                        collapsed: collapsed,
                        artifactTitle: artifact?.title,
                        onShowArtifact: artifact == null
                            ? null
                            : () => tabs.park(conversation),
                        onExpand: onExpand,
                        headWrapper: headWrapper,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
