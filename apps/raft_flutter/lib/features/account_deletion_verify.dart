// Delete Account's proof that it is the person (Web features/settings/
// account/DeleteAccountVerifyDialog.tsx, design §4), as the server's
// `methods` ask, over the Delete Account page:
//   - two-step verification: the app's "Verify it's you" ([showVerifyItsYou]:
//     authenticator code, backup code), sent as `secondFactor`;
//   - a password: `password`, in the same request;
//   - neither (social sign-in only): an emailed 6-digit code, `emailCode`.
// One field each: a small dialog (a sheet on a phone).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'account_deletion_flow.dart';
import 'account_security_answer.dart';
import 'account_security_dialogs.dart';
import 'second_factor_step_up.dart';

/// Shows the step [reauth] names. Resolves when the dialog closes: cancelled,
/// or another phase took over ([submit] answered "moved").
Future<void> showAccountDeletionProof(
  BuildContext context,
  RaftClient client,
  AccountDeletionReauth reauth, {
  required AccountDeletionSubmit submit,

  /// To the proof a refusal names instead (Send code's 409
  /// `email_code_not_available`); sends nothing.
  required void Function(AccountDeletionReauth reauth) moveToReauth,
  required VoidCallback onSignOut,
}) async {
  switch (reauth) {
    case AccountDeletionSecondFactor():
      await showVerifyItsYou(
        context,
        client,
        methods: reauth.methods,
        description: raftText(
          context,
          "Confirm it's you to delete your account.",
        ),
        onSignInAgain: onSignOut,
        onAnswer: (answer) async {
          final outcome = await submit(
            AccountDeletionProof.secondFactor(answer),
          );
          if (outcome is AccountDeletionFailed) throw outcome.error;
          if (outcome is AccountDeletionNeedsSignIn) {
            throw RaftApiException.response(
              'session_family_required',
              status: 403,
              body: {
                'error': 'session_family_required',
                'code': 'session_family_required',
              },
            );
          }
        },
      );
    case AccountDeletionPassword():
      await showSecondFactorStep<void>(
        context,
        label: "Verify it's you",
        builder: (_) =>
            _PasswordStep(client: client, submit: submit, onSignOut: onSignOut),
      );
    case AccountDeletionEmailCode():
      await showSecondFactorStep<void>(
        context,
        label: "Verify it's you",
        builder: (_) => _EmailCodeStep(
          client: client,
          submit: submit,
          moveToReauth: moveToReauth,
          onSignOut: onSignOut,
        ),
      );
  }
}

class _PasswordStep extends StatefulWidget {
  const _PasswordStep({
    required this.client,
    required this.submit,
    required this.onSignOut,
  });
  final RaftClient client;
  final AccountDeletionSubmit submit;
  final VoidCallback onSignOut;

  @override
  State<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<_PasswordStep>
    with SecondFactorAnswerState {
  bool signInAgain = false;

  Future<void> send() async {
    if (answer.text.isEmpty || busy) return;
    setState(() => signInAgain = false);
    await attempt(
      () async {
        final outcome = await widget.submit(
          AccountDeletionProof.password(answer.text),
        );
        if (!mounted) return;
        if (outcome is AccountDeletionMoved) {
          Navigator.of(context).pop();
          return;
        }
        final shown = accountDeletionFailure(
          context,
          widget.client,
          outcome,
          SecondFactorAnswerKind.password,
        );
        setState(() {
          fieldError = shown.field;
          bannerError = shown.banner;
          signInAgain = shown.signInAgain;
        });
      },
      client: widget.client,
      kind: SecondFactorAnswerKind.password,
      handled: (_) => true,
    );
  }

  @override
  Widget build(BuildContext context) => SecondFactorStepDialog(
    key: const ValueKey('account-deletion-password'),
    title: raftText(context, "Verify it's you"),
    busy: busy,
    actions: [
      secondFactorCancel(context, busy: busy),
      secondFactorCommit(
        context,
        label: raftText(context, 'Delete account'),
        variant: RaftButtonRecipeVariant.danger,
        busy: busy,
        onPressed: answer.text.isEmpty ? null : send,
      ),
    ],
    children: [
      SecondFactorAnswerField(
        kind: SecondFactorAnswerKind.password,
        controller: answer,
        enabled: !busy,
        error: fieldError,
        onChanged: changed,
        onSubmitted: send,
      ),
      if (bannerError case final text?) secondFactorBanner(text),
      if (signInAgain)
        AccountDeletionSignInAgainBanner(onSignOut: widget.onSignOut),
    ],
  );
}

/// No password and no two-step verification: send a code to the account's
/// email, then type it.
class _EmailCodeStep extends StatefulWidget {
  const _EmailCodeStep({
    required this.client,
    required this.submit,
    required this.moveToReauth,
    required this.onSignOut,
  });
  final RaftClient client;
  final AccountDeletionSubmit submit;
  final void Function(AccountDeletionReauth reauth) moveToReauth;
  final VoidCallback onSignOut;

