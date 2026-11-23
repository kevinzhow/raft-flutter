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
import 'desktop_browser_windows_page.dart';

class ChannelBrowserPlace extends StatefulWidget {
  const ChannelBrowserPlace({
    super.key,
    required this.workspace,
    required this.conversation,
    required this.covering,
    required this.collapsed,
    required this.expanded,
    required this.onExpand,
    required this.headWrapper,
  });

  final WorkspaceController workspace;
  final String conversation;
  final bool covering, collapsed, expanded;
  final VoidCallback? onExpand;
  final ChannelSideHeadWrapper headWrapper;

  @override
  State<ChannelBrowserPlace> createState() => _ChannelBrowserPlaceState();
}

class _ChannelBrowserPlaceState extends State<ChannelBrowserPlace> {
  final _windows = DesktopBrowserWindowsProfile();

  @override
  void dispose() {
    _windows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final conversation = widget.conversation;
    final tabs = WebPreviewStore.of(workspace).browserTabs;
    final artifacts = ChannelArtifactPlace.of(workspace);
    final raftHosts = raftAppHostnames(workspace);
    return ListenableBuilder(
      listenable: Listenable.merge([tabs.placement, artifacts]),
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
                      page: widget.covering,
                      inline: true,
                      collapsed: widget.collapsed,
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
                      wrapHeader: (context, head) => widget.headWrapper(
                        context,
                        ChannelSideSection.artifact,
                        head,
                      ),
                      headerActions: [
                        if (widget.onExpand != null)
                          raftConversationHeaderToggle(
                            key: const ValueKey('inline-artifact-expand'),
                            glyph: widget.expanded
                                ? RaftGlyph.minimize2
                                : RaftGlyph.maximize2,
                            label: raftText(
                              context,
                              widget.expanded ? 'Restore' : 'Expand',
                            ),
                            pressed: widget.expanded,
                            onPressed: widget.onExpand,
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
                  child: DesktopBrowserPanel(
                    key: const ValueKey('channel-desktop-browser'),
                    tabs: tabs,
                    conversation: conversation,
                    raftHosts: raftHosts,
                    showing: browserInFront,
                    covering: widget.covering,
                    expanded: widget.expanded,
                    collapsed: widget.collapsed,
                    artifactTitle: artifact?.title,
                    onShowArtifact: artifact == null
                        ? null
                        : () => tabs.park(conversation),
                    onExpand: widget.onExpand,
                    headWrapper: widget.headWrapper,
                    pageBuilder: (context, tab, visible, events) =>
                        DesktopBrowserNativePage(
                          tab: tab,
                          visible: visible,
                          events: events,
                          raftHosts: raftHosts,
                          windows: _windows,
                        ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
