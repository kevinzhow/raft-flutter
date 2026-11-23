import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform/app_window.dart';
import 'channel_side_card.dart';
import 'channel_side_layout.dart';
import 'channel_side_web_preview.dart';
import 'desktop_browser_address.dart';
import 'desktop_browser_tab_strip.dart';
import 'desktop_browser_tabs.dart';

typedef DesktopBrowserPageEvents = ({
  ValueChanged<BrowserPageState> state,
  ValueChanged<BrowserHistoryActions?> history,
  ValueChanged<Uri> openExternal,
  VoidCallback closeTab,
  VoidCallback closePanel,
});

typedef DesktopBrowserPageBuilder = Widget Function(
  BuildContext context,
  DesktopBrowserTab tab,
  bool visible,
  DesktopBrowserPageEvents events,
);

void openBrowserExternal(Uri url) =>
    unawaited(launchUrl(url, mode: LaunchMode.externalApplication));

class DesktopBrowserPanel extends StatefulWidget {
  const DesktopBrowserPanel({
    super.key,
    required this.tabs,
    required this.conversation,
    required this.raftHosts,
    required this.pageBuilder,
    this.openExternal = openBrowserExternal,
    this.showing = true,
    this.covering = false,
    this.expanded = false,
    this.collapsed = false,
    this.artifactTitle,
    this.onShowArtifact,
    this.onExpand,
    this.headWrapper,
  });

  final DesktopBrowserTabs tabs;
  final String conversation;
  final Set<String> raftHosts;
  final DesktopBrowserPageBuilder pageBuilder;
  final ValueChanged<Uri> openExternal;
  final bool showing, covering, expanded, collapsed;
  final String? artifactTitle;
  final VoidCallback? onShowArtifact, onExpand;
  final ChannelSideHeadWrapper? headWrapper;

  @override
  State<DesktopBrowserPanel> createState() => _DesktopBrowserPanelState();
}

