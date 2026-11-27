import 'overlays/dialog.dart' show RaftDialog;
// Web `member/InviteHumanDialog.tsx`: the "Invite human" DialogCard (`max-w-lg`)
// with the By email / By link segmented control, one row per invitee (email
// Input + optional role Select + remove), "Add another", the join-link field
// with its limits, and Cancel / Send invites. Presentation only: the app owns
// requests, billing gates and navigation.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption;
import 'raft/button.dart';
import 'interaction.dart';
import 'label.dart';

import 'package:flutter/material.dart';

import 'form_presentation.dart';

import 'banner.dart';
import 'dialog_card.dart';
import 'error_presentation.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'select_field.dart';
import 'theme.dart';

class RaftInvitee {
  RaftInvitee({this.email = ''}) : id = _next++;
  static int _next = 0;
  final int id;
  String email;
}

/// State of the join link the By link tab shows.
class RaftInviteLink {
  const RaftInviteLink({
    this.loading = false,
    this.url,
    this.copied = false,
    this.hasLink = false,
    this.maxUses,
    this.expiresAt,
    this.expiresOn,
    this.usedLabel,
  });
  final bool loading, copied, hasLink;
  final String? url, usedLabel, expiresOn, expiresAt;
  final int? maxUses;
}

class RaftInviteHumanDialog extends StatefulWidget {
  const RaftInviteHumanDialog({
    super.key,
    required this.onClose,
    required this.onSend,
    this.link = const RaftInviteLink(),
    this.onCopyLink,
    this.onApplyLink,
    this.onRevokeLink,
    this.initialTab = 'email',
    this.seatLimitMessage,
    this.onViewBilling,
  });
  final VoidCallback onClose;
  final Future<void> Function(List<String> invites) onSend;
  final RaftInviteLink link;
  final VoidCallback? onCopyLink, onRevokeLink;

  /// Apply: `(maxUsesChoice, expiryChoice)` as the Select values.
  final void Function(String maxUses, String expiry)? onApplyLink;
  final String initialTab;
  final String? seatLimitMessage;
  final VoidCallback? onViewBilling;
  @override
  State<RaftInviteHumanDialog> createState() => _RaftInviteHumanDialogState();
}

class _RaftInviteHumanDialogState extends State<RaftInviteHumanDialog> {
  late String tab = widget.initialTab;
  final invitees = <RaftInvitee>[RaftInvitee()];
  final controllers = <int, TextEditingController>{};
  bool sending = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next send starts; the dialog state is dropped when it closes.
  String? error;

  /// The last send had no email: the prompt holds only while no row has one.
  bool emailRequired = false;
  late String maxUses = widget.link.maxUses == null ? 'unlimited' : 'keep';
  late String expiry = widget.link.expiresAt == null ? 'never' : 'keep';
  final _linkController = TextEditingController();

