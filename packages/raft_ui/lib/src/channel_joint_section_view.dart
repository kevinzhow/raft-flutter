// The joint-channel block of the Web EditChannelDialog settings panel
// (components/channel/EditChannelDialog.tsx `channel-settings-joint-section`):
// the "Connected servers" list with plan and status badges, the Resend Invite
// button, and the "Channel connection invitation" form (server slug, invited
// people, the RFC 075 same-admin confirmation). The app adapter owns state and
// the mutations.
import 'package:flutter/material.dart';

import 'banner.dart';
import 'dialog_card.dart';
import 'form_controls.dart';
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'settings_controls.dart' show RaftSettingsRecipeButton;
import 'theme.dart';
import 'tooltip.dart';

/// One connected (or pending) server of a joint channel.
@immutable
class RaftJointServerRow {
  const RaftJointServerRow({
    required this.name,
    required this.slug,
    required this.active,
    this.isCurrent = false,
    this.plan,
  });
  final String name, slug;

  /// `status == active` (else pending).
  final bool active, isCurrent;

  /// `free`, `paid` or null (no badge).
  final String? plan;
}

class RaftChannelJointSectionView extends StatelessWidget {
  const RaftChannelJointSectionView({
    super.key,
    required this.servers,
    required this.showInvite,
    required this.limitReached,
    required this.maxServers,
    required this.slug,
    required this.people,
    required this.onSendInvite,
    this.showResend = false,
    this.resendBusy = false,
    this.resendDone = false,
    this.resendError,
    this.onResend,
    this.slugError,
    this.peopleError,
    this.sameAdminNotice,
    this.inviteBusy = false,
    this.canSend = false,
    this.submitError,
    this.status,
  });
  final List<RaftJointServerRow> servers;

