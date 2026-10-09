import 'package:flutter/material.dart';

import 'components.dart';
import 'icons.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'recipes/banner.g.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// Local outcome of a pending mention action (Web
/// `PendingMentionActionLocalState`).
enum RaftPendingMentionState { notified, added }

/// One `PendingMentionAction` returned by the send receipt.
@immutable
class RaftPendingMention {
  const RaftPendingMention({
    required this.resolutionId,
    required this.targetType,
    required this.targetHandle,
    required this.availableActions,
    this.avatar,
  });
  final String resolutionId, targetType, targetHandle;
  final List<String> availableActions;

  /// Authorized target artwork (agent/user avatar); null → app initial.
  final Widget? avatar;

  bool get canNotify =>
      availableActions.any((a) => a == 'notify' || a == 'notify_only');
  bool get canAdd => availableActions.any((a) => a == 'add' || a == 'invite');

  /// `pendingMentionTargetLabel`.
  String get label {
    final handle = targetHandle.isNotEmpty ? targetHandle : targetType;
    if ((targetType == 'user' || targetType == 'agent') &&
        handle.isNotEmpty &&
        !handle.startsWith('@')) {
      return '@$handle';
    }
    return handle;
  }
}

/// Web `PendingMentionActionStrip.tsx`: shown above the composer after a
/// send mentioned someone outside the channel — UserX, target avatar,
/// "@x was not notified because they are not in #channel", then Add /
/// Notify / Ignore (plus "Add all" when several can be added).
class RaftPendingMentionActionStrip extends StatelessWidget {
  const RaftPendingMentionActionStrip({
    super.key,
    required this.actions,
    required this.channelName,
    required this.onMark,
    required this.onDismiss,
    this.onAddAll,
    this.state = const {},
    this.removing = const {},
    this.executing = const {},
  });
  final List<RaftPendingMention> actions;
  final String channelName;
  final Map<String, RaftPendingMentionState> state, executing;
  final Set<String> removing;
  final void Function(String resolutionId, RaftPendingMentionState state)
  onMark;
  final ValueChanged<String> onDismiss;
  final ValueChanged<List<String>>? onAddAll;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final channel = channelName.startsWith('#') ? channelName : '#$channelName';
    final addable = [
      for (final a in actions)
        if (a.canAdd &&
            !state.containsKey(a.resolutionId) &&
            !removing.contains(a.resolutionId))
          a.resolutionId,
    ];
    final hint = t.colors['foreground-hint'] ?? t.colors['foreground-muted']!;
    return Container(
      key: const ValueKey('pending-mention-action-strip'),
      // `rounded-lg border border-line-muted bg-layer-panel px-3 py-2
      // shadow-raft-xs`; brutal `rounded-none border-2 border-black
      // bg-brutal-cream shadow-brutal-sm`.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.brutal
            ? t.colors['color-brutal-cream']
            : t.colors['layer-panel'],
        border: t.brutal
            ? Border.all(color: Colors.black, width: 2)
            : Border.all(color: t.colors['line-muted']!),
        borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
        boxShadow: (t.brutal ? t.themeShadows.sm : t.themeShadows.xs).outer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _row(context, t, actions[i], channel, hint),
          ],
          if (addable.length > 1 && onAddAll != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: t.colors['line-hairline']!),
                ),
              ),
              alignment: Alignment.centerRight,
              child: _StripButton(
                variant: RaftButtonRecipeVariant.accent,
                glyph: RaftGlyph.userPlus,
                label: raftText(context, 'Add all'),
                onPressed: addable.any(executing.containsKey)
                    ? null
                    : () => onAddAll!(addable),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    RaftTokens t,
    RaftPendingMention action,
    String channel,
    Color hint,
  ) {
    final local = state[action.resolutionId];
    final busy = executing.containsKey(action.resolutionId);
    final target = action.label;
    final status = switch (local) {
      RaftPendingMentionState.added => raftFormat(
        context,
        '{target} was added to {channel}',
        {'target': target, 'channel': channel},
      ),
      RaftPendingMentionState.notified => raftFormat(
        context,
        'Notification queued for {target} · still not in {channel}',
        {'target': target, 'channel': channel},
      ),
      null => raftFormat(
        context,
        '{target} was not notified because they are not in {channel}',
        {'target': target, 'channel': channel},
      ),
    };
    Widget done(String label) => Container(
      // `rounded-md border bg-fill-muted px-2 py-0.5 text-[12px] font-bold`;
      // brutal `border-2 border-black/20 bg-black/[0.04] text-black/40`.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.brutal
            ? Colors.black.withValues(alpha: .04)
            : t.colors['fill-muted'],
        border: t.brutal
            ? Border.all(color: Colors.black.withValues(alpha: .2), width: 2)
            : Border.all(color: t.colors['line-hairline']!),
        borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftIcon(
            RaftGlyph.check,
            size: 12,
            strokeWidth: 3,
            color: t.brutal ? Colors.black.withValues(alpha: .4) : hint,
          ),
          const SizedBox(width: 4),
          Text(
            raftText(context, label),
            style: TextStyle(
              fontFamily: t.headingFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.brutal ? Colors.black.withValues(alpha: .4) : hint,
            ),
          ),
        ],
      ),
    );
    return AnimatedOpacity(
      key: ValueKey('pending-mention-${action.resolutionId}'),
      opacity: removing.contains(action.resolutionId) ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RaftIcon(RaftGlyph.userX, size: 14, color: hint),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 20,
                child:
                    action.avatar ??
                    RaftAvatar(
                      name: target,
                      size: 20,
                      kind: RaftAvatarKind.app,
                      mountedContext: RaftMountedAvatarContext.compactList,
                      content: RaftMountedAvatarFallback(
                        avatarContext: RaftMountedAvatarContext.compactList,
                        identity: RaftMountedAvatarIdentity.app,
                        initials: target.replaceFirst('@', '').trim(),
                      ),
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.headingFont,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w700,
                        color: t.strong,
                      ),
                    ),
                    Text(
                      status,
                      key: const ValueKey('pending-mention-action-status'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.headingFont,
                        fontSize: 11,
                        height: 16 / 11,
                        color: t.colors['foreground-muted'],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (local == RaftPendingMentionState.added)
                done('Added')
              else if (action.canAdd && local == null)
                _StripButton(
                  variant: RaftButtonRecipeVariant.accent,
                  glyph: RaftGlyph.userPlus,
                  label: raftText(context, 'Add'),
                  onPressed: busy
                      ? null
                      : () => onMark(
                          action.resolutionId,
                          RaftPendingMentionState.added,
                        ),
                ),
              if (local == RaftPendingMentionState.notified) ...[
                const SizedBox(width: 6),
                done('Queued'),
              ] else if (action.canNotify && local == null) ...[
                const SizedBox(width: 6),
                _StripButton(
                  variant: RaftButtonRecipeVariant.outline,
                  glyph: RaftGlyph.bellRing,
                  label: raftText(context, 'Notify'),
                  onPressed: busy
                      ? null
                      : () => onMark(
                          action.resolutionId,
                          RaftPendingMentionState.notified,
                        ),
                ),
              ],
              const SizedBox(width: 6),
              _StripButton(
                variant: RaftButtonRecipeVariant.muted,
                label: raftText(context, 'Ignore'),
                onPressed: () => onDismiss(action.resolutionId),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// raft-ui `Button size="sm"` resolved from the generated recipe (h-7,
/// px-2.5, 12/16 bold, 14px icon, gap 5, hover lift + larger shadow).
class _StripButton extends StatefulWidget {
  const _StripButton({
    required this.variant,
    required this.label,
    this.glyph,
    this.onPressed,
  });
  final RaftButtonRecipeVariant variant;
  final String label;
  final RaftGlyph? glyph;
  final VoidCallback? onPressed;
  @override
  State<_StripButton> createState() => _StripButtonState();
}

class _StripButtonState extends State<_StripButton> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final enabled = widget.onPressed != null;
    final s = RaftButtonRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      variant: widget.variant,
      size: RaftButtonRecipeSize.sm,
      states: RaftRecipeStates({
        if (enabled && hovered) RaftRecipeStates.hover,
        if (enabled && pressed) RaftRecipeStates.active,
        if (!enabled) RaftRecipeStates.disabled,
      }),
      tokens: resolver,
    ).root;
    final text = s
        .textStyle(resolver)
        .copyWith(leadingDistribution: TextLeadingDistribution.even);
    final icon = s.target("& svg:not([class*='size-'])")?.width ?? 14;
    Widget button = Container(
      height: s.height,
      padding: s.padding,
      decoration: s.decoration(resolver),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.glyph != null) ...[
            RaftIcon(widget.glyph!, size: icon, color: text.color),
            SizedBox(width: s.columnGap ?? 5),
          ],
          Text(widget.label, style: text),
        ],
      ),
    );
    final offset = s.translate;
    if (offset != null && offset != Offset.zero) {
      button = Transform.translate(offset: offset, child: button);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
          onTapCancel: () => setState(() => pressed = false),
          onTapUp: (_) => setState(() => pressed = false),
          onTap: widget.onPressed,
          child: Opacity(opacity: s.opacity ?? 1, child: button),
        ),
      ),
    );
  }
}

