// The Public server page of the Web client (raft-source 26f77ef,
// packages/web/src/pages/PublicServerPage.tsx): the anonymous `/s/<slug>`
// preview (and the signed-in nonmember variant) with the public channel
// sidebar, the bottom sign-in / join banner, the floating notices and the
// shared community agreement dialog (community_agreement_dialog.dart). The rail, header and message rows reuse the
// shared raft_ui components; the app owns the data and the join flow.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'banner.dart';
import 'channel_header.dart' show raftCollapseWhitespace;
import 'components.dart' show RaftConversationNavKind, RaftNavItem;
import 'computer_surfaces.dart' show RaftPanelHeaderIconTile;
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'mobile_navigation.dart' show RaftMobileRootHeader;
import 'page_tokens.dart';
import 'panel_layout.dart' show RaftCssText, RaftPanelHeaderBar;
import 'sidebar_frame.dart' show RaftMountedSidebarFrame;
import 'recipe_surface.dart';
import 'recipes/banner.g.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'tooltip.dart' show RaftTooltip;
import 'adaptive_workspace.dart' show RaftRailDestination, RaftWorkspaceRail;
import 'workspace_shell.dart'
    show
        RaftChatSidebarHeading,
        RaftWorkspaceRailAction,
        RaftWorkspaceRailFooter;
import 'status_bar.dart';
import 'theme.dart';
import 'viewport_breakpoints.dart';

/// `h-panel-header`: the shell's `--shell-header-height` (AppShellRoot sets it
/// since Web v1.21.12): 56px Elegant, 62px Brutal, 48px on short viewports.
double _publicHeaderHeight(BuildContext context) =>
    RaftLayoutMetrics.shellHeaderHeight(
      RaftTokens.of(context),
      MediaQuery.sizeOf(context).height,
    );

/// `PublicServerPage` loading branch: `min-h-screen ... bg-layer-canvas-muted
/// theme-brutal:bg-brutal-cream` with a large centred Spinner (Web v1.21.12;
/// it was the bold word "Loading" before). [label] is the Spinner's name.
class RaftPublicServerLoading extends StatelessWidget {
  const RaftPublicServerLoading({super.key, this.label = 'Loading server…'});
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.colors['layer-canvas-muted']!,
      child: Center(
        child: Semantics(
          label: raftText(context, label),
          liveRegion: true,
          child: const RaftSpinner(size: 24),
        ),
      ),
    );
  }
}

/// A public channel in the sidebar.
@immutable
class RaftPublicServerChannel {
  const RaftPublicServerChannel({required this.id, required this.name});
  final String id, name;
}

