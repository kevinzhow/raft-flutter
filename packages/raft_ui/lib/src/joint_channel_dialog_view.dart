// Presentation of the Web CreateJointChannelDialog
// (packages/web/src/components/channel/CreateJointChannelDialog.tsx): DialogCard
// `max-w-lg` with a GitBranch title icon, the free-allowance info Banner,
// Name / Description, the "Invite servers" Card of per-server invite cards
// (SlugInput + invited people), the current-server member picker and
// Cancel / Create Joint Channel. The app adapter owns state and the create command.
import 'package:flutter/material.dart';

import 'form_presentation.dart';

import 'banner.dart';
import 'create_channel_view.dart';
import 'dialog_card.dart';
import 'form_controls.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

/// One `JointInviteDraft`: a target server slug and the invited people text.
class RaftJointInviteDraft {
  RaftJointInviteDraft(this.id)
    : slug = TextEditingController(),
      people = TextEditingController();
  final String id;
  final TextEditingController slug, people;
  void dispose() {
    slug.dispose();
    people.dispose();
  }
}

class RaftCreateJointChannelDialogView extends StatelessWidget {
  const RaftCreateJointChannelDialogView({
    super.key,
    required this.name,
    required this.description,
    required this.search,
    required this.drafts,
    required this.maxServers,
    required this.onAddServer,
    required this.onRemoveServer,
    required this.onInviteChanged,
    required this.agents,
    required this.humans,
    required this.hasCandidates,
    required this.isSelected,
    required this.onToggle,
    required this.onClose,
    required this.onSubmit,
    this.freeAllowance = false,
    this.error,
    this.onViewBilling,
    this.notice,
    this.inviteNotice,
    this.submitting = false,
  });
  final TextEditingController name, description, search;
  final List<RaftJointInviteDraft> drafts;

  /// `MAX_JOINT_CHANNEL_SERVERS` (invites are limited to one fewer).
  final int maxServers;
  final VoidCallback onAddServer, onClose, onSubmit, onInviteChanged;
  final ValueChanged<String> onRemoveServer;
  final List<RaftPickerItem> agents, humans;
  final bool hasCandidates, freeAllowance, submitting;
  final bool Function(String key) isSelected;
  final ValueChanged<String> onToggle;
  final String? error;

  /// The billing-gate error's inline "View Billing" link.
  final VoidCallback? onViewBilling;

  /// Extra banner under [error] (the archived-name collision).
  final Widget? notice;

