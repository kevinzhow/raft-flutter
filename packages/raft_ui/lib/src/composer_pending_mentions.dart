import 'reduced_motion.dart';

import 'package:flutter/material.dart';

import 'card.dart';
import 'components.dart';
import 'icons.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
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
    this.readOnlyInLounge = false,
    this.avatar,
  });
  final String resolutionId, targetType, targetHandle;
  final List<String> availableActions;
  final bool readOnlyInLounge;

  /// Authorized target artwork (agent/user avatar); null → app initial.
  final Widget? avatar;

  bool get canNotify =>
      !readOnlyInLounge &&
      availableActions.any((a) => a == 'notify' || a == 'notify_only');
  bool get canAdd =>
      !readOnlyInLounge &&
      availableActions.any((a) => a == 'add' || a == 'invite');

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
    return RaftCard(
      key: const ValueKey('pending-mention-action-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, bounds) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _row(
                context,
                t,
                actions[i],
                channel,
                hint,
                wide: bounds.maxWidth >= 576,
              ),
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
                  variant: RaftButtonVariant.outline,
                  glyph: RaftGlyph.userPlus,
                  label: raftText(context, 'Add All'),
                  onPressed: addable.any(executing.containsKey)
                      ? null
                      : () => onAddAll!(addable),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    RaftTokens t,
    RaftPendingMention action,
    String channel,
    Color hint, {
    required bool wide,
  }) {
    final local = state[action.resolutionId];
    final busy = executing.containsKey(action.resolutionId);
    final target = action.label;
    final status = switch ((action.readOnlyInLounge, local)) {
      (true, _) => raftFormat(
        context,
        "{target} won't be notified: other agents can only read this chat.",
        {'target': target},
      ),
      (false, RaftPendingMentionState.added) => raftFormat(
        context,
        '{target} was added to {channel}',
        {'target': target, 'channel': channel},
      ),
      (false, RaftPendingMentionState.notified) => raftFormat(
        context,
        'Notification queued for {target} · still not in {channel}',
        {'target': target, 'channel': channel},
      ),
      (false, null) => raftFormat(
        context,
        '{target} was not notified because they are not in {channel}',
        {'target': target, 'channel': channel},
      ),
    };
    Widget done(String label) => Container(
      // `rounded-md border bg-fill-muted px-2 py-0.5 text-[12px] font-bold`.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.colors['fill-muted'],
        border: Border.all(color: t.colors['line-hairline']!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftIcon(RaftGlyph.check, size: 12, strokeWidth: 3, color: hint),
          const SizedBox(width: 4),
          Text(
            raftText(context, label),
            style: TextStyle(
              fontFamily: t.headingFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: hint,
            ),
          ),
        ],
      ),
    );
    final info = Row(
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
              RaftCssText(
                target,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.scale(
                  t.typeSlot('footnote'),
                  weight: FontWeight.w700,
                  color: t.ui.foreground,
                ),
              ),
              RaftCssText(
                status,
                key: const ValueKey('pending-mention-action-status'),
                maxLines: wide ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: t.scale(
                  t.typeSlot('caption'),
                  color: t.ui.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final buttons = Row(
      mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (local == RaftPendingMentionState.added)
          done('Added')
        else if (action.canAdd && local == null)
          _StripButton(
            variant: RaftButtonVariant.outline,
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
            variant: RaftButtonVariant.outline,
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
          variant: RaftButtonVariant.ghost,
          label: raftText(context, 'Ignore'),
          onPressed: () => onDismiss(action.resolutionId),
        ),
      ],
    );
    return AnimatedOpacity(
      key: ValueKey('pending-mention-${action.resolutionId}'),
      opacity: removing.contains(action.resolutionId) ? 0 : 1,
      duration: raftMotionDuration(context, const Duration(milliseconds: 300)),
      child: wide
          ? Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 8),
                buttons,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 8), buttons],
            ),
    );
  }
}

/// The strip uses raft-ui's standard medium buttons.
class _StripButton extends StatelessWidget {
  const _StripButton({
    required this.variant,
    required this.label,
    this.glyph,
    this.onPressed,
  });
  final RaftButtonVariant variant;
  final String label;
  final RaftGlyph? glyph;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => RaftButton(
    label: label,
    glyph: glyph,
    uiVariant: variant,
    uiSize: RaftButtonSize.md,
    disabled: onPressed == null,
    onPressed: onPressed,
  );
}

/// MessageInput slot above the composer: the mention-action notice, then the
/// strip with its `mb-2` (inside the composer's `flex-col gap-2`).
class RaftPendingMentionSlot extends StatelessWidget {
  const RaftPendingMentionSlot({super.key, required this.strip, this.notice});
  final Widget strip;
  final String? notice;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // Web `mentionActionNotice`: `rounded-md border border-line-muted
            // bg-fill-muted/50 px-2 py-1 text-[11px] font-bold leading-4
            // text-foreground-muted`.
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.colors['fill-muted']!.withValues(
                    alpha: t.colors['fill-muted']!.a * .5,
                  ),
                  border: Border.all(color: t.colors['line-muted']!, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  notice!,
                  style: TextStyle(
                    fontFamily: t.headingFont,
                    fontSize: 11,
                    height: 16 / 11,
                    fontWeight: FontWeight.w700,
                    color: t.colors['foreground-muted'],
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ),
          ),
        Padding(padding: const EdgeInsets.only(bottom: 8), child: strip),
      ],
    );
  }
}

/// MessageInput `flex-col gap-2` between stacked composer notices.
class RaftComposerGap extends StatelessWidget {
  const RaftComposerGap({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: 8);
}
