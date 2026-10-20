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
import 'computer_surfaces.dart' show RaftPanelHeaderIconTile;
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart'
    show RaftCssText, RaftPanelHeaderBar, RaftPanelIconButton;
import 'recipe_surface.dart';
import 'recipes/banner.g.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'tokens/shadows.g.dart' show RaftProductShadows;
import 'workspace_shell.dart' show RaftWorkspaceRailAction;
import 'status_bar.dart';
import 'theme.dart';
import 'viewport_breakpoints.dart';
import 'sized_image.dart';

/// `h-panel-header`: 62px on every theme (48px on short viewports).
double _publicHeaderHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height <= 600 ? 48 : 62;

/// `PublicServerPage` loading branch: `min-h-screen ... bg-layer-canvas-muted
/// theme-brutal:bg-brutal-cream font-display font-bold`, the label centred.
class RaftPublicServerLoading extends StatelessWidget {
  const RaftPublicServerLoading({super.key, this.label = 'Loading…'});
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.brutal ? t.product.brutalCream : t.colors['layer-canvas-muted']!,
      child: Center(
        child: Text(
          raftText(context, label),
          style: RaftTypography.inherited(
            t,
            size: 16,
            line: 24,
            weight: FontWeight.w700,
            color: RaftSettingsText(t).strong,
          ),
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

/// The `nav` column: `w-36 sm:w-[240px] border-r bg-layer-inset` (Brutal
/// `border-r-2 border-black bg-brutal-cream`) with the server name header and
/// the "Public channels" list.
class RaftPublicChannelSidebar extends StatelessWidget {
  const RaftPublicChannelSidebar({
    super.key,
    required this.serverName,
    required this.channels,
    required this.selectedId,
    required this.onSelect,
    this.width,
    this.label = 'Public channels',
  });
  final String serverName, label;
  final List<RaftPublicServerChannel> channels;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Dragged width (sm and up); null keeps the 240 / 144 default.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final sm = raftBreakpointWidth(context) >= 640;
    final headerHeight = _publicHeaderHeight(context);
    final edge = t.brutal ? Colors.black : t.colors['line-hairline'];
    final rule = BorderSide(color: edge ?? text.edge, width: t.brutal ? 2 : 1);
    return Semantics(
      container: true,
      label: raftText(context, label),
      child: RaftStatusBarSource(
        color: t.brutal ? t.product.brutalCream : t.colors['layer-inset']!,
        child: Container(
          key: const ValueKey('public-server-channel-sidebar'),
          width: sm ? (width ?? 240) : 144,
          decoration: BoxDecoration(
            color: t.brutal ? t.product.brutalCream : t.colors['layer-inset'],
            border: Border(right: rule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: headerHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x4),
                decoration: BoxDecoration(border: Border(bottom: rule)),
                child: Semantics(
                  header: true,
                  child: Text(
                    serverName,
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
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(RaftSpace.x3),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        RaftSpace.x2,
                        0,
                        RaftSpace.x2,
                        RaftSpace.x2,
                      ),
                      child: Text(
                        raftText(context, label).toUpperCase(),
                        style: RaftTypography.inherited(
                          t,
                          size: 11,
                          line: 16.5,
                          weight: FontWeight.w700,
                          color: t.colors['foreground-hint'] ?? t.muted,
                        ).copyWith(letterSpacing: 11 * .05),
                      ),
                    ),
                    for (final channel in channels)
                      _ChannelButton(
                        channel: channel,
                        selected: channel.id == selectedId,
                        onPressed: () => onSelect(channel.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelButton extends StatelessWidget {
  const _ChannelButton({
    required this.channel,
    required this.selected,
    required this.onPressed,
  });
  final RaftPublicServerChannel channel;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final radius = t.brutal ? BorderRadius.zero : BorderRadius.circular(6);
    final color = selected
        ? (t.brutal ? Colors.black : t.colors['accent-strong'])
        : text.strong;
    return Padding(
      padding: const EdgeInsets.only(bottom: RaftSpace.x1),
      child: RaftInteractive(
        key: ValueKey('public-channel-${channel.id}'),
        semanticLabel: channel.name,
        selected: selected,
        onPressed: onPressed,
        builder: (context, state) {
          final fill = selected
              ? (t.brutal ? t.product.brutalPink : t.colors['accent-soft'])
              : (state.hovered
                    ? (t.brutal ? Colors.white : t.panel)
                    : Colors.transparent);
          final content = Row(
            spacing: 6,
            children: [
              RaftIcon(RaftGlyph.hash, size: 15, color: color),
              Expanded(
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.inherited(
                    t,
                    size: 14,
                    line: 20,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          );
          const inset = EdgeInsets.symmetric(
            horizontal: RaftSpace.x2,
            vertical: RaftSpace.x1,
          );
          if (selected || state.hovered) {
            return RaftSettingsCard.box(
              t,
              color: fill,
              radius: radius,
              padding: inset,
              child: content,
            );
          }
          return Container(
            padding: inset.add(EdgeInsets.all(t.border)),
            decoration: BoxDecoration(color: fill, borderRadius: radius),
            child: content,
          );
        },
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
    final copy = Text(
      raftText(context, message),
      style: recipe.description
          .text(tokens, base: base)
          .copyWith(fontSize: 14, fontWeight: FontWeight.w700),
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: RaftSpace.x2,
      children: actions,
    );
    final narrow = raftBreakpointWidth(context) < 640;
    return Semantics(
      key: const ValueKey('public-server-bottom-action'),
      container: true,
      liveRegion: true,
      child: RaftRecipeBox(
        style: recipe.root,
        tokens: tokens,
        width: double.infinity,
        applyText: false,
        padding: EdgeInsets.symmetric(
          horizontal: RaftSpace.x5,
          vertical: recipe.root.padding.top,
        ),
        decorationOverride: (d) => d.copyWith(
          borderRadius: BorderRadius.zero,
          border: d.border is Border
              ? Border(top: (d.border as Border).top)
              : d.border,
          boxShadow: const [],
        ),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // The Banner grid's `max-sm:gap-2` + its own row gap: the
                // action row sits 16px under the copy.
                spacing: RaftSpace.x4,
                children: [
                  copy,
                  Align(alignment: Alignment.centerRight, child: buttons),
                ],
              )
            : Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: RaftSpace.x2),
                  buttons,
                ],
              ),
      ),
    );
  }
}

/// Sign in / Create account / Join as Guest: a `Button size="md"` with a
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
    size: RaftButtonRecipeSize.md,
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

/// A one-line `text-sm text-foreground-muted` centred message (empty channel
/// list, empty timeline).
class RaftPublicEmptyMessage extends StatelessWidget {
  const RaftPublicEmptyMessage(this.message, {super.key, this.hint = true});
  final String message;

  /// `text-foreground-hint` (empty messages) vs `text-foreground-muted`.
  final bool hint;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RaftSpace.x6),
        child: RaftCssText(
          raftText(context, message),
          textAlign: TextAlign.center,
          style: RaftTypography.inherited(
            t,
            size: 14,
            line: 20,
            color: hint ? (t.colors['foreground-hint'] ?? t.muted) : t.muted,
          ),
        ),
      ),
    );
  }
}

/// `border-r/border-l border-line-hairline` (Brutal `border-2 border-black`).
BorderSide _publicRule(RaftTokens t) => BorderSide(
  color: t.brutal
      ? Colors.black
      : (t.colors['line-hairline'] ?? t.colors['line-muted']!),
  width: t.brutal ? 2 : 1,
);

/// The page canvas: `bg-layer-canvas theme-brutal:bg-white`.
class RaftPublicSurface extends StatelessWidget {
  const RaftPublicSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-canvas']!,
      child: child,
    );
  }
}

/// `h-panel-header` title strip of a sidebar column ("Settings").
class RaftPublicSidebarHeader extends StatelessWidget {
  const RaftPublicSidebarHeader({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final height = _publicHeaderHeight(context);
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5),
      decoration: BoxDecoration(border: Border(bottom: _publicRule(t))),
      child: Text(
        title,
        style: RaftTypography.inherited(
          t,
          size: 18,
          line: 28,
          weight: FontWeight.w700,
          color: RaftSettingsText(t).strong,
        ),
      ),
    );
  }
}

/// The settings surface sidebar (`aside`): same column chrome as the channel
/// list.
class RaftPublicSettingsSidebar extends StatelessWidget {
  const RaftPublicSettingsSidebar({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final sm = raftBreakpointWidth(context) >= 640;
    return RaftStatusBarSource(
      color: t.brutal ? t.product.brutalCream : t.colors['layer-inset']!,
      child: Container(
        key: const ValueKey('public-server-settings-sidebar'),
        width: sm ? 240 : 144,
        decoration: BoxDecoration(
          color: t.brutal ? t.product.brutalCream : t.colors['layer-inset'],
          border: Border(right: _publicRule(t)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftPublicSidebarHeader(title: title),
            Expanded(
              child: SingleChildScrollView(
                padding: RaftSettingsSidebarList.inset(t),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The side column of the thread panel at sm and up (`sm:w-[380px]
/// sm:border-l`).
class RaftPublicThreadColumn extends StatelessWidget {
  const RaftPublicThreadColumn({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: t.brutal ? Colors.white : t.colors['layer-canvas'],
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
    required this.loadOlderLabel,
    this.error,
    this.onLoadOlder,
  });
  final String title, channelContext, closeLabel, emptyTitle, loadOlderLabel;
  final VoidCallback onClose;
  final bool showClose, loading;
  final Widget parent;
  final List<Widget> replies;
  final String? error;
  final VoidCallback? onLoadOlder;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final narrow = raftBreakpointWidth(context) < 1024;
    final head = RaftTypography.inherited(
      t,
      size: 16,
      line: 24,
      weight: FontWeight.w700,
      color: text.strong,
    );
    final parentBox = Container(
      key: const ValueKey('thread-panel-parent'),
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x3,
        vertical: RaftSpace.x3,
      ),
      decoration: BoxDecoration(
        color: t.brutal ? Colors.white : t.panel,
        border: Border(
          bottom: BorderSide(color: text.edge, width: t.brutal ? 2 : 1),
        ),
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
          Expanded(child: RaftPublicEmptyMessage(emptyTitle, hint: false)),
        ],
      );
    } else {
      body = ListView(
        children: [
          if (onLoadOlder != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RaftSpace.x3),
              child: Center(
                child: RaftSettingsRecipeButton(
                  label: loadOlderLabel,
                  size: RaftButtonRecipeSize.xs,
                  onPressed: loading ? null : onLoadOlder,
                ),
              ),
            ),
          parentBox,
          for (final reply in replies)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x3),
              child: RaftPublicMessageRow(child: reply),
            ),
        ],
      );
    }
    return Container(
      key: const ValueKey('public-server-thread-panel'),
      color: t.brutal ? Colors.white : t.colors['layer-canvas'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            title: '',
            onBack: narrow ? onClose : null,
            backKey: const ValueKey('thread-mobile-back'),
            titleSlot: Text.rich(
              TextSpan(
                text: raftText(context, title),
                children: [
                  TextSpan(
                    // Web: the gap is `ml-1`, not a leading space in the catalog text.
                    text: ' $channelContext',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: t.colors['foreground-hint'] ?? t.muted,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: head,
            ),
            actions: [
              if (showClose)
                RaftPanelIconButton(
                  key: const ValueKey('thread-close'),
                  glyph: RaftGlyph.x,
                  tooltip: closeLabel,
                  onPressed: onClose,
                ),
            ],
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
    required this.banner,
    this.rail,
    this.threadOverlay,
    this.overlays = const [],
  });
  final Widget columns, banner;
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
        fallback: t.brutal ? Colors.white : t.colors['layer-canvas']!,
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
                            banner,
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
  });
  final String name, description;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final meta = raftCollapseWhitespace(description);
    return RaftPanelHeaderBar(
      title: name,
      subtitle: meta.isEmpty ? null : meta,
      // AppPanelHeader `icon` with the default `bg-primary`.
      iconSlot: RaftPanelHeaderIconTile(
        glyph: RaftGlyph.hash,
        background: t.brutal
            ? t.colors['primary-400']!
            : t.colors['fill-muted']!,
        borderless: !t.brutal,
      ),
    );
  }
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
  Widget build(BuildContext context) => RaftCollapsedBottomMargin(
    amount: RaftTokens.of(context).brutal ? 4 : 0,
    child: child,
  );
}

/// The public rail logo: `size-10 border-2 border-black bg-black font-display
/// text-base font-bold text-soft-signal shadow-brutal-sm`, on every theme.
class RaftPublicServerLogo extends StatelessWidget {
  const RaftPublicServerLogo({
    super.key,
    required this.initial,
    this.avatarUrl,
  });
  final String initial;
  final String? avatarUrl;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final extent = MediaQuery.sizeOf(context).height <= 600 ? 36.0 : 40.0;
    final letter = Center(
      child: Text(
        initial,
        style: RaftTypography.heading(
          t,
          size: 16,
          line: 24,
          weight: FontWeight.w700,
          color: t.product.softSignal,
        ),
      ),
    );
    final url = avatarUrl?.trim();
    return Container(
      width: extent,
      height: extent,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: RaftProductShadows.shadowBrutalSm.outer,
      ),
      child: url == null || url.isEmpty
          ? letter
          : RaftSizedImage.avatar(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => letter,
            ),
    );
  }
}

/// The public server rail (`data-public-server-rail`): a soft-signal strip on
/// every theme with the logo header, the Chat tab, an optional Help button and
/// Settings.
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
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final headerHeight = _publicHeaderHeight(context);
    return Container(
      key: const ValueKey('public-server-rail'),
      width: 64,
      decoration: BoxDecoration(
        color: t.product.softSignal,
        border: const Border(right: BorderSide(color: Colors.black, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AppRailHeader: Brutal draws its `border-b-2` inside the switcher.
          Container(
            height: headerHeight,
            decoration: BoxDecoration(
              border: t.brutal
                  ? null
                  : const Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
            ),
            child: header,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: RaftSpace.x2),
              child: Align(
                alignment: Alignment.topCenter,
                child: RaftWorkspaceRailAction(
                  key: const ValueKey('public-rail-chat'),
                  label: chatLabel,
                  glyph: RaftGlyph.messageSquare,
                  selected: chatSelected,
                  onPressed: onChat,
                ),
              ),
            ),
          ),
          if (help != null) SizedBox(height: 44, child: Center(child: help)),
          SizedBox(
            height: 44,
            child: Center(
              child: RaftWorkspaceRailAction(
                key: const ValueKey('public-rail-settings'),
                label: settingsLabel,
                glyph: RaftGlyph.settings,
                selected: settingsSelected,
                onPressed: onSettings,
              ),
            ),
          ),
          const SizedBox(height: RaftSpace.x2),
        ],
      ),
    );
  }
}