/// Frame shared by the two side columns of the public page (channels and
/// settings): `PublicServerSidebarFrame`, a rui SidebarRoot (`border-r
/// border-line-muted bg-layer-canvas-muted`, Brutal `border-r-2 border-black
/// bg-brutal-cream`), an `h-panel-header` title row and a scroll surface
/// (`px-2 py-3`).
class _PublicSidebarFrame extends StatelessWidget {
  const _PublicSidebarFrame({
    required this.frameKey,
    required this.title,
    required this.width,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
  });
  final Key frameKey;
  final String title;
  final double width;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // Web v1.21.23 builds the frame from the same rui SidebarRoot / SidebarHeader
    // as the signed-in Sidebar; the Raft look shares that frame, the pre-theme
    // looks keep their own column (publicServer.sidebar).
    if (t.option('publicServer.sidebar', or: 'shared') == 'shared') {
      final mobile =
          raftBreakpointWidth(context) < RaftLayoutMetrics.desktopBreakpoint;
      return SizedBox(
        key: frameKey,
        width: width,
        child: RaftMountedSidebarFrame(
          trailingEdge: !mobile || width.isFinite,
          header: mobile
              ? RaftMobileRootHeader(title: title)
              : RaftChatSidebarHeading(label: title),
          body: SingleChildScrollView(padding: padding, child: child),
        ),
      );
    }
    final text = RaftSettingsText(t);
    final fill = t.colors['layer-canvas-muted']!;
    final rule = BorderSide(color: t.colors['line-muted']!, width: 1);
    return RaftStatusBarSource(
      color: fill,
      child: Container(
        key: frameKey,
        width: width,
        decoration: BoxDecoration(
          color: fill,
          border: Border(right: rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: _publicHeaderHeight(context),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5),
              decoration: BoxDecoration(border: Border(bottom: rule)),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // `font-heading text-lg in-data-[theme=elegant]:text-[17px]`.
                  style: RaftTypography.heading(
                    t,
                    size: 17,
                    line: 25.5,
                    weight: FontWeight.w700,
                    color: text.strong,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// The `nav` column of the channel list: `w-36 sm:w-[240px]`, built from the
/// same rows as the signed-in Sidebar (accent SidebarItem, the channel icon at
/// 18px) so the two read as one surface in every theme.
class RaftPublicChannelSidebar extends StatelessWidget {
  const RaftPublicChannelSidebar({
    super.key,
    required this.serverName,
    required this.channels,
    required this.selectedId,
    required this.onSelect,
    this.width,
    this.label = 'Public channels',
    this.fill = false,
  });
  final String serverName, label;
  final List<RaftPublicServerChannel> channels;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Below sm the channel list is the page, one column at a time (`col-span-full
  /// w-full`): it fills the width instead of the 144px column.
  final bool fill;

  /// Dragged width (sm and up); null keeps the 240 / 144 default.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final sm = raftBreakpointWidth(context) >= 640;
    final shared = t.option('publicServer.sidebar', or: 'shared') == 'shared';
    return Semantics(
      container: true,
      label: raftText(context, label),
      child: _PublicSidebarFrame(
        frameKey: const ValueKey('public-server-channel-sidebar'),
        title: serverName,
        width: fill ? double.infinity : (sm ? (width ?? 240) : 144),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `mb-1 flex h-6 items-center px-2`; below sm the column is too
            // narrow for one line at the signed-in metrics, so it wraps
            // (`max-sm:h-auto max-sm:min-h-6 text-[11px] tracking-wider`).
            // v1.21.23: SectionEyebrow as written, sentence case 13/18 bold.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: shared
                      ? Text(
                          raftText(context, label),
                          maxLines: sm ? 1 : null,
                          overflow: sm
                              ? TextOverflow.ellipsis
                              : TextOverflow.clip,
                          style: t.sectionEyebrow(),
                        )
                      : Text(
                          raftText(context, label).toUpperCase(),
                          maxLines: sm ? 1 : null,
                          overflow: sm
                              ? TextOverflow.ellipsis
                              : TextOverflow.clip,
                          style: RaftTypography.inherited(
                            t,
                            size: sm ? 12 : 11,
                            line: sm ? 16 : 16.5,
                            weight: FontWeight.w700,
                            color: text.strong,
                          ).copyWith(letterSpacing: (sm ? 12 * .1 : 11 * .05)),
                        ),
                ),
              ),
            ),
            for (final channel in channels)
              RaftNavItem(
                key: ValueKey('public-channel-${channel.id}'),
                label: channel.name,
                glyph: RaftGlyph.hash,
                conversationKind: RaftConversationNavKind.channel,
                selected: channel.id == selectedId,
                onTap: () => onSelect(channel.id),
              ),
          ],
        ),
      ),
    );
  }
}