  @override
  void didUpdateWidget(RaftInviteHumanDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.link.url != oldWidget.link.url &&
        (widget.link.hasLink || !widget.link.loading)) {
      maxUses = widget.link.maxUses == null ? 'unlimited' : 'keep';
      expiry = widget.link.expiresAt == null ? 'never' : 'keep';
    }
  }

  TextEditingController controllerFor(RaftInvitee i) =>
      controllers.putIfAbsent(i.id, () {
        final c = TextEditingController(text: i.email);
        // The seat-limit banner follows the typed rows, so a change rebuilds.
        c.addListener(() {
          if (i.email == c.text) return;
          i.email = c.text;
          if (mounted) setState(() {});
        });
        return c;
      });

  @override
  void dispose() {
    _linkController.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> send() async {
    final targets = [
      for (final i in invitees)
        if (i.email.trim().isNotEmpty) i.email.trim(),
    ];
    if (targets.isEmpty) {
      setState(() {
        error = null;
        emailRequired = true;
      });
      return;
    }
    setState(() {
      sending = true;
      error = null;
      emailRequired = false;
    });
    try {
      await widget.onSend(targets);
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = raftErrorMessage(
            context,
            e,
            fallback: 'Failed to send invites',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final seatReached =
        widget.seatLimitMessage != null &&
        tab == 'email' &&
        invitees.any((i) => i.email.trim().isNotEmpty);
    final shownError =
        error ??
        (emailRequired && invitees.every((i) => i.email.trim().isEmpty)
            ? raftText(
                context,
                'Enter at least one email, or copy the invite link above.',
              )
            : null);
    final sheet = RaftFormFrame.sheetOf(context);
    final gap = RaftInteraction.of(context).touch ? 16.0 : 12.0;
    final sendButton = RaftButton(
      key: const ValueKey('invite-send'),
      label: sending ? 'Sending…' : 'Invite',
      glyph: RaftGlyph.mail,
      uiVariant: RaftButtonVariant.primary,
      uiSize: sheet ? RaftButtonSize.md : RaftButtonSize.lg,
      onPressed: sending || seatReached ? null : send,
    );
    // Web `Modal`: full-window backdrop, `p-4` frame, centred column.
    return RaftModalBackdrop(
      child: Material(
        type: MaterialType.transparency,
        child: RaftDialog.card(
          key: const ValueKey('invite-dialog'),
          title: 'Invite human',
          maxWidth: 512,
          onClose: widget.onClose,
          sheetCommit: tab == 'email' ? sendButton : const SizedBox.shrink(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // `space-y-4`
              if (shownError != null && !seatReached) ...[
                RaftErrorBanner(shownError, bold: true),
                SizedBox(height: gap),
              ],
              if (seatReached) ...[
                RaftBanner(
                  description: widget.seatLimitMessage!,
                  descriptionTail: widget.onViewBilling == null
                      ? null
                      : (
                          label: raftText(context, 'View billing'),
                          onPressed: widget.onViewBilling!,
                        ),
                ),
                SizedBox(height: gap),
              ],
              // `member.invite.agentReachHint`: any member can DM and direct
              // every agent in the server, so the dialog says so up front.
              RaftBanner(
                key: const ValueKey('invite-agent-reach-hint'),
                status: RaftBannerRecipeStatus.info,
                glyph: RaftGlyph.info,
                description: raftText(
                  context,
                  'Everyone in this server can message and work with every agent here. For agents that are just for you, use a server of your own.',
                ),
              ),
              SizedBox(height: gap),
              RaftSegmentedControl<String>(
                expand: true,
                value: tab,
                label: raftText(context, 'Invite method'),
                items: const [
                  RaftSegmentedOption(value: 'email', label: 'By email'),
                  RaftSegmentedOption(
                    value: 'link',
                    label: 'By link',
                    itemKey: ValueKey('invite-tab-link'),
                  ),
                ],
                onChanged: (v) => setState(() => tab = v),
              ),
              SizedBox(height: gap),
              if (tab == 'email') _email(context, t) else _link(context, t),
            ],
          ),
          footer: sheet
              ? null
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: 12,
                  children: [
                    RaftButton(
                      label: 'Cancel',
                      uiVariant: RaftButtonVariant.ghost,
                      uiSize: RaftButtonSize.lg,
                      onPressed: raftExplicitClose(context, widget.onClose),
                    ),
                    if (tab == 'email') sendButton,
                  ],
                ),
        ),
      ),
    );
  }

  /// The Web's `FIELD_LABEL_CLASS` label (13/18 600 ink-2) is a [RaftLabel].
  Widget _fieldLabel(BuildContext context, RaftTokens t, String text) {
    // `mb-1.5` under the label.
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RaftLabel(text),
    );
  }

  Widget _email(BuildContext context, RaftTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _fieldLabel(context, t, 'Invite by email'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, invitee) in invitees.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RaftDialogTextInput(
                    fieldKey: ValueKey('invite-email-$index'),
                    controller: controllerFor(invitee),
                    placeholder: 'name@company.com',
                  ),
                ),
                if (invitees.length > 1) ...[
                  const SizedBox(width: 8),
                  RaftRecipeButton(
                    glyph: RaftGlyph.trash2,
                    glyphSize: 14,
                    variant: RaftButtonRecipeVariant.danger,
                    size: RaftButtonRecipeSize.iconXs,
                    tooltip: raftFormat(context, 'Remove Invitee {index}', {
                      'index': index + 1,
                    }),
                    onPressed: () => setState(() => invitees.remove(invitee)),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftRecipeButton(
              key: const ValueKey('invite-add'),
              label: raftText(context, 'Add another'),
              glyph: RaftGlyph.plus,
              glyphSize: 14,
              variant: RaftButtonRecipeVariant.ghost,
              size: RaftButtonRecipeSize.sm,
              onPressed: () => setState(() => invitees.add(RaftInvitee())),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _link(BuildContext context, RaftTokens t) {
    final link = widget.link;
    final urlText = link.loading
        ? raftText(context, 'Preparing invite link…')
        : link.url ?? raftText(context, 'Invite link unavailable');
    _linkController.text = urlText;
    RaftSelectItem<String> item(String v, String label) =>
        RaftSelectItem(value: v, label: raftText(context, label));
    final muted = t.colors['foreground-muted'];
    Widget labelText(String text) => Text(
      raftText(context, text),
      style: TextStyle(
        fontFamily: t.headingFont,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, t, 'Invite link'),
        Row(
          children: [
            Expanded(
              child: RaftDialogTextInput(
                fieldKey: const ValueKey('invite-link-field'),
                controller: _linkController,
                readOnly: true,
                mono: true,
              ),
            ),
            const SizedBox(width: 8),
            RaftRecipeButton(
              key: const ValueKey('invite-link-copy'),
              glyph: link.copied ? RaftGlyph.check : RaftGlyph.copy,
              glyphSize: 14,
              size: RaftButtonRecipeSize.iconMd,
              tooltip: raftText(context, 'Copy invite link'),
              disabled: link.url == null || link.loading,
              onPressed: widget.onCopyLink,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                labelText('Uses'),
                const SizedBox(width: 6),
                SizedBox(
                  width: 128,
                  child: RaftSelectField<String>(
                    value: maxUses,
                    label: raftText(context, 'Uses'),
                    items: [
                      if (link.maxUses != null) item('keep', 'Keep current'),
                      item('unlimited', 'Unlimited'),
                      item('1', '1 use'),
                      item('5', '5 uses'),
                      item('10', '10 uses'),
                      item('25', '25 uses'),
                      item('100', '100 uses'),
                    ],
                    onChanged: (v) => setState(() => maxUses = v ?? maxUses),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                labelText('Expires'),
                const SizedBox(width: 6),
                SizedBox(
                  width: 128,
                  child: RaftSelectField<String>(
                    value: expiry,
                    label: raftText(context, 'Expires'),
                    items: [
                      if (link.expiresAt != null) item('keep', 'Keep current'),
                      item('never', 'Never'),
                      item('1h', '1 hour'),
                      item('1d', '1 day'),
                      item('7d', '7 days'),
                      item('30d', '30 days'),
                    ],
                    onChanged: (v) => setState(() => expiry = v ?? expiry),
                  ),
                ),
              ],
            ),
            RaftRecipeButton(
              key: const ValueKey('invite-link-apply'),
              label: raftText(context, 'Update link'),
              size: RaftButtonRecipeSize.sm,
              disabled: link.loading,
              onPressed: widget.onApplyLink == null
                  ? null
                  : () => widget.onApplyLink!(maxUses, expiry),
            ),
            if (link.hasLink)
              GestureDetector(
                key: const ValueKey('invite-link-revoke'),
                onTap: widget.onRevokeLink,
                child: Text(
                  raftText(context, 'Revoke link'),
                  style: TextStyle(
                    fontFamily: t.headingFont,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w700,
                    color: t.colors['accent-strong'],
                  ),
                ),
              ),
          ],
        ),
        if (link.hasLink) ...[
          const SizedBox(height: 4),
          Text(
            raftText(
              context,
              'Updating replaces the current link — the old one stops working.',
            ),
            style: TextStyle(
              fontFamily: t.headingFont,
              fontSize: 11,
              height: 16.5 / 11,
              color: muted?.withValues(alpha: .8),
            ),
          ),
        ],
        if (link.usedLabel != null || link.expiresOn != null) ...[
          const SizedBox(height: 4),
          Text(
            [?link.usedLabel, ?link.expiresOn].join(' · '),
            key: const ValueKey('invite-link-status'),
            style: TextStyle(
              fontFamily: t.headingFont,
              fontSize: 12,
              height: 16 / 12,
              color: muted,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            RaftIcon(RaftGlyph.link2, size: 12, color: muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                raftText(
                  context,
                  widget.seatLimitMessage != null
                      ? 'This link will show a seat-limit message until you add a human seat.'
                      : 'Send this link to your teammates to join the server.',
                ),
                style: TextStyle(
                  fontFamily: t.headingFont,
                  fontSize: 12,
                  height: 16 / 12,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