  @override
  State<_EmailCodeStep> createState() => _EmailCodeStepState();
}

class _EmailCodeStepState extends State<_EmailCodeStep>
    with SecondFactorAnswerState {
  bool sent = false, sending = false, signInAgain = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when a code is sent again and when the answer is submitted; the dialog state is dropped when it closes.
  String? notice;

  String get email => widget.client.user?.string('email') ?? '';

  Future<void> sendCode() async {
    setState(() {
      sending = true;
      notice = null;
      signInAgain = false;
      fieldError = bannerError = null;
    });
    try {
      await widget.client.sendAccountDeletionEmailCode();
      if (!mounted) return;
      answer.clear();
      setState(() => sent = true);
    } catch (error) {
      if (!mounted) return;
      // One went out a moment ago: it still works, so ask for it.
      if (SecondFactorFailure.of(error).code == 'email_code_recently_sent') {
        setState(() {
          sent = true;
          notice = raftText(
            context,
            'A code was just sent. Wait a minute before asking for another.',
          );
        });
        return;
      }
      // Never the deletion itself from here: a 409 email_code_not_available
      // names the proof to use instead, and the dialog only moves to it.
      final refusal = AccountDeletionRefusal.of(error);
      if (refusal is AccountDeletionSignInAgain) {
        setState(() => signInAgain = true);
      } else if (refusal is AccountDeletionReauthRefused) {
        widget.moveToReauth(refusal.reauth);
        Navigator.of(context).pop();
      } else {
        setState(
          () => bannerError = raftText(
            context,
            "Couldn't delete your account. Try again.",
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> send() async {
    if (!sent) return sendCode();
    if (entered.isEmpty || busy) return;
    setState(() => signInAgain = false);
    await attempt(
      () async {
        setState(() => notice = null);
        final outcome = await widget.submit(
          AccountDeletionProof.emailCode(entered),
        );
        if (!mounted) return;
        if (outcome is AccountDeletionMoved) {
          Navigator.of(context).pop();
          return;
        }
        final shown = accountDeletionFailure(
          context,
          widget.client,
          outcome,
          SecondFactorAnswerKind.totp,
        );
        setState(() {
          fieldError = shown.field;
          bannerError = shown.banner;
          signInAgain = shown.signInAgain;
        });
      },
      client: widget.client,
      kind: SecondFactorAnswerKind.totp,
      handled: (_) => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final working = busy || sending;
    return SecondFactorStepDialog(
      key: const ValueKey('account-deletion-email-code'),
      title: tr("Verify it's you"),
      busy: working,
      actions: [
        secondFactorCancel(context, busy: working),
        if (sent)
          secondFactorCommit(
            context,
            label: tr('Delete account'),
            variant: RaftButtonRecipeVariant.danger,
            busy: busy,
            onPressed: entered.isEmpty || sending ? null : send,
          )
        else
          secondFactorCommit(
            context,
            label: tr('Send code'),
            busy: sending,
            onPressed: send,
          ),
      ],
      children: [
        // Before sending, one sentence: it will send an email, and where. After,
        // the code field's label names where it went.
        if (!sent)
          RaftDialogDescription(
            raftFormat(context, "We'll email a code to {email}.", {
              'email': email,
            }),
          ),
        if (sent) ...[
          RaftField(
            label: raftFormat(context, 'Code sent to {email}', {
              'email': email,
            }),
            error: fieldError,
            child: RaftTextInput(
              key: const ValueKey('account-deletion-email-code-field'),
              controller: answer,
              autofocus: true,
              enabled: !busy,
              invalid: fieldError != null,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              semanticLabel: raftFormat(context, 'Code sent to {email}', {
                'email': email,
              }),
              onChanged: changed,
              onSubmitted: (_) => send(),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftAuthTextLink(
              key: const ValueKey('account-deletion-email-resend'),
              label: tr('Send a new code'),
              onTap: working ? null : sendCode,
            ),
          ),
        ],
        if (notice case final text?)
          secondFactorBanner(text, status: RaftBannerRecipeStatus.info),
        if (bannerError case final text?) secondFactorBanner(text),
        if (signInAgain)
          AccountDeletionSignInAgainBanner(onSignOut: widget.onSignOut),
      ],
    );
  }
}