/// The `bottomBanner`: an info Banner pinned under every column
/// (`z-10 w-full shrink-0 !items-center rounded-none border-x-0 border-b-0
/// !px-5`) with the copy and the action buttons.
class RaftPublicBottomBanner extends StatelessWidget {
  const RaftPublicBottomBanner({
    super.key,
    required this.message,
    required this.actions,
  });
  final String message;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final recipe = RaftBannerRecipe.resolve(
      theme: t.recipeTheme,
      status: RaftBannerRecipeStatus.info,
      size: RaftBannerRecipeSize.sm,
      states: t.recipeStates(
        extra: {
          'group/banner:data-size=sm',
          'group/banner:data-status=info',
          'has:>data-slot=banner-action',
        },
      ),
      tokens: tokens,
    );
    final base = recipe.root.text(
      tokens,
      base: DefaultTextStyle.of(context).style,
    );
    // `text-callout font-bold max-sm:text-footnote`.
    final narrow = raftBreakpointWidth(context) < 640;
    final copy = Text(
      raftText(context, message),
      style: recipe.description
          .text(tokens, base: base)
          .copyWith(
            fontSize: narrow ? 12 : 14,
            fontWeight: FontWeight.w700,
            color: t.colors['foreground-banner-body'],
          ),
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: RaftSpace.x2,
      children: actions,
    );
    return Semantics(
      key: const ValueKey('public-server-bottom-action'),
      container: true,
      liveRegion: true,
      child: RaftRecipeBox(
        style: recipe.root,
        tokens: tokens,
        width: double.infinity,
        applyText: false,
        // `!px-5 max-sm:!px-3 max-sm:!py-2`.
        padding: EdgeInsets.symmetric(
          horizontal: narrow ? RaftSpace.x3 : RaftSpace.x5,
          vertical: narrow ? RaftSpace.x2 : recipe.root.padding.top,
        ),
        decorationOverride: (d) => d.copyWith(
          borderRadius: BorderRadius.zero,
          border: d.border is Border
              ? Border(top: (d.border as Border).top)
              : d.border,
          boxShadow: const [],
        ),
        // On phones the copy and the actions stay on one row (small text and
        // small buttons): stacked, the banner was ~105px tall on a 390px phone.
        // From sm up v1.21.23 stacks them (the action slot is `mt-2` under the
        // description); the pre-theme looks kept the row (publicServer.banner).
        child:
            !narrow &&
                t.option('publicServer.banner', or: 'stacked') == 'stacked'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  copy,
                  const SizedBox(height: RaftSpace.x2),
                  Align(alignment: Alignment.centerLeft, child: buttons),
                ],
              )
            : LayoutBuilder(
                builder: (context, box) => Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: RaftSpace.x2),
                    // The copy keeps at least 120px beside the actions; wider
                    // actions (large text, long labels) shrink to fit instead
                    // of squeezing the sentence into a tall one-word column.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: box.maxWidth.isFinite
                            ? (box.maxWidth - RaftSpace.x2 - 120).clamp(0, 1e9)
                            : double.infinity,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: buttons,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Sign in / Create account / Join as Guest: a `Button size="sm"` with a
/// leading icon (`<LogIn className="size-4" />`).
class RaftPublicActionButton extends StatelessWidget {
  const RaftPublicActionButton({
    super.key,
    required this.label,
    required this.glyph,
    required this.accent,
    required this.onPressed,
  });
  final String label;
  final RaftGlyph glyph;
  final bool accent;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftSettingsRecipeButton(
    label: label,
    glyph: glyph,
    glyphSize: 16,
    variant: accent
        ? RaftButtonRecipeVariant.accent
        : RaftButtonRecipeVariant.outline,
    size: RaftButtonRecipeSize.sm,
    onPressed: onPressed,
  );
}

/// A floating `Banner` (`fixed left-1/2 ... -translate-x-1/2`): the server
/// switcher notice at the top, the join error at the bottom.
class RaftPublicFloatingBanner extends StatelessWidget {
  const RaftPublicFloatingBanner({
    super.key,
    required this.message,
    required this.top,
    this.action,
    this.warning = false,
  });
  final String message;
  final bool top, warning;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: top ? RaftSpace.x4 : null,
    bottom: top ? null : RaftSpace.x4,
    child: Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: RaftBanner(
          status: warning
              ? RaftBannerRecipeStatus.warning
              : RaftBannerRecipeStatus.info,
          size: RaftBannerRecipeSize.sm,
          description: message,
          descriptionWeight: warning ? FontWeight.w700 : null,
          action: action,
        ),
      ),
    ),
  );
}

/// A centred `text-sm text-foreground-muted` message (the thread's "No replies
/// yet"). With a [glyph] it is the EmptyState of the public page: a 36px icon
/// over the title, centred in the column (`flex h-full flex-col items-center
/// justify-center`).
class RaftPublicEmptyMessage extends StatelessWidget {
  const RaftPublicEmptyMessage(
    this.message, {
    super.key,
    this.hint = true,
    this.glyph,
    this.icon,
  });
  final String message;

