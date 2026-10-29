// Web components/auth/InviteAcceptPage.tsx: the page an invite link opens
// (signed out: sign in / create account; signed in: join). Presentation only:
// the app loads the invite, joins and navigates.
import 'package:flutter/material.dart';

import 'auth_page.dart';
import 'components.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'settings_administration.dart' show RaftAgreementBody;
import 'theme.dart';

/// `GET /auth/invite-info`.
class RaftInviteInfo {
  const RaftInviteInfo({
    required this.serverName,
    this.joinLink = false,
    this.inviterName,
    this.memberCount = 0,
    this.agentCount = 0,
    this.insideCountsHidden = false,
    this.humanSeatLimitReached = false,
    this.agreementTitle,
    this.agreementVersion,
    this.agreementBody,
  });

  /// `kind === "join_link"` (no inviter) instead of an email invite.
  final bool joinLink;
  final String serverName;
  final String? inviterName;
  final int memberCount, agentCount;
  final bool insideCountsHidden, humanSeatLimitReached;

  /// The pre-join agreement the member accepts by joining.
  final String? agreementTitle, agreementBody;
  final int? agreementVersion;
  bool get hasAgreement => agreementTitle != null;
}

/// The page's screens, in the order the Web page tests them.
enum RaftInviteStage { loading, accepted, ready }

/// Loading ("Loading invite…"), accepted ("You're in" + Continue to Raft) or
/// the invite itself: error banner, details, agreement, seat limit, and the
/// signed-in Join button or the signed-out Sign In / Create Account pair.
class RaftInviteAcceptPage extends StatelessWidget {
  const RaftInviteAcceptPage({
    super.key,
    required this.stage,
    this.info,
    this.errorText = '',
    this.signedIn = false,
    this.accepting = false,
    this.acceptedServerName = '',
    this.onJoin,
    this.onContinue,
    this.onSignIn,
    this.onCreateAccount,
    this.onGoToRaft,
    this.server,
    this.onServer,
  });
  final RaftInviteStage stage;
  final RaftInviteInfo? info;

  /// The load, validation or accept failure (a Banner under "Invite error").
  final String errorText;
  final bool signedIn, accepting;
  final String acceptedServerName;
  final VoidCallback? onJoin, onContinue, onSignIn, onCreateAccount, onGoToRaft;

  /// Native-only server origin control of the top bar.
  final String? server;
  final VoidCallback? onServer;

  /// Splits a catalog sentence with `<tag></tag>` placeholders around bold runs.
  static InlineSpan rich(
    String template,
    Map<String, String> bold,
    TextStyle strong,
  ) {
    final pattern = RegExp('<(${bold.keys.join('|')})></\\1>');
    final children = <InlineSpan>[];
    var from = 0;
    for (final match in pattern.allMatches(template)) {
      if (match.start > from) {
        children.add(TextSpan(text: template.substring(from, match.start)));
      }
      children.add(TextSpan(text: bold[match.group(1)], style: strong));
      from = match.end;
    }
    if (from < template.length) {
      children.add(TextSpan(text: template.substring(from)));
    }
    return TextSpan(children: children);
  }

  /// `renderInsideCount` / `renderInsidePreview`: one whole sentence per shape
  /// (humans and agents, humans, agents, everyone); null when nothing to name.
  static InlineSpan? inside(
    BuildContext context,
    RaftInviteInfo info,
    TextStyle strong,
  ) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    String humans(int n) =>
        chinese ? '$n 位人类' : (n == 1 ? '1 human' : '$n humans');
    String agents(int n) =>
        chinese ? '$n 个 Agent' : (n == 1 ? '1 agent' : '$n agents');
    InlineSpan sentence(
      String before,
      List<String> bolds,
      List<String> glue,
      String after,
    ) {
      final children = <InlineSpan>[TextSpan(text: before)];
      for (final (i, text) in bolds.indexed) {
        if (i > 0) children.add(TextSpan(text: glue[i - 1]));
        children.add(TextSpan(text: text, style: strong));
      }
      children.add(TextSpan(text: after));
      return TextSpan(children: children);
    }

