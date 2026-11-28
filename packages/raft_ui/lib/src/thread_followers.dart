// Web ThreadAgentFollowers (components/thread/ThreadAgentFollowers.tsx), header
// variant: the "N agents following" trigger and its popover with the follower
// rows (remove / retry / loading / empty). The app adapter owns the roster,
// removal, undo and profile opening.
import 'package:flutter/material.dart';

import 'anchored_popup.dart';
import 'dialog_card.dart';
import 'dismiss_scope.dart';
import 'hover_region.dart';
import 'indicators.dart';
import 'icons.dart';
import 'interaction.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'popover_surface.dart';
import 'raft/button.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/popover.g.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftDesktopMetrics;

/// One follower row: `ChannelMemberRow type="agent"` (avatar with its activity
/// badge, name with an optional peer-server badge, mono activity line) and the
/// manager's remove button.
@immutable
class RaftFollowerRow {
  const RaftFollowerRow({
    required this.id,
    required this.label,
    required this.avatar,
    required this.secondary,
    this.peerLabel,
    this.onOpen,
    this.removeLabel,
    this.canRemove = false,
    this.removing = false,
    this.onRemove,
  });
  final String id, label;
  final Widget avatar;

  /// The caption supplied by `AgentActivityInfo`.
  final String secondary;

  /// `JointPeerBadge` label of a follower that lives on another server.
  final String? peerLabel;
  final VoidCallback? onOpen;

  /// Accessible name of the remove button. A null label hides the action.
  final String? removeLabel;
  final bool canRemove, removing;
  final VoidCallback? onRemove;
}

enum RaftFollowersBody { loading, error, empty, list }

class RaftThreadFollowers extends StatefulWidget {
  const RaftThreadFollowers({
    super.key,
    required this.triggerLabel,
    required this.avatars,
    required this.count,
    required this.error,
    required this.body,
    required this.rows,
    required this.onRetry,
    this.visible = true,
    this.folded = false,
    this.openRequest = 0,
  });

  /// False while Web renders nothing (count unknown / no followers): the
  /// popover's open state survives, so a reload brings it back open.
  final bool visible, folded;
  final int openRequest;

  /// Tooltip and accessible label ("2 Agents following" / "Followers couldn't
  /// be loaded.").
  final String triggerLabel;

  /// The first three followers' compact avatars.
  final List<Widget> avatars;
  final int count;
  final bool error;
  final RaftFollowersBody body;
  final List<RaftFollowerRow> rows;
  final VoidCallback onRetry;

  @override
  State<RaftThreadFollowers> createState() => _RaftThreadFollowersState();
}

class _RaftThreadFollowersState extends State<RaftThreadFollowers> {
  final portal = OverlayPortalController();
  final anchor = GlobalKey();
  final group = Object();
  bool open = false;

