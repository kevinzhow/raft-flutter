import 'reduced_motion.dart';

import 'package:flutter/material.dart';

import 'banner.dart';
import 'components.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/banner.g.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';
import 'raft/css_box.dart';

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
        color: t.colors['layer-panel'],
        border: Border.all(color: t.colors['line-muted']!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: t.themeShadows.xs.outer,
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
                label: raftText(context, 'Add All'),
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
    // Web `sm:` is the viewport media query (640px), not the strip width:
    // `sm:flex-row sm:items-center` keeps the buttons on the text row, below it
    // the row stacks with `gap-2` and the status clamps to two lines.
    final wide = MediaQuery.sizeOf(context).width >= 640;
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
                style: TextStyle(
                  fontFamily: t.headingFont,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w700,
                  color: t.strong,
                ),
              ),
              RaftCssText(
                status,
                key: const ValueKey('pending-mention-action-status'),
                maxLines: wide ? 1 : 2,
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
    );
    final buttons = Row(
      mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
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

/// raft-ui `Button size="sm"` resolved from the generated recipe (h-7,
/// px-2.5, 12/16 bold, 14px icon, gap 5, hover lift + larger shadow).
class _StripButton extends StatelessWidget {
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
  Widget build(BuildContext context) => RaftRecipeButton(
    label: label,
    glyph: glyph,
    variant: variant,
    size: RaftButtonRecipeSize.sm,
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
            // text-foreground-muted`; brutal `rounded-none border-2
            // border-black/35 bg-black/[0.04] text-black/70`.
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

/// Web MessageInput `<Banner intent="warning" density="sm">` above the
/// composer (attachment-limit and send errors). raft-ui banner recipe; the
/// `group-data-[size=sm]` description is `text-xs leading-4`.
class RaftComposerNotice extends StatelessWidget {
  const RaftComposerNotice({
    super.key,
    required this.message,
    this.onDismiss,
    this.dismissLabel,
  });
  final String message;

  /// Web `Banner actions`: the trailing `Button ghost icon-xs` with an X
  /// (delivery-warning and unresolved-mention banners).
  final VoidCallback? onDismiss;
  final String? dismissLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option('sticker.ring', or: 'none') == 'dieCut') {
      final font = t.size('type.composerNotice.size', fallback: 13);
      final text = Text(
        message,
        style: TextStyle(
          fontFamily: t.bodyFont,
          fontFamilyFallback: t.fontFallback,
          fontSize: font,
          height: t.size('type.composerNotice.line', fallback: 18) / font,
          fontWeight: raftFontWeight(
            t.size('type.composerNotice.weight', fallback: 400),
          ),
          color: t.colors['foreground-composer-notice'],
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
      return Semantics(
        liveRegion: true,
        child: RaftCssBox(
          width: double.infinity,
          radius: t.size('radius.composerNotice', fallback: 10),
          fill: t.colors['layer-composer-notice'],
          insetRingWidth: t.size('stroke.composerNotice', fallback: 1),
          insetRingColor: t.colors['line-composer-notice'],
          padding: EdgeInsets.fromLTRB(
            t.size('space.composerNoticeStart', fallback: 12),
            t.size('space.composerNoticeTop', fallback: 8),
            t.size('space.composerNoticeEnd', fallback: 12),
            t.size('space.composerNoticeBottom', fallback: 8),
          ),
          child: onDismiss == null
              ? text
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 8),
                    RaftButton(
                      label: '',
                      glyph: RaftGlyph.x,
                      uiVariant: RaftButtonVariant.ghost,
                      uiSize: RaftButtonSize.iconXs,
                      tooltip: dismissLabel,
                      onPressed: onDismiss,
                    ),
                  ],
                ),
        ),
      );
    }
    if (onDismiss != null) {
      // Banner with `actions`: the public composition (grid action cell, the
      // `@max-[24rem]` drop below the copy, status colours).
      return DefaultTextStyle.merge(
        style: TextStyle(fontFamily: t.headingFont),
        child: RaftBanner(
          description: message,
          descriptionWeight: FontWeight.w700,
          size: RaftBannerRecipeSize.sm,
          // Measured on Web: the `icon-xs` button is 24px in Brutal but 16px in
          // Elegant (the recipe resolves 24 for both); its 12px glyph stays.
          action: SizedBox.square(
            dimension: 16,
            child: RaftRecipeButton(
              variant: RaftButtonRecipeVariant.ghost,
              size: RaftButtonRecipeSize.iconXs,
              glyph: RaftGlyph.x,
              glyphSize: 12,
              foreground: t.colors['warning-strong'],
              tooltip: dismissLabel,
              onPressed: onDismiss,
            ),
          ),
        ),
      );
    }
    final resolver = RaftRecipeTokens(t);
    final s = RaftBannerRecipe.resolve(
      theme: t.option('press.effect', or: 'scale') == 'offsetShadow'
          ? RaftRecipeTheme.brutal
          : RaftRecipeTheme.elegant,
      status: RaftBannerRecipeStatus.warning,
      size: RaftBannerRecipeSize.sm,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: resolver,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          t.size('space.composerNoticeStart', fallback: 12),
          t.size('space.composerNoticeTop', fallback: 8),
          t.size('space.composerNoticeEnd', fallback: 12),
          t.size('space.composerNoticeBottom', fallback: 8),
        ),
        decoration: s.root
            .decoration(resolver)
            .copyWith(
              color: t.colors['layer-composer-notice'],
              border: t.size('stroke.composerNotice', fallback: 1) > 0
                  ? Border.all(
                      color: t.colors['line-composer-notice']!,
                      width: t.size('stroke.composerNotice', fallback: 1),
                    )
                  : const Border(),
              borderRadius: BorderRadius.circular(
                t.size('radius.composerNotice', fallback: 10),
              ),
            ),
        child: Text(
          message,
          style: s.description
              .textStyle(resolver)
              .copyWith(
                fontFamily: t.headingFont,
                fontSize: t.size('type.composerNotice.size', fallback: 13),
                height:
                    t.size('type.composerNotice.line', fallback: 18) /
                    t.size('type.composerNotice.size', fallback: 13),
                fontWeight: raftFontWeight(
                  t.size('type.composerNotice.weight', fallback: 400),
                ),
                color: t.colors['foreground-composer-notice'],
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
