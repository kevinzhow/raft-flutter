// Web ThreadAgentFollowers (components/thread/ThreadAgentFollowers.tsx), header
// variant: the "N agents following" trigger and its popover with the follower
// rows (remove / retry / loading / empty). The app adapter owns the roster,
// removal, undo and profile opening.
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'anchored_popup.dart';
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'dismiss_scope.dart';
import 'indicators.dart';
import 'icons.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'popover_surface.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

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

  /// `AgentActivityInfo`: `truncate font-mono text-xs text-foreground-muted`.
  final String secondary;

  /// `JointPeerBadge` label of a follower that lives on another server.
  final String? peerLabel;
  final VoidCallback? onOpen;

  /// Tooltip / semantics of the remove button; null hides the button (the
  /// viewer cannot manage followers).
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
  });

  /// False while Web renders nothing (count unknown / no followers): the
  /// popover's open state survives, so a reload brings it back open.
  final bool visible;

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
    final trigger = RaftRecipeButton(
      key: const Key('thread-followers-header-trigger'),
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      gap: 4,
      tooltip: widget.triggerLabel,
      onPressed: toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
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
              style: TextStyle(
                fontFamily: t.headingFont,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w700,
              ),
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
                    child: TapRegion(
                      groupId: group,
                      child: SizedBox(
                        width: 288,
                        child: _Popover(
                          key: const Key('thread-followers-popover'),
                          body: widget.body,
                          rows: widget.rows,
                          onRetry: widget.onRetry,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        child: KeyedSubtree(key: anchor, child: trigger),
      ),
    );
  }
}

/// `flex -space-x-1` of the compact avatars.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars, required this.size});
  final List<Widget> avatars;
  final double size;
  @override
  Widget build(BuildContext context) {
    const overlap = 4.0;
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
  });
  final RaftFollowersBody body;
  final List<RaftFollowerRow> rows;
  final VoidCallback onRetry;

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
          raftText(context, 'No Agents are following this thread.'),
          style: placeholder,
          textAlign: TextAlign.center,
        ),
      ),
      RaftFollowersBody.list => Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final row in rows) _FollowerRow(row: row)],
      ),
    };
    return RaftPopoverSurface(
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(color: t.popover),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: t.panel,
                  border: Border(
                    bottom: BorderSide(
                      color: t.colors['line-muted']!,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  raftText(context, 'Following Agents'),
                  style: TextStyle(
                    fontFamily: t.headingFont,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w700,
                    color: t.strong,
                  ),
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
      ),
    );
  }
}

class _FollowerRow extends StatefulWidget {
  const _FollowerRow({required this.row});
  final RaftFollowerRow row;
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
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Container(
        key: Key('thread-follower-row-${r.id}'),
        color: hovered ? t.colors['fill-muted'] : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: r.onOpen,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: r.avatar,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            spacing: 6,
                            children: [
                              Flexible(
                                child: Text(
                                  r.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: t.headingFont,
                                    fontSize: 14,
                                    height: 20 / 14,
                                    fontWeight: FontWeight.w500,
                                    color: t.strong,
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
                            style: TextStyle(
                              fontFamily: t.monoFont,
                              fontSize: 12,
                              height: 16 / 12,
                              color: t.muted,
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
              Opacity(
                opacity: r.canRemove ? 1 : .45,
                child: RaftIconButton(
                  key: const Key('thread-follower-remove'),
                  glyph: RaftGlyph.x,
                  tooltip: remove,
                  visualSize: 28,
                  minimumTargetSize: 28,
                  onPressed: r.canRemove && !r.removing ? r.onRemove : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
