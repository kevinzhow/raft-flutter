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

import 'package:flutter/material.dart';

import 'form_presentation.dart';

import 'banner.dart';
import 'design_primitives.dart'
    show RaftLayoutMetrics, RaftTextLink, RaftTextLinkVariant;
import 'dialog_card.dart';
import 'error_presentation.dart';
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'select_field.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftDesktopMetrics, RaftTypeScale;
import 'viewport_breakpoints.dart';

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
    final fineWide =
        raftBreakpointWidth(context) >= RaftLayoutMetrics.desktopBreakpoint &&
        !RaftInteraction.of(context).touch;
    final gap = fineWide ? 12.0 : 16.0;
    final sendButton = RaftButton(
      key: const ValueKey('invite-send'),
      label: sending ? 'Sending…' : 'Invite',
      glyph: RaftGlyph.mail,
      glyphSize: 18,
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
          footerGap: gap,
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
                  descriptionBuilder: widget.onViewBilling == null
                      ? null
                      : (style) => RaftCssText.rich(
                          TextSpan(
                            text: '${widget.seatLimitMessage!} ',
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: RaftTextLink(
                                  label: raftText(context, 'View billing'),
                                  variant: RaftTextLinkVariant.strong,
                                  typeStyle: style.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onPressed: widget.onViewBilling,
                                ),
                              ),
                            ],
                          ),
                          style: style,
                        ),
                ),
                SizedBox(height: gap),
              ],
              // `member.invite.agentReachHint`: any member can DM and direct
              // every agent in the server, so the dialog says so up front.
              RaftBanner(
                key: const ValueKey('invite-agent-reach-hint'),
                status: RaftBannerRecipeStatus.info,
                browserFillBlend: true,
                glyph: RaftGlyph.info,
                description: raftText(
                  context,
                  'Everyone in this server can message and work with every agent here. For agents that are just for you, use a server of your own.',
                ),
              ),
              SizedBox(height: gap),
              RaftSegmentedControl<String>(
                expand: true,
                visualHeight: fineWide ? RaftDesktopMetrics.controlHeight : 32,
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
              if (tab == 'email') _email(context) else _link(context, t),
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

  Widget _label(BuildContext context, String text) {
    final tokens = RaftTokens.of(context);
    return RaftCssText(
      raftText(context, text),
      style: tokens.scale(
        RaftTypeScale.footnote,
        weight: FontWeight.w600,
        color: tokens.ui.foregroundMuted,
      ),
    );
  }

  Widget _email(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label(context, 'Invite by email'),
      const SizedBox(height: 6),
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
                    semanticLabel: 'Email address',
                  ),
                ),
                if (invitees.length > 1) ...[
                  const SizedBox(width: 8),
                  RaftButton(
                    glyph: RaftGlyph.trash2,
                    glyphSize: 18,
                    uiVariant: RaftButtonVariant.ghost,
                    uiSize: RaftButtonSize.iconLg,
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
            child: RaftButton(
              key: const ValueKey('invite-add'),
              label: raftText(context, 'Add another'),
              glyph: RaftGlyph.plus,
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.md,
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
    final captionStyle = t.scale(
      RaftTypeScale.caption,
      color: t.ui.foregroundHint,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Invite link'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: RaftDialogTextInput(
                fieldKey: const ValueKey('invite-link-field'),
                controller: _linkController,
                readOnly: true,
                mono: true,
                textStep: (
                  RaftTypeScale.monoCode.fontSize,
                  RaftTypeScale.monoCode.lineHeight,
                ),
                semanticLabel: 'Invite link',
              ),
            ),
            const SizedBox(width: 8),
            RaftButton(
              key: const ValueKey('invite-link-copy'),
              glyph: link.copied ? RaftGlyph.check : RaftGlyph.copy,
              glyphSize: 20,
              uiSize: RaftButtonSize.iconLg,
              uiVariant: RaftButtonVariant.outline,
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
                _label(context, 'Uses'),
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
                _label(context, 'Expires'),
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
            RaftButton(
              key: const ValueKey('invite-link-apply'),
              label: raftText(context, 'Update link'),
              uiSize: RaftButtonSize.md,
              uiVariant: RaftButtonVariant.outline,
              disabled: link.loading,
              onPressed: widget.onApplyLink == null
                  ? null
                  : () => widget.onApplyLink!(maxUses, expiry),
            ),
            if (link.hasLink)
              RaftTextLink(
                key: const ValueKey('invite-link-revoke'),
                onPressed: widget.onRevokeLink,
                label: raftText(context, 'Revoke link'),
                variant: RaftTextLinkVariant.muted,
                scale: RaftTypeScale.footnote,
              ),
          ],
        ),
        if (link.hasLink) ...[
          const SizedBox(height: 6),
          RaftCssText(
            raftText(
              context,
              'Updating replaces the current link — the old one stops working.',
            ),
            style: captionStyle,
          ),
        ],
        if (link.usedLabel != null || link.expiresOn != null) ...[
          const SizedBox(height: 6),
          RaftCssText(
            [?link.usedLabel, ?link.expiresOn].join(' · '),
            key: const ValueKey('invite-link-status'),
            style: captionStyle,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            RaftIcon(RaftGlyph.link, size: 14, color: t.ui.foregroundHint),
            const SizedBox(width: 6),
            Flexible(
              child: RaftCssText(
                raftText(
                  context,
                  widget.seatLimitMessage != null
                      ? 'This link will show a seat-limit message until you add a human seat.'
                      : 'Send this link to your teammates to join the server.',
                ),
                style: captionStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