  /// A custom icon (the thread glyph); wins over [glyph].
  final Widget? icon;

  /// `text-foreground-hint` (empty messages) vs `text-foreground-muted`.
  final bool hint;
  final RaftGlyph? glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = glyph != null || icon != null
        ? t.muted
        : hint
        ? (t.colors['foreground-hint'] ?? t.muted)
        : t.muted;
    final text = RaftCssText(
      raftText(context, message),
      textAlign: TextAlign.center,
      style: RaftTypography.inherited(
        t,
        size: 14,
        line: 20,
        weight: glyph != null || icon != null
            ? FontWeight.w500
            : FontWeight.w400,
        color: color,
      ),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RaftSpace.x6),
        child: glyph == null
            ? text
            : Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  RaftIcon(glyph!, size: 36, color: color),
                  text,
                ],
              ),
      ),
    );
  }
}

/// Loads the older page when the scroll view reaches its start (Web
/// `MessageTimeline`'s top sentinel; the public page has had no "Load older
/// messages" button since v1.21.12). It also fires when the content is shorter
/// than the viewport, so a sparse first page keeps loading until it fills.
/// [reverse] names a reversed scroll view, whose start is its far end.
class RaftPublicAutoLoadOlder extends StatefulWidget {
  const RaftPublicAutoLoadOlder({
    super.key,
    required this.enabled,
    required this.onLoadOlder,
    required this.controller,
    required this.child,
    this.reverse = false,
  });
  final bool enabled, reverse;
  final VoidCallback onLoadOlder;

  /// The scroll view's controller, read to see whether the content still
  /// leaves the start in view after a page arrived.
  final ScrollController controller;
  final Widget child;

  /// The top sentinel's root margin: start loading a little before the edge.
  static const double margin = 120;

  @override
  State<RaftPublicAutoLoadOlder> createState() =>
      _RaftPublicAutoLoadOlderState();
}

class _RaftPublicAutoLoadOlderState extends State<RaftPublicAutoLoadOlder> {
  bool _atStart(ScrollMetrics m) =>
      (widget.reverse ? m.extentAfter : m.extentBefore) <=
      RaftPublicAutoLoadOlder.margin;

  void _ask() {
    if (mounted && widget.enabled) widget.onLoadOlder();
  }

  /// A page that does not fill the panel leaves the start in view without any
  /// scrolling: look again after every layout while loading is possible.
  void _recheck() {
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled || !widget.controller.hasClients) return;
      if (_atStart(widget.controller.position)) _ask();
    });
  }

  @override
  void initState() {
    super.initState();
    _recheck();
  }

  @override
  void didUpdateWidget(RaftPublicAutoLoadOlder old) {
    super.didUpdateWidget(old);
    _recheck();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth == 0 && _atStart(n.metrics)) _ask();
          return false;
        },
        child: widget.child,
      );
}

/// `<div className="flex justify-center p-6"><Spinner size="md" /></div>`:
/// the public timeline while its first page loads.
class RaftPublicLoadingSpinner extends StatelessWidget {
  const RaftPublicLoadingSpinner({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: const EdgeInsets.all(RaftSpace.x6),
      child: Semantics(
        label: raftText(context, label),
        liveRegion: true,
        child: const RaftSpinner(size: 20),
      ),
    ),
  );
}

/// `border-r/border-l border-line-hairline` (Brutal `border-2 border-black`).
BorderSide _publicRule(RaftTokens t) => BorderSide(
  color: (t.colors['line-hairline'] ?? t.colors['line-muted']!),
  width: 1,
);

/// The channel timeline's panel (ConversationPanelRoot): `bg-layer-canvas`.
class RaftPublicConversationSurface extends StatelessWidget {
  const RaftPublicConversationSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.colors['layer-conversation-content']!,
      child: child,
    );
  }
}

/// The page canvas: `bg-layer-canvas theme-brutal:bg-white`.
class RaftPublicSurface extends StatelessWidget {
  const RaftPublicSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(color: t.colors['layer-canvas']!, child: child);
  }
}