  @override
  void didUpdateWidget(covariant RaftThreadFollowers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && widget.openRequest != oldWidget.openRequest) {
      open = true;
    }
  }

  void toggle() {
    setState(() => open = !open);
    open ? portal.show() : portal.hide();
  }

  void close() {
    if (!open) return;
    setState(() => open = false);
    portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final shown = open && widget.visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shown && !portal.isShowing) portal.show();
      if (!shown && portal.isShowing) portal.hide();
    });
    if (!widget.visible) return const SizedBox.shrink();
    final pointer = RaftInteraction.of(context).pointer;
    final trigger = RaftButton(
      key: const Key('thread-followers-header-trigger'),
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.md,
      physicalHeight: pointer ? RaftDesktopMetrics.barButtonSize : null,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      semanticLabel: widget.triggerLabel,
      tooltip: widget.triggerLabel,
      onPressed: toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (widget.error)
            const RaftIcon(RaftGlyph.circleAlert, size: 14)
          else
            _AvatarStack(
              avatars: widget.avatars,
              size: RaftMountedAvatarRecipe(
                t,
                RaftMountedAvatarContext.sidebarList,
                RaftMountedAvatarIdentity.agent,
              ).extent,
            ),
          if (!widget.error)
            Text(
              '${widget.count}',
              style: t.scale(t.typeSlot('mono-meta'), mono: true),
            ),
        ],
      ),
    );
    return TapRegion(
      groupId: group,
      onTapOutside: (_) => close(),
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (context) => RaftBackDismiss(
          onDismiss: close,
          child: Stack(
            children: [
              Positioned.fill(
                // Escape closes the popover, not the thread panel under it.
                child: RaftDismissScope(
                  onDismiss: close,
                  takeFocus: true,
                  child: RaftAnchoredPopup(
                    anchorKey: anchor,
                    alignRight: true,
                    gap: 6,
                    snapToDevicePixels: true,
                    child: TapRegion(
                      groupId: group,
                      child: SizedBox(
                        width: 288,
                        child: _Popover(
                          key: const Key('thread-followers-popover'),
                          body: widget.body,
                          rows: widget.rows,
                          onRetry: widget.onRetry,
                          onProfileOpen: close,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        child: KeyedSubtree(
          key: anchor,
          child: widget.folded ? const SizedBox(width: 0, height: 32) : trigger,
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars, required this.size});
  final List<Widget> avatars;
  final double size;
  @override
  Widget build(BuildContext context) {
    const overlap = 5.0;
    if (avatars.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: avatars.length * size - (avatars.length - 1) * overlap,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < avatars.length; i++)
            Positioned(left: i * (size - overlap), child: avatars[i]),
        ],
      ),
    );
  }
}

class _Popover extends StatelessWidget {
  const _Popover({
    super.key,
    required this.body,
    required this.rows,
    required this.onRetry,
    required this.onProfileOpen,
  });
  final RaftFollowersBody body;
  final List<RaftFollowerRow> rows;
  final VoidCallback onRetry;
  final VoidCallback onProfileOpen;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final placeholder = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w700,
      color: t.colors['foreground-placeholder'],
    );
    final muted = placeholder.copyWith(color: t.muted);
    Widget status(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Center(child: child),
    );
    final Widget content = switch (body) {
      RaftFollowersBody.loading => status(
        Text(
          key: const Key('thread-followers-loading'),
          raftText(context, 'Loading followers…'),
          style: placeholder,
          textAlign: TextAlign.center,
        ),
      ),
      RaftFollowersBody.error => status(
        Column(
          key: const Key('thread-followers-error'),
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            RaftIcon(RaftGlyph.circleAlert, size: 18, color: muted.color),
            Text(
              raftText(context, "Followers couldn't be loaded."),
              style: muted,
              textAlign: TextAlign.center,
            ),
            RaftRecipeButton(
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              label: raftText(context, 'Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
      RaftFollowersBody.empty => status(
        Text(
          key: const Key('thread-followers-empty'),
          raftText(context, 'No Agents follow this thread'),
          style: placeholder,
          textAlign: TextAlign.center,
        ),
      ),
      RaftFollowersBody.list => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            _FollowerRow(row: row, onProfileOpen: onProfileOpen),
        ],
      ),
    };
    final popover = RaftPopoverRecipe.resolve(
      tokens: t.recipeTokens,
      states: t.recipeStates(),
    ).content;
    return RaftPopoverSurface(
      surfaceStyle: popover,
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: t.colors['line-seam']!),
                ),
              ),
              child: Text(
                raftText(context, 'Following agents'),
                style: t.scale(t.typeSlot('headline')),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 288),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowerRow extends StatefulWidget {
  const _FollowerRow({required this.row, required this.onProfileOpen});
  final RaftFollowerRow row;
  final VoidCallback onProfileOpen;
  @override
  State<_FollowerRow> createState() => _FollowerRowState();
}

class _FollowerRowState extends State<_FollowerRow> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final r = widget.row;
    final remove = r.removeLabel;
    final viewport = MediaQuery.sizeOf(context);
    final short = viewport.height <= 600;
    final compactTouch =
        viewport.width >= 768 && RaftInteraction.of(context).touch;
    final canPress = r.canRemove && !r.removing;
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Container(
        key: Key('thread-follower-row-${r.id}'),
        color: hovered ? t.colors['fill-subtle'] : null,
        constraints: BoxConstraints(
          minHeight: short
              ? 0
              : compactTouch
              ? 56
              : 64,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: short ? 6 : 10),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: r.onOpen == null
                    ? null
                    : () {
                        widget.onProfileOpen();
                        r.onOpen!();
                      },
                child: Row(
                  spacing: 12,
                  children: [
                    r.avatar,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            spacing: 6,
                            children: [
                              Flexible(
                                child: Text(
                                  r.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.scale(
                                    t.typeSlot('subhead'),
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (r.peerLabel != null)
                                Flexible(
                                  child: RaftBadge(
                                    label: r.peerLabel!,
                                    appearance: RaftBadgeRecipeAppearance.soft,
                                    variant: RaftBadgeRecipeVariant.information,
                                    fontFamily: t.monoFont,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            r.secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.scale(
                              t.typeSlot('caption'),
                              color: t.ui.foregroundHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (remove != null)
              RaftButton(
                key: const Key('thread-follower-remove'),
                glyph: RaftGlyph.x,
                uiVariant: RaftButtonVariant.ghost,
                uiSize: RaftButtonSize.iconMd,
                tooltip: canPress ? remove : null,
                semanticLabel: remove,
                onPressed: canPress ? r.onRemove : null,
              ),
          ],
        ),
      ),
    );
  }
}