class _DesktopBrowserPanelState extends State<DesktopBrowserPanel> {
  final _focus = FocusNode();
  final _live = <int>{};
  final _history = <int, BrowserHistoryActions>{};
  ({int tab, String label, double width})? _frontTab;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() => widget.tabs.close(widget.conversation);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.tabs,
    builder: (context, _) {
      final browser = widget.tabs.forConversation(widget.conversation);
      if (browser == null) {
        _live.clear();
        _history.clear();
        return const SizedBox.shrink();
      }
      final active = browser.active;
      if (active.url != null) _live.add(active.id);
      final known = browser.tabs.map((tab) => tab.id).toSet();
      _live.retainAll(known);
      _history.removeWhere((id, _) => !known.contains(id));
      final tokens = RaftTokens.of(context);
      final label = active.url == null
          ? raftText(context, 'Browser')
          : raftFormat(context, 'Web preview: {host}', {
              'host': browserTabLabel(context, active),
            });
      void closeTab() => widget.tabs.closeTab(widget.conversation, active.id);
      final head = _head(browser);
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _close,
          const SingleActivator(
            LogicalKeyboardKey.keyW,
            meta: true,
            includeRepeats: false,
          ): closeTab,
          const SingleActivator(
            LogicalKeyboardKey.keyW,
            control: true,
            includeRepeats: false,
          ): closeTab,
        },
        child: Actions(
          actions: {
            CloseWindowContentIntent: CallbackAction<CloseWindowContentIntent>(
              onInvoke: (_) => closeTab(),
            ),
          },
          child: Focus(
            focusNode: _focus,
            autofocus: widget.showing && active.url != null,
            descendantsAreFocusable: widget.showing,
            child: Semantics(
              container: true,
              label: label,
              explicitChildNodes: true,
              child: ColoredBox(
                key: const ValueKey('desktop-browser'),
                color: tokens.colors['layer-card'] ?? tokens.panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    widget.headWrapper?.call(
                          context,
                          ChannelSideSection.artifact,
                          head,
                        ) ??
                        head,
                    if (!widget.collapsed)
                      DesktopBrowserAddress(
                        key: ValueKey(active.id),
                        tab: active,
                        raftHosts: widget.raftHosts,
                        history: _history[active.id],
                        navigate: (url) => widget.tabs.navigate(
                          widget.conversation,
                          active.id,
                          url,
                        ),
                        openExternal: widget.openExternal,
                      ),
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final tab in browser.tabs)
                            if (_live.contains(tab.id))
                              _page(context, tab, tab.id == active.id),
                          if (active.url == null && !widget.collapsed)
                            RaftEmptyState(
                              key: const ValueKey('browser-empty-tab'),
                              title: raftText(context, 'New tab'),
                              detail: raftText(
                                context,
                                'Type an address above to open a page.',
                              ),
                              glyph: RaftGlyph.globe,
                              titleHeading: true,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _page(BuildContext context, DesktopBrowserTab tab, bool active) {
    final visible = widget.showing && active && !widget.collapsed;
    return Offstage(
      key: ValueKey(tab.id),
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: widget.pageBuilder(context, tab, visible, (
          state: (state) {
            if (mounted) widget.tabs.report(widget.conversation, tab.id, state);
          },
          history: (actions) {
            if (!mounted) return;
            setState(() {
              if (actions == null) {
                _history.remove(tab.id);
              } else {
                _history[tab.id] = actions;
              }
            });
          },
          openExternal: (url) {
            final allowed = webPreviewTarget(url.toString(), widget.raftHosts);
            if (allowed != null) widget.openExternal(allowed);
          },
          closeTab: () => widget.tabs.closeTab(widget.conversation, tab.id),
          closePanel: _close,
        )),
      ),
    );
  }

  Widget _head(DesktopBrowser browser) => LayoutBuilder(
    builder: (context, box) {
      final close = raftText(context, 'Close');
      final swap = widget.onShowArtifact;
      final label = browserTabLabel(context, browser.active);
      final measured = _frontTab;
      final frontWidth =
          measured?.tab == browser.activeId && measured?.label == label
          ? measured?.width
          : null;
      final fit = fitBrowserHeader(
        width: box.maxWidth,
        activeWidth: frontWidth ?? 120,
        count: browser.tabs.length,
        controls: 1 + (widget.onExpand == null ? 0 : 1),
        artifact: swap != null,
      );
      final tokens = RaftTokens.of(context);
      final tiny = box.maxWidth < 200;
      final actionWidth = tiny
          ? RaftDesktopMetrics.controlEmbeddedSize
          : RaftDesktopMetrics.barButtonSize;
      return RaftPanelHeaderBar(
        key: const ValueKey('browser-header'),
        title: '',
        titleSlot: DesktopBrowserTabStrip(
          browser: browser,
          shown: fit.visible,
          frontWidth: frontWidth,
          onFrontWidth: (width) {
            final next = (tab: browser.activeId, label: label, width: width);
            if (mounted && next != _frontTab) setState(() => _frontTab = next);
          },
          onNew: () => widget.tabs.newTab(widget.conversation),
          onClose: (id) => widget.tabs.closeTab(widget.conversation, id),
          onSelect: (id) => widget.tabs.activate(widget.conversation, id),
        ),
        desktopBar: !tiny,
        itemGap: tiny ? 0 : RaftSpace.x1,
        contentInsets: tiny
            ? const EdgeInsets.symmetric(horizontal: RaftSpace.half)
            : null,
        leftPadding: 13,
        background: tokens.colors['layer-canvas'],
        bottomRule: true,
        bottomBorder: RaftSidePanelFrame.headerRule(tokens),
        onBack: widget.covering ? _close : null,
        backKey: const ValueKey('browser-back'),
        backTooltip: close,
        leading: swap == null
            ? null
            : BrowserSwitchChip(
                key: const ValueKey('switch-to-artifact'),
                glyph: RaftGlyph.artifact,
                label: widget.artifactTitle == null
                    ? raftText(context, 'Back to Artifact')
                    : raftFormat(context, 'Back to {title}', {
                        'title': widget.artifactTitle,
                      }),
                onPressed: swap,
                text: fit.chipTitle > 0 ? widget.artifactTitle : null,
                maxTextWidth: fit.chipTitle,
                compact: tiny,
              ),
        actions: [
          if (widget.onExpand != null)
            SizedBox(
              width: actionWidth,
              child: raftConversationHeaderToggle(
                key: const ValueKey('browser-expand'),
                glyph: widget.expanded
                    ? RaftGlyph.minimize2
                    : RaftGlyph.maximize2,
                label: raftText(
                  context,
                  widget.expanded ? 'Restore' : 'Expand',
                ),
                pressed: widget.expanded,
                onPressed: widget.onExpand,
                desktopBar: !tiny,
                size: tiny ? RaftButtonSize.iconXs : RaftButtonSize.iconSm,
              ),
            ),
          if (!widget.covering)
            SizedBox(
              width: actionWidth,
              child: RaftPanelAction(
                key: const ValueKey('browser-close'),
                glyph: RaftGlyph.x,
                tooltip: close,
                onPressed: _close,
                desktopBar: !tiny,
                ghostSize: tiny ? RaftButtonSize.iconXs : null,
              ),
            ),
        ],
      );
    },
  );
}

class BrowserSwitchChip extends StatelessWidget {
  const BrowserSwitchChip({
    super.key,
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.text,
    this.maxTextWidth = 132,
    this.count,
    this.compact = false,
  });

  final RaftGlyph glyph;
  final String label;
  final VoidCallback onPressed;
  final String? text;
  final double maxTextWidth;
  final int? count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: compact ? RaftSpace.half : RaftSpace.x2,
      children: [
        if (text == null && count == null)
          SizedBox(
            width: compact
                ? RaftDesktopMetrics.controlEmbeddedSize
                : RaftDesktopMetrics.barButtonSize,
            child: RaftPanelAction(
              glyph: glyph,
              tooltip: label,
              desktopBar: !compact,
              ghostSize: compact ? RaftButtonSize.iconXs : null,
              onPressed: onPressed,
            ),
          )
        else
          RaftButton(
            label: '',
            semanticLabel: label,
            tooltip: label,
            uiVariant: RaftButtonVariant.ghost,
            uiSize: RaftButtonSize.sm,
            onPressed: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: RaftSpace.x1_5,
              children: [
                RaftIcon(glyph, size: 16, color: tokens.ui.foregroundMuted),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTextWidth),
                  child: Text(
                    text ?? '$count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.scale(
                      tokens.typeSlot(count == null ? 'callout' : 'mono-meta'),
                      color: tokens.ui.foregroundMuted,
                      weight: count == null ? FontWeight.w600 : FontWeight.w400,
                      mono: count != null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: RaftSpace.hairline,
          height: RaftSpace.x4,
          child: ColoredBox(color: tokens.ui.lineHairline),
        ),
      ],
    );
  }
}
