part of 'channel_members_view.dart';

// Web components/channel/ExternalInviteRows.tsx: an open external invite is a
// `ChannelMemberRow` with a Mail tile instead of an avatar, so it belongs
// beside the member row and inherits its inset, minimum height, hairline and
// hover-revealed actions. The group above it is the same `MemberPageSection`
// as Humans and Agents (features/channel/ChannelMembers.tsx:1120-1128).
//
// The app owns the reads and the two requests; this file owns the chrome.

/// One open external invite of the members page's Invited group
/// (`ExternalInviteRow`).
@immutable
class RaftChannelInvite {
  const RaftChannelInvite({
    required this.email,
    required this.state,
    this.id,
    this.canResend = false,
    this.revocable = true,
    this.busy = false,
    this.onResend,
    this.onWithdraw,
  });

  /// The invitee's address: the row's title.
  final String email;

  /// Where the invite stands, after the email in hint ink: the days left, or
  /// that it is connecting a server or waiting for an approver
  /// (ExternalInviteRows.tsx:40-49).
  final String state;

  /// Keys the row `external-invite-<id>`, as a member row's testId does.
  final String? id;

  /// A resend is a fresh send, so it needs the feature on and an invite that
  /// is neither connecting nor awaiting approval (ExternalInviteRows.tsx:51).
  final bool canResend;

  /// The server refuses to withdraw an invite whose conversion it already
  /// started (:53): Withdraw renders disabled with the reason in its tooltip.
  final bool revocable;

  /// A request for this invite is in flight: both actions are inert.
  final bool busy;

  final VoidCallback? onResend, onWithdraw;
}

/// The members page's Invited group: Web's failed-read notice
/// (ChannelMembers.tsx:729-743) above `MemberPageSection kind="invited"`
/// (:1120-1128). Renders nothing when there is neither.
class RaftChannelInvitedGroup extends StatelessWidget {
  const RaftChannelInvitedGroup({
    super.key,
    this.invites = const [],
    this.onRetry,
  });

  final List<RaftChannelInvite> invites;

  /// Set when the read failed and nothing is cached: Web's warning banner
  /// with Retry, in its own `p-3` box.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty && onRetry == null) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    // Above the default text size the state moves under the email instead of
    // squeezing it, as the member row's own name and detail do.
    final grows = RaftScaled.grows(context);
    final box = resolveRecipeClasses(
      const ['p-3'],
      t.recipeStates(),
      t.recipeTokens,
    );
    // `ExternalInviteRows.tsx:107` actions span: `flex items-center gap-1`.
    final gap =
        resolveRecipeClasses(
          const ['gap-1'],
          t.recipeStates(),
          t.recipeTokens,
        ).columnGap ??
        0;
    // `text-caption font-normal text-foreground-hint` (:159).
    final stateStyle = t.scale(
      RaftTypeScale.caption,
      color: t.ui.foregroundHint,
      weight: FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onRetry case final retry?)
          Padding(
            padding: box.padding,
            child: RaftErrorBanner(
              raftText(context, "Couldn't load the invites."),
              onRetry: retry,
              retryLabel: 'Retry',
            ),
          ),
        if (invites.isNotEmpty)
          _MemberSection(
            key: const ValueKey('member-page-section-invited'),
            label: raftText(context, 'Invited'),
            count: invites.length,
            rows: [
              for (final invite in invites)
                RaftMemberRowData(
                  testId: invite.id == null
                      ? null
                      : 'external-invite-${invite.id}',
                  label: invite.email,
                  searchText: invite.email,
                  avatar: const RaftIconTile(glyph: RaftGlyph.mail),
                  badge: grows ? null : Text(invite.state, style: stateStyle),
                  secondary: grows ? invite.state : null,
                  actions: _inviteActions(context, invite, gap),
                ),
            ],
          ),
      ],
    );
  }

  /// Mail resends, X withdraws: ghost `icon-md` buttons with short tooltips,
  /// revealed on row hover by the member row itself (:96-137).
  Widget _inviteActions(
    BuildContext context,
    RaftChannelInvite invite,
    double gap,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: gap,
    children: [
      if (invite.canResend)
        RaftButton(
          glyph: RaftGlyph.mail,
          uiSize: RaftButtonSize.iconMd,
          uiVariant: RaftButtonVariant.ghost,
          tooltip: raftText(context, 'Resend invite'),
          onPressed: invite.busy ? null : invite.onResend,
        ),
      RaftButton(
        glyph: RaftGlyph.x,
        uiSize: RaftButtonSize.iconMd,
        uiVariant: RaftButtonVariant.ghost,
        tooltip: raftText(
          context,
          invite.revocable ? 'Withdraw invite' : 'You can withdraw this invite once its server finishes connecting.',
        ),
        onPressed: invite.busy || !invite.revocable ? null : invite.onWithdraw,
      ),
    ],
  );
}