/// The settings surface sidebar (`aside`): same frame as the channel list.
class RaftPublicSettingsSidebar extends StatelessWidget {
  const RaftPublicSettingsSidebar({
    super.key,
    required this.title,
    required this.child,
    this.width,
  });
  final String title;
  final Widget child;

  /// Dragged width (sm and up); null keeps the 240 / 144 default.
  final double? width;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final sm = raftBreakpointWidth(context) >= 640;
    return _PublicSidebarFrame(
      frameKey: const ValueKey('public-server-settings-sidebar'),
      title: title,
      width: sm ? (width ?? 240) : 144,
      padding: RaftSettingsSidebarList.inset(t),
      child: child,
    );
  }
}

/// The side column of the thread panel at sm and up (`sm:w-[380px]
/// sm:border-l`).
class RaftPublicThreadColumn extends StatelessWidget {
  const RaftPublicThreadColumn({super.key, required this.child, this.width});
  final Widget child;

  /// Dragged width; null keeps the 380 default.
  final double? width;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: width ?? 380,
      decoration: BoxDecoration(
        color: t.colors['layer-canvas'],
        border: Border(left: _publicRule(t)),
      ),
      child: child,
    );
  }
}

/// The read-only ThreadPanel: header ("Thread" + the muted channel), the parent
/// message, the replies and the loading / error / empty states.
class RaftPublicThreadPanel extends StatelessWidget {
  const RaftPublicThreadPanel({
    super.key,
    required this.title,
    required this.channelContext,
    required this.closeLabel,
    required this.onClose,
    required this.showClose,
    required this.parent,
    required this.replies,
    required this.loading,
    required this.emptyTitle,
    required this.scrollController,
    this.error,
    this.onLoadOlder,
  });
  final String title, channelContext, closeLabel, emptyTitle;
  final VoidCallback onClose;
  final bool showClose, loading;