    if (info.insideCountsHidden) {
      return sentence(
        chinese ? '认识里面的' : 'Meet ',
        [chinese ? '所有人' : 'everyone'],
        const [],
        chinese ? '。' : ' inside.',
      );
    }
    final h = info.memberCount, a = info.agentCount;
    if (h > 0 && a > 0) {
      return sentence(
        chinese ? '认识里面的 ' : 'Meet ',
        [humans(h), agents(a)],
        [chinese ? ' 和 ' : ' and '],
        chinese ? '。' : ' inside.',
      );
    }
    if (h > 0) {
      return sentence(
        chinese ? '认识里面的 ' : 'Meet ',
        [humans(h)],
        const [],
        chinese ? '。' : ' inside.',
      );
    }
    if (a > 0) {
      return sentence(
        chinese ? '认识里面的 ' : 'Meet ',
        [agents(a)],
        const [],
        chinese ? '。' : ' inside.',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final body = RaftTypography.heading(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w400,
      color: t.muted,
    );
    final strong = body.copyWith(
      fontWeight: FontWeight.w700,
      color: t.semantic.foreground,
    );
    final children = <Widget>[];
    if (stage == RaftInviteStage.loading) {
      children.add(RaftAuthIntro(title: tr('Loading invite…')));
    } else if (stage == RaftInviteStage.accepted) {
      children
        ..add(
          RaftAuthIntro(
            title: tr("You're in"),
            descriptionSpan: rich(tr("You've joined <server></server>."), {
              'server': acceptedServerName,
            }, strong),
          ),
        )
        ..add(
          RaftAuthWideButton(
            key: const ValueKey('invite-continue'),
            label: tr('Continue to Raft'),
            variant: RaftControlVariant.accent,
            onPressed: onContinue,
          ),
        );
    } else {
      final invite = info;
      final seatLimit = invite?.humanSeatLimitReached == true;
      final canAct = invite != null && errorText.isEmpty && !seatLimit;
      if (errorText.isNotEmpty) {
        children
          ..add(RaftAuthIntro(title: tr('Invite error')))
          ..add(_gap(RaftAuthBanner(text: errorText), 24));
      } else if (invite != null) {
        final inside = RaftInviteAcceptPage.inside(context, invite, strong);
        children.add(
          RaftAuthIntro(
            title: tr(invite.joinLink ? 'Join this server' : "You're invited"),
            descriptionSpan: invite.joinLink
                ? rich(tr('Use this link to join <server></server> on Raft.'), {
                    'server': invite.serverName,
                  }, strong)
                : rich(
                    tr(
                      '<inviter></inviter> invited you to join <server></server> on Raft.',
                    ),
                    {
                      'inviter': invite.inviterName ?? '',
                      'server': invite.serverName,
                    },
                    strong,
                  ),
            children: [
              if (inside != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text.rich(
                    inside,
                    textAlign: TextAlign.center,
                    style: body,
                  ),
                ),
            ],
          ),
        );
        if (invite.hasAgreement) {
          children.add(_gap(_AgreementCard(info: invite), 16));
        }
        if (seatLimit) {
          children.add(
            _gap(
              RaftAuthBanner(
                text: tr(
                  'This server has no available human seats right now. Contact the server owner to add a human seat, then try this link again.',
                ),
              ),
              24,
            ),
          );
        }
      }
      if (accepting) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              tr('Joining server…'),
              textAlign: TextAlign.center,
              style: body,
            ),
          ),
        );
      }
      if (canAct && signedIn) {
        children.add(
          RaftAuthWideButton(
            key: const ValueKey('invite-join'),
            label: accepting
                ? tr('Joining Server…')
                : tr(invite.hasAgreement ? 'Agree & Join' : 'Join Server'),
            variant: RaftControlVariant.accent,
            onPressed: accepting ? null : onJoin,
          ),
        );
      }
      if (canAct && !signedIn) {
        children.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  tr('Sign in or create an account to accept this invite.'),
                  textAlign: TextAlign.center,
                  style: body,
                ),
              ),
              RaftAuthWideButton(
                key: const ValueKey('invite-sign-in'),
                label: tr('Sign In'),
                variant: RaftControlVariant.accent,
                leading: RaftIcon(RaftGlyph.logIn, size: 16),
                gap: 8,
                onPressed: onSignIn,
              ),
              const SizedBox(height: 12),
              RaftButton(
                key: const ValueKey('invite-create-account'),
                label: tr('Create Account'),
                glyph: RaftGlyph.userPlus,
                variant: RaftControlVariant.outline,
                size: RaftButtonRecipeSize.sm,
                expand: true,
                onPressed: onCreateAccount,
              ),
            ],
          ),
        );
      }
      if (errorText.isNotEmpty || seatLimit) {
        children.add(
          RaftButton(
            key: const ValueKey('invite-go-to-raft'),
            label: tr('Go to Raft'),
            glyph: RaftGlyph.arrowLeft,
            variant: RaftControlVariant.outline,
            size: RaftButtonRecipeSize.sm,
            expand: true,
            onPressed: onGoToRaft,
          ),
        );
      }
    }
    return RaftAuthShell(
      server: server,
      onServer: onServer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  static Widget _gap(Widget child, double bottom) => Padding(
    padding: EdgeInsets.only(bottom: bottom),
    child: child,
  );
}

/// `card-brutal mb-4 p-4 text-left`: agreement title and version over the
/// scrollable body box (`max-h-56 rounded-md border border-line-muted
/// bg-layer-canvas-muted p-3 text-sm`; brutal: square, `border-2
/// border-black/30 bg-brutal-cream`).
class _AgreementCard extends StatelessWidget {
  const _AgreementCard({required this.info});
  final RaftInviteInfo info;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftPanel(
      key: const ValueKey('invite-agreement'),
      style: RaftPanelStyle.legacyCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.agreementTitle!,
                  style: RaftTypography.heading(
                    t,
                    size: 14,
                    line: 20,
                    color: t.strong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  raftFormat(context, 'Version {version}', {
                    'version': info.agreementVersion,
                  }),
                  style: RaftTypography.heading(
                    t,
                    size: 12,
                    line: 16,
                    weight: FontWeight.w400,
                    color: t.semantic.foregroundHint,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 224),
            child: Container(
              decoration: BoxDecoration(
                color: t.sidebar,
                border: Border.all(
                  color: t.semantic.lineMuted,
                  width: t.border,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.all(12),
                child: RaftAgreementBody(
                  source: info.agreementBody ?? '',
                  style: RaftTypography.heading(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w400,
                    color: t.semantic.foreground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