  /// Content under one invite card's fields (Web JointInviteDraftCard
  /// `sameAdminTarget` notice); null for none.
  final Widget? Function(RaftJointInviteDraft draft)? inviteNotice;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    const gap = SizedBox(height: 16); // space-y-4
    final canAdd = drafts.length < maxServers - 1;
    final eyebrow = raftCssTextStyle(
      family: t.headingFont,
      step: RaftTextSteps.xs,
      weight: FontWeight.w700,
      color: t.brutal
          ? Colors.black.withValues(alpha: .6)
          : t.colors['foreground-muted'],
      trackingEm: .025,
    );
    // Web `flex justify-end gap-3`; on a phone-width dialog the two buttons
    // wrap instead of overflowing (same layout whenever they fit).
    Widget actionButtons() => Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 8,
      children: [
        RaftRecipeButton(
          label: 'Cancel',
          variant: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.sm,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStep: RaftTextSteps.sm,
          disabled: submitting,
          onPressed: raftExplicitClose(context, onClose),
        ),
        RaftRecipeButton(
          key: const ValueKey('joint-create-submit'),
          label: submitting ? 'Creating…' : 'Create Joint Channel',
          variant: RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.sm,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStep: RaftTextSteps.sm,
          disabled: submitting,
          onPressed: onSubmit,
        ),
      ],
    );
    return RaftModalBackdrop(
      child: RaftDialogCard(
        title: 'Create Joint Channel',
        titleGlyph: RaftGlyph.gitBranch,
        maxWidth: 512, // max-w-lg
        onClose: onClose,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (freeAllowance) ...[
              RaftBanner(
                status: RaftBannerRecipeStatus.info,
                description: raftText(
                  context,
                  'Free servers can create and join Joint Channels. Each Joint Channel can have up to 30 servers, at most 2 of them free.',
                ),
                descriptionWeight: FontWeight.w700,
              ),
              gap,
            ],
            if (error != null) ...[
              onViewBilling == null
                  ? RaftWarningBanner(
                      error!,
                      key: const ValueKey('joint-create-error'),
                    )
                  : RaftBanner(
                      status: RaftBannerRecipeStatus.warning,
                      description: error!,
                      descriptionWeight: FontWeight.w700,
                      descriptionTail: (
                        label: raftText(context, 'View Billing'),
                        onPressed: onViewBilling!,
                      ),
                    ),
              gap,
            ],
            if (notice != null) ...[notice!, gap],
            RaftProductFormField(
              label: 'Name',
              required: true,
              child: RaftDialogTextInput(
                fieldKey: const ValueKey('joint-name'),
                controller: name,
                placeholder: 'e.g. partner-launch',
                autofocus: true,
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            gap,
            RaftProductFormField(
              label: 'Description',
              optional: true,
              child: RaftDialogTextInput(
                fieldKey: const ValueKey('joint-description'),
                controller: description,
                placeholder: 'What will both servers use this channel for?',
                multiline: true,
              ),
            ),
            gap,
            RaftRecipeCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          spacing: 8,
                          children: [
                            RaftIcon(
                              RaftGlyph.gitBranch,
                              size: 14,
                              color: eyebrow.color,
                            ),
                            Flexible(
                              child: Text(
                                raftText(
                                  context,
                                  'Invite servers',
                                ).toUpperCase(),
                                style: eyebrow,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12), // gap-3
                      RaftRecipeButton(
                        key: const ValueKey('joint-add-server'),
                        label: 'Add server',
                        glyph: RaftGlyph.plus,
                        glyphSize: 14,
                        gap: 4,
                        variant: RaftButtonRecipeVariant.outline,
                        size: RaftButtonRecipeSize.sm,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        textStep: RaftTextSteps.xs,
                        disabled: submitting || !canAdd,
                        onPressed: onAddServer,
                      ),
                    ],
                  ),
                  if (!canAdd) ...[
                    const SizedBox(height: 12),
                    Text(
                      raftFormat(
                        context,
                        'Joint channels support a maximum of {max} servers, including this server.',
                        {'max': maxServers},
                      ),
                      key: const ValueKey('create-joint-max-servers-hint'),
                      style: raftCssTextStyle(
                        family: t.headingFont,
                        step: RaftTextSteps.xs,
                        weight: FontWeight.w700,
                        color: eyebrow.color,
                      ),
                    ),
                  ],
                  for (final (index, draft) in drafts.indexed) ...[
                    const SizedBox(height: 12), // space-y-3
                    _InviteCard(
                      key: ValueKey('joint-invite-${draft.id}'),
                      index: index,
                      draft: draft,
                      removable: drafts.length > 1,
                      submitting: submitting,
                      eyebrow: eyebrow,
                      onRemove: () => onRemoveServer(draft.id),
                      onChanged: onInviteChanged,
                      notice: inviteNotice?.call(draft),
                    ),
                  ],
                ],
              ),
            ),
            gap,
            RaftProductFormField(
              label: 'Current server members',
              optional: true,
              child: RaftMemberPickerContent(
                search: search,
                agents: agents,
                humans: humans,
                hasCandidates: hasCandidates,
                isSelected: isSelected,
                onToggle: submitting ? null : onToggle,
              ),
            ),
          ],
        ),
        footer: actionButtons(),
      ),
    );
  }
}

/// `Card space-y-3 bg-layer-inset p-3` (one card per server invite).
class _InviteCard extends StatelessWidget {
  const _InviteCard({
    super.key,
    required this.index,
    required this.draft,
    required this.removable,
    required this.submitting,
    required this.eyebrow,
    required this.onRemove,
    required this.onChanged,
    this.notice,
  });
  final Widget? notice;
  final int index;
  final RaftJointInviteDraft draft;
  final bool removable, submitting;
  final TextStyle eyebrow;
  final VoidCallback onRemove, onChanged;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    const gap = SizedBox(height: 12);
    return RaftRecipeCard(
      padding: const EdgeInsets.all(12),
      // `theme-brutal:bg-brutal-gray/20` names no theme colour, so Brutal keeps
      // the `bg-layer-inset` fill too.
      background: t.colors['layer-inset'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  raftFormat(context, 'Server invite {n}', {
                    'n': index + 1,
                  }).toUpperCase(),
                  style: eyebrow.copyWith(letterSpacing: 0),
                ),
              ),
              if (removable) ...[
                const SizedBox(width: 12),
                RaftRecipeButton(
                  key: ValueKey('joint-remove-${draft.id}'),
                  glyph: RaftGlyph.trash2,
                  glyphSize: 14,
                  variant: RaftButtonRecipeVariant.danger,
                  size: RaftButtonRecipeSize.sm,
                  padding: const EdgeInsets.all(4),
                  tooltip: raftFormat(context, 'Remove server invite {n}', {
                    'n': index + 1,
                  }),
                  disabled: submitting,
                  onPressed: onRemove,
                ),
              ],
            ],
          ),
          gap,
          RaftProductFormField(
            label: 'Server slug',
            required: true,
            child: RaftSlugInput(
              key: ValueKey('joint-slug-$index'),
              controller: draft.slug,
              hintText: 'partner-workspace',
              onChanged: (_) => onChanged(),
            ),
          ),
          gap,
          RaftProductFormField(
            label: 'Invited people',
            required: true,
            hint: raftText(
              context,
              'Use target-server owner/admin handles or emails, separated by commas or new lines.',
            ),
            child: RaftDialogTextInput(
              fieldKey: ValueKey('joint-people-$index'),
              controller: draft.people,
              placeholder: '@admin or admin@example.com',
              multiline: true,
            ),
          ),
          if (notice != null) ...[gap, notice!],
        ],
      ),
    );
  }
}