  /// The replies' scroll controller (older replies load at the top).
  final ScrollController scrollController;
  final Widget parent;
  final List<Widget> replies;
  final String? error;
  final VoidCallback? onLoadOlder;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final narrow = raftBreakpointWidth(context) < 1024;
    final parentBox = Container(
      key: const ValueKey('thread-panel-parent'),
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x3,
        vertical: RaftSpace.x3,
      ),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(bottom: BorderSide(color: text.edge, width: 1)),
      ),
      child: parent,
    );
    final Widget body;
    if (error != null) {
      body = ListView(
        children: [
          parentBox,
          Padding(
            padding: const EdgeInsets.all(RaftSpace.x3),
            child: RaftBanner(
              status: RaftBannerRecipeStatus.warning,
              description: error!,
            ),
          ),
        ],
      );
    } else if (replies.isEmpty && !loading) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          parentBox,
          Expanded(
            child: RaftPublicEmptyMessage(
              emptyTitle,
              hint: false,
              icon: RaftThreadIcon(size: 36, color: t.muted),
            ),
          ),
        ],
      );
    } else {
      body = RaftPublicAutoLoadOlder(
        enabled: onLoadOlder != null && !loading,
        onLoadOlder: () => onLoadOlder?.call(),
        controller: scrollController,
        child: ListView(
          controller: scrollController,
          children: [
            parentBox,
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x3),
                child: RaftPublicMessageRow(child: reply),
              ),
          ],
        ),
      );
    }
    return Container(
      key: const ValueKey('public-server-thread-panel'),
      color: t.colors['layer-canvas'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Web ReadOnlyThreadPanel: a PanelHeader whose title is "Thread"
          // plus the muted channel (`ml-1 font-normal text-foreground-placeholder`,
          // 15px in Elegant) and a plain ghost close button.
          _publicHeaderStrip(
            t,
            RaftPanelHeaderBar(
              title: '',
              onBack: narrow ? onClose : null,
              backKey: const ValueKey('thread-mobile-back'),
              titleSlot: Text.rich(
                TextSpan(
                  text: raftText(context, title),
                  children: [
                    TextSpan(
                      // The gap is `ml-1`, not a leading space in the catalog text.
                      text: ' $channelContext',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                        color: (t.colors['foreground-placeholder'] ?? t.muted),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RaftTypography.inherited(
                  t,
                  size: 16,
                  line: 24,
                  weight: FontWeight.w700,
                  color: text.strong,
                ),
              ),
              actions: [
                if (showClose)
                  RaftTooltip(
                    message: raftText(context, closeLabel),
                    child: RaftSettingsRecipeButton(
                      key: const ValueKey('thread-close'),
                      label: '',
                      semanticLabel: raftText(context, closeLabel),
                      glyph: RaftGlyph.x,
                      glyphSize: 14,
                      variant: RaftButtonRecipeVariant.ghost,
                      size: RaftButtonRecipeSize.iconSm,
                      onPressed: onClose,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// The page frame: rail (md and up), the columns, the thread overlay below sm,
/// the bottom banner and the floating overlays.
class RaftPublicServerLayout extends StatelessWidget {
  const RaftPublicServerLayout({
    super.key,
    required this.columns,
    this.banner,
    this.rail,
    this.threadOverlay,
    this.overlays = const [],
  });
  final Widget columns;

  /// A banner under every column; null when [columns] places it itself (since
  /// Web v1.21.23 it sits under the conversation only, so the channel column
  /// runs the full height beside it).
  final Widget? banner;
  final Widget? rail, threadOverlay;
  final List<Widget> overlays;
  @override
  Widget build(BuildContext context) {
    // The page sits outside any Scaffold: a Material layer supplies the text
    // defaults (no debug underline) and ink for the controls.
    final t = RaftTokens.of(context);
    return Material(
      type: MaterialType.transparency,
      // Edge to edge: the status bar shows the header under it (published by
      // RaftPanelHeaderBar), else the page surface.
      child: RaftStatusBarHost(
        fallback: t.colors['layer-canvas']!,
        expand: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: RaftPublicSurface(
                // Only the top inset: the banner and rail handle the sides/bottom.
                child: SafeArea(
                  left: false,
                  right: false,
                  bottom: false,
                  child: Row(
                    key: const ValueKey('public-server-page'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?rail,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: columns),
                                  if (threadOverlay != null)
                                    Positioned.fill(child: threadOverlay!),
                                ],
                              ),
                            ),
                            ?banner,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...overlays,
          ],
        ),
      ),
    );
  }
}

/// The channel header of the public page: PanelHeader with the Hash icon,
/// the channel name and its description, and no actions (read only).
class RaftPublicChannelHeader extends StatelessWidget {
  const RaftPublicChannelHeader({
    super.key,
    required this.name,
    this.description = '',
    this.onBack,
    this.backLabel = 'Back to channels',
  });
  final String name, description;

  /// Phones show one column at a time: Back returns to the channel list
  /// (`onMobileBack` + `backButtonVisibility="always"`).
  final VoidCallback? onBack;
  final String backLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final meta = raftCollapseWhitespace(description);
    final bar = RaftPanelHeaderBar(
      title: name,
      subtitle: meta.isEmpty ? null : meta,
      onBack: onBack,
      backKey: onBack == null
          ? null
          : const ValueKey('public-server-phone-back'),
      backTooltip: raftText(context, backLabel),
      // AppPanelHeader `icon` with the default `bg-primary`; v1.21.23 passes
      // `iconTone="location"`: the yellow "you are here" sticker.
      iconSlot: t.option('publicServer.channelTile', or: 'sticker') == 'sticker'
          ? const _LocationTile(glyph: RaftGlyph.hash)
          : RaftPanelHeaderIconTile(
              glyph: RaftGlyph.hash,
              background: t.colors['fill-muted']!,
              borderless: !false,
            ),
    );
    return _publicHeaderStrip(t, bar);
  }
}

/// raft-ui `PanelHeaderIcon` (location tone): `size-[27px] rounded-sticker
/// border-[1.5px] border-sticker-ink bg-brand text-sticker-ink
/// ring-[1.5px] ring-sticker-edge`, the glyph at 14px with a 2px stroke.
class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.glyph});
  final RaftGlyph glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = t.colors['sticker-ink']!;
    return Container(
      width: 27,
      height: 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.colors['brand-400'],
        borderRadius: BorderRadius.circular(
          t.size('radius.sticker', fallback: 4),
        ),
        border: Border.all(color: ink, width: 1.5),
        boxShadow: [
          BoxShadow(color: t.colors['sticker-edge']!, spreadRadius: 1.5),
        ],
      ),
      child: RaftIcon(glyph, size: 14, color: ink, strokeWidth: 2),
    );
  }
}

/// An attached panel header (ConversationPanelRoot `edge="attached"`, the
/// read-only thread's `in-data-[theme=elegant]:bg-layer-canvas-muted`): on
/// Elegant a `layer-canvas-muted` strip with a `border-line-muted` rule under
/// it; Brutal's own rule comes from the header recipe.
Widget _publicHeaderStrip(RaftTokens t, Widget bar) {
  final fill = t.colors['layer-canvas-muted']!;
  return RaftStatusBarSource(
    color: fill,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border(bottom: BorderSide(color: t.colors['line-muted']!)),
      ),
      child: bar,
    ),
  );
}