  /// `federateChannels` on a channel that is not archived: resend and invite.
  final bool showInvite, showResend;
  final bool limitReached, resendBusy, resendDone, inviteBusy, canSend;
  final int maxServers;
  final TextEditingController slug, people;
  final VoidCallback onSendInvite;
  final VoidCallback? onResend;
  final String? resendError, slugError, peopleError, submitError, status;
  final Widget? sameAdminNotice;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hairline = t.brutal
        ? Colors.black.withValues(alpha: .1)
        : t.colors['line-muted']!;
    // v1.21.23 `SectionEyebrow tone="muted"`: a small muted sentence-case
    // heading (the uppercase eyebrow went with the old themes).
    final eyebrow = raftCssTextStyle(
      family: t.bodyFont,
      step: RaftTextSteps.sm,
      weight: FontWeight.w500,
      color: t.colors['foreground-muted'],
    );
    final hint = t.colors['foreground-hint'];
    final rule = raftText(
      context,
      'Each Joint Channel can have up to 30 servers, with 2 free-server slots',
    );
    Widget rowFor(RaftJointServerRow server) => Padding(
      key: ValueKey('channel-settings-joint-server-row:${server.slug}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name.isEmpty ? server.slug : server.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: raftCssTextStyle(
                    family: t.bodyFont,
                    step: RaftTextSteps.sm,
                    weight: FontWeight.w600,
                    color: t.strong,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: server.slug,
                        style: TextStyle(fontFamily: t.monoFont),
                      ),
                      if (server.isCurrent)
                        TextSpan(
                          text: ' · ${raftText(context, 'This server')}',
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: raftCssTextStyle(
                    family: t.bodyFont,
                    step: RaftTextSteps.xs,
                    color: hint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (server.plan != null) ...[
            RaftBadge(
              key: const ValueKey('channel-settings-joint-server-plan'),
              label: raftText(context, server.plan == 'paid' ? 'Paid' : 'Free'),
              appearance: RaftBadgeRecipeAppearance.outline,
            ),
            const SizedBox(width: 8),
          ],
          RaftBadge(
            key: const ValueKey('channel-settings-joint-server-status'),
            label: raftText(context, server.active ? 'active' : 'pending'),
            appearance: RaftBadgeRecipeAppearance.soft,
            variant: server.active
                ? RaftBadgeRecipeVariant.success
                : RaftBadgeRecipeVariant.warning,
          ),
        ],
      ),
    );
    final resendLabel = resendBusy
        ? 'Resending…'
        : resendDone
        ? 'Invite resent'
        : 'Resend Invite';
    return Container(
      key: const ValueKey('channel-settings-joint-section'),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  raftText(context, 'Connected servers'),
                  style: eyebrow,
                ),
              ),
              const SizedBox(width: 6),
              RaftTooltip(
                message: rule,
                child: Semantics(
                  label: rule,
                  child: SizedBox(
                    key: const ValueKey('channel-settings-joint-servers-rule'),
                    width: 24,
                    height: 24,
                    child: Center(
                      child: RaftIcon(RaftGlyph.info, size: 16, color: hint),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (servers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                key: const ValueKey('channel-settings-joint-servers'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < servers.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, thickness: 1, color: hairline),
                    rowFor(servers[i]),
                  ],
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                raftText(
                  context,
                  'Connected server metadata is not available yet.',
                ),
                style: raftCssTextStyle(
                  family: t.bodyFont,
                  step: RaftTextSteps.sm,
                  color: hint,
                ),
              ),
            ),
          if (showInvite && showResend) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: RaftSettingsRecipeButton(
                key: const ValueKey('channel-settings-joint-resend'),
                label: resendLabel,
                glyph: resendDone ? RaftGlyph.check : RaftGlyph.mail,
                glyphSize: 16,
                variant: resendDone
                    ? RaftButtonRecipeVariant.success
                    : RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.sm,
                onPressed: resendBusy ? null : onResend,
              ),
            ),
            if (resendError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  resendError!,
                  key: const ValueKey('channel-settings-joint-resend-error'),
                  style: raftCssTextStyle(
                    family: t.bodyFont,
                    step: RaftTextSteps.xs,
                    weight: FontWeight.w600,
                    color: t.colors['danger-strong'],
                  ),
                ),
              ),
          ],
          if (showInvite) ...[
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: hairline),
            const SizedBox(height: 16),
            Text(
              raftText(context, 'Channel connection invitation'),
              style: eyebrow,
            ),
            const SizedBox(height: 12),
            if (limitReached)
              Text(
                raftFormat(
                  context,
                  'Joint channels support a maximum of {max} servers.',
                  {'max': maxServers},
                ),
                key: const ValueKey('channel-settings-joint-max-servers'),
                style: raftCssTextStyle(
                  family: t.bodyFont,
                  step: RaftTextSteps.sm,
                  color: hint,
                ),
              )
            else
              Column(
                key: const ValueKey('channel-settings-joint-invite-form'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftProductFormField(
                    label: 'Server slug',
                    uppercase: false,
                    required: true,
                    labelWeight: FontWeight.w500,
                    family: t.bodyFont,
                    error: slugError,
                    child: RaftSlugInput(
                      key: const ValueKey('channel-settings-joint-server-slug'),
                      controller: slug,
                      enabled: !inviteBusy,
                      invalid: slugError != null,
                      hintText: raftText(context, 'e.g. partner-workspace'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RaftProductFormField(
                    label: 'Invited people',
                    uppercase: false,
                    required: true,
                    labelWeight: FontWeight.w500,
                    family: t.bodyFont,
                    hint: raftText(
                      context,
                      'Use target-server owner/admin handles or emails, separated by commas or new lines.',
                    ),
                    error: peopleError,
                    child: RaftDialogTextInput(
                      fieldKey: const ValueKey(
                        'channel-settings-joint-invited-people',
                      ),
                      controller: people,
                      enabled: !inviteBusy,
                      multiline: true,
                      placeholder: '@admin or admin@example.com',
                    ),
                  ),
                  if (sameAdminNotice != null) ...[
                    const SizedBox(height: 12),
                    sameAdminNotice!,
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: RaftSettingsRecipeButton(
                      key: const ValueKey('channel-settings-joint-send-invite'),
                      label: inviteBusy ? 'Inviting…' : 'Send Invite',
                      glyph: RaftGlyph.mail,
                      glyphSize: 16,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: inviteBusy || !canSend ? null : onSendInvite,
                    ),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 12),
                    RaftBanner(
                      key: const ValueKey(
                        'channel-settings-joint-invite-submit-error',
                      ),
                      description: submitError!,
                      descriptionWeight: FontWeight.w700,
                    ),
                  ],
                  if (status != null && status!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        status!,
                        key: const ValueKey('channel-settings-joint-status'),
                        style: raftCssTextStyle(
                          family: t.bodyFont,
                          step: RaftTextSteps.xs,
                          color: hint,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