/// MessageInput slot above the composer: the mention-action notice, then the
/// strip with its `mb-2` (inside the composer's `flex-col gap-2`).
class RaftPendingMentionSlot extends StatelessWidget {
  const RaftPendingMentionSlot({super.key, required this.strip, this.notice});
  final Widget strip;
  final String? notice;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (notice != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(liveRegion: true, child: Text(notice!)),
        ),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: strip),
    ],
  );
}

/// Web MessageInput `<Banner intent="warning" density="sm">` above the
/// composer (attachment-limit and send errors). raft-ui banner recipe; the
/// `group-data-[size=sm]` description is `text-xs leading-4`.
class RaftComposerNotice extends StatelessWidget {
  const RaftComposerNotice({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final s = RaftBannerRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      status: RaftBannerRecipeStatus.warning,
      size: RaftBannerRecipeSize.sm,
      tokens: resolver,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: s.root.padding,
        decoration: s.root.decoration(resolver),
        child: Text(
          message,
          style: s.description
              .textStyle(resolver)
              .copyWith(
                fontFamily: t.headingFont,
                fontSize: 12,
                height: 16 / 12,
                leadingDistribution: TextLeadingDistribution.even,
              ),
        ),
      ),
    );
  }
}

/// MessageInput `flex-col gap-2` between stacked composer notices.
class RaftComposerGap extends StatelessWidget {
  const RaftComposerGap({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: 8);
}