/// CSS margin collapsing between sibling message rows: the row's `mb-1` (4px)
/// merges into the next row's `mt-1.5` (6px) instead of adding to it, so the
/// row reports [amount] less height while painting in full.
class RaftCollapsedBottomMargin extends SingleChildRenderObjectWidget {
  const RaftCollapsedBottomMargin({
    super.key,
    required this.amount,
    required super.child,
  });
  final double amount;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCollapsedBottomMargin(amount);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCollapsedBottomMargin renderObject,
  ) => renderObject.amount = amount;
}

class _RenderCollapsedBottomMargin extends RenderShiftedBox {
  _RenderCollapsedBottomMargin(this._amount) : super(null);
  double _amount;
  set amount(double value) {
    if (value == _amount) return;
    _amount = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(
      Size(
        child.size.width,
        (child.size.height - _amount).clamp(0, double.infinity),
      ),
    );
    (child.parentData! as BoxParentData).offset = Offset.zero;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      ((child?.getMinIntrinsicHeight(width) ?? 0) - _amount).clamp(
        0,
        double.infinity,
      );
  @override
  double computeMaxIntrinsicHeight(double width) =>
      ((child?.getMaxIntrinsicHeight(width) ?? 0) - _amount).clamp(
        0,
        double.infinity,
      );
}

/// A message row of the public timeline: Brutal rows carry `mb-1` that
/// collapses into the next row's `mt-1.5`.
class RaftPublicMessageRow extends StatelessWidget {
  const RaftPublicMessageRow({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      RaftCollapsedBottomMargin(amount: 0, child: child);
}

/// The public server rail (`data-public-server-rail`): the signed-in app rail
/// (AppRailRoot / Header / Nav / Footer) with the server switcher, the Chat tab,
/// an optional Help button and Settings, on every theme. Web v1.21.12 dropped
/// the hand-built soft-signal strip and the black logo block this rail used to
/// draw.
class RaftPublicRail extends StatelessWidget {
  const RaftPublicRail({
    super.key,
    required this.header,
    required this.chatLabel,
    required this.settingsLabel,
    required this.chatSelected,
    required this.settingsSelected,
    required this.onChat,
    required this.onSettings,
    this.help,
  });
  final Widget header;
  final String chatLabel, settingsLabel;
  final bool chatSelected, settingsSelected;
  final VoidCallback onChat, onSettings;
  final Widget? help;
  @override
  Widget build(BuildContext context) => RaftWorkspaceRail(
    key: const ValueKey('public-server-rail'),
    destinations: [
      RaftRailDestination(
        id: 'chat',
        label: chatLabel,
        glyph: RaftGlyph.messageSquare,
      ),
    ],
    selected: chatSelected ? 'chat' : '',
    onSelected: (_) => onChat(),
    workspaceName: '',
    workspaceTooltip: '',
    onWorkspace: () {},
    workspaceHeader: header,
    footer: RaftWorkspaceRailFooter(
      children: [
        ?help,
        RaftWorkspaceRailAction(
          key: const ValueKey('public-rail-settings'),
          label: settingsLabel,
          glyph: RaftGlyph.settings,
          selected: settingsSelected,
          onPressed: onSettings,
        ),
      ],
    ),
  );
}
